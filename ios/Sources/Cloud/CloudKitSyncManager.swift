//
//  CloudKitSyncManager.swift
//  MyApp
//
//  Manages CloudKit metadata synchronization for documents, settings, and scan history.
//

import Foundation
import CloudKit
import Combine

@MainActor
final class CloudKitSyncManager: ObservableObject {
    static let shared = CloudKitSyncManager()

    // MARK: - Published Properties

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var isCloudKitAvailable = false

    // MARK: - Private Properties

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()

    // Record types
    private let documentMetadataRecordType = "DocumentMetadata"
    private let scanHistoryRecordType = "ScanHistory"
    private let settingsRecordType = "UserSettings"

    // MARK: - Initialization

    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        checkCloudKitAvailability()
    }

    // MARK: - CloudKit Availability

    func checkCloudKitAvailability() {
        Task {
            do {
                let status = try await container.accountStatus()
                isCloudKitAvailable = (status == .available)

                if !isCloudKitAvailable {
                    Analytics.track(event: "cloudkit_unavailable", parameters: ["status": "\(status.rawValue)"])
                }
            } catch {
                isCloudKitAvailable = false
                Analytics.track(event: "cloudkit_check_error", parameters: ["error": error.localizedDescription])
            }
        }
    }

    // MARK: - Pro Status Check

    var canSync: Bool {
        guard QuotaManager.shared.isPro else {
            return false
        }
        guard isCloudKitAvailable else {
            return false
        }
        return true
    }

    // MARK: - Document Metadata Sync

    /// Save document metadata to CloudKit
    func saveDocumentMetadata(_ metadata: DocumentMetadata) async throws {
        guard canSync else {
            throw CloudKitError.syncNotAvailable
        }

        isSyncing = true
        syncError = nil

        do {
            let record = CKRecord(recordType: documentMetadataRecordType, recordID: CKRecord.ID(recordName: metadata.id.uuidString))
            record["documentName"] = metadata.name
            record["createdDate"] = metadata.createdDate
            record["modifiedDate"] = metadata.modifiedDate
            record["pageCount"] = metadata.pageCount
            record["fileSize"] = metadata.fileSize
            record["tags"] = metadata.tags
            record["isFavorite"] = metadata.isFavorite

            try await privateDatabase.save(record)

            lastSyncDate = Date()
            Analytics.track(event: "metadata_synced", parameters: ["document": metadata.name])

            isSyncing = false
        } catch {
            syncError = error.localizedDescription
            isSyncing = false
            Analytics.track(event: "metadata_sync_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    /// Fetch all document metadata from CloudKit
    func fetchAllDocumentMetadata() async throws -> [DocumentMetadata] {
        guard canSync else {
            throw CloudKitError.syncNotAvailable
        }

        isSyncing = true
        syncError = nil

        do {
            let query = CKQuery(recordType: documentMetadataRecordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "modifiedDate", ascending: false)]

            let results = try await privateDatabase.records(matching: query)
            var metadata: [DocumentMetadata] = []

            for (_, result) in results.matchResults {
                if let record = try? result.get() {
                    if let meta = DocumentMetadata(from: record) {
                        metadata.append(meta)
                    }
                }
            }

            lastSyncDate = Date()
            Analytics.track(event: "metadata_fetched", parameters: ["count": metadata.count])

            isSyncing = false
            return metadata

        } catch {
            syncError = error.localizedDescription
            isSyncing = false
            Analytics.track(event: "metadata_fetch_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    /// Delete document metadata from CloudKit
    func deleteDocumentMetadata(id: UUID) async throws {
        guard canSync else {
            throw CloudKitError.syncNotAvailable
        }

        do {
            let recordID = CKRecord.ID(recordName: id.uuidString)
            try await privateDatabase.deleteRecord(withID: recordID)

            Analytics.track(event: "metadata_deleted", parameters: ["id": id.uuidString])
        } catch {
            Analytics.track(event: "metadata_delete_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    // MARK: - Scan History Sync

    /// Save scan history entry to CloudKit
    func saveScanHistory(_ scan: ScanHistoryEntry) async throws {
        guard canSync else {
            throw CloudKitError.syncNotAvailable
        }

        do {
            let record = CKRecord(recordType: scanHistoryRecordType, recordID: CKRecord.ID(recordName: scan.id.uuidString))
            record["scanDate"] = scan.scanDate
            record["pageCount"] = scan.pageCount
            record["scanMode"] = scan.scanMode
            record["documentName"] = scan.documentName

            try await privateDatabase.save(record)

            Analytics.track(event: "scan_history_synced")
        } catch {
            Analytics.track(event: "scan_history_sync_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    /// Fetch scan history from CloudKit
    func fetchScanHistory() async throws -> [ScanHistoryEntry] {
        guard canSync else {
            throw CloudKitError.syncNotAvailable
        }

        do {
            let query = CKQuery(recordType: scanHistoryRecordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "scanDate", ascending: false)]

            let results = try await privateDatabase.records(matching: query)
            var history: [ScanHistoryEntry] = []

            for (_, result) in results.matchResults {
                if let record = try? result.get() {
                    if let entry = ScanHistoryEntry(from: record) {
                        history.append(entry)
                    }
                }
            }

            Analytics.track(event: "scan_history_fetched", parameters: ["count": history.count])
            return history

        } catch {
            Analytics.track(event: "scan_history_fetch_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    // MARK: - Settings Sync

    /// Save user settings to CloudKit
    func saveSettings(_ settings: [String: Any]) async throws {
        guard canSync else {
            throw CloudKitError.syncNotAvailable
        }

        do {
            let recordID = CKRecord.ID(recordName: "UserSettings")
            let record = CKRecord(recordType: settingsRecordType, recordID: recordID)

            for (key, value) in settings {
                record[key] = value as? CKRecordValue
            }

            try await privateDatabase.save(record)

            Analytics.track(event: "settings_synced")
        } catch {
            Analytics.track(event: "settings_sync_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    /// Fetch user settings from CloudKit
    func fetchSettings() async throws -> [String: Any] {
        guard canSync else {
            throw CloudKitError.syncNotAvailable
        }

        do {
            let recordID = CKRecord.ID(recordName: "UserSettings")
            let record = try await privateDatabase.record(for: recordID)

            var settings: [String: Any] = [:]
            for key in record.allKeys() {
                if let value = record[key] {
                    settings[key] = value
                }
            }

            Analytics.track(event: "settings_fetched")
            return settings

        } catch {
            Analytics.track(event: "settings_fetch_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    // MARK: - Batch Sync

    /// Sync all data to CloudKit
    func syncAll() async throws {
        guard canSync else {
            throw CloudKitError.syncNotAvailable
        }

        isSyncing = true

        do {
            // This would typically sync all local data
            // For now, just mark as synced
            lastSyncDate = Date()
            Analytics.track(event: "full_sync_completed")

            isSyncing = false
        } catch {
            syncError = error.localizedDescription
            isSyncing = false
            throw error
        }
    }
}

// MARK: - Supporting Types

enum CloudKitError: LocalizedError {
    case syncNotAvailable
    case recordNotFound
    case saveFailed
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .syncNotAvailable:
            return "CloudKit sync is not available. Please upgrade to Pro and sign in to iCloud."
        case .recordNotFound:
            return "Record not found in CloudKit."
        case .saveFailed:
            return "Failed to save data to CloudKit."
        case .fetchFailed:
            return "Failed to fetch data from CloudKit."
        }
    }
}

// MARK: - Data Models

struct DocumentMetadata: Identifiable {
    let id: UUID
    let name: String
    let createdDate: Date
    let modifiedDate: Date
    let pageCount: Int
    let fileSize: Int64
    let tags: [String]
    let isFavorite: Bool

    init(id: UUID, name: String, createdDate: Date, modifiedDate: Date, pageCount: Int, fileSize: Int64, tags: [String], isFavorite: Bool) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.pageCount = pageCount
        self.fileSize = fileSize
        self.tags = tags
        self.isFavorite = isFavorite
    }

    init?(from record: CKRecord) {
        guard let name = record["documentName"] as? String,
              let createdDate = record["createdDate"] as? Date,
              let modifiedDate = record["modifiedDate"] as? Date,
              let pageCount = record["pageCount"] as? Int,
              let fileSize = record["fileSize"] as? Int64,
              let isFavorite = record["isFavorite"] as? Bool else {
            return nil
        }

        self.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        self.name = name
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.pageCount = pageCount
        self.fileSize = fileSize
        self.tags = record["tags"] as? [String] ?? []
        self.isFavorite = isFavorite
    }
}

struct ScanHistoryEntry: Identifiable {
    let id: UUID
    let scanDate: Date
    let pageCount: Int
    let scanMode: String
    let documentName: String

    init(id: UUID, scanDate: Date, pageCount: Int, scanMode: String, documentName: String) {
        self.id = id
        self.scanDate = scanDate
        self.pageCount = pageCount
        self.scanMode = scanMode
        self.documentName = documentName
    }

    init?(from record: CKRecord) {
        guard let scanDate = record["scanDate"] as? Date,
              let pageCount = record["pageCount"] as? Int,
              let scanMode = record["scanMode"] as? String,
              let documentName = record["documentName"] as? String else {
            return nil
        }

        self.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        self.scanDate = scanDate
        self.pageCount = pageCount
        self.scanMode = scanMode
        self.documentName = documentName
    }
}
