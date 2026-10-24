//
//  DocumentFileManager.swift
//  MyApp
//
//  Manages file system operations for documents, including secure storage,
//  organization, and file lifecycle management.
//

import Foundation
import UIKit
import UniformTypeIdentifiers

/// Manages file system operations for documents
actor DocumentFileManager {
    
    static let shared = DocumentFileManager()
    
    private let fileManager = FileManager.default
    
    // MARK: - Directory Structure
    
    private enum Directory {
        case documents
        case scans
        case thumbnails
        case temp
        case cache
        
        var url: URL {
            let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            
            switch self {
            case .documents:
                return baseURL.appendingPathComponent("Documents", isDirectory: true)
            case .scans:
                return baseURL.appendingPathComponent("Scans", isDirectory: true)
            case .thumbnails:
                return baseURL.appendingPathComponent("Thumbnails", isDirectory: true)
            case .temp:
                return baseURL.appendingPathComponent("Temp", isDirectory: true)
            case .cache:
                return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        Task {
            await createDirectoryStructure()
        }
    }
    
    /// Create directory structure if it doesn't exist
    private func createDirectoryStructure() {
        let directories: [Directory] = [.documents, .scans, .thumbnails, .temp, .cache]
        
        for directory in directories {
            let url = directory.url
            
            if !fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.createDirectory(
                        at: url,
                        withIntermediateDirectories: true,
                        attributes: [.protectionKey: FileProtectionType.complete]
                    )
                    debugPrint("✅ Created directory: \(directory)")
                } catch {
                    debugPrint("❌ Failed to create directory \(directory): \(error)")
                }
            }
        }
    }
    
    // MARK: - Document Storage
    
    /// Save a document file to secure storage
    func saveDocument(data: Data, filename: String, format: DocumentFormat) throws -> URL {
        let sanitizedFilename = sanitizeFilename(filename)
        let fullFilename = ensureExtension(sanitizedFilename, for: format)
        let fileURL = Directory.documents.url.appendingPathComponent(fullFilename)
        
        // Check available storage
        guard hasAvailableStorage(requiredBytes: Int64(data.count)) else {
            throw DocumentError.insufficientStorage
        }
        
        // Write with file protection
        try data.write(
            to: fileURL,
            options: [.atomic, .completeFileProtection]
        )
        
        Analytics.track(event: "document_file_saved", properties: [
            "format": format.rawValue,
            "size": data.count
        ])
        
        return fileURL
    }
    
    /// Save a scanned image
    func saveScanImage(image: UIImage, quality: ScanQuality, format: ImageFormat = .jpeg) throws -> URL {
        let filename = generateScanFilename(format: format)
        let fileURL = Directory.scans.url.appendingPathComponent(filename)
        
        guard let data = image.imageData(format: format, quality: quality.compressionQuality) else {
            throw DocumentError.processingFailed(reason: "Failed to convert image to data")
        }
        
        guard hasAvailableStorage(requiredBytes: Int64(data.count)) else {
            throw DocumentError.insufficientStorage
        }
        
        try data.write(
            to: fileURL,
            options: [.atomic, .completeFileProtection]
        )
        
        return fileURL
    }
    
    /// Save a thumbnail
    func saveThumbnail(image: UIImage, documentID: UUID) throws -> Data {
        let thumbnailSize = CGSize(width: 200, height: 200)
        
        guard let thumbnail = image.preparingThumbnail(of: thumbnailSize),
              let data = thumbnail.jpegData(compressionQuality: 0.7) else {
            throw DocumentError.processingFailed(reason: "Failed to create thumbnail")
        }
        
        return data
    }
    
    /// Load a document file
    func loadDocument(at url: URL) throws -> Data {
        guard fileManager.fileExists(atPath: url.path) else {
            throw DocumentError.fileNotFound
        }
        
        return try Data(contentsOf: url)
    }
    
    /// Delete a document file
    func deleteDocument(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return // Already deleted
        }
        
        try fileManager.removeItem(at: url)
        
        Analytics.track(event: "document_file_deleted")
    }
    
    /// Move a document file
    func moveDocument(from sourceURL: URL, to destinationURL: URL) throws {
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }
    
    /// Copy a document file
    func copyDocument(from sourceURL: URL, to destinationURL: URL) throws {
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }
    
    // MARK: - File Organization
    
    /// Create a folder for organizing documents
    func createFolder(name: String, parentURL: URL? = nil) throws -> URL {
        let baseURL = parentURL ?? Directory.documents.url
        let folderURL = baseURL.appendingPathComponent(sanitizeFilename(name), isDirectory: true)
        
        try fileManager.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        
        return folderURL
    }
    
    /// Delete a folder and its contents
    func deleteFolder(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }
    
    /// List all files in a directory
    func listFiles(in directoryURL: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
    }
    
    // MARK: - File Format Detection
    
    /// Detect file format from data
    func detectFormat(data: Data) -> DocumentFormat? {
        // Check magic numbers
        if data.isPDF {
            return .pdf
        } else if data.isJPEG {
            return .jpeg
        } else if data.isPNG {
            return .png
        } else if data.isHEIC {
            return .heic
        } else if data.isTIFF {
            return .tiff
        }
        
        return nil
    }
    
    /// Detect format from file extension
    func detectFormat(filename: String) -> DocumentFormat? {
        let ext = (filename as NSString).pathExtension.lowercased()
        
        switch ext {
        case "pdf": return .pdf
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "heic": return .heic
        case "tif", "tiff": return .tiff
        case "docx": return .word
        case "xlsx": return .excel
        case "pptx": return .powerpoint
        case "txt": return .text
        case "rtf": return .rtf
        case "html", "htm": return .html
        default: return nil
        }
    }
    
    /// Get UTType for a document format
    func getUTType(for format: DocumentFormat) -> UTType {
        switch format {
        case .pdf: return .pdf
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        case .tiff: return .tiff
        case .word: return UTType(filenameExtension: "docx") ?? .data
        case .excel: return UTType(filenameExtension: "xlsx") ?? .data
        case .powerpoint: return UTType(filenameExtension: "pptx") ?? .data
        case .text: return .plainText
        case .rtf: return .rtf
        case .html: return .html
        }
    }
    
    // MARK: - File Size & Storage
    
    /// Get file size in bytes
    func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    /// Get total size of all documents
    func getTotalDocumentsSize() throws -> Int64 {
        var totalSize: Int64 = 0
        
        let directories = [Directory.documents.url, Directory.scans.url]
        
        for directory in directories {
            if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(size)
                    }
                }
            }
        }
        
        return totalSize
    }
    
    /// Check available storage space
    func getAvailableStorage() -> Int64 {
        if let attributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = attributes[.systemFreeSize] as? Int64 {
            return freeSize
        }
        return 0
    }
    
    /// Check if there's enough storage for a file
    func hasAvailableStorage(requiredBytes: Int64) -> Bool {
        let available = getAvailableStorage()
        let buffer: Int64 = 50 * 1024 * 1024 // Keep 50 MB buffer
        return available > (requiredBytes + buffer)
    }
    
    // MARK: - Temporary File Management
    
    /// Create a temporary file
    func createTempFile(data: Data, extension ext: String) throws -> URL {
        let filename = "\(UUID().uuidString).\(ext)"
        let tempURL = Directory.temp.url.appendingPathComponent(filename)
        
        try data.write(to: tempURL, options: [.atomic])
        
        return tempURL
    }
    
    /// Clean up old temporary files (older than 24 hours)
    func cleanupTempFiles() async {
        let tempDirectory = Directory.temp.url
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        
        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
        var deletedCount = 0
        
        for fileURL in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < twentyFourHoursAgo {
                try? fileManager.removeItem(at: fileURL)
                deletedCount += 1
            }
        }
        
        if deletedCount > 0 {
            debugPrint("🧹 Cleaned up \(deletedCount) temporary files")
        }
    }
    
    // MARK: - Cache Management
    
    /// Get cache directory for a specific type
    func getCacheDirectory(for type: String) -> URL {
        Directory.cache.url.appendingPathComponent(type, isDirectory: true)
    }
    
    /// Clear cache for a specific type
    func clearCache(type: String) async throws {
        let cacheURL = getCacheDirectory(for: type)
        
        if fileManager.fileExists(atPath: cacheURL.path) {
            try fileManager.removeItem(at: cacheURL)
            try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
            
            debugPrint("🧹 Cleared cache: \(type)")
        }
    }
    
    /// Clear all caches
    func clearAllCaches() async throws {
        let cacheDirectory = Directory.cache.url
        
        if let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for url in contents {
                try? fileManager.removeItem(at: url)
            }
            debugPrint("🧹 Cleared all caches")
        }
    }
    
    /// Get total cache size
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        let cacheDirectory = Directory.cache.url
        
        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        
        return totalSize
    }
    
    // MARK: - External Storage Support
    
    /// Check if iCloud Drive is available
    func isICloudAvailable() -> Bool {
        fileManager.ubiquityIdentityToken != nil
    }
    
    /// Get iCloud container URL
    func getICloudContainerURL() -> URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
    }
    
    /// Export document to Files app
    func prepareForFilesAppExport(url: URL) throws -> URL {
        // Files in the Documents directory are automatically available in Files app
        // If the file is elsewhere, copy it to Documents
        if !url.path.contains(Directory.documents.url.path) {
            let filename = url.lastPathComponent
            let exportURL = Directory.documents.url.appendingPathComponent(filename)
            try fileManager.copyItem(at: url, to: exportURL)
            return exportURL
        }
        return url
    }
    
    // MARK: - Utilities
    
    /// Sanitize filename to remove invalid characters
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return filename.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
    
    /// Ensure filename has correct extension
    private func ensureExtension(_ filename: String, for format: DocumentFormat) -> String {
        let ext = (filename as NSString).pathExtension
        if ext.isEmpty {
            return "\(filename).\(format.fileExtension)"
        }
        return filename
    }
    
    /// Generate unique filename for scan
    private func generateScanFilename(format: ImageFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        return "Scan_\(dateString)_\(UUID().uuidString.prefix(8)).\(format.fileExtension)"
    }
}

// MARK: - Image Format Enum

enum ImageFormat {
    case jpeg
    case png
    case heic
    
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        }
    }
}

// MARK: - Data Extensions for Format Detection

extension Data {
    
    var isPDF: Bool {
        guard count >= 4 else { return false }
        return self[0] == 0x25 && self[1] == 0x50 && self[2] == 0x44 && self[3] == 0x46 // %PDF
    }
    
    var isJPEG: Bool {
        guard count >= 2 else { return false }
        return self[0] == 0xFF && self[1] == 0xD8
    }
    
    var isPNG: Bool {
        guard count >= 8 else { return false }
        return self[0] == 0x89 && self[1] == 0x50 && self[2] == 0x4E && self[3] == 0x47
    }
    
    var isHEIC: Bool {
        guard count >= 12 else { return false }
        // Check for 'ftyp' at offset 4 and 'heic' or 'heix' at offset 8
        return self[4] == 0x66 && self[5] == 0x74 && self[6] == 0x79 && self[7] == 0x70
    }
    
    var isTIFF: Bool {
        guard count >= 4 else { return false }
        // Little endian: 0x49 0x49 0x2A 0x00
        // Big endian: 0x4D 0x4D 0x00 0x2A
        return (self[0] == 0x49 && self[1] == 0x49 && self[2] == 0x2A && self[3] == 0x00) ||
               (self[0] == 0x4D && self[1] == 0x4D && self[2] == 0x00 && self[3] == 0x2A)
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    
    /// Convert image to data with format and quality
    func imageData(format: ImageFormat, quality: Double) -> Data? {
        switch format {
        case .jpeg:
            return jpegData(compressionQuality: quality)
        case .png:
            return pngData()
        case .heic:
            if #available(iOS 17.0, *) {
                return heicData(compressionQuality: quality)
            } else {
                return jpegData(compressionQuality: quality)
            }
        }
    }
}

// MARK: - ScanQuality Extension

extension ScanQuality {
    
    var compressionQuality: Double {
        switch self {
        case .low: return 0.5
        case .medium: return 0.7
        case .high: return 0.85
        case .ultra: return 0.95
        }
    }
}
