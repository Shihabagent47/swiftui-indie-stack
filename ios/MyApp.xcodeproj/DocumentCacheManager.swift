//
//  DocumentCacheManager.swift
//  MyApp
//
//  Manages caching for thumbnails, previews, and temporary processing files.
//

import Foundation
import UIKit

/// Manages document caching system
@MainActor
class DocumentCacheManager {
    
    static let shared = DocumentCacheManager()
    
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let previewCache = NSCache<NSString, UIImage>()
    private let dataCache = NSCache<NSString, NSData>()
    
    private let fileManager = DocumentFileManager.shared
    
    // MARK: - Initialization
    
    private init() {
        configureCaches()
        setupMemoryWarningObserver()
    }
    
    private func configureCaches() {
        // Thumbnail cache: ~50 MB
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024
        thumbnailCache.countLimit = 200
        
        // Preview cache: ~100 MB
        previewCache.totalCostLimit = 100 * 1024 * 1024
        previewCache.countLimit = 50
        
        // Data cache: ~200 MB
        dataCache.totalCostLimit = 200 * 1024 * 1024
        dataCache.countLimit = 100
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        clearMemoryCaches()
        debugPrint("⚠️ Memory warning - cleared caches")
    }
    
    // MARK: - Thumbnail Caching
    
    /// Cache a thumbnail image
    func cacheThumbnail(_ image: UIImage, for documentID: UUID) {
        let key = "thumbnail_\(documentID.uuidString)" as NSString
        let cost = estimateImageMemorySize(image)
        thumbnailCache.setObject(image, forKey: key, cost: cost)
    }
    
    /// Retrieve cached thumbnail
    func getThumbnail(for documentID: UUID) -> UIImage? {
        let key = "thumbnail_\(documentID.uuidString)" as NSString
        return thumbnailCache.object(forKey: key)
    }
    
    /// Remove thumbnail from cache
    func removeThumbnail(for documentID: UUID) {
        let key = "thumbnail_\(documentID.uuidString)" as NSString
        thumbnailCache.removeObject(forKey: key)
    }
    
    // MARK: - Preview Caching
    
    /// Cache a preview image (higher resolution than thumbnail)
    func cachePreview(_ image: UIImage, for documentID: UUID, page: Int = 0) {
        let key = "preview_\(documentID.uuidString)_\(page)" as NSString
        let cost = estimateImageMemorySize(image)
        previewCache.setObject(image, forKey: key, cost: cost)
    }
    
    /// Retrieve cached preview
    func getPreview(for documentID: UUID, page: Int = 0) -> UIImage? {
        let key = "preview_\(documentID.uuidString)_\(page)" as NSString
        return previewCache.object(forKey: key)
    }
    
    /// Remove preview from cache
    func removePreview(for documentID: UUID, page: Int = 0) {
        let key = "preview_\(documentID.uuidString)_\(page)" as NSString
        previewCache.removeObject(forKey: key)
    }
    
    // MARK: - Data Caching
    
    /// Cache document data
    func cacheData(_ data: Data, for key: String) {
        let cacheKey = key as NSString
        let nsData = data as NSData
        dataCache.setObject(nsData, forKey: cacheKey, cost: data.count)
    }
    
    /// Retrieve cached data
    func getData(for key: String) -> Data? {
        let cacheKey = key as NSString
        return dataCache.object(forKey: cacheKey) as Data?
    }
    
    /// Remove data from cache
    func removeData(for key: String) {
        let cacheKey = key as NSString
        dataCache.removeObject(forKey: cacheKey)
    }
    
    // MARK: - OCR Text Caching
    
    /// Cache OCR result
    func cacheOCRText(_ text: String, for documentID: UUID) {
        let key = "ocr_\(documentID.uuidString)"
        UserDefaults.standard.set(text, forKey: key)
    }
    
    /// Retrieve cached OCR text
    func getOCRText(for documentID: UUID) -> String? {
        let key = "ocr_\(documentID.uuidString)"
        return UserDefaults.standard.string(forKey: key)
    }
    
    /// Remove cached OCR text
    func removeOCRText(for documentID: UUID) {
        let key = "ocr_\(documentID.uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    // MARK: - Disk Cache Management
    
    /// Save data to disk cache
    func saveToDiskCache(data: Data, key: String, category: String = "general") async throws {
        let cacheDir = await fileManager.getCacheDirectory(for: category)
        
        // Create directory if needed
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try FileManager.default.createDirectory(
                at: cacheDir,
                withIntermediateDirectories: true
            )
        }
        
        let fileURL = cacheDir.appendingPathComponent(key)
        try data.write(to: fileURL)
    }
    
    /// Load data from disk cache
    func loadFromDiskCache(key: String, category: String = "general") async -> Data? {
        let cacheDir = await fileManager.getCacheDirectory(for: category)
        let fileURL = cacheDir.appendingPathComponent(key)
        
        return try? Data(contentsOf: fileURL)
    }
    
    /// Remove item from disk cache
    func removeFromDiskCache(key: String, category: String = "general") async {
        let cacheDir = await fileManager.getCacheDirectory(for: category)
        let fileURL = cacheDir.appendingPathComponent(key)
        
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - Cache Cleanup
    
    /// Clear all memory caches
    func clearMemoryCaches() {
        thumbnailCache.removeAllObjects()
        previewCache.removeAllObjects()
        dataCache.removeAllObjects()
        
        Analytics.track(event: "cache_cleared", properties: ["type": "memory"])
    }
    
    /// Clear all caches (memory + disk)
    func clearAllCaches() async {
        clearMemoryCaches()
        
        do {
            try await fileManager.clearAllCaches()
            Analytics.track(event: "cache_cleared", properties: ["type": "all"])
        } catch {
            debugPrint("❌ Failed to clear disk caches: \(error)")
        }
    }
    
    /// Clear cache for specific document
    func clearCacheForDocument(_ documentID: UUID) async {
        removeThumbnail(for: documentID)
        removePreview(for: documentID)
        removeOCRText(for: documentID)
        
        // Clear all preview pages
        for page in 0..<100 { // Assume max 100 pages
            removePreview(for: documentID, page: page)
        }
        
        await removeFromDiskCache(key: documentID.uuidString, category: "documents")
    }
    
    /// Get total cache size
    func getTotalCacheSize() async -> String {
        let diskCacheSize = await fileManager.getCacheSize()
        return ByteCountFormatter.string(fromByteCount: diskCacheSize, countStyle: .file)
    }
    
    // MARK: - Cache Statistics
    
    /// Get cache statistics
    func getCacheStats() -> CacheStats {
        CacheStats(
            thumbnailCount: thumbnailCache.countLimit,
            previewCount: previewCache.countLimit,
            dataCount: dataCache.countLimit
        )
    }
    
    // MARK: - Utilities
    
    /// Estimate memory size of UIImage
    private func estimateImageMemorySize(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let bytesPerPixel = 4 // RGBA
        return cgImage.width * cgImage.height * bytesPerPixel
    }
}

// MARK: - Cache Stats

struct CacheStats {
    let thumbnailCount: Int
    let previewCount: Int
    let dataCount: Int
}
