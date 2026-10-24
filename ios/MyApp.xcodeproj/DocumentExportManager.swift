//
//  DocumentExportManager.swift
//  MyApp
//
//  Manages exporting documents to various formats.
//

import Foundation
import UIKit
import PDFKit
import UniformTypeIdentifiers

/// Manages document export to various formats
actor DocumentExportManager {
    
    static let shared = DocumentExportManager()
    
    private init() {}
    
    // MARK: - Image Export
    
    /// Export PDF to individual images
    func exportPDFToImages(
        _ pdfURL: URL,
        format: ImageExportFormat = .jpeg,
        quality: ExportQuality = .high
    ) async throws -> [URL] {
        guard let document = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        var imageURLs: [URL] = []
        let pageCount = document.pageCount
        
        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex) else {
                continue
            }
            
            let imageURL = try await exportPDFPageToImage(
                page,
                pageNumber: pageIndex + 1,
                format: format,
                quality: quality
            )
            imageURLs.append(imageURL)
        }
        
        Analytics.track(event: "pdf_exported_to_images", properties: [
            "page_count": pageCount,
            "format": format.rawValue,
            "quality": quality.rawValue
        ])
        
        return imageURLs
    }
    
    private func exportPDFPageToImage(
        _ page: PDFPage,
        pageNumber: Int,
        format: ImageExportFormat,
        quality: ExportQuality
    ) async throws -> URL {
        let bounds = page.bounds(for: .mediaBox)
        
        // Determine scale based on quality
        let scale: CGFloat = switch quality {
        case .low: 1.0
        case .medium: 2.0
        case .high: 3.0
        case .maximum: 4.0
        }
        
        let scaledSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.saveGState()
            context.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
        
        // Convert to data with appropriate format
        let data: Data
        let fileExtension: String
        
        switch format {
        case .jpeg:
            let compressionQuality = quality.imageCompressionQuality
            guard let jpegData = image.jpegData(compressionQuality: compressionQuality) else {
                throw DocumentError.processingFailed(reason: "Failed to create JPEG data")
            }
            data = jpegData
            fileExtension = "jpg"
            
        case .png:
            guard let pngData = image.pngData() else {
                throw DocumentError.processingFailed(reason: "Failed to create PNG data")
            }
            data = pngData
            fileExtension = "png"
            
        case .tiff:
            guard let tiffData = image.jpegData(compressionQuality: 1.0) else {
                throw DocumentError.processingFailed(reason: "Failed to create TIFF data")
            }
            data = tiffData
            fileExtension = "tiff"
        }
        
        let filename = "Page_\(pageNumber)_\(Date().timeIntervalSince1970).\(fileExtension)"
        return try await DocumentFileManager.shared.saveDocument(
            data: data,
            filename: filename,
            format: .image
        )
    }
    
    // MARK: - Text Export
    
    /// Export PDF text content to text file
    func exportPDFToText(_ pdfURL: URL) async throws -> URL {
        let text = try await OCRManager.shared.extractText(from: pdfURL)
        
        guard !text.isEmpty else {
            throw DocumentError.processingFailed(reason: "No text content found in PDF")
        }
        
        guard let data = text.data(using: .utf8) else {
            throw DocumentError.processingFailed(reason: "Failed to encode text")
        }
        
        let filename = pdfURL.deletingPathExtension().lastPathComponent + ".txt"
        let url = try await DocumentFileManager.shared.saveDocument(
            data: data,
            filename: filename,
            format: .text
        )
        
        Analytics.track(event: "pdf_exported_to_text", properties: [
            "character_count": text.count
        ])
        
        return url
    }
    
    /// Export images to text file (OCR)
    func exportImagesToText(_ imageURLs: [URL]) async throws -> URL {
        var combinedText = ""
        
        for (index, url) in imageURLs.enumerated() {
            guard let image = UIImage(contentsOfFile: url.path) else {
                continue
            }
            
            let text = try await OCRManager.shared.performOCR(on: image)
            
            if !text.isEmpty {
                if index > 0 {
                    combinedText += "\n\n--- Page \(index + 1) ---\n\n"
                }
                combinedText += text
            }
        }
        
        guard !combinedText.isEmpty else {
            throw DocumentError.processingFailed(reason: "No text content found in images")
        }
        
        guard let data = combinedText.data(using: .utf8) else {
            throw DocumentError.processingFailed(reason: "Failed to encode text")
        }
        
        let filename = "Exported_Text_\(Date().timeIntervalSince1970).txt"
        return try await DocumentFileManager.shared.saveDocument(
            data: data,
            filename: filename,
            format: .text
        )
    }
    
    // MARK: - RTF Export
    
    /// Export text to RTF with basic formatting
    func exportToRTF(_ text: String, title: String) async throws -> URL {
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.label
            ]
        )
        
        return try await exportAttributedStringToRTF(attributedString, title: title)
    }
    
    /// Export attributed string to RTF
    func exportAttributedStringToRTF(
        _ attributedString: NSAttributedString,
        title: String
    ) async throws -> URL {
        let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        
        guard let rtfData = try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: documentAttributes
        ) else {
            throw DocumentError.processingFailed(reason: "Failed to create RTF data")
        }
        
        let filename = "\(title).rtf"
        return try await DocumentFileManager.shared.saveDocument(
            data: rtfData,
            filename: filename,
            format: .text
        )
    }
    
    // MARK: - HTML Export
    
    /// Export text to HTML
    func exportToHTML(_ text: String, title: String) async throws -> URL {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                    line-height: 1.6;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 20px;
                    color: #333;
                }
                pre {
                    white-space: pre-wrap;
                    word-wrap: break-word;
                }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            <pre>\(text.htmlEscaped)</pre>
        </body>
        </html>
        """
        
        guard let data = html.data(using: .utf8) else {
            throw DocumentError.processingFailed(reason: "Failed to encode HTML")
        }
        
        let filename = "\(title).html"
        return try await DocumentFileManager.shared.saveDocument(
            data: data,
            filename: filename,
            format: .html
        )
    }
    
    /// Export PDF to HTML (text content only)
    func exportPDFToHTML(_ pdfURL: URL) async throws -> URL {
        let text = try await OCRManager.shared.extractText(from: pdfURL)
        let title = pdfURL.deletingPathExtension().lastPathComponent
        return try await exportToHTML(text, title: title)
    }
    
    // MARK: - Word Document Export
    
    /// Export text to Word document (.docx)
    /// Note: This creates a basic RTF which can be opened in Word
    func exportToWord(_ text: String, title: String) async throws -> URL {
        // For basic Word export, we can use RTF which is compatible
        // For true .docx, would need a third-party library like ZIPFoundation
        let url = try await exportToRTF(text, title: title)
        
        // Rename to .doc extension for better compatibility
        let docURL = url.deletingPathExtension().appendingPathExtension("doc")
        try FileManager.default.moveItem(at: url, to: docURL)
        
        Analytics.track(event: "exported_to_word", properties: [:])
        
        return docURL
    }
    
    // MARK: - CSV Export (for structured data)
    
    /// Export structured data to CSV
    func exportToCSV(
        headers: [String],
        rows: [[String]],
        filename: String
    ) async throws -> URL {
        var csvContent = headers.joined(separator: ",") + "\n"
        
        for row in rows {
            let escapedRow = row.map { field in
                // Escape fields containing commas or quotes
                if field.contains(",") || field.contains("\"") {
                    return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return field
            }
            csvContent += escapedRow.joined(separator: ",") + "\n"
        }
        
        guard let data = csvContent.data(using: .utf8) else {
            throw DocumentError.processingFailed(reason: "Failed to encode CSV")
        }
        
        let csvFilename = filename.hasSuffix(".csv") ? filename : "\(filename).csv"
        return try await DocumentFileManager.shared.saveDocument(
            data: data,
            filename: csvFilename,
            format: .text
        )
    }
    
    // MARK: - Batch Export
    
    /// Export multiple PDFs to images
    func batchExportPDFsToImages(
        _ pdfURLs: [URL],
        format: ImageExportFormat = .jpeg,
        quality: ExportQuality = .high
    ) async throws -> [BatchExportResult] {
        var results: [BatchExportResult] = []
        
        for pdfURL in pdfURLs {
            do {
                let imageURLs = try await exportPDFToImages(
                    pdfURL,
                    format: format,
                    quality: quality
                )
                
                results.append(BatchExportResult(
                    sourceURL: pdfURL,
                    outputURLs: imageURLs,
                    success: true,
                    error: nil
                ))
            } catch {
                results.append(BatchExportResult(
                    sourceURL: pdfURL,
                    outputURLs: [],
                    success: false,
                    error: error
                ))
            }
        }
        
        Analytics.track(event: "batch_export_completed", properties: [
            "total": pdfURLs.count,
            "successful": results.filter { $0.success }.count,
            "format": format.rawValue
        ])
        
        return results
    }
    
    /// Export multiple documents to specified format
    func batchExport(
        _ urls: [URL],
        to exportFormat: ExportFormat,
        quality: ExportQuality = .high
    ) async throws -> [BatchExportResult] {
        var results: [BatchExportResult] = []
        
        for url in urls {
            do {
                let outputURL = try await exportDocument(
                    url,
                    to: exportFormat,
                    quality: quality
                )
                
                results.append(BatchExportResult(
                    sourceURL: url,
                    outputURLs: [outputURL],
                    success: true,
                    error: nil
                ))
            } catch {
                results.append(BatchExportResult(
                    sourceURL: url,
                    outputURLs: [],
                    success: false,
                    error: error
                ))
            }
        }
        
        return results
    }
    
    /// Smart export that handles different source formats
    func exportDocument(
        _ url: URL,
        to exportFormat: ExportFormat,
        quality: ExportQuality = .high
    ) async throws -> URL {
        let sourceExtension = url.pathExtension.lowercased()
        
        switch exportFormat {
        case .jpeg, .png, .tiff:
            // Export to image
            let imageFormat = ImageExportFormat(rawValue: exportFormat.rawValue) ?? .jpeg
            
            if sourceExtension == "pdf" {
                let imageURLs = try await exportPDFToImages(url, format: imageFormat, quality: quality)
                guard let firstURL = imageURLs.first else {
                    throw DocumentError.processingFailed(reason: "No images generated")
                }
                return firstURL
            } else {
                // Already an image, just copy/convert
                guard let image = UIImage(contentsOfFile: url.path) else {
                    throw DocumentError.invalidFormat
                }
                
                let data: Data
                let ext: String
                
                switch imageFormat {
                case .jpeg:
                    guard let jpegData = image.jpegData(compressionQuality: quality.imageCompressionQuality) else {
                        throw DocumentError.processingFailed(reason: "Failed to create JPEG")
                    }
                    data = jpegData
                    ext = "jpg"
                case .png:
                    guard let pngData = image.pngData() else {
                        throw DocumentError.processingFailed(reason: "Failed to create PNG")
                    }
                    data = pngData
                    ext = "png"
                case .tiff:
                    guard let tiffData = image.jpegData(compressionQuality: 1.0) else {
                        throw DocumentError.processingFailed(reason: "Failed to create TIFF")
                    }
                    data = tiffData
                    ext = "tiff"
                }
                
                let filename = "\(url.deletingPathExtension().lastPathComponent).\(ext)"
                return try await DocumentFileManager.shared.saveDocument(
                    data: data,
                    filename: filename,
                    format: .image
                )
            }
            
        case .text:
            if sourceExtension == "pdf" {
                return try await exportPDFToText(url)
            } else {
                throw DocumentError.processingFailed(reason: "Text export only supported for PDFs")
            }
            
        case .html:
            if sourceExtension == "pdf" {
                return try await exportPDFToHTML(url)
            } else {
                throw DocumentError.processingFailed(reason: "HTML export only supported for PDFs")
            }
            
        case .rtf:
            if sourceExtension == "pdf" {
                let text = try await OCRManager.shared.extractText(from: url)
                let title = url.deletingPathExtension().lastPathComponent
                return try await exportToRTF(text, title: title)
            } else {
                throw DocumentError.processingFailed(reason: "RTF export only supported for PDFs")
            }
            
        case .word:
            if sourceExtension == "pdf" {
                let text = try await OCRManager.shared.extractText(from: url)
                let title = url.deletingPathExtension().lastPathComponent
                return try await exportToWord(text, title: title)
            } else {
                throw DocumentError.processingFailed(reason: "Word export only supported for PDFs")
            }
            
        case .pdf:
            // If already PDF, return as-is
            if sourceExtension == "pdf" {
                return url
            } else {
                // Convert to PDF using import manager
                return try await DocumentImportManager.shared.importDocument(url)
            }
        }
    }
}

// MARK: - Supporting Types

enum ImageExportFormat: String {
    case jpeg = "jpeg"
    case png = "png"
    case tiff = "tiff"
    
    var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .tiff: return .tiff
        }
    }
}

enum ExportFormat: String {
    case jpeg = "jpeg"
    case png = "png"
    case tiff = "tiff"
    case text = "text"
    case html = "html"
    case rtf = "rtf"
    case word = "word"
    case pdf = "pdf"
    
    var displayName: String {
        switch self {
        case .jpeg: return "JPEG Image"
        case .png: return "PNG Image"
        case .tiff: return "TIFF Image"
        case .text: return "Plain Text"
        case .html: return "HTML"
        case .rtf: return "Rich Text Format"
        case .word: return "Word Document"
        case .pdf: return "PDF Document"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .tiff: return "tiff"
        case .text: return "txt"
        case .html: return "html"
        case .rtf: return "rtf"
        case .word: return "doc"
        case .pdf: return "pdf"
        }
    }
}

enum ExportQuality: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case maximum = "maximum"
    
    var imageCompressionQuality: CGFloat {
        switch self {
        case .low: return 0.5
        case .medium: return 0.7
        case .high: return 0.85
        case .maximum: return 1.0
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .maximum: return "Maximum"
        }
    }
}

struct BatchExportResult {
    let sourceURL: URL
    let outputURLs: [URL]
    let success: Bool
    let error: Error?
}

// MARK: - String Extension

private extension String {
    var htmlEscaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
