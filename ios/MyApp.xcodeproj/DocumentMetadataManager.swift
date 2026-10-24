//
//  DocumentMetadataManager.swift
//  MyApp
//
//  Manager for document metadata, properties, and versioning.
//

import Foundation
import PDFKit
import SwiftData

actor DocumentMetadataManager {
    
    static let shared = DocumentMetadataManager()
    
    private init() {}
    
    // MARK: - Metadata Extraction
    
    /// Extract metadata from a document file
    func extractMetadata(from url: URL, format: DocumentFormat) async throws -> DocumentMetadata {
        switch format {
        case .pdf:
            return try await extractPDFMetadata(from: url)
        case .jpeg, .png, .heic, .tiff:
            return try await extractImageMetadata(from: url)
        default:
            return try await extractGenericMetadata(from: url)
        }
    }
    
    private func extractPDFMetadata(from url: URL) async throws -> DocumentMetadata {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        let attributes = pdfDocument.documentAttributes
        
        var metadata = DocumentMetadata(fileURL: url)
        
        // Basic info
        metadata.title = attributes?[PDFDocumentAttribute.titleAttribute] as? String
        metadata.author = attributes?[PDFDocumentAttribute.authorAttribute] as? String
        metadata.subject = attributes?[PDFDocumentAttribute.subjectAttribute] as? String
        metadata.keywords = (attributes?[PDFDocumentAttribute.keywordsAttribute] as? [String]) ?? []
        metadata.creator = attributes?[PDFDocumentAttribute.creatorAttribute] as? String
        metadata.producer = attributes?[PDFDocumentAttribute.producerAttribute] as? String
        
        // Dates
        metadata.creationDate = attributes?[PDFDocumentAttribute.creationDateAttribute] as? Date
        metadata.modificationDate = attributes?[PDFDocumentAttribute.modificationDateAttribute] as? Date
        
        // Document info
        metadata.pageCount = pdfDocument.pageCount
        
        if let firstPage = pdfDocument.page(at: 0) {
            let pageSize = firstPage.bounds(for: .mediaBox).size
            metadata.pageSize = pageSize
        }
        
        // Security
        metadata.isEncrypted = pdfDocument.isEncrypted
        metadata.isLocked = pdfDocument.isLocked
        
        // Permissions
        if !pdfDocument.isLocked {
            metadata.allowsPrinting = pdfDocument.allowsPrinting
            metadata.allowsCopying = pdfDocument.allowsCopying
        }
        
        Analytics.track(event: "metadata_extracted", properties: [
            "format": "pdf",
            "has_author": metadata.author != nil,
            "is_encrypted": metadata.isEncrypted
        ])
        
        return metadata
    }
    
    private func extractImageMetadata(from url: URL) async throws -> DocumentMetadata {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw DocumentError.invalidFormat
        }
        
        var metadata = DocumentMetadata(fileURL: url)
        metadata.pageCount = 1
        
        // Image dimensions
        if let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
           let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
            metadata.pageSize = CGSize(width: width, height: height)
            metadata.imageDimensions = (width, height)
        }
        
        // Color info
        if let colorModel = properties[kCGImagePropertyColorModel as String] as? String {
            metadata.colorSpace = colorModel
        }
        
        if let depth = properties[kCGImagePropertyDepth as String] as? Int {
            metadata.bitDepth = depth
        }
        
        // DPI
        if let dpiWidth = properties[kCGImagePropertyDPIWidth as String] as? Double,
           let dpiHeight = properties[kCGImagePropertyDPIHeight as String] as? Double {
            metadata.dpi = (dpiWidth, dpiHeight)
        }
        
        // EXIF data
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            metadata.exifData = exif
            
            if let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                metadata.creationDate = parseExifDate(dateString)
            }
        }
        
        Analytics.track(event: "metadata_extracted", properties: [
            "format": "image",
            "has_exif": metadata.exifData != nil
        ])
        
        return metadata
    }
    
    private func extractGenericMetadata(from url: URL) async throws -> DocumentMetadata {
        var metadata = DocumentMetadata(fileURL: url)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        
        metadata.fileSize = attributes[.size] as? Int64 ?? 0
        metadata.creationDate = attributes[.creationDate] as? Date
        metadata.modificationDate = attributes[.modificationDate] as? Date
        
        return metadata
    }
    
    // MARK: - Metadata Updates
    
    /// Update PDF metadata
    func updatePDFMetadata(
        url: URL,
        title: String? = nil,
        author: String? = nil,
        subject: String? = nil,
        keywords: [String]? = nil
    ) async throws {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        var attributes = pdfDocument.documentAttributes ?? [:]
        
        if let title = title {
            attributes[PDFDocumentAttribute.titleAttribute] = title
        }
        
        if let author = author {
            attributes[PDFDocumentAttribute.authorAttribute] = author
        }
        
        if let subject = subject {
            attributes[PDFDocumentAttribute.subjectAttribute] = subject
        }
        
        if let keywords = keywords {
            attributes[PDFDocumentAttribute.keywordsAttribute] = keywords
        }
        
        attributes[PDFDocumentAttribute.modificationDateAttribute] = Date()
        
        pdfDocument.documentAttributes = attributes
        
        // Save updated PDF
        guard pdfDocument.write(to: url) else {
            throw DocumentError.processingFailed(reason: "Failed to save updated metadata")
        }
        
        Analytics.track(event: "metadata_updated", properties: [
            "format": "pdf"
        ])
    }
    
    // MARK: - Custom Properties
    
    /// Save custom properties to extended attributes
    func saveCustomProperties(_ properties: [String: String], to url: URL) async throws {
        let data = try JSONEncoder().encode(properties)
        
        try url.setExtendedAttribute(
            data: data,
            forName: "com.myapp.customProperties"
        )
        
        Analytics.track(event: "custom_properties_saved", properties: [
            "property_count": properties.count
        ])
    }
    
    /// Load custom properties from extended attributes
    func loadCustomProperties(from url: URL) async throws -> [String: String] {
        guard let data = try url.extendedAttribute(forName: "com.myapp.customProperties") else {
            return [:]
        }
        
        return try JSONDecoder().decode([String: String].self, from: data)
    }
    
    // MARK: - Versioning
    
    /// Create a version snapshot of a document
    func createVersion(_ document: Document) async throws -> DocumentVersion {
        let version = DocumentVersion(
            documentID: document.id,
            versionNumber: await getNextVersionNumber(for: document),
            fileURL: document.fileURL,
            fileSize: document.fileSize,
            modifiedAt: document.modifiedAt
        )
        
        // Copy file to versions directory
        let versionURL = try await copyToVersionsDirectory(document.fileURL, versionID: version.id)
        version.versionFileURL = versionURL
        
        Analytics.track(event: "version_created", properties: [
            "version_number": version.versionNumber
        ])
        
        return version
    }
    
    /// Restore a document from a version
    func restoreVersion(_ version: DocumentVersion, to document: Document) async throws {
        guard let versionURL = version.versionFileURL else {
            throw DocumentError.fileNotFound
        }
        
        // Create backup of current version
        _ = try await createVersion(document)
        
        // Copy version file to document location
        try FileManager.default.removeItem(at: document.fileURL)
        try FileManager.default.copyItem(at: versionURL, to: document.fileURL)
        
        document.modifiedAt = Date()
        
        Analytics.track(event: "version_restored", properties: [
            "version_number": version.versionNumber
        ])
    }
    
    /// Get all versions for a document
    func getVersions(for document: Document, modelContext: ModelContext) async throws -> [DocumentVersion] {
        let descriptor = FetchDescriptor<DocumentVersion>(
            predicate: #Predicate { $0.documentID == document.id },
            sortBy: [SortDescriptor(\DocumentVersion.versionNumber, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    private func getNextVersionNumber(for document: Document) async -> Int {
        // TODO: Query existing versions and return next number
        return 1
    }
    
    private func copyToVersionsDirectory(_ url: URL, versionID: UUID) async throws -> URL {
        let versionsDir = try DocumentFileManager.shared.getVersionsDirectory()
        let versionURL = versionsDir.appendingPathComponent(versionID.uuidString + "_" + url.lastPathComponent)
        
        try FileManager.default.copyItem(at: url, to: versionURL)
        
        return versionURL
    }
    
    // MARK: - Helpers
    
    private func parseExifDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }
}

// MARK: - Document Metadata

struct DocumentMetadata {
    let fileURL: URL
    
    // Basic info
    var title: String?
    var author: String?
    var subject: String?
    var keywords: [String] = []
    var creator: String?
    var producer: String?
    
    // Dates
    var creationDate: Date?
    var modificationDate: Date?
    
    // Document info
    var pageCount: Int = 0
    var pageSize: CGSize?
    var fileSize: Int64 = 0
    
    // Image-specific
    var imageDimensions: (width: Int, height: Int)?
    var dpi: (width: Double, height: Double)?
    var colorSpace: String?
    var bitDepth: Int?
    var exifData: [String: Any]?
    
    // Security
    var isEncrypted = false
    var isLocked = false
    var allowsPrinting = true
    var allowsCopying = true
}

// MARK: - Document Version

@Model
final class DocumentVersion {
    @Attribute(.unique) var id: UUID
    var documentID: UUID
    var versionNumber: Int
    
    var fileURL: URL
    var versionFileURL: URL?
    var fileSize: Int64
    
    var createdAt: Date
    var modifiedAt: Date
    
    var changeDescription: String?
    
    init(
        documentID: UUID,
        versionNumber: Int,
        fileURL: URL,
        fileSize: Int64,
        modifiedAt: Date
    ) {
        self.id = UUID()
        self.documentID = documentID
        self.versionNumber = versionNumber
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.createdAt = Date()
        self.modifiedAt = modifiedAt
    }
}

// MARK: - URL Extensions

extension URL {
    func setExtendedAttribute(data: Data, forName name: String) throws {
        try data.withUnsafeBytes { bytes in
            let result = setxattr(
                path,
                name,
                bytes.baseAddress,
                data.count,
                0,
                0
            )
            
            if result == -1 {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        }
    }
    
    func extendedAttribute(forName name: String) throws -> Data? {
        let length = getxattr(path, name, nil, 0, 0, 0)
        
        guard length >= 0 else {
            if errno == ENOATTR {
                return nil
            }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        
        var data = Data(count: length)
        
        let result = data.withUnsafeMutableBytes { bytes in
            getxattr(path, name, bytes.baseAddress, data.count, 0, 0)
        }
        
        guard result >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        
        return data
    }
}
