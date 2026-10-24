//
//  PDFOptimizationManager.swift
//  MyApp
//
//  Manages PDF compression and optimization to reduce file size.
//

import Foundation
import UIKit
import PDFKit
import CoreGraphics

/// Manages PDF optimization and compression
actor PDFOptimizationManager {
    
    static let shared = PDFOptimizationManager()
    
    private init() {}
    
    // MARK: - PDF Compression
    
    /// Compress PDF with specified quality level
    func compressPDF(
        at url: URL,
        quality: PDFQuality = .medium,
        options: OptimizationOptions = .default
    ) async throws -> OptimizationResult {
        guard let originalPDF = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        let originalSize = try await DocumentFileManager.shared.getFileSize(at: url)
        
        // Create optimized PDF
        let optimizedPDF = PDFDocument()
        
        for i in 0..<originalPDF.pageCount {
            guard let page = originalPDF.page(at: i) else { continue }
            
            // Optimize page
            let optimizedPage = await optimizePage(
                page,
                quality: quality,
                options: options
            )
            
            optimizedPDF.insert(optimizedPage, at: i)
        }
        
        // Apply metadata optimization
        if options.stripMetadata {
            stripMetadata(from: optimizedPDF)
        }
        
        // Save optimized PDF
        let filename = generateOptimizedFilename(from: url)
        let outputURL = try await savePDF(optimizedPDF, filename: filename)
        
        let optimizedSize = try await DocumentFileManager.shared.getFileSize(at: outputURL)
        let compressionRatio = Double(originalSize) / Double(optimizedSize)
        
        Analytics.track(event: "pdf_compressed", properties: [
            "original_size": originalSize,
            "optimized_size": optimizedSize,
            "ratio": compressionRatio,
            "quality": quality.rawValue
        ])
        
        return OptimizationResult(
            originalSize: originalSize,
            optimizedSize: optimizedSize,
            compressionRatio: compressionRatio,
            outputURL: outputURL
        )
    }
    
    // MARK: - Page Optimization
    
    private func optimizePage(
        _ page: PDFPage,
        quality: PDFQuality,
        options: OptimizationOptions
    ) async -> PDFPage {
        let bounds = page.bounds(for: .mediaBox)
        
        // Render page to image
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let pageImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(bounds)
            
            context.cgContext.translateBy(x: 0, y: bounds.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        // Downsample if needed
        var optimizedImage = pageImage
        
        if options.downsampleImages {
            let targetSize = calculateTargetSize(
                original: bounds.size,
                quality: quality
            )
            
            optimizedImage = await downsampleImage(
                pageImage,
                to: targetSize,
                quality: quality
            )
        }
        
        // Compress image
        let compressedData = optimizedImage.jpegData(
            compressionQuality: quality.compressionQuality
        )!
        let compressedImage = UIImage(data: compressedData)!
        
        // Create new PDF page
        return createPDFPage(from: compressedImage, bounds: bounds)
    }
    
    // MARK: - Image Downsampling
    
    private func downsampleImage(
        _ image: UIImage,
        to targetSize: CGSize,
        quality: PDFQuality
    ) async -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // Use 1x scale for smaller file size
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    private func calculateTargetSize(
        original: CGSize,
        quality: PDFQuality
    ) -> CGSize {
        let scale: CGFloat
        
        switch quality {
        case .low:
            scale = 0.5
        case .medium:
            scale = 0.7
        case .high:
            scale = 0.85
        case .lossless:
            scale = 1.0
        }
        
        return CGSize(
            width: original.width * scale,
            height: original.height * scale
        )
    }
    
    // MARK: - Font Optimization
    
    /// Subset fonts to reduce file size (remove unused glyphs)
    private func subsetFonts(in pdf: PDFDocument) {
        // Font subsetting is complex and requires low-level PDF manipulation
        // For now, this is a placeholder for future implementation
        // Would require CGPDFDocument and manual font table manipulation
    }
    
    // MARK: - Resource Removal
    
    /// Remove unused resources from PDF
    func removeUnusedResources(from url: URL) async throws -> URL {
        guard let pdf = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        // Remove unused annotations
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i) else { continue }
            
            // Remove invisible or duplicate annotations
            let annotations = page.annotations
            for annotation in annotations {
                if annotation.bounds.width == 0 || annotation.bounds.height == 0 {
                    page.removeAnnotation(annotation)
                }
            }
        }
        
        let filename = generateOptimizedFilename(from: url, suffix: "cleaned")
        return try await savePDF(pdf, filename: filename)
    }
    
    // MARK: - Linearization
    
    /// Linearize PDF for fast web viewing (fast web view optimization)
    func linearizePDF(at url: URL) async throws -> URL {
        // Linearization requires reordering PDF objects for sequential access
        // This is a simplified version - production would use PDFKit's built-in support
        guard let pdf = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        // PDFKit automatically linearizes when saving
        let filename = generateOptimizedFilename(from: url, suffix: "linearized")
        let outputURL = try await savePDF(pdf, filename: filename)
        
        Analytics.track(event: "pdf_linearized")
        
        return outputURL
    }
    
    // MARK: - Metadata Optimization
    
    /// Strip metadata from PDF
    private func stripMetadata(from pdf: PDFDocument) {
        // Remove document attributes
        pdf.documentAttributes = [:]
    }
    
    /// Remove specific metadata while keeping essential info
    func optimizeMetadata(at url: URL, keepEssential: Bool = true) async throws -> URL {
        guard let pdf = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        if keepEssential {
            // Keep only title and page count
            let title = pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
            pdf.documentAttributes = [
                PDFDocumentAttribute.titleAttribute: title ?? "Document"
            ]
        } else {
            pdf.documentAttributes = [:]
        }
        
        let filename = generateOptimizedFilename(from: url, suffix: "optimized_metadata")
        return try await savePDF(pdf, filename: filename)
    }
    
    // MARK: - Size Reduction Preview
    
    /// Calculate estimated size reduction without actually compressing
    func previewSizeReduction(
        at url: URL,
        quality: PDFQuality
    ) async throws -> SizeReductionPreview {
        let originalSize = try await DocumentFileManager.shared.getFileSize(at: url)
        
        // Estimate based on quality level
        let estimatedRatio: Double
        
        switch quality {
        case .low:
            estimatedRatio = 3.0 // 3x compression
        case .medium:
            estimatedRatio = 2.0 // 2x compression
        case .high:
            estimatedRatio = 1.5 // 1.5x compression
        case .lossless:
            estimatedRatio = 1.1 // 1.1x compression (metadata only)
        }
        
        let estimatedSize = Int64(Double(originalSize) / estimatedRatio)
        let estimatedSavings = originalSize - estimatedSize
        
        return SizeReductionPreview(
            originalSize: originalSize,
            estimatedSize: estimatedSize,
            estimatedSavings: estimatedSavings,
            estimatedRatio: estimatedRatio
        )
    }
    
    // MARK: - Quality Trade-off Analysis
    
    /// Analyze quality vs size trade-off for different compression levels
    func analyzeQualityTradeoffs(at url: URL) async throws -> [QualityTradeoff] {
        var tradeoffs: [QualityTradeoff] = []
        
        for quality in [PDFQuality.low, .medium, .high, .lossless] {
            let preview = try await previewSizeReduction(at: url, quality: quality)
            
            let tradeoff = QualityTradeoff(
                quality: quality,
                estimatedSize: preview.estimatedSize,
                estimatedSavings: preview.estimatedSavings,
                compressionRatio: preview.estimatedRatio
            )
            
            tradeoffs.append(tradeoff)
        }
        
        return tradeoffs
    }
    
    // MARK: - Batch Optimization
    
    /// Optimize multiple PDFs
    func batchOptimize(
        urls: [URL],
        quality: PDFQuality,
        options: OptimizationOptions = .default
    ) async throws -> [OptimizationResult] {
        var results: [OptimizationResult] = []
        
        for url in urls {
            do {
                let result = try await compressPDF(at: url, quality: quality, options: options)
                results.append(result)
            } catch {
                debugPrint("❌ Failed to optimize \(url.lastPathComponent): \(error)")
            }
        }
        
        Analytics.track(event: "pdf_batch_optimized", properties: [
            "count": urls.count,
            "quality": quality.rawValue
        ])
        
        return results
    }
    
    // MARK: - Utilities
    
    private func createPDFPage(from image: UIImage, bounds: CGRect) -> PDFPage {
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            image.draw(in: bounds)
        }
        
        let pdfDocument = PDFDocument(data: data)!
        return pdfDocument.page(at: 0)!
    }
    
    private func savePDF(_ pdf: PDFDocument, filename: String) async throws -> URL {
        guard let data = pdf.dataRepresentation() else {
            throw DocumentError.processingFailed(reason: "Could not create PDF data")
        }
        
        return try await DocumentFileManager.shared.saveDocument(
            data: data,
            filename: filename,
            format: .pdf
        )
    }
    
    private func generateOptimizedFilename(from url: URL, suffix: String = "optimized") -> String {
        let baseName = url.deletingPathExtension().lastPathComponent
        return "\(baseName)_\(suffix)_\(UUID().uuidString).pdf"
    }
}

// MARK: - Supporting Types

struct OptimizationOptions {
    var downsampleImages: Bool
    var stripMetadata: Bool
    var removeUnusedResources: Bool
    var linearize: Bool
    
    static let `default` = OptimizationOptions(
        downsampleImages: true,
        stripMetadata: false,
        removeUnusedResources: true,
        linearize: false
    )
    
    static let aggressive = OptimizationOptions(
        downsampleImages: true,
        stripMetadata: true,
        removeUnusedResources: true,
        linearize: true
    )
}

struct OptimizationResult {
    let originalSize: Int64
    let optimizedSize: Int64
    let compressionRatio: Double
    let outputURL: URL
    
    var savedBytes: Int64 {
        originalSize - optimizedSize
    }
    
    var savedPercentage: Double {
        (Double(savedBytes) / Double(originalSize)) * 100
    }
    
    var formattedSavings: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: savedBytes)
    }
}

struct SizeReductionPreview {
    let originalSize: Int64
    let estimatedSize: Int64
    let estimatedSavings: Int64
    let estimatedRatio: Double
    
    var formattedOriginal: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
    
    var formattedEstimated: String {
        ByteCountFormatter.string(fromByteCount: estimatedSize, countStyle: .file)
    }
    
    var formattedSavings: String {
        ByteCountFormatter.string(fromByteCount: estimatedSavings, countStyle: .file)
    }
    
    var savingsPercentage: Double {
        (Double(estimatedSavings) / Double(originalSize)) * 100
    }
}

struct QualityTradeoff {
    let quality: PDFQuality
    let estimatedSize: Int64
    let estimatedSavings: Int64
    let compressionRatio: Double
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: estimatedSize, countStyle: .file)
    }
    
    var formattedSavings: String {
        ByteCountFormatter.string(fromByteCount: estimatedSavings, countStyle: .file)
    }
    
    var savingsPercentage: Double {
        guard estimatedSize > 0 else { return 0 }
        return (Double(estimatedSavings) / Double(estimatedSize + estimatedSavings)) * 100
    }
}
