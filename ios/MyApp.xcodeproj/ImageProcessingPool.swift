//
//  ImageProcessingPool.swift
//  MyApp
//
//  Resource pooling for efficient image processing operations.
//

import Foundation
import UIKit
import Accelerate

/// Manages a pool of reusable resources for image processing
actor ImageProcessingPool {
    
    static let shared = ImageProcessingPool()
    
    // Reusable buffers
    private var bufferPool: [UnsafeMutablePointer<vImage_Buffer>] = []
    private let maxPoolSize = 5
    
    // Processing queue
    private let processingQueue = DispatchQueue(
        label: "com.yourapp.imageProcessing",
        qos: .userInitiated,
        attributes: .concurrent
    )
    
    // Semaphore to limit concurrent operations
    private let semaphore = DispatchSemaphore(value: 3) // Max 3 concurrent
    
    private init() {}
    
    // MARK: - Buffer Management
    
    private func getBuffer() -> UnsafeMutablePointer<vImage_Buffer>? {
        if !bufferPool.isEmpty {
            return bufferPool.removeLast()
        }
        return nil
    }
    
    private func returnBuffer(_ buffer: UnsafeMutablePointer<vImage_Buffer>) {
        if bufferPool.count < maxPoolSize {
            bufferPool.append(buffer)
        } else {
            // Pool is full, deallocate
            buffer.deallocate()
        }
    }
    
    // MARK: - Image Enhancement
    
    /// Enhance image brightness and contrast
    func enhanceImage(
        _ image: UIImage,
        brightness: Float = 0.0,
        contrast: Float = 1.0
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            processingQueue.async {
                self.semaphore.wait()
                defer { self.semaphore.signal() }
                
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let enhancedImage = self.applyBrightnessContrast(
                    cgImage: cgImage,
                    brightness: brightness,
                    contrast: contrast
                )
                
                continuation.resume(returning: enhancedImage)
            }
        }
    }
    
    private func applyBrightnessContrast(
        cgImage: CGImage,
        brightness: Float,
        contrast: Float
    ) -> UIImage? {
        let width = cgImage.width
        let height = cgImage.height
        
        var format = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: nil,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )
        
        var sourceBuffer = vImage_Buffer()
        var error = vImageBuffer_InitWithCGImage(
            &sourceBuffer,
            &format,
            nil,
            cgImage,
            UInt32(kvImageNoFlags)
        )
        
        guard error == kvImageNoError else { return nil }
        
        defer {
            sourceBuffer.data.deallocate()
        }
        
        var destBuffer = vImage_Buffer()
        destBuffer.width = sourceBuffer.width
        destBuffer.height = sourceBuffer.height
        destBuffer.rowBytes = sourceBuffer.rowBytes
        destBuffer.data = UnsafeMutableRawPointer.allocate(
            byteCount: Int(sourceBuffer.rowBytes * sourceBuffer.height),
            alignment: 16
        )
        
        defer {
            destBuffer.data.deallocate()
        }
        
        // Apply contrast and brightness
        let multiplier = [contrast, contrast, contrast, 1.0]
        let divisor: Int32 = 256
        let offset = [Int16(brightness * 255), Int16(brightness * 255), Int16(brightness * 255), 0]
        
        error = vImageMatrixMultiply_ARGB8888(
            &sourceBuffer,
            &destBuffer,
            multiplier,
            divisor,
            offset,
            nil,
            UInt32(kvImageNoFlags)
        )
        
        guard error == kvImageNoError else { return nil }
        
        guard let outputCGImage = vImageCreateCGImageFromBuffer(
            &destBuffer,
            &format,
            nil,
            nil,
            UInt32(kvImageNoFlags),
            &error
        )?.takeRetainedValue() else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage)
    }
    
    /// Sharpen image
    func sharpenImage(_ image: UIImage, intensity: Float = 1.0) async -> UIImage? {
        await withCheckedContinuation { continuation in
            processingQueue.async {
                self.semaphore.wait()
                defer { self.semaphore.signal() }
                
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let sharpened = self.applySharpen(cgImage: cgImage, intensity: intensity)
                continuation.resume(returning: sharpened)
            }
        }
    }
    
    private func applySharpen(cgImage: CGImage, intensity: Float) -> UIImage? {
        var format = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: nil,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )
        
        var sourceBuffer = vImage_Buffer()
        var error = vImageBuffer_InitWithCGImage(
            &sourceBuffer,
            &format,
            nil,
            cgImage,
            UInt32(kvImageNoFlags)
        )
        
        guard error == kvImageNoError else { return nil }
        
        defer {
            sourceBuffer.data.deallocate()
        }
        
        var destBuffer = vImage_Buffer()
        destBuffer.width = sourceBuffer.width
        destBuffer.height = sourceBuffer.height
        destBuffer.rowBytes = sourceBuffer.rowBytes
        destBuffer.data = UnsafeMutableRawPointer.allocate(
            byteCount: Int(sourceBuffer.rowBytes * sourceBuffer.height),
            alignment: 16
        )
        
        defer {
            destBuffer.data.deallocate()
        }
        
        // Unsharp mask
        error = vImageUnsharpMask_ARGB8888(
            &sourceBuffer,
            &destBuffer,
            nil,
            UInt32(kvImageNoFlags),
            intensity,
            1.0
        )
        
        guard error == kvImageNoError else { return nil }
        
        guard let outputCGImage = vImageCreateCGImageFromBuffer(
            &destBuffer,
            &format,
            nil,
            nil,
            UInt32(kvImageNoFlags),
            &error
        )?.takeRetainedValue() else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage)
    }
    
    /// Convert image to grayscale
    func convertToGrayscale(_ image: UIImage) async -> UIImage? {
        await withCheckedContinuation { continuation in
            processingQueue.async {
                self.semaphore.wait()
                defer { self.semaphore.signal() }
                
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let grayscale = self.applyGrayscale(cgImage: cgImage)
                continuation.resume(returning: grayscale)
            }
        }
    }
    
    private func applyGrayscale(cgImage: CGImage) -> UIImage? {
        let width = cgImage.width
        let height = cgImage.height
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let grayscaleCGImage = context?.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: grayscaleCGImage)
    }
    
    /// Rotate image efficiently
    func rotateImage(_ image: UIImage, degrees: CGFloat) async -> UIImage? {
        await withCheckedContinuation { continuation in
            processingQueue.async {
                self.semaphore.wait()
                defer { self.semaphore.signal() }
                
                let radians = degrees * .pi / 180
                let rotatedImage = self.applyRotation(image: image, radians: radians)
                continuation.resume(returning: rotatedImage)
            }
        }
    }
    
    private func applyRotation(image: UIImage, radians: CGFloat) -> UIImage? {
        let rotatedSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        
        let renderer = UIGraphicsImageRenderer(size: rotatedSize)
        
        return renderer.image { context in
            context.cgContext.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            context.cgContext.rotate(by: radians)
            context.cgContext.translateBy(x: -image.size.width / 2, y: -image.size.height / 2)
            image.draw(at: .zero)
        }
    }
    
    // MARK: - Batch Processing
    
    /// Process multiple images in batch
    func batchProcess(
        images: [UIImage],
        operation: @escaping (UIImage) async -> UIImage?
    ) async -> [UIImage] {
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let processed = await operation(image)
                    return (index, processed)
                }
            }
            
            var results: [(Int, UIImage?)] = []
            for await result in group {
                results.append(result)
            }
            
            // Sort by original index and filter out nils
            return results
                .sorted { $0.0 < $1.0 }
                .compactMap { $0.1 }
        }
    }
}

// MARK: - Performance Monitoring

extension ImageProcessingPool {
    
    /// Measure performance of operation
    func measurePerformance<T>(
        operation: () async throws -> T,
        label: String
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let duration = CFAbsoluteTimeGetCurrent() - start
        
        debugPrint("⏱️ \(label): \(String(format: "%.3f", duration))s")
        
        Analytics.track(event: "image_processing_performance", properties: [
            "operation": label,
            "duration_ms": Int(duration * 1000)
        ])
        
        return result
    }
}
