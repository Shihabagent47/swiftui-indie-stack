//
//  BackgroundProcessingManager.swift
//  MyApp
//
//  Manages background tasks for document processing, OCR, and sync.
//

import Foundation
import BackgroundTasks

/// Manages background processing tasks
actor BackgroundProcessingManager {
    
    static let shared = BackgroundProcessingManager()
    
    // Background task identifiers (must match Info.plist)
    private enum TaskIdentifier {
        static let documentProcessing = "com.yourapp.documentProcessing"
        static let ocrProcessing = "com.yourapp.ocrProcessing"
        static let cleanup = "com.yourapp.cleanup"
        static let sync = "com.yourapp.sync"
    }
    
    private let processingQueue = OperationQueue()
    
    // MARK: - Initialization
    
    private init() {
        processingQueue.maxConcurrentOperationCount = 2
        processingQueue.qualityOfService = .utility
    }
    
    // MARK: - Registration
    
    /// Register all background tasks (call from AppDelegate/App)
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifier.documentProcessing,
            using: nil
        ) { task in
            Task {
                await self.handleDocumentProcessing(task: task as! BGProcessingTask)
            }
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifier.ocrProcessing,
            using: nil
        ) { task in
            Task {
                await self.handleOCRProcessing(task: task as! BGProcessingTask)
            }
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifier.cleanup,
            using: nil
        ) { task in
            Task {
                await self.handleCleanup(task: task as! BGProcessingTask)
            }
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifier.sync,
            using: nil
        ) { task in
            Task {
                await self.handleSync(task: task as! BGProcessingTask)
            }
        }
        
        debugPrint("✅ Registered background tasks")
    }
    
    // MARK: - Scheduling
    
    /// Schedule document processing task
    func scheduleDocumentProcessing() {
        let request = BGProcessingTaskRequest(identifier: TaskIdentifier.documentProcessing)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            debugPrint("📅 Scheduled document processing task")
        } catch {
            debugPrint("❌ Failed to schedule document processing: \(error)")
        }
    }
    
    /// Schedule OCR processing task
    func scheduleOCRProcessing() {
        let request = BGProcessingTaskRequest(identifier: TaskIdentifier.ocrProcessing)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true // OCR is intensive
        
        do {
            try BGTaskScheduler.shared.submit(request)
            debugPrint("📅 Scheduled OCR processing task")
        } catch {
            debugPrint("❌ Failed to schedule OCR processing: \(error)")
        }
    }
    
    /// Schedule cleanup task
    func scheduleCleanup() {
        let request = BGProcessingTaskRequest(identifier: TaskIdentifier.cleanup)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            debugPrint("📅 Scheduled cleanup task")
        } catch {
            debugPrint("❌ Failed to schedule cleanup: \(error)")
        }
    }
    
    /// Schedule sync task
    func scheduleSync() {
        let request = BGProcessingTaskRequest(identifier: TaskIdentifier.sync)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            debugPrint("📅 Scheduled sync task")
        } catch {
            debugPrint("❌ Failed to schedule sync: \(error)")
        }
    }
    
    // MARK: - Task Handlers
    
    private func handleDocumentProcessing(task: BGProcessingTask) async {
        debugPrint("🔄 Background: Processing documents")
        
        task.expirationHandler = {
            debugPrint("⏰ Document processing task expired")
            self.processingQueue.cancelAllOperations()
        }
        
        // Process pending conversion jobs
        do {
            let repository = DocumentRepository()
            let pendingJobs = try await repository.fetchPendingConversions()
            
            for job in pendingJobs.prefix(5) { // Process max 5 in background
                guard !task.isCancelled else { break }
                
                // TODO: Implement actual conversion
                debugPrint("Processing job: \(job.id)")
            }
            
            task.setTaskCompleted(success: true)
        } catch {
            debugPrint("❌ Document processing failed: \(error)")
            task.setTaskCompleted(success: false)
        }
        
        // Schedule next run
        scheduleDocumentProcessing()
    }
    
    private func handleOCRProcessing(task: BGProcessingTask) async {
        debugPrint("🔄 Background: Processing OCR")
        
        task.expirationHandler = {
            debugPrint("⏰ OCR processing task expired")
            self.processingQueue.cancelAllOperations()
        }
        
        // TODO: Process documents that need OCR
        
        task.setTaskCompleted(success: true)
        scheduleOCRProcessing()
    }
    
    private func handleCleanup(task: BGProcessingTask) async {
        debugPrint("🔄 Background: Cleanup")
        
        task.expirationHandler = {
            debugPrint("⏰ Cleanup task expired")
        }
        
        // Cleanup temp files
        await DocumentFileManager.shared.cleanupTempFiles()
        
        // Clear old cache entries
        // TODO: Implement cache expiry logic
        
        task.setTaskCompleted(success: true)
        scheduleCleanup()
    }
    
    private func handleSync(task: BGProcessingTask) async {
        debugPrint("🔄 Background: Sync")
        
        task.expirationHandler = {
            debugPrint("⏰ Sync task expired")
        }
        
        // TODO: Implement iCloud/CloudKit sync
        
        task.setTaskCompleted(success: true)
        scheduleSync()
    }
    
    // MARK: - Foreground Processing Queue
    
    /// Add operation to foreground processing queue
    func addOperation(_ operation: Operation) {
        processingQueue.addOperation(operation)
    }
    
    /// Process document asynchronously
    func processDocument(
        _ document: Document,
        operation: @escaping (Document) async throws -> Void
    ) async throws {
        try await operation(document)
    }
}

// MARK: - Document Processing Operation

class DocumentProcessingOperation: Operation {
    
    private let document: Document
    private let processingBlock: (Document) async throws -> Void
    
    init(document: Document, processingBlock: @escaping (Document) async throws -> Void) {
        self.document = document
        self.processingBlock = processingBlock
        super.init()
    }
    
    override func main() {
        guard !isCancelled else { return }
        
        Task {
            do {
                try await processingBlock(document)
            } catch {
                debugPrint("❌ Document processing operation failed: \(error)")
            }
        }
    }
}
