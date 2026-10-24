//
//  DocumentModels.swift
//  MyApp
//
//  Data models for document management, scanning, and processing.
//

import Foundation
import SwiftData

// MARK: - Document Model

/// Represents a document in the library
@Model
final class Document {
    
    // MARK: - Identity
    
    @Attribute(.unique) var id: UUID
    var title: String
    var filename: String
    
    // MARK: - File Information
    
    var fileURL: URL
    var fileSize: Int64 // in bytes
    var pageCount: Int
    var fileFormat: DocumentFormat
    
    // MARK: - Dates
    
    var createdAt: Date
    var modifiedAt: Date
    var scannedAt: Date?
    
    // MARK: - Organization
    
    var folder: DocumentFolder?
    var tags: [String]
    var isFavorite: Bool
    var colorLabel: ColorLabel?
    
    // MARK: - Content & Metadata
    
    var thumbnailData: Data?
    var ocrText: String? // Extracted text for search
    var customProperties: [String: String]
    
    // MARK: - Processing Status
    
    var processingStatus: ProcessingStatus
    var compressionRatio: Double? // Original size / compressed size
    
    // MARK: - Scan-Specific
    
    var scanQuality: ScanQuality?
    var scanMode: ScanMode?
    var scans: [ScanPage]
    
    // MARK: - Cloud Sync
    
    var cloudSyncStatus: CloudSyncStatus
    var lastSyncedAt: Date?
    
    init(
        title: String,
        filename: String,
        fileURL: URL,
        fileSize: Int64,
        pageCount: Int,
        fileFormat: DocumentFormat,
        tags: [String] = [],
        scans: [ScanPage] = []
    ) {
        self.id = UUID()
        self.title = title
        self.filename = filename
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.pageCount = pageCount
        self.fileFormat = fileFormat
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.tags = tags
        self.isFavorite = false
        self.customProperties = [:]
        self.processingStatus = .completed
        self.scans = scans
        self.cloudSyncStatus = .notSynced
    }
}

// MARK: - Scan Page Model

/// Represents a single scanned page within a document
@Model
final class ScanPage {
    
    @Attribute(.unique) var id: UUID
    var pageNumber: Int
    var imageURL: URL
    var imageSize: Int64
    
    var scanQuality: ScanQuality
    var scanMode: ScanMode
    var scannedAt: Date
    
    var hasOCR: Bool
    var ocrText: String?
    var ocrConfidence: Double? // 0.0 to 1.0
    
    var edgeDetectionApplied: Bool
    var perspectiveCorrectionApplied: Bool
    var enhancementsApplied: [String] // e.g., ["brightness", "contrast", "sharpen"]
    
    var thumbnailData: Data?
    
    init(
        pageNumber: Int,
        imageURL: URL,
        imageSize: Int64,
        scanQuality: ScanQuality,
        scanMode: ScanMode
    ) {
        self.id = UUID()
        self.pageNumber = pageNumber
        self.imageURL = imageURL
        self.imageSize = imageSize
        self.scanQuality = scanQuality
        self.scanMode = scanMode
        self.scannedAt = Date()
        self.hasOCR = false
        self.edgeDetectionApplied = false
        self.perspectiveCorrectionApplied = false
        self.enhancementsApplied = []
    }
}

// MARK: - Document Folder Model

/// Represents a folder for organizing documents
@Model
final class DocumentFolder {
    
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String? // SF Symbol name
    var colorLabel: ColorLabel?
    
    var createdAt: Date
    var modifiedAt: Date
    
    var parentFolder: DocumentFolder?
    var subfolders: [DocumentFolder]
    var documents: [Document]
    
    var isSmartFolder: Bool
    var smartFolderRules: [String: String]? // JSON-encoded rules
    
    init(
        name: String,
        icon: String? = nil,
        colorLabel: ColorLabel? = nil,
        isSmartFolder: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorLabel = colorLabel
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.subfolders = []
        self.documents = []
        self.isSmartFolder = isSmartFolder
    }
    
    var documentCount: Int {
        documents.count
    }
    
    var totalSize: Int64 {
        documents.reduce(0) { $0 + $1.fileSize }
    }
}

// MARK: - Scan Session Model

/// Represents an active or completed scanning session
@Model
final class ScanSession {
    
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var completedAt: Date?
    
    var isMultiPage: Bool
    var pageCount: Int
    var scanMode: ScanMode
    var scanQuality: ScanQuality
    
    var savedDocument: Document?
    var status: ScanSessionStatus
    
    init(
        isMultiPage: Bool,
        scanMode: ScanMode,
        scanQuality: ScanQuality
    ) {
        self.id = UUID()
        self.startedAt = Date()
        self.isMultiPage = isMultiPage
        self.pageCount = 0
        self.scanMode = scanMode
        self.scanQuality = scanQuality
        self.status = .active
    }
}

// MARK: - Conversion Job Model

/// Represents a document conversion job
@Model
final class ConversionJob {
    
    @Attribute(.unique) var id: UUID
    var sourceDocument: Document
    var targetFormat: DocumentFormat
    
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    
    var status: ProcessingStatus
    var progress: Double // 0.0 to 1.0
    var errorMessage: String?
    
    var resultDocument: Document?
    
    var settings: [String: String] // JSON-encoded conversion settings
    
    init(
        sourceDocument: Document,
        targetFormat: DocumentFormat,
        settings: [String: String] = [:]
    ) {
        self.id = UUID()
        self.sourceDocument = sourceDocument
        self.targetFormat = targetFormat
        self.createdAt = Date()
        self.status = .pending
        self.progress = 0.0
        self.settings = settings
    }
}

// MARK: - User Preferences Model

/// User preferences for document processing
@Model
final class UserPreferences {
    
    @Attribute(.unique) var id: UUID
    
    // Scanning Preferences
    var defaultScanMode: ScanMode
    var defaultScanQuality: ScanQuality
    var autoEdgeDetection: Bool
    var autoPerspectiveCorrection: Bool
    var autoEnhancement: Bool
    
    // PDF Preferences
    var defaultPDFQuality: PDFQuality
    var defaultCompressionLevel: CompressionLevel
    var includeOCRInPDFs: Bool
    
    // Organization Preferences
    var defaultSaveLocation: DocumentFolder?
    var autoTagging: Bool
    var autoNaming: Bool
    var namingTemplate: String?
    
    // Quota & Limits (synced with backend)
    var dailyScanLimit: Int
    var dailyConversionLimit: Int
    var scansUsedToday: Int
    var conversionsUsedToday: Int
    var lastQuotaReset: Date
    
    // Pro Features
    var isPro: Bool
    var proExpiresAt: Date?
    
    init() {
        self.id = UUID()
        
        // Default scanning preferences
        self.defaultScanMode = .color
        self.defaultScanQuality = .high
        self.autoEdgeDetection = true
        self.autoPerspectiveCorrection = true
        self.autoEnhancement = true
        
        // Default PDF preferences
        self.defaultPDFQuality = .high
        self.defaultCompressionLevel = .medium
        self.includeOCRInPDFs = true
        
        // Default organization
        self.autoTagging = false
        self.autoNaming = true
        self.namingTemplate = "Scan {date} {time}"
        
        // Default quota (free tier)
        self.dailyScanLimit = 5
        self.dailyConversionLimit = 3
        self.scansUsedToday = 0
        self.conversionsUsedToday = 0
        self.lastQuotaReset = Date()
        
        self.isPro = false
    }
    
    var hasScansRemaining: Bool {
        isPro || scansUsedToday < dailyScanLimit
    }
    
    var hasConversionsRemaining: Bool {
        isPro || conversionsUsedToday < dailyConversionLimit
    }
    
    var scansRemaining: Int? {
        isPro ? nil : max(0, dailyScanLimit - scansUsedToday)
    }
    
    var conversionsRemaining: Int? {
        isPro ? nil : max(0, dailyConversionLimit - conversionsUsedToday)
    }
    
    func resetQuotaIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastQuotaReset) {
            scansUsedToday = 0
            conversionsUsedToday = 0
            lastQuotaReset = Date()
        }
    }
}

// MARK: - Enums

enum DocumentFormat: String, Codable {
    case pdf = "PDF"
    case jpeg = "JPEG"
    case png = "PNG"
    case heic = "HEIC"
    case tiff = "TIFF"
    case word = "DOCX"
    case excel = "XLSX"
    case powerpoint = "PPTX"
    case text = "TXT"
    case rtf = "RTF"
    case html = "HTML"
    
    var displayName: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .tiff: return "tiff"
        case .word: return "docx"
        case .excel: return "xlsx"
        case .powerpoint: return "pptx"
        case .text: return "txt"
        case .rtf: return "rtf"
        case .html: return "html"
        }
    }
    
    var isPDF: Bool { self == .pdf }
    var isImage: Bool {
        [.jpeg, .png, .heic, .tiff].contains(self)
    }
    var isOfficeDocument: Bool {
        [.word, .excel, .powerpoint].contains(self)
    }
}

enum ScanMode: String, Codable {
    case color = "Color"
    case grayscale = "Grayscale"
    case blackAndWhite = "Black & White"
    
    var displayName: String { rawValue }
}

enum ScanQuality: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case ultra = "Ultra"
    
    var displayName: String { rawValue }
    
    var dpi: Int {
        switch self {
        case .low: return 150
        case .medium: return 200
        case .high: return 300
        case .ultra: return 600
        }
    }
}

enum PDFQuality: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case lossless = "Lossless"
    
    var displayName: String { rawValue }
    
    var compressionQuality: Double {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.8
        case .lossless: return 1.0
        }
    }
}

enum CompressionLevel: String, Codable {
    case none = "None"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case maximum = "Maximum"
    
    var displayName: String { rawValue }
}

enum ProcessingStatus: String, Codable {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
    
    var displayName: String { rawValue }
    
    var isComplete: Bool { self == .completed }
    var isFailed: Bool { self == .failed }
    var isActive: Bool { self == .processing }
}

enum ScanSessionStatus: String, Codable {
    case active = "Active"
    case saved = "Saved"
    case cancelled = "Cancelled"
    
    var displayName: String { rawValue }
}

enum CloudSyncStatus: String, Codable {
    case notSynced = "Not Synced"
    case syncing = "Syncing"
    case synced = "Synced"
    case error = "Error"
    
    var displayName: String { rawValue }
}

enum ColorLabel: String, Codable, CaseIterable {
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"
    case gray = "Gray"
    
    var displayName: String { rawValue }
}

// MARK: - Errors

enum DocumentError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case corruptedFile
    case insufficientStorage
    case quotaExceeded(type: QuotaType)
    case processingFailed(reason: String)
    case networkError
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The document file could not be found."
        case .invalidFormat:
            return "This file format is not supported."
        case .corruptedFile:
            return "The file appears to be corrupted."
        case .insufficientStorage:
            return "Not enough storage space available."
        case .quotaExceeded(let type):
            return "You've reached your daily \(type.rawValue) limit. Upgrade to Pro for unlimited access."
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        case .networkError:
            return "Network connection error. Please try again."
        case .unauthorized:
            return "You don't have permission to perform this action."
        }
    }
}

enum ScanError: LocalizedError {
    case cameraUnavailable
    case permissionDenied
    case scanFailed(reason: String)
    case ocrFailed
    case qualityTooLow
    
    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is not available on this device."
        case .permissionDenied:
            return "Camera permission is required to scan documents."
        case .scanFailed(let reason):
            return "Scan failed: \(reason)"
        case .ocrFailed:
            return "Text recognition failed. The scan was saved without OCR."
        case .qualityTooLow:
            return "Image quality is too low. Please try scanning again in better lighting."
        }
    }
}

enum QuotaType: String {
    case scan = "scan"
    case conversion = "conversion"
    case export = "export"
}
