//
//  DocumentImportManager.swift
//  MyApp
//
//  Manages importing various document formats and converting them to PDF.
//

import Foundation
import UIKit
import PDFKit
import QuickLook
import UniformTypeIdentifiers

/// Manages document import and format conversion
actor DocumentImportManager {
    
    static let shared = DocumentImportManager()
    
    private init() {}
    
    // MARK: - Image Import
    
    /// Import image files and convert to PDF
    func importImages(_ urls: [URL]) async throws -> URL {
        var images: [UIImage] = []
        
        for url in urls {
            guard let image = await loadImage(from: url) else {
                continue
            }
            images.append(image)
        }
        
        guard !images.isEmpty else {
            throw DocumentError.processingFailed(reason: "No valid images found")
        }
        
        // Create PDF from images
        let pdfURL = try await PDFManager.shared.createPDF(
            from: images,
            title: "Imported_\(Date().timeIntervalSince1970)"
        )
        
        Analytics.track(event: "images_imported", properties: [
            "count": urls.count
        ])
        
        return pdfURL
    }
    
    private func loadImage(from url: URL) async -> UIImage? {
        do {
            let data = try Data(contentsOf: url)
            
            // Support various image formats
            if url.pathExtension.lowercased() == "heic" {
                return UIImage(data: data)
            } else {
                return UIImage(data: data)
            }
        } catch {
            debugPrint("❌ Failed to load image: \(error)")
            return nil
        }
    }
    
    // MARK: - Office Document Import
    
    /// Import Word document and convert to PDF
    func importWordDocument(_ url: URL) async throws -> URL {
        // Use QuickLook to render Office documents
        return try await convertUsingQuickLook(url, documentType: .word)
    }
    
    /// Import Excel spreadsheet and convert to PDF
    func importExcelDocument(_ url: URL) async throws -> URL {
        return try await convertUsingQuickLook(url, documentType: .excel)
    }
    
    /// Import PowerPoint presentation and convert to PDF
    func importPowerPointDocument(_ url: URL) async throws -> URL {
        return try await convertUsingQuickLook(url, documentType: .powerpoint)
    }
    
    // MARK: - Text File Import
    
    /// Import plain text file and convert to PDF
    func importTextFile(_ url: URL) async throws -> URL {
        let text = try String(contentsOf: url, encoding: .utf8)
        return try await createPDFFromText(text, title: url.deletingPathExtension().lastPathComponent)
    }
    
    /// Import RTF file and convert to PDF
    func importRTFFile(_ url: URL) async throws -> URL {
        let data = try Data(contentsOf: url)
        
        guard let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else {
            throw DocumentError.invalidFormat
        }
        
        return try await createPDFFromAttributedText(
            attributedString,
            title: url.deletingPathExtension().lastPathComponent
        )
    }
    
    private func createPDFFromText(_ text: String, title: String) async throws -> URL {
        let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageSize)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            let textRect = pageSize.insetBy(dx: 50, dy: 50)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .paragraphStyle: paragraphStyle
            ]
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        let filename = "\(title).pdf"
        return try await DocumentFileManager.shared.saveDocument(
            data: data,
            filename: filename,
            format: .pdf
        )
    }
    
    private func createPDFFromAttributedText(
        _ attributedString: NSAttributedString,
        title: String
    ) async throws -> URL {
        let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageSize)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            let textRect = pageSize.insetBy(dx: 50, dy: 50)
            attributedString.draw(in: textRect)
        }
        
        let filename = "\(title).pdf"
        return try await DocumentFileManager.shared.saveDocument(
            data: data,
            filename: filename,
            format: .pdf
        )
    }
    
    // MARK: - HTML/Webpage Import
    
    /// Import HTML content and convert to PDF
    func importHTML(_ html: String, title: String) async throws -> URL {
        guard let data = html.data(using: .utf8),
              let attributedString = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
              ) else {
            throw DocumentError.invalidFormat
        }
        
        return try await createPDFFromAttributedText(attributedString, title: title)
    }
    
    /// Import webpage URL and convert to PDF
    func importWebpage(_ urlString: String, title: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw DocumentError.invalidFormat
        }
        
        return try await WebpageRenderer.shared.renderWebpageToPDF(url: url, title: title)
    }
    
    // MARK: - iWork Documents (Pages/Numbers/Keynote)
    
    /// Import iWork document using QuickLook
    func importiWorkDocument(_ url: URL) async throws -> URL {
        let ext = url.pathExtension.lowercased()
        
        let documentType: OfficeDocumentType
        switch ext {
        case "pages":
            documentType = .pages
        case "numbers":
            documentType = .numbers
        case "key":
            documentType = .keynote
        default:
            throw DocumentError.invalidFormat
        }
        
        return try await convertUsingQuickLook(url, documentType: documentType)
    }
    
    // MARK: - QuickLook Conversion
    
    private func convertUsingQuickLook(
        _ url: URL,
        documentType: OfficeDocumentType
    ) async throws -> URL {
        // Use QLThumbnailGenerator to create PDF representation
        let size = CGSize(width: 612, height: 792) // US Letter
        let scale = UIScreen.main.scale
        
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .all
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let thumbnail = thumbnail else {
                    continuation.resume(throwing: DocumentError.processingFailed(reason: "No thumbnail generated"))
                    return
                }
                
                // Convert thumbnail to PDF
                Task {
                    do {
                        let pdfURL = try await PDFManager.shared.createPDF(
                            from: [thumbnail.uiImage],
                            title: url.deletingPathExtension().lastPathComponent
                        )
                        continuation.resume(returning: pdfURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // MARK: - Batch Import
    
    /// Import multiple documents of various formats
    func batchImport(_ urls: [URL]) async throws -> [ImportResult] {
        var results: [ImportResult] = []
        
        for url in urls {
            do {
                let outputURL = try await importDocument(url)
                results.append(ImportResult(
                    sourceURL: url,
                    outputURL: outputURL,
                    success: true,
                    error: nil
                ))
            } catch {
                results.append(ImportResult(
                    sourceURL: url,
                    outputURL: nil,
                    success: false,
                    error: error
                ))
            }
        }
        
        Analytics.track(event: "batch_import_completed", properties: [
            "total": urls.count,
            "successful": results.filter { $0.success }.count
        ])
        
        return results
    }
    
    /// Smart import that detects format and uses appropriate method
    func importDocument(_ url: URL) async throws -> URL {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        // Images
        case "jpg", "jpeg", "png", "heic", "tiff", "tif":
            return try await importImages([url])
            
        // Office formats
        case "doc", "docx":
            return try await importWordDocument(url)
        case "xls", "xlsx":
            return try await importExcelDocument(url)
        case "ppt", "pptx":
            return try await importPowerPointDocument(url)
            
        // Text formats
        case "txt":
            return try await importTextFile(url)
        case "rtf":
            return try await importRTFFile(url)
            
        // iWork formats
        case "pages", "numbers", "key":
            return try await importiWorkDocument(url)
            
        // PDF (just copy)
        case "pdf":
            let data = try Data(contentsOf: url)
            return try await DocumentFileManager.shared.saveDocument(
                data: data,
                filename: url.lastPathComponent,
                format: .pdf
            )
            
        default:
            throw DocumentError.invalidFormat
        }
    }
    
    // MARK: - Format Detection
    
    /// Check if file format is supported for import
    func isSupportedFormat(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let supportedExtensions = [
            "jpg", "jpeg", "png", "heic", "tiff", "tif",
            "pdf",
            "doc", "docx", "xls", "xlsx", "ppt", "pptx",
            "txt", "rtf", "html",
            "pages", "numbers", "key"
        ]
        return supportedExtensions.contains(ext)
    }
    
    /// Get document type from file extension
    func getDocumentType(for url: URL) -> ImportableDocumentType? {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "jpg", "jpeg", "png", "heic", "tiff", "tif":
            return .image
        case "pdf":
            return .pdf
        case "doc", "docx":
            return .word
        case "xls", "xlsx":
            return .excel
        case "ppt", "pptx":
            return .powerpoint
        case "txt":
            return .text
        case "rtf":
            return .rtf
        case "html", "htm":
            return .html
        case "pages":
            return .pages
        case "numbers":
            return .numbers
        case "key":
            return .keynote
        default:
            return nil
        }
    }
}

// MARK: - Supporting Types

enum OfficeDocumentType {
    case word
    case excel
    case powerpoint
    case pages
    case numbers
    case keynote
}

enum ImportableDocumentType {
    case image
    case pdf
    case word
    case excel
    case powerpoint
    case text
    case rtf
    case html
    case pages
    case numbers
    case keynote
    
    var displayName: String {
        switch self {
        case .image: return "Image"
        case .pdf: return "PDF"
        case .word: return "Word Document"
        case .excel: return "Excel Spreadsheet"
        case .powerpoint: return "PowerPoint"
        case .text: return "Text File"
        case .rtf: return "Rich Text"
        case .html: return "HTML"
        case .pages: return "Pages"
        case .numbers: return "Numbers"
        case .keynote: return "Keynote"
        }
    }
    
    var icon: String {
        switch self {
        case .image: return "photo"
        case .pdf: return "doc.fill"
        case .word: return "doc.text"
        case .excel: return "tablecells"
        case .powerpoint: return "play.rectangle"
        case .text: return "doc.plaintext"
        case .rtf: return "doc.richtext"
        case .html: return "globe"
        case .pages: return "doc"
        case .numbers: return "tablecells"
        case .keynote: return "play.rectangle"
        }
    }
}

struct ImportResult {
    let sourceURL: URL
    let outputURL: URL?
    let success: Bool
    let error: Error?
}
