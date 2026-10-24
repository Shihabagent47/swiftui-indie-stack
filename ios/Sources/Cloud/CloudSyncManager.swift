//
//  CloudSyncManager.swift
//  MyApp
//
//  Manages iCloud Drive document synchronization for Pro users.
//

import Foundation
import Combine
import UIKit

@MainActor
final class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()

    // MARK: - Published Properties

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var syncProgress: Double = 0.0
    @Published var isCloudAvailable = false

    // MARK: - Private Properties

    private var metadataQuery: NSMetadataQuery?
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()

    // MARK: - iCloud Container

    private var ubiquityURL: URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)
    }

    private var documentsURL: URL? {
        ubiquityURL?.appendingPathComponent("Documents")
    }

    // MARK: - Initialization

    private init() {
        checkCloudAvailability()
        setupMetadataQuery()
    }

    // MARK: - Cloud Availability

    func checkCloudAvailability() {
        isCloudAvailable = ubiquityURL != nil

        if !isCloudAvailable {
            Analytics.track(event: "icloud_unavailable")
        }

        // Monitor for iCloud availability changes
        NotificationCenter.default.publisher(for: .NSUbiquityIdentityDidChange)
            .sink { [weak self] _ in
                self?.checkCloudAvailability()
            }
            .store(in: &cancellables)
    }

    // MARK: - Pro Status Check

    var canSync: Bool {
        guard QuotaManager.shared.isPro else {
            Analytics.track(event: "sync_blocked_not_pro")
            return false
        }
        guard isCloudAvailable else {
            Analytics.track(event: "sync_blocked_no_icloud")
            return false
        }
        return true
    }

    // MARK: - Sync Operations

    /// Sync a document to iCloud Drive
    func syncDocument(at localURL: URL) async throws {
        guard canSync else {
            throw CloudSyncError.syncNotAvailable
        }

        guard let documentsURL = documentsURL else {
            throw CloudSyncError.containerNotFound
        }

        isSyncing = true
        syncError = nil

        do {
            // Create documents directory if needed
            try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)

            let fileName = localURL.lastPathComponent
            let cloudURL = documentsURL.appendingPathComponent(fileName)

            // Copy file to iCloud
            if fileManager.fileExists(atPath: cloudURL.path) {
                try fileManager.removeItem(at: cloudURL)
            }

            try fileManager.copyItem(at: localURL, to: cloudURL)

            lastSyncDate = Date()
            Analytics.track(event: "document_synced", parameters: ["filename": fileName])

            isSyncing = false
        } catch {
            syncError = error.localizedDescription
            isSyncing = false
            Analytics.track(event: "sync_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    /// Download a document from iCloud Drive
    func downloadDocument(at cloudURL: URL, to localURL: URL) async throws {
        guard canSync else {
            throw CloudSyncError.syncNotAvailable
        }

        isSyncing = true
        syncError = nil

        do {
            // Start downloading if needed
            try fileManager.startDownloadingUbiquitousItem(at: cloudURL)

            // Wait for download to complete
            var isDownloading = true
            while isDownloading {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                var resourceValues = try cloudURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                let status = resourceValues.ubiquitousItemDownloadingStatus

                if status == .current {
                    isDownloading = false
                }
            }

            // Copy to local URL
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }

            try fileManager.copyItem(at: cloudURL, to: localURL)

            lastSyncDate = Date()
            Analytics.track(event: "document_downloaded", parameters: ["filename": cloudURL.lastPathComponent])

            isSyncing = false
        } catch {
            syncError = error.localizedDescription
            isSyncing = false
            Analytics.track(event: "download_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    /// Sync all local documents to iCloud
    func syncAllDocuments() async throws {
        guard canSync else {
            throw CloudSyncError.syncNotAvailable
        }

        let localDocuments = try getLocalDocuments()
        let total = Double(localDocuments.count)

        for (index, documentURL) in localDocuments.enumerated() {
            syncProgress = Double(index + 1) / total
            try await syncDocument(at: documentURL)
        }

        syncProgress = 0.0
        Analytics.track(event: "all_documents_synced", parameters: ["count": localDocuments.count])
    }

    /// Delete document from iCloud
    func deleteCloudDocument(at cloudURL: URL) async throws {
        guard canSync else {
            throw CloudSyncError.syncNotAvailable
        }

        do {
            try fileManager.removeItem(at: cloudURL)
            Analytics.track(event: "cloud_document_deleted", parameters: ["filename": cloudURL.lastPathComponent])
        } catch {
            Analytics.track(event: "cloud_delete_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    // MARK: - Metadata Query

    private func setupMetadataQuery() {
        metadataQuery = NSMetadataQuery()
        metadataQuery?.predicate = NSPredicate(format: "%K LIKE '*.pdf'", NSMetadataItemFSNameKey)
        metadataQuery?.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        NotificationCenter.default.publisher(for: .NSMetadataQueryDidFinishGathering, object: metadataQuery)
            .sink { [weak self] _ in
                self?.processMetadataResults()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .NSMetadataQueryDidUpdate, object: metadataQuery)
            .sink { [weak self] _ in
                self?.processMetadataResults()
            }
            .store(in: &cancellables)
    }

    func startMonitoring() {
        guard canSync else { return }
        metadataQuery?.start()
        Analytics.track(event: "cloud_monitoring_started")
    }

    func stopMonitoring() {
        metadataQuery?.stop()
        Analytics.track(event: "cloud_monitoring_stopped")
    }

    private func processMetadataResults() {
        guard let query = metadataQuery else { return }

        Analytics.track(event: "cloud_documents_found", parameters: ["count": query.resultCount])
    }

    // MARK: - Helper Methods

    private func getLocalDocuments() throws -> [URL] {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let contents = try fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
        return contents.filter { $0.pathExtension == "pdf" }
    }

    func getCloudDocuments() throws -> [URL] {
        guard let documentsURL = documentsURL else {
            throw CloudSyncError.containerNotFound
        }

        guard fileManager.fileExists(atPath: documentsURL.path) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
        return contents.filter { $0.pathExtension == "pdf" }
    }

    // MARK: - Conflict Resolution

    func resolveConflict(localURL: URL, cloudURL: URL, keepVersion: ConflictResolution) async throws {
        switch keepVersion {
        case .local:
            try await syncDocument(at: localURL)
            Analytics.track(event: "conflict_resolved_keep_local")

        case .cloud:
            try await downloadDocument(at: cloudURL, to: localURL)
            Analytics.track(event: "conflict_resolved_keep_cloud")

        case .both:
            // Keep both by renaming local file
            let localFileName = localURL.deletingPathExtension().lastPathComponent
            let localExt = localURL.pathExtension
            let newName = "\(localFileName)_local.\(localExt)"
            let newLocalURL = localURL.deletingLastPathComponent().appendingPathComponent(newName)

            try fileManager.moveItem(at: localURL, to: newLocalURL)
            try await syncDocument(at: newLocalURL)
            try await downloadDocument(at: cloudURL, to: localURL)
            Analytics.track(event: "conflict_resolved_keep_both")
        }
    }
}

// MARK: - Supporting Types

enum CloudSyncError: LocalizedError {
    case syncNotAvailable
    case containerNotFound
    case downloadFailed
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .syncNotAvailable:
            return "Cloud sync is not available. Please upgrade to Pro and enable iCloud Drive."
        case .containerNotFound:
            return "iCloud container not found. Please enable iCloud Drive in Settings."
        case .downloadFailed:
            return "Failed to download document from iCloud."
        case .uploadFailed:
            return "Failed to upload document to iCloud."
        }
    }
}

enum ConflictResolution {
    case local
    case cloud
    case both
}
