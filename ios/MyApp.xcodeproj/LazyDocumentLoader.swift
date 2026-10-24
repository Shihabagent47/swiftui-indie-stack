//
//  LazyDocumentLoader.swift
//  MyApp
//
//  Implements lazy loading for large documents with pagination support.
//

import Foundation
import PDFKit
import UIKit

/// Lazy loader for large documents
actor LazyDocumentLoader {
    
    // MARK: - Page Cache
    
    private var pageCache: [Int: PDFPage] = [:]
    private var imageCache: [Int: UIImage] = [:]
    private let cacheSize = 10 // Keep 10 pages in memory
    
    private let document: PDFDocument
    private let documentURL: URL
    
    // MARK: - Initialization
    
    init(url: URL) throws {
        self.documentURL = url
        
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        self.document = pdfDocument
    }
    
    // MARK: - Lazy Page Loading
    
    /// Load page at index (cached)
    func loadPage(at index: Int) -> PDFPage? {
        // Check cache first
        if let cachedPage = pageCache[index] {
            return cachedPage
        }
        
        // Load from document
        guard let page = document.page(at: index) else {
            return nil
        }
        
        // Cache the page
        cachePage(page, at: index)
        
        return page
    }
    
    /// Load multiple pages (for smooth scrolling)
    func loadPages(in range: Range<Int>) -> [Int: PDFPage] {
        var pages: [Int: PDFPage] = [:]
        
        for index in range {
            if let page = loadPage(at: index) {
                pages[index] = page
            }
        }
        
        return pages
    }
    
    /// Preload pages around current index
    func preloadPages(around index: Int, count: Int = 2) {
        let startIndex = max(0, index - count)
        let endIndex = min(document.pageCount - 1, index + count)
        
        for i in startIndex...endIndex {
            _ = loadPage(at: i)
        }
    }
    
    // MARK: - Image Rendering
    
    /// Render page to image with size optimization
    func renderPage(
        at index: Int,
        size: CGSize,
        scale: CGFloat = UIScreen.main.scale
    ) -> UIImage? {
        // Check image cache
        if let cachedImage = imageCache[index] {
            return cachedImage
        }
        
        guard let page = loadPage(at: index) else {
            return nil
        }
        
        let image = renderPageToImage(page, size: size, scale: scale)
        
        // Cache rendered image
        cacheImage(image, at: index)
        
        return image
    }
    
    private func renderPageToImage(
        _ page: PDFPage,
        size: CGSize,
        scale: CGFloat
    ) -> UIImage {
        let bounds = page.bounds(for: .mediaBox)
        let aspectRatio = bounds.width / bounds.height
        
        var renderSize = size
        if aspectRatio > size.width / size.height {
            renderSize.height = size.width / aspectRatio
        } else {
            renderSize.width = size.height * aspectRatio
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        
        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))
            
            context.cgContext.translateBy(x: 0, y: renderSize.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            
            let transform = page.transform(for: .mediaBox, to: renderSize)
            context.cgContext.concatenate(transform)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
    
    // MARK: - Progressive Rendering
    
    /// Render page progressively (low quality first, then high quality)
    func renderPageProgressively(
        at index: Int,
        targetSize: CGSize,
        lowQualityCompletion: @escaping (UIImage?) -> Void,
        highQualityCompletion: @escaping (UIImage?) -> Void
    ) {
        // Render low quality immediately
        Task {
            let lowQualitySize = CGSize(
                width: targetSize.width * 0.5,
                height: targetSize.height * 0.5
            )
            
            let lowQualityImage = renderPage(at: index, size: lowQualitySize, scale: 1.0)
            
            await MainActor.run {
                lowQualityCompletion(lowQualityImage)
            }
        }
        
        // Render high quality in background
        Task {
            let highQualityImage = renderPage(at: index, size: targetSize, scale: 2.0)
            
            await MainActor.run {
                highQualityCompletion(highQualityImage)
            }
        }
    }
    
    // MARK: - Cache Management
    
    private func cachePage(_ page: PDFPage, at index: Int) {
        pageCache[index] = page
        
        // Evict old pages if cache is full
        if pageCache.count > cacheSize {
            evictOldestPage()
        }
    }
    
    private func cacheImage(_ image: UIImage, at index: Int) {
        imageCache[index] = image
        
        // Evict old images if cache is full
        if imageCache.count > cacheSize {
            evictOldestImage()
        }
    }
    
    private func evictOldestPage() {
        if let oldestIndex = pageCache.keys.min() {
            pageCache.removeValue(forKey: oldestIndex)
        }
    }
    
    private func evictOldestImage() {
        if let oldestIndex = imageCache.keys.min() {
            imageCache.removeValue(forKey: oldestIndex)
        }
    }
    
    /// Clear all caches
    func clearCache() {
        pageCache.removeAll()
        imageCache.removeAll()
    }
    
    /// Clear cache for specific page range
    func clearCache(outsideRange range: Range<Int>) {
        pageCache = pageCache.filter { range.contains($0.key) }
        imageCache = imageCache.filter { range.contains($0.key) }
    }
    
    // MARK: - Document Info
    
    var pageCount: Int {
        document.pageCount
    }
    
    func getPageSize(at index: Int) -> CGSize {
        guard let page = loadPage(at: index) else {
            return .zero
        }
        return page.bounds(for: .mediaBox).size
    }
}

// MARK: - Thumbnail Generator

/// Efficient thumbnail generation for documents
actor ThumbnailGenerator {
    
    static let shared = ThumbnailGenerator()
    
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
    private init() {
        configureThumbnailCache()
    }
    
    private func configureThumbnailCache() {
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        thumbnailCache.countLimit = 200
    }
    
    /// Generate thumbnail for document
    func generateThumbnail(
        for documentURL: URL,
        size: CGSize = CGSize(width: 200, height: 200)
    ) async throws -> UIImage {
        let cacheKey = "\(documentURL.lastPathComponent)_\(Int(size.width))x\(Int(size.height))" as NSString
        
        // Check cache
        if let cachedThumbnail = thumbnailCache.object(forKey: cacheKey) {
            return cachedThumbnail
        }
        
        // Generate new thumbnail
        let thumbnail: UIImage
        
        if documentURL.pathExtension.lowercased() == "pdf" {
            thumbnail = try await generatePDFThumbnail(url: documentURL, size: size)
        } else {
            thumbnail = try await generateImageThumbnail(url: documentURL, size: size)
        }
        
        // Cache it
        let cost = estimateImageMemorySize(thumbnail)
        thumbnailCache.setObject(thumbnail, forKey: cacheKey, cost: cost)
        
        return thumbnail
    }
    
    private func generatePDFThumbnail(url: URL, size: CGSize) async throws -> UIImage {
        guard let pdf = PDFDocument(url: url),
              let page = pdf.page(at: 0) else {
            throw DocumentError.invalidFormat
        }
        
        let pageBounds = page.bounds(for: .mediaBox)
        let scale = min(size.width / pageBounds.width, size.height / pageBounds.height)
        let scaledSize = CGSize(
            width: pageBounds.width * scale,
            height: pageBounds.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            context.cgContext.scaleBy(x: scale, y: scale)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
    
    private func generateImageThumbnail(url: URL, size: CGSize) async throws -> UIImage {
        // Use downsampling for memory efficiency
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height)
        ] as CFDictionary
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) else {
            throw DocumentError.processingFailed(reason: "Failed to create thumbnail")
        }
        
        return UIImage(cgImage: thumbnail)
    }
    
    private func estimateImageMemorySize(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.width * cgImage.height * 4 // RGBA
    }
}
