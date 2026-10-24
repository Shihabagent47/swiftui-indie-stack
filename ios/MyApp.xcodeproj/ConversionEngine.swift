//
//  ConversionEngine.swift
//  MyApp
//
//  Manages document conversion queue, progress tracking, and history.
//

import Foundation
import Combine

/// Central engine for managing document conversions
actor ConversionEngine {
    
    static let shared = ConversionEngine()
    
    private var activeJobs: [UUID: ConversionJob] = [:]
    private var jobQueue: [ConversionJob] = []
    private var completedJobs: [ConversionJob] = []
    private var isProcessing = false
    
    private let maxConcurrentJobs = 3
    private let maxHistorySize = 100
    
    private init() {}
    
    // MARK: - Queue Management
    
    /// Add a conversion job to the queue
    @discardableResult
    func enqueueConversion(
        _ request: ConversionRequest
    ) async throws -> UUID {
        let job = ConversionJob(
            id: UUID(),
            request: request,
            status: .queued,
            progress: 0.0,
            createdAt: Date(),
            startedAt: nil,
            completedAt: nil,
            error: nil,
            outputURL: nil
        )
        
        jobQueue.append(job)
        
        Analytics.track(event: "conversion_enqueued", properties: [
            "source_format": request.sourceFormat,
            "target_format": request.targetFormat.rawValue,
            "queue_size": jobQueue.count
        ])
        
        // Start processing if not already running
        await processQueue()
        
        return job.id
    }
    
    /// Add multiple conversion jobs
    func enqueueBatch(_ requests: [ConversionRequest]) async throws -> [UUID] {
        var jobIDs: [UUID] = []
        
        for request in requests {
            let jobID = try await enqueueConversion(request)
            jobIDs.append(jobID)
        }
        
        Analytics.track(event: "batch_conversion_enqueued", properties: [
            "count": requests.count
        ])
        
        return jobIDs
    }
    
    /// Process the conversion queue
    private func processQueue() async {
        guard !isProcessing else { return }
        guard !jobQueue.isEmpty else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        while !jobQueue.isEmpty && activeJobs.count < maxConcurrentJobs {
            guard let job = jobQueue.first else { break }
            jobQueue.removeFirst()
            
            // Start processing this job
            Task {
                await processJob(job)
            }
        }
        
        // Continue processing if queue still has items
        if !jobQueue.isEmpty {
            Task {
                await processQueue()
            }
        }
    }
    
    /// Process a single conversion job
    private func processJob(_ job: ConversionJob) async {
        var updatedJob = job
        updatedJob.status = .processing
        updatedJob.startedAt = Date()
        activeJobs[job.id] = updatedJob
        
        do {
            // Perform the conversion
            let outputURL = try await performConversion(job.request, jobID: job.id)
            
            // Update job as completed
            updatedJob.status = .completed
            updatedJob.progress = 1.0
            updatedJob.completedAt = Date()
            updatedJob.outputURL = outputURL
            
            activeJobs.removeValue(forKey: job.id)
            addToHistory(updatedJob)
            
            Analytics.track(event: "conversion_completed", properties: [
                "source_format": job.request.sourceFormat,
                "target_format": job.request.targetFormat.rawValue,
                "duration": updatedJob.completedAt!.timeIntervalSince(updatedJob.startedAt!)
            ])
            
        } catch {
            // Update job as failed
            updatedJob.status = .failed
            updatedJob.completedAt = Date()
            updatedJob.error = error
            
            activeJobs.removeValue(forKey: job.id)
            addToHistory(updatedJob)
            
            Analytics.track(event: "conversion_failed", properties: [
                "source_format": job.request.sourceFormat,
                "target_format": job.request.targetFormat.rawValue,
                "error": error.localizedDescription
            ])
        }
        
        // Continue processing queue
        await processQueue()
    }
    
    /// Perform the actual conversion
    private func performConversion(
        _ request: ConversionRequest,
        jobID: UUID
    ) async throws -> URL {
        // Update progress: Starting
        await updateProgress(jobID: jobID, progress: 0.1)
        
        switch request.operation {
        case .importToPDF:
            // Use import manager
            let url = try await DocumentImportManager.shared.importDocument(request.sourceURL)
            await updateProgress(jobID: jobID, progress: 1.0)
            return url
            
        case .exportFromPDF(let exportFormat, let quality):
            // Use export manager
            await updateProgress(jobID: jobID, progress: 0.3)
            let url = try await DocumentExportManager.shared.exportDocument(
                request.sourceURL,
                to: exportFormat,
                quality: quality
            )
            await updateProgress(jobID: jobID, progress: 1.0)
            return url
            
        case .convert(let targetFormat, let settings):
            // Generic conversion
            await updateProgress(jobID: jobID, progress: 0.2)
            let url = try await convertDocument(
                request.sourceURL,
                to: targetFormat,
                settings: settings
            )
            await updateProgress(jobID: jobID, progress: 1.0)
            return url
            
        case .optimize(let optimizationLevel):
            // Optimize PDF
            await updateProgress(jobID: jobID, progress: 0.3)
            let url = try await PDFManager.shared.compressPDF(
                request.sourceURL,
                quality: optimizationLevel.pdfQuality
            )
            await updateProgress(jobID: jobID, progress: 1.0)
            return url
        }
    }
    
    /// Generic document conversion
    private func convertDocument(
        _ sourceURL: URL,
        to targetFormat: ExportFormat,
        settings: ConversionSettings
    ) async throws -> URL {
        // Use the appropriate manager based on target format
        if targetFormat == .pdf {
            return try await DocumentImportManager.shared.importDocument(sourceURL)
        } else {
            return try await DocumentExportManager.shared.exportDocument(
                sourceURL,
                to: targetFormat,
                quality: settings.quality
            )
        }
    }
    
    // MARK: - Progress Tracking
    
    /// Update progress for a job
    private func updateProgress(jobID: UUID, progress: Double) async {
        guard var job = activeJobs[jobID] else { return }
        job.progress = progress
        activeJobs[jobID] = job
    }
    
    /// Get progress for a job
    func getProgress(for jobID: UUID) async -> Double? {
        if let activeJob = activeJobs[jobID] {
            return activeJob.progress
        }
        if let completedJob = completedJobs.first(where: { $0.id == jobID }) {
            return completedJob.progress
        }
        if let queuedJob = jobQueue.first(where: { $0.id == jobID }) {
            return queuedJob.progress
        }
        return nil
    }
    
    /// Get status for a job
    func getStatus(for jobID: UUID) async -> ConversionStatus? {
        if let activeJob = activeJobs[jobID] {
            return activeJob.status
        }
        if let completedJob = completedJobs.first(where: { $0.id == jobID }) {
            return completedJob.status
        }
        if let queuedJob = jobQueue.first(where: { $0.id == jobID }) {
            return queuedJob.status
        }
        return nil
    }
    
    /// Get full job details
    func getJob(for jobID: UUID) async -> ConversionJob? {
        if let activeJob = activeJobs[jobID] {
            return activeJob
        }
        if let completedJob = completedJobs.first(where: { $0.id == jobID }) {
            return completedJob
        }
        if let queuedJob = jobQueue.first(where: { $0.id == jobID }) {
            return queuedJob
        }
        return nil
    }
    
    // MARK: - Job Control
    
    /// Cancel a job
    func cancelJob(_ jobID: UUID) async throws {
        // Remove from queue if queued
        if let index = jobQueue.firstIndex(where: { $0.id == jobID }) {
            jobQueue.remove(at: index)
            Analytics.track(event: "conversion_cancelled", properties: ["status": "queued"])
            return
        }
        
        // Cancel if active (note: actual cancellation of in-progress work is limited)
        if var job = activeJobs[jobID] {
            job.status = .cancelled
            job.completedAt = Date()
            activeJobs.removeValue(forKey: jobID)
            addToHistory(job)
            Analytics.track(event: "conversion_cancelled", properties: ["status": "processing"])
            return
        }
        
        throw DocumentError.processingFailed(reason: "Job not found or already completed")
    }
    
    /// Retry a failed job
    func retryJob(_ jobID: UUID) async throws -> UUID {
        guard let job = completedJobs.first(where: { $0.id == jobID }),
              job.status == .failed else {
            throw DocumentError.processingFailed(reason: "Job not found or not failed")
        }
        
        // Create new job with same request
        return try await enqueueConversion(job.request)
    }
    
    // MARK: - History Management
    
    private func addToHistory(_ job: ConversionJob) {
        completedJobs.insert(job, at: 0)
        
        // Limit history size
        if completedJobs.count > maxHistorySize {
            completedJobs = Array(completedJobs.prefix(maxHistorySize))
        }
    }
    
    /// Get conversion history
    func getHistory(limit: Int = 50) async -> [ConversionJob] {
        Array(completedJobs.prefix(limit))
    }
    
    /// Clear conversion history
    func clearHistory() async {
        completedJobs.removeAll()
        Analytics.track(event: "conversion_history_cleared", properties: [:])
    }
    
    /// Get active jobs
    func getActiveJobs() async -> [ConversionJob] {
        Array(activeJobs.values)
    }
    
    /// Get queued jobs
    func getQueuedJobs() async -> [ConversionJob] {
        jobQueue
    }
    
    // MARK: - Statistics
    
    /// Get conversion statistics
    func getStatistics() async -> ConversionStatistics {
        let completed = completedJobs.filter { $0.status == .completed }.count
        let failed = completedJobs.filter { $0.status == .failed }.count
        
        let averageDuration = completedJobs
            .filter { $0.status == .completed }
            .compactMap { job -> TimeInterval? in
                guard let start = job.startedAt,
                      let end = job.completedAt else { return nil }
                return end.timeIntervalSince(start)
            }
            .reduce(0, +) / Double(max(completed, 1))
        
        return ConversionStatistics(
            totalCompleted: completed,
            totalFailed: failed,
            activeJobs: activeJobs.count,
            queuedJobs: jobQueue.count,
            averageDuration: averageDuration
        )
    }
}

// MARK: - Supporting Types

struct ConversionRequest {
    let sourceURL: URL
    let sourceFormat: String
    let targetFormat: ExportFormat
    let operation: ConversionOperation
    let settings: ConversionSettings
    
    init(
        sourceURL: URL,
        targetFormat: ExportFormat,
        operation: ConversionOperation,
        settings: ConversionSettings = ConversionSettings()
    ) {
        self.sourceURL = sourceURL
        self.sourceFormat = sourceURL.pathExtension.lowercased()
        self.targetFormat = targetFormat
        self.operation = operation
        self.settings = settings
    }
}

enum ConversionOperation {
    case importToPDF
    case exportFromPDF(format: ExportFormat, quality: ExportQuality)
    case convert(to: ExportFormat, settings: ConversionSettings)
    case optimize(level: OptimizationLevel)
}

struct ConversionSettings {
    var quality: ExportQuality
    var preserveMetadata: Bool
    var compression: Bool
    var colorSpace: ColorSpace
    
    init(
        quality: ExportQuality = .high,
        preserveMetadata: Bool = true,
        compression: Bool = true,
        colorSpace: ColorSpace = .rgb
    ) {
        self.quality = quality
        self.preserveMetadata = preserveMetadata
        self.compression = compression
        self.colorSpace = colorSpace
    }
}

enum ColorSpace: String {
    case rgb = "rgb"
    case grayscale = "grayscale"
    case cmyk = "cmyk"
}

enum OptimizationLevel {
    case low
    case medium
    case high
    case maximum
    
    var pdfQuality: PDFCompressionQuality {
        switch self {
        case .low: return .maximum
        case .medium: return .high
        case .high: return .medium
        case .maximum: return .low
        }
    }
}

struct ConversionJob: Identifiable {
    let id: UUID
    let request: ConversionRequest
    var status: ConversionStatus
    var progress: Double
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var error: Error?
    var outputURL: URL?
    
    var duration: TimeInterval? {
        guard let start = startedAt,
              let end = completedAt else { return nil }
        return end.timeIntervalSince(start)
    }
}

enum ConversionStatus: String {
    case queued = "queued"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .queued: return "Queued"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var iconName: String {
        switch self {
        case .queued: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }
}

struct ConversionStatistics {
    let totalCompleted: Int
    let totalFailed: Int
    let activeJobs: Int
    let queuedJobs: Int
    let averageDuration: TimeInterval
    
    var successRate: Double {
        let total = totalCompleted + totalFailed
        guard total > 0 else { return 0 }
        return Double(totalCompleted) / Double(total)
    }
}
