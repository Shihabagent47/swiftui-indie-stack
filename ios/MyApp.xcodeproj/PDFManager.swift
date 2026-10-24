//
//  PDFManager.swift
//  MyApp
//
//  Manages PDF creation, editing, and manipulation using PDFKit.
//

import Foundation
import UIKit
import PDFKit

/// Manages PDF document creation and editing
actor PDFManager {
    
    static let shared = PDFManager()
    
    private init() {}
    
    // MARK: - PDF Creation
    
    /// Create PDF from images
    func createPDF(from images: [UIImage], title: String? = nil) async throws -> URL {
        guard !images.isEmpty else {
            throw DocumentError.processingFailed(reason: "No images provided")
        }
        
        let pdfDocument = PDFDocument()
        
        for (index, image) in images.enumerated() {
            guard let page = createPDFPage(from: image) else {
                continue
            }
            pdfDocument.insert(page, at: index)
        }
        
        // Save PDF
        let filename = "\(title ?? "Document")_\(UUID().uuidString).pdf"
        let fileURL = try await savePDF(pdfDocument, filename: filename)
        
        Analytics.track(event: "pdf_created", properties: [
            "page_count": images.count
        ])
        
        return fileURL
    }
    
    /// Create PDF page from image
    private func createPDFPage(from image: UIImage) -> PDFPage? {
        let pageRect = CGRect(origin: .zero, size: image.size)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            image.draw(in: pageRect)
        }
        
        guard let pdfDocument = PDFDocument(data: data),
              let page = pdfDocument.page(at: 0) else {
            return nil
        }
        
        return page
    }
    
    // MARK: - Page Operations
    
    /// Reorder pages in PDF
    func reorderPages(
        in pdfURL: URL,
        from sourceIndex: Int,
        to destinationIndex: Int
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        guard sourceIndex < pdfDocument.pageCount,
              destinationIndex <= pdfDocument.pageCount else {
            throw DocumentError.processingFailed(reason: "Invalid page indices")
        }
        
        guard let page = pdfDocument.page(at: sourceIndex) else {
            throw DocumentError.processingFailed(reason: "Could not get page")
        }
        
        pdfDocument.removePage(at: sourceIndex)
        pdfDocument.insert(page, at: destinationIndex)
        
        let filename = generateFilename(from: pdfURL, suffix: "reordered")
        let outputURL = try await savePDF(pdfDocument, filename: filename)
        
        Analytics.track(event: "pdf_pages_reordered")
        
        return outputURL
    }
    
    /// Delete page from PDF
    func deletePage(at index: Int, from pdfURL: URL) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        guard index < pdfDocument.pageCount else {
            throw DocumentError.processingFailed(reason: "Invalid page index")
        }
        
        guard pdfDocument.pageCount > 1 else {
            throw DocumentError.processingFailed(reason: "Cannot delete the only page")
        }
        
        pdfDocument.removePage(at: index)
        
        let filename = generateFilename(from: pdfURL, suffix: "edited")
        let outputURL = try await savePDF(pdfDocument, filename: filename)
        
        Analytics.track(event: "pdf_page_deleted")
        
        return outputURL
    }
    
    /// Insert page into PDF
    func insertPage(
        _ image: UIImage,
        at index: Int,
        into pdfURL: URL
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        guard let newPage = createPDFPage(from: image) else {
            throw DocumentError.processingFailed(reason: "Could not create page")
        }
        
        pdfDocument.insert(newPage, at: index)
        
        let filename = generateFilename(from: pdfURL, suffix: "edited")
        let outputURL = try await savePDF(pdfDocument, filename: filename)
        
        Analytics.track(event: "pdf_page_inserted")
        
        return outputURL
    }
    
    /// Rotate page in PDF
    func rotatePage(
        at index: Int,
        in pdfURL: URL,
        by degrees: Int
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        guard let page = pdfDocument.page(at: index) else {
            throw DocumentError.processingFailed(reason: "Could not get page")
        }
        
        let currentRotation = page.rotation
        let newRotation = (currentRotation + degrees) % 360
        page.rotation = newRotation
        
        let filename = generateFilename(from: pdfURL, suffix: "rotated")
        let outputURL = try await savePDF(pdfDocument, filename: filename)
        
        Analytics.track(event: "pdf_page_rotated", properties: [
            "degrees": degrees
        ])
        
        return outputURL
    }
    
    /// Rotate entire PDF
    func rotateDocument(
        _ pdfURL: URL,
        by degrees: Int
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            let currentRotation = page.rotation
            let newRotation = (currentRotation + degrees) % 360
            page.rotation = newRotation
        }
        
        let filename = generateFilename(from: pdfURL, suffix: "rotated")
        let outputURL = try await savePDF(pdfDocument, filename: filename)
        
        Analytics.track(event: "pdf_document_rotated", properties: [
            "degrees": degrees,
            "page_count": pdfDocument.pageCount
        ])
        
        return outputURL
    }
    
    // MARK: - Merge & Split
    
    /// Merge multiple PDFs into one
    func mergePDFs(_ pdfURLs: [URL], title: String? = nil) async throws -> URL {
        guard !pdfURLs.isEmpty else {
            throw DocumentError.processingFailed(reason: "No PDFs to merge")
        }
        
        let mergedDocument = PDFDocument()
        var pageIndex = 0
        
        for url in pdfURLs {
            guard let pdf = PDFDocument(url: url) else { continue }
            
            for i in 0..<pdf.pageCount {
                guard let page = pdf.page(at: i) else { continue }
                mergedDocument.insert(page, at: pageIndex)
                pageIndex += 1
            }
        }
        
        let filename = "\(title ?? "Merged")_\(UUID().uuidString).pdf"
        let outputURL = try await savePDF(mergedDocument, filename: filename)
        
        Analytics.track(event: "pdfs_merged", properties: [
            "count": pdfURLs.count,
            "total_pages": mergedDocument.pageCount
        ])
        
        return outputURL
    }
    
    /// Split PDF into individual pages
    func splitPDF(_ pdfURL: URL) async throws -> [URL] {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        var outputURLs: [URL] = []
        
        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            
            let singlePageDocument = PDFDocument()
            singlePageDocument.insert(page, at: 0)
            
            let filename = "\(pdfURL.deletingPathExtension().lastPathComponent)_page\(i+1).pdf"
            let outputURL = try await savePDF(singlePageDocument, filename: filename)
            outputURLs.append(outputURL)
        }
        
        Analytics.track(event: "pdf_split", properties: [
            "page_count": pdfDocument.pageCount
        ])
        
        return outputURLs
    }
    
    /// Extract specific pages from PDF
    func extractPages(
        from pdfURL: URL,
        pageIndices: [Int],
        title: String? = nil
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        let extractedDocument = PDFDocument()
        
        for (newIndex, originalIndex) in pageIndices.enumerated() {
            guard originalIndex < pdfDocument.pageCount,
                  let page = pdfDocument.page(at: originalIndex) else {
                continue
            }
            extractedDocument.insert(page, at: newIndex)
        }
        
        let filename = "\(title ?? "Extracted")_\(UUID().uuidString).pdf"
        let outputURL = try await savePDF(extractedDocument, filename: filename)
        
        Analytics.track(event: "pdf_pages_extracted", properties: [
            "page_count": pageIndices.count
        ])
        
        return outputURL
    }
    
    // MARK: - Annotations
    
    /// Add text annotation to PDF page
    func addTextAnnotation(
        to pdfURL: URL,
        pageIndex: Int,
        text: String,
        rect: CGRect,
        color: UIColor = .yellow
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        guard let page = pdfDocument.page(at: pageIndex) else {
            throw DocumentError.processingFailed(reason: "Could not get page")
        }
        
        let annotation = PDFAnnotation(
            bounds: rect,
            forType: .freeText,
            withProperties: nil
        )
        annotation.contents = text
        annotation.color = color
        annotation.font = UIFont.systemFont(ofSize: 12)
        
        page.addAnnotation(annotation)
        
        let filename = generateFilename(from: pdfURL, suffix: "annotated")
        let outputURL = try await savePDF(pdfDocument, filename: filename)
        
        Analytics.track(event: "pdf_text_annotation_added")
        
        return outputURL
    }
    
    /// Add highlight annotation to PDF
    func addHighlight(
        to pdfURL: URL,
        pageIndex: Int,
        rect: CGRect,
        color: UIColor = .yellow
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        guard let page = pdfDocument.page(at: pageIndex) else {
            throw DocumentError.processingFailed(reason: "Could not get page")
        }
        
        let annotation = PDFAnnotation(
            bounds: rect,
            forType: .highlight,
            withProperties: nil
        )
        annotation.color = color.withAlphaComponent(0.5)
        
        page.addAnnotation(annotation)
        
        let filename = generateFilename(from: pdfURL, suffix: "highlighted")
        let outputURL = try await savePDF(pdfDocument, filename: filename)
        
        Analytics.track(event: "pdf_highlight_added")
        
        return outputURL
    }
    
    /// Add signature to PDF
    func addSignature(
        _ signatureImage: UIImage,
        to pdfURL: URL,
        pageIndex: Int,
        rect: CGRect
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        guard let page = pdfDocument.page(at: pageIndex) else {
            throw DocumentError.processingFailed(reason: "Could not get page")
        }
        
        let annotation = PDFAnnotation(
            bounds: rect,
            forType: .stamp,
            withProperties: nil
        )
        
        // Convert signature image to PDF annotation
        if let imageData = signatureImage.pngData() {
            annotation.setValue(imageData, forAnnotationKey: .appearanceState)
        }
        
        page.addAnnotation(annotation)
        
        let filename = generateFilename(from: pdfURL, suffix: "signed")
        let outputURL = try await savePDF(pdfDocument, filename: filename)
        
        Analytics.track(event: "pdf_signature_added")
        
        return outputURL
    }
    
    // MARK: - Form Filling
    
    /// Get form fields from PDF
    func getFormFields(from pdfURL: URL) async throws -> [PDFFormField] {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        var formFields: [PDFFormField] = []
        
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            for annotation in page.annotations {
                if annotation.widgetFieldType != nil {
                    let field = PDFFormField(
                        annotation: annotation,
                        pageIndex: pageIndex
                    )
                    formFields.append(field)
                }
            }
        }
        
        return formFields
    }
    
    /// Fill form field in PDF
    func fillFormField(
        in pdfURL: URL,
        fieldName: String,
        value: String
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            for annotation in page.annotations {
                if annotation.fieldName == fieldName {
                    annotation.widgetStringValue = value
                }
            }
        }
        
        let filename = generateFilename(from: pdfURL, suffix: "filled")
        let outputURL = try await savePDF(pdfDocument, filename: filename)
        
        Analytics.track(event: "pdf_form_filled")
        
        return outputURL
    }
    
    // MARK: - Utilities
    
    private func savePDF(_ pdfDocument: PDFDocument, filename: String) async throws -> URL {
        guard let data = pdfDocument.dataRepresentation() else {
            throw DocumentError.processingFailed(reason: "Could not create PDF data")
        }
        
        return try await DocumentFileManager.shared.saveDocument(
            data: data,
            filename: filename,
            format: .pdf
        )
    }
    
    private func generateFilename(from url: URL, suffix: String) -> String {
        let baseName = url.deletingPathExtension().lastPathComponent
        return "\(baseName)_\(suffix)_\(UUID().uuidString).pdf"
    }
}

// MARK: - PDF Form Field

struct PDFFormField {
    let annotation: PDFAnnotation
    let pageIndex: Int
    
    var fieldName: String? {
        annotation.fieldName
    }
    
    var fieldType: PDFAnnotationSubtype? {
        annotation.widgetFieldType
    }
    
    var currentValue: String? {
        annotation.widgetStringValue
    }
    
    var isRequired: Bool {
        annotation.isRequired
    }
}
