//
//  FileCompressionManager.swift
//  MyApp
//
//  Handles file compression and decompression for documents and images.
//

import Foundation
import UIKit
import Compression

/// Manages file compression and decompression
actor FileCompressionManager {
    
    static let shared = FileCompressionManager()
    
    private init() {}
    
    // MARK: - Image Compression
    
    /// Compress an image to target file size
    func compressImage(
        _ image: UIImage,
        targetSizeKB: Int,
        format: ImageFormat = .jpeg
    ) async -> Data? {
        var compressionQuality: Double = 1.0
        var imageData: Data?
        let targetBytes = targetSizeKB * 1024
        
        // Binary search for optimal compression quality
        var minQuality: Double = 0.0
        var maxQuality: Double = 1.0
        
        for _ in 0..<10 { // Max 10 iterations
            compressionQuality = (minQuality + maxQuality) / 2
            
            imageData = image.imageData(format: format, quality: compressionQuality)
            
            guard let data = imageData else { return nil }
            
            if data.count <= targetBytes {
                break
            } else if data.count > targetBytes {
                maxQuality = compressionQuality
            } else {
                minQuality = compressionQuality
            }
        }
        
        return imageData
    }
    
    /// Compress image to specific quality level
    func compressImage(
        _ image: UIImage,
        quality: CompressionLevel,
        format: ImageFormat = .jpeg
    ) -> Data? {
        let compressionQuality = quality.imageQuality
        return image.imageData(format: format, quality: compressionQuality)
    }
    
    /// Downsample image to reduce memory usage
    func downsampleImage(
        at url: URL,
        to targetSize: CGSize,
        scale: CGFloat = UIScreen.main.scale
    ) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions) else {
            return nil
        }
        
        let maxDimensionInPixels = max(targetSize.width, targetSize.height) * scale
        
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    // MARK: - Data Compression (ZIP)
    
    /// Compress data using LZFSE algorithm
    func compressData(_ data: Data, algorithm: Algorithm = .lzfse) throws -> Data {
        return try data.compressed(using: algorithm)
    }
    
    /// Decompress data
    func decompressData(_ data: Data, algorithm: Algorithm = .lzfse) throws -> Data {
        return try data.decompressed(using: algorithm)
    }
    
    /// Compress file
    func compressFile(at sourceURL: URL, algorithm: Algorithm = .lzfse) throws -> URL {
        let data = try Data(contentsOf: sourceURL)
        let compressedData = try compressData(data, algorithm: algorithm)
        
        let compressedURL = sourceURL.deletingPathExtension()
            .appendingPathExtension("compressed")
            .appendingPathExtension(sourceURL.pathExtension)
        
        try compressedData.write(to: compressedURL)
        
        Analytics.track(event: "file_compressed", properties: [
            "original_size": data.count,
            "compressed_size": compressedData.count,
            "ratio": Double(data.count) / Double(compressedData.count)
        ])
        
        return compressedURL
    }
    
    /// Decompress file
    func decompressFile(at sourceURL: URL, algorithm: Algorithm = .lzfse) throws -> URL {
        let compressedData = try Data(contentsOf: sourceURL)
        let decompressedData = try decompressData(compressedData, algorithm: algorithm)
        
        let decompressedURL = sourceURL.deletingPathExtension()
        try decompressedData.write(to: decompressedURL)
        
        return decompressedURL
    }
    
    // MARK: - File Size Optimization
    
    /// Calculate optimal compression for file size target
    func optimizeFileSize(
        data: Data,
        targetSizeKB: Int,
        level: CompressionLevel
    ) async throws -> Data {
        let algorithm: Algorithm
        
        switch level {
        case .none:
            return data
        case .low:
            algorithm = .lz4
        case .medium:
            algorithm = .zlib
        case .high, .maximum:
            algorithm = .lzfse
        }
        
        let compressed = try compressData(data, algorithm: algorithm)
        
        let targetBytes = targetSizeKB * 1024
        if compressed.count <= targetBytes {
            return compressed
        }
        
        // If still too large, return best effort
        return compressed
    }
    
    /// Get compression ratio
    func getCompressionRatio(original: Int64, compressed: Int64) -> Double {
        guard compressed > 0 else { return 0 }
        return Double(original) / Double(compressed)
    }
    
    /// Estimate compressed size
    func estimateCompressedSize(
        originalSize: Int64,
        level: CompressionLevel
    ) -> Int64 {
        let estimatedRatio: Double
        
        switch level {
        case .none:
            estimatedRatio = 1.0
        case .low:
            estimatedRatio = 1.2
        case .medium:
            estimatedRatio = 1.5
        case .high:
            estimatedRatio = 2.0
        case .maximum:
            estimatedRatio = 2.5
        }
        
        return Int64(Double(originalSize) / estimatedRatio)
    }
}

// MARK: - Compression Algorithm

extension FileCompressionManager {
    enum Algorithm {
        case lz4      // Fast, lower compression
        case zlib     // Balanced
        case lzfse    // High compression, slower
        case lzma     // Maximum compression, slowest
        
        var compressionAlgorithm: compression_algorithm {
            switch self {
            case .lz4: return COMPRESSION_LZ4
            case .zlib: return COMPRESSION_ZLIB
            case .lzfse: return COMPRESSION_LZFSE
            case .lzma: return COMPRESSION_LZMA
            }
        }
    }
}

// MARK: - Data Compression Extension

extension Data {
    
    /// Compress data using specified algorithm
    func compressed(using algorithm: FileCompressionManager.Algorithm) throws -> Data {
        let sourceBuffer = [UInt8](self)
        let destinationBufferSize = sourceBuffer.count
        var destinationBuffer = [UInt8](repeating: 0, count: destinationBufferSize)
        
        let compressedSize = compression_encode_buffer(
            &destinationBuffer,
            destinationBufferSize,
            sourceBuffer,
            sourceBuffer.count,
            nil,
            algorithm.compressionAlgorithm
        )
        
        guard compressedSize > 0 else {
            throw DocumentError.processingFailed(reason: "Compression failed")
        }
        
        return Data(destinationBuffer.prefix(compressedSize))
    }
    
    /// Decompress data using specified algorithm
    func decompressed(using algorithm: FileCompressionManager.Algorithm) throws -> Data {
        let sourceBuffer = [UInt8](self)
        let destinationBufferSize = sourceBuffer.count * 4 // Estimate 4x expansion
        var destinationBuffer = [UInt8](repeating: 0, count: destinationBufferSize)
        
        let decompressedSize = compression_decode_buffer(
            &destinationBuffer,
            destinationBufferSize,
            sourceBuffer,
            sourceBuffer.count,
            nil,
            algorithm.compressionAlgorithm
        )
        
        guard decompressedSize > 0 else {
            throw DocumentError.processingFailed(reason: "Decompression failed")
        }
        
        return Data(destinationBuffer.prefix(decompressedSize))
    }
}

// MARK: - CompressionLevel Extension

extension CompressionLevel {
    
    var imageQuality: Double {
        switch self {
        case .none: return 1.0
        case .low: return 0.8
        case .medium: return 0.6
        case .high: return 0.4
        case .maximum: return 0.2
        }
    }
}
