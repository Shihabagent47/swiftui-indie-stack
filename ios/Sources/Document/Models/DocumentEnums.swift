//
//  DocumentEnums.swift
//  MyApp
//
//  Shared enums for document processing.
//

import Foundation
import CoreGraphics
import Combine

// MARK: - Scan Mode

enum ScanMode: String, Codable, CaseIterable {
    case color = "Color"
    case grayscale = "Grayscale"
    case blackAndWhite = "Black & White"
    case photo = "Photo"

    var displayName: String { rawValue }

    var descriptionText: String {
        switch self {
        case .color:
            return "Full color scan"
        case .grayscale:
            return "Black and white with shades of gray"
        case .blackAndWhite:
            return "Pure black and white, no gray"
        case .photo:
            return "Optimized for photos"
        }
    }
}

// MARK: - Scan Quality

enum ScanQuality: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case veryHigh = "Very High"

    var displayName: String { rawValue }

    var dpi: Int {
        switch self {
        case .low: return 150
        case .medium: return 200
        case .high: return 300
        case .veryHigh: return 600
        }
    }
}

// MARK: - Color Label

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

// MARK: - Processing Status

enum ProcessingStatus: String, Codable {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

// MARK: - Cloud Sync Status

enum CloudSyncStatus: String, Codable {
    case notSynced = "Not Synced"
    case syncing = "Syncing"
    case synced = "Synced"
    case failed = "Failed"
}

// MARK: - Document Format

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

// MARK: - PDF Quality

enum PDFQuality: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case maximum = "Maximum"

    var displayName: String { rawValue }

    var compressionQuality: CGFloat {
        switch self {
        case .low: return 0.3
        case .medium: return 0.5
        case .high: return 0.7
        case .maximum: return 1.0
        }
    }
}

// MARK: - Compression Level

enum CompressionLevel: String, Codable {
    case none = "None"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case maximum = "Maximum"

    var displayName: String { rawValue }
}

// MARK: - Scan Session Status

enum ScanSessionStatus: String, Codable {
    case active = "Active"
    case completed = "Completed"
    case cancelled = "Cancelled"
}
