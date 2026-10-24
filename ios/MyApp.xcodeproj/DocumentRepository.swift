//
//  DocumentRepository.swift
//  MyApp
//
//  Repository pattern for document data access operations.
//

import Foundation
import SwiftData

/// Repository for managing document data operations
@MainActor
class DocumentRepository {
    
    private let context: ModelContext
    
    init(context: ModelContext = DocumentContainer.shared.mainContext) {
        self.context = context
    }
    
    // MARK: - Document Operations
    
    /// Fetch all documents
    func fetchAllDocuments() throws -> [Document] {
        let descriptor = FetchDescriptor<Document>(
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Fetch documents in a specific folder
    func fetchDocuments(in folder: DocumentFolder) throws -> [Document] {
        let descriptor = FetchDescriptor<Document>(
            predicate: #Predicate { document in
                document.folder?.id == folder.id
            },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Fetch favorite documents
    func fetchFavoriteDocuments() throws -> [Document] {
        let descriptor = FetchDescriptor<Document>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Fetch recent documents (last 30 days)
    func fetchRecentDocuments(limit: Int = 20) throws -> [Document] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        
        let descriptor = FetchDescriptor<Document>(
            predicate: #Predicate { document in
                document.modifiedAt >= thirtyDaysAgo
            },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return try context.fetch(descriptor)
    }
    
    /// Search documents by title or OCR text
    func searchDocuments(query: String) throws -> [Document] {
        let lowercasedQuery = query.lowercased()
        
        let descriptor = FetchDescriptor<Document>(
            predicate: #Predicate { document in
                document.title.localizedStandardContains(query) ||
                (document.ocrText?.localizedStandardContains(query) ?? false)
            },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        
        return try context.fetch(descriptor)
    }
    
    /// Fetch documents by format
    func fetchDocuments(format: DocumentFormat) throws -> [Document] {
        let descriptor = FetchDescriptor<Document>(
            predicate: #Predicate { $0.fileFormat == format },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Save a new document
    func saveDocument(_ document: Document) throws {
        context.insert(document)
        try context.save()
        
        Analytics.track(event: "document_saved", properties: [
            "format": document.fileFormat.rawValue,
            "page_count": document.pageCount,
            "file_size": document.fileSize
        ])
    }
    
    /// Update an existing document
    func updateDocument(_ document: Document) throws {
        document.modifiedAt = Date()
        try context.save()
    }
    
    /// Delete a document
    func deleteDocument(_ document: Document) throws {
        // Delete associated files
        try? FileManager.default.removeItem(at: document.fileURL)
        
        // Delete scan page images
        for scan in document.scans {
            try? FileManager.default.removeItem(at: scan.imageURL)
        }
        
        context.delete(document)
        try context.save()
        
        Analytics.track(event: "document_deleted")
    }
    
    /// Delete multiple documents
    func deleteDocuments(_ documents: [Document]) throws {
        for document in documents {
            try? FileManager.default.removeItem(at: document.fileURL)
            for scan in document.scans {
                try? FileManager.default.removeItem(at: scan.imageURL)
            }
            context.delete(document)
        }
        try context.save()
        
        Analytics.track(event: "documents_bulk_deleted", properties: [
            "count": documents.count
        ])
    }
    
    /// Get document by ID
    func getDocument(id: UUID) throws -> Document? {
        let descriptor = FetchDescriptor<Document>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    // MARK: - Folder Operations
    
    /// Fetch all folders
    func fetchAllFolders() throws -> [DocumentFolder] {
        let descriptor = FetchDescriptor<DocumentFolder>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Fetch root folders (no parent)
    func fetchRootFolders() throws -> [DocumentFolder] {
        let descriptor = FetchDescriptor<DocumentFolder>(
            predicate: #Predicate { $0.parentFolder == nil },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Create a new folder
    func createFolder(name: String, parent: DocumentFolder? = nil) throws -> DocumentFolder {
        let folder = DocumentFolder(name: name)
        folder.parentFolder = parent
        
        context.insert(folder)
        try context.save()
        
        Analytics.track(event: "folder_created")
        
        return folder
    }
    
    /// Delete a folder
    func deleteFolder(_ folder: DocumentFolder) throws {
        // Move documents to parent folder or root
        for document in folder.documents {
            document.folder = folder.parentFolder
        }
        
        // Delete subfolders recursively
        for subfolder in folder.subfolders {
            try deleteFolder(subfolder)
        }
        
        context.delete(folder)
        try context.save()
        
        Analytics.track(event: "folder_deleted")
    }
    
    /// Move document to folder
    func moveDocument(_ document: Document, to folder: DocumentFolder?) throws {
        document.folder = folder
        document.modifiedAt = Date()
        try context.save()
    }
    
    // MARK: - Scan Session Operations
    
    /// Create a new scan session
    func createScanSession(
        isMultiPage: Bool,
        scanMode: ScanMode,
        scanQuality: ScanQuality
    ) throws -> ScanSession {
        let session = ScanSession(
            isMultiPage: isMultiPage,
            scanMode: scanMode,
            scanQuality: scanQuality
        )
        
        context.insert(session)
        try context.save()
        
        Analytics.track(event: "scan_session_started", properties: [
            "multi_page": isMultiPage,
            "scan_mode": scanMode.rawValue,
            "quality": scanQuality.rawValue
        ])
        
        return session
    }
    
    /// Complete a scan session
    func completeScanSession(_ session: ScanSession, savedDocument: Document) throws {
        session.completedAt = Date()
        session.savedDocument = savedDocument
        session.status = .saved
        try context.save()
        
        Analytics.track(event: "scan_session_completed", properties: [
            "page_count": session.pageCount
        ])
    }
    
    /// Cancel a scan session
    func cancelScanSession(_ session: ScanSession) throws {
        session.status = .cancelled
        try context.save()
        
        Analytics.track(event: "scan_session_cancelled")
    }
    
    // MARK: - Conversion Job Operations
    
    /// Create a conversion job
    func createConversionJob(
        source: Document,
        targetFormat: DocumentFormat,
        settings: [String: String] = [:]
    ) throws -> ConversionJob {
        let job = ConversionJob(
            sourceDocument: source,
            targetFormat: targetFormat,
            settings: settings
        )
        
        context.insert(job)
        try context.save()
        
        Analytics.track(event: "conversion_job_created", properties: [
            "source_format": source.fileFormat.rawValue,
            "target_format": targetFormat.rawValue
        ])
        
        return job
    }
    
    /// Update conversion job progress
    func updateConversionProgress(_ job: ConversionJob, progress: Double) throws {
        job.progress = progress
        try context.save()
    }
    
    /// Complete a conversion job
    func completeConversionJob(_ job: ConversionJob, result: Document) throws {
        job.completedAt = Date()
        job.resultDocument = result
        job.status = .completed
        try context.save()
        
        Analytics.track(event: "conversion_completed")
    }
    
    /// Fail a conversion job
    func failConversionJob(_ job: ConversionJob, error: String) throws {
        job.status = .failed
        job.errorMessage = error
        try context.save()
        
        Analytics.track(event: "conversion_failed", properties: [
            "error": error
        ])
    }
    
    /// Fetch pending conversion jobs
    func fetchPendingConversions() throws -> [ConversionJob] {
        let descriptor = FetchDescriptor<ConversionJob>(
            predicate: #Predicate { $0.status == .pending },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }
    
    // MARK: - User Preferences
    
    /// Get user preferences (creates if doesn't exist)
    func getUserPreferences() throws -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>()
        
        if let preferences = try context.fetch(descriptor).first {
            preferences.resetQuotaIfNeeded()
            return preferences
        }
        
        // Create new preferences
        let preferences = UserPreferences()
        context.insert(preferences)
        try context.save()
        
        return preferences
    }
    
    /// Update user preferences
    func updatePreferences(_ preferences: UserPreferences) throws {
        try context.save()
    }
    
    /// Record scan usage (for quota tracking)
    func recordScanUsage() throws {
        let preferences = try getUserPreferences()
        preferences.resetQuotaIfNeeded()
        preferences.scansUsedToday += 1
        try context.save()
        
        Analytics.track(event: "scan_quota_used", properties: [
            "remaining": preferences.scansRemaining as Any
        ])
    }
    
    /// Record conversion usage (for quota tracking)
    func recordConversionUsage() throws {
        let preferences = try getUserPreferences()
        preferences.resetQuotaIfNeeded()
        preferences.conversionsUsedToday += 1
        try context.save()
        
        Analytics.track(event: "conversion_quota_used", properties: [
            "remaining": preferences.conversionsRemaining as Any
        ])
    }
    
    /// Check if user can scan
    func canPerformScan() throws -> Bool {
        let preferences = try getUserPreferences()
        preferences.resetQuotaIfNeeded()
        return preferences.hasScansRemaining
    }
    
    /// Check if user can convert
    func canPerformConversion() throws -> Bool {
        let preferences = try getUserPreferences()
        preferences.resetQuotaIfNeeded()
        return preferences.hasConversionsRemaining
    }
    
    // MARK: - Statistics
    
    /// Get total document count
    func getTotalDocumentCount() throws -> Int {
        let descriptor = FetchDescriptor<Document>()
        return try context.fetchCount(descriptor)
    }
    
    /// Get total storage used
    func getTotalStorageUsed() throws -> Int64 {
        let documents = try fetchAllDocuments()
        return documents.reduce(0) { $0 + $1.fileSize }
    }
    
    /// Get documents by format statistics
    func getDocumentCountByFormat() throws -> [DocumentFormat: Int] {
        let documents = try fetchAllDocuments()
        var stats: [DocumentFormat: Int] = [:]
        
        for document in documents {
            stats[document.fileFormat, default: 0] += 1
        }
        
        return stats
    }
}
