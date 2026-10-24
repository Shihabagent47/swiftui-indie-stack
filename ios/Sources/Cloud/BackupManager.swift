//
//  BackupManager.swift
//  MyApp
//
//  Manages automatic backups and restore functionality for Pro users.
//

import Foundation
import Combine
import UIKit

@MainActor
final class BackupManager: ObservableObject {
    static let shared = BackupManager()

    // MARK: - Published Properties

    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var lastBackupDate: Date?
    @Published var backupError: String?
    @Published var backupProgress: Double = 0.0
    @Published var availableBackups: [Backup] = []
    @Published var autoBackupEnabled = true
    @Published var backupFrequency: BackupFrequency = .daily

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    private let backupQueue = DispatchQueue(label: "com.myapp.backup", qos: .utility)

    // Storage keys
    private enum StorageKeys {
        static let lastBackupDate = "lastBackupDate"
        static let autoBackupEnabled = "autoBackupEnabled"
        static let backupFrequency = "backupFrequency"
    }

    // MARK: - Backup Directory

    private var backupDirectory: URL? {
        guard let ubiquityURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        return ubiquityURL.appendingPathComponent("Backups")
    }

    private var localDocumentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Initialization

    private init() {
        loadSettings()
        setupAutoBackup()
    }

    // MARK: - Settings

    private func loadSettings() {
        if let lastBackup = UserDefaults.standard.object(forKey: StorageKeys.lastBackupDate) as? Date {
            lastBackupDate = lastBackup
        }

        autoBackupEnabled = UserDefaults.standard.bool(forKey: StorageKeys.autoBackupEnabled)

        if let frequencyRaw = UserDefaults.standard.string(forKey: StorageKeys.backupFrequency),
           let frequency = BackupFrequency(rawValue: frequencyRaw) {
            backupFrequency = frequency
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(lastBackupDate, forKey: StorageKeys.lastBackupDate)
        UserDefaults.standard.set(autoBackupEnabled, forKey: StorageKeys.autoBackupEnabled)
        UserDefaults.standard.set(backupFrequency.rawValue, forKey: StorageKeys.backupFrequency)
    }

    // MARK: - Pro Status Check

    var canBackup: Bool {
        guard QuotaManager.shared.isPro else {
            Analytics.track(event: "backup_blocked_not_pro")
            return false
        }
        guard backupDirectory != nil else {
            Analytics.track(event: "backup_blocked_no_icloud")
            return false
        }
        return true
    }

    // MARK: - Auto Backup

    private func setupAutoBackup() {
        // Check if backup is needed on app launch
        Timer.publish(every: 3600, on: .main, in: .common) // Check every hour
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.performAutoBackupIfNeeded()
                }
            }
            .store(in: &cancellables)

        // Also check when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.performAutoBackupIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    private func performAutoBackupIfNeeded() async {
        guard autoBackupEnabled && canBackup else { return }

        let shouldBackup: Bool
        if let lastBackup = lastBackupDate {
            let timeSinceLastBackup = Date().timeIntervalSince(lastBackup)
            shouldBackup = timeSinceLastBackup >= backupFrequency.interval
        } else {
            shouldBackup = true
        }

        if shouldBackup {
            do {
                try await createBackup(automatic: true)
            } catch {
                Analytics.track(event: "auto_backup_failed", parameters: ["error": error.localizedDescription])
            }
        }
    }

    // MARK: - Backup Operations

    /// Create a new backup
    func createBackup(automatic: Bool = false) async throws {
        guard canBackup else {
            throw BackupError.backupNotAvailable
        }

        guard !isBackingUp else {
            throw BackupError.backupInProgress
        }

        guard let backupDir = backupDirectory else {
            throw BackupError.directoryNotFound
        }

        isBackingUp = true
        backupError = nil
        backupProgress = 0.0

        do {
            // Create backup directory if needed
            try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)

            // Create timestamped backup folder
            let timestamp = Date().timeIntervalSince1970
            let backupName = automatic ? "auto_\(Int(timestamp))" : "manual_\(Int(timestamp))"
            let thisBackupDir = backupDir.appendingPathComponent(backupName)
            try fileManager.createDirectory(at: thisBackupDir, withIntermediateDirectories: true)

            // Get all documents to backup
            let documents = try getDocumentsToBackup()
            let total = Double(documents.count)

            // Copy each document
            for (index, documentURL) in documents.enumerated() {
                backupProgress = Double(index + 1) / total

                let fileName = documentURL.lastPathComponent
                let destinationURL = thisBackupDir.appendingPathComponent(fileName)

                try fileManager.copyItem(at: documentURL, to: destinationURL)
            }

            // Create backup manifest
            let manifest = BackupManifest(
                date: Date(),
                documentCount: documents.count,
                automatic: automatic,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            )

            let manifestData = try JSONEncoder().encode(manifest)
            let manifestURL = thisBackupDir.appendingPathComponent("manifest.json")
            try manifestData.write(to: manifestURL)

            // Update state
            lastBackupDate = Date()
            saveSettings()

            backupProgress = 0.0
            isBackingUp = false

            Analytics.track(event: "backup_created", parameters: [
                "automatic": automatic,
                "document_count": documents.count
            ])

            // Refresh available backups
            try await loadAvailableBackups()

        } catch {
            backupError = error.localizedDescription
            backupProgress = 0.0
            isBackingUp = false
            Analytics.track(event: "backup_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    /// Restore from a backup
    func restoreBackup(_ backup: Backup) async throws {
        guard canBackup else {
            throw BackupError.backupNotAvailable
        }

        guard !isRestoring else {
            throw BackupError.restoreInProgress
        }

        guard let backupDir = backupDirectory else {
            throw BackupError.directoryNotFound
        }

        isRestoring = true
        backupError = nil

        do {
            let thisBackupDir = backupDir.appendingPathComponent(backup.name)

            // Get all files in backup
            let backupContents = try fileManager.contentsOfDirectory(at: thisBackupDir, includingPropertiesForKeys: nil)
            let documents = backupContents.filter { $0.lastPathComponent != "manifest.json" }

            // Clear current documents (with confirmation)
            // In a real app, you'd want to show a confirmation dialog first

            // Copy documents from backup
            for documentURL in documents {
                let fileName = documentURL.lastPathComponent
                let destinationURL = localDocumentsDirectory.appendingPathComponent(fileName)

                // Remove existing file if present
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }

                try fileManager.copyItem(at: documentURL, to: destinationURL)
            }

            isRestoring = false

            Analytics.track(event: "backup_restored", parameters: [
                "backup_name": backup.name,
                "document_count": documents.count
            ])

        } catch {
            backupError = error.localizedDescription
            isRestoring = false
            Analytics.track(event: "restore_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    /// Delete a backup
    func deleteBackup(_ backup: Backup) async throws {
        guard let backupDir = backupDirectory else {
            throw BackupError.directoryNotFound
        }

        do {
            let thisBackupDir = backupDir.appendingPathComponent(backup.name)
            try fileManager.removeItem(at: thisBackupDir)

            Analytics.track(event: "backup_deleted", parameters: ["backup_name": backup.name])

            // Refresh available backups
            try await loadAvailableBackups()

        } catch {
            Analytics.track(event: "backup_delete_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    /// Load all available backups
    func loadAvailableBackups() async throws {
        guard let backupDir = backupDirectory else {
            availableBackups = []
            return
        }

        guard fileManager.fileExists(atPath: backupDir.path) else {
            availableBackups = []
            return
        }

        do {
            let contents = try fileManager.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.creationDateKey])

            var backups: [Backup] = []

            for folder in contents where folder.hasDirectoryPath {
                let manifestURL = folder.appendingPathComponent("manifest.json")

                if let manifestData = try? Data(contentsOf: manifestURL),
                   let manifest = try? JSONDecoder().decode(BackupManifest.self, from: manifestData) {

                    let backup = Backup(
                        name: folder.lastPathComponent,
                        date: manifest.date,
                        documentCount: manifest.documentCount,
                        automatic: manifest.automatic,
                        size: try? getFolderSize(url: folder)
                    )
                    backups.append(backup)
                }
            }

            availableBackups = backups.sorted { $0.date > $1.date }

        } catch {
            Analytics.track(event: "backup_list_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    // MARK: - Helper Methods

    private func getDocumentsToBackup() throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(at: localDocumentsDirectory, includingPropertiesForKeys: nil)
        return contents.filter { $0.pathExtension == "pdf" }
    }

    private func getFolderSize(url: URL) throws -> Int64 {
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
        var totalSize: Int64 = 0

        for fileURL in contents {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += Int64(resourceValues.fileSize ?? 0)
        }

        return totalSize
    }
}

// MARK: - Supporting Types

enum BackupError: LocalizedError {
    case backupNotAvailable
    case directoryNotFound
    case backupInProgress
    case restoreInProgress
    case backupNotFound

    var errorDescription: String? {
        switch self {
        case .backupNotAvailable:
            return "Backup is not available. Please upgrade to Pro and enable iCloud Drive."
        case .directoryNotFound:
            return "Backup directory not found."
        case .backupInProgress:
            return "A backup is already in progress."
        case .restoreInProgress:
            return "A restore is already in progress."
        case .backupNotFound:
            return "Backup not found."
        }
    }
}

enum BackupFrequency: String, CaseIterable {
    case hourly = "Hourly"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var interval: TimeInterval {
        switch self {
        case .hourly: return 3600
        case .daily: return 86400
        case .weekly: return 604800
        case .monthly: return 2592000
        }
    }

    var description: String {
        rawValue
    }
}

struct Backup: Identifiable {
    let id = UUID()
    let name: String
    let date: Date
    let documentCount: Int
    let automatic: Bool
    let size: Int64?

    var sizeFormatted: String {
        guard let size = size else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var typeLabel: String {
        automatic ? "Automatic" : "Manual"
    }
}

struct BackupManifest: Codable {
    let date: Date
    let documentCount: Int
    let automatic: Bool
    let appVersion: String
}
