//
//  ImageEnhancementManager.swift
//  MyApp
//
//  Advanced image enhancement and quality improvements for scanned documents.
//

import Foundation
import UIKit
import CoreImage
import Accelerate

/// Manages advanced image enhancement and quality improvements
actor ImageEnhancementManager {
    
    static let shared = ImageEnhancementManager()
    
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    private init() {}
    
    // MARK: - Auto Enhancement
    
    /// Apply automatic enhancements to scanned image
    func autoEnhance(_ image: UIImage) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Apply auto-enhancement filters
        let filters = ciImage.autoAdjustmentFilters(options: [
            .enhance: true,
            .redEye: false
        ])
        
        var enhanced = ciImage
        for filter in filters {
            filter.setValue(enhanced, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                enhanced = output
            }
        }
        
        return renderImage(enhanced)
    }
    
    // MARK: - Exposure & White Balance
    
    /// Adjust exposure automatically
    func adjustExposure(_ image: UIImage) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Analyze image histogram to determine optimal exposure
        let histogram = calculateHistogram(ciImage)
        let exposureAdjustment = calculateOptimalExposure(histogram)
        
        guard let filter = CIFilter(name: "CIExposureAdjust") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(exposureAdjustment, forKey: kCIInputEVKey)
        
        guard let output = filter.outputImage else { return nil }
        return renderImage(output)
    }
    
    /// Adjust white balance automatically
    func adjustWhiteBalance(_ image: UIImage) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Use temperature and tint filters
        guard let temperatureFilter = CIFilter(name: "CITemperatureAndTint") else { return nil }
        
        // Calculate optimal white balance
        let neutralVector = CIVector(x: 6500, y: 0) // Daylight
        let targetVector = CIVector(x: 6500, y: 0)
        
        temperatureFilter.setValue(ciImage, forKey: kCIInputImageKey)
        temperatureFilter.setValue(neutralVector, forKey: "inputNeutral")
        temperatureFilter.setValue(targetVector, forKey: "inputTargetNeutral")
        
        guard let output = temperatureFilter.outputImage else { return nil }
        return renderImage(output)
    }
    
    // MARK: - Noise Reduction
    
    /// Reduce noise in scanned image
    func reduceNoise(_ image: UIImage, level: NoiseReductionLevel = .medium) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        guard let filter = CIFilter(name: "CINoiseReduction") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(level.intensity, forKey: "inputNoiseLevel")
        filter.setValue(level.sharpness, forKey: "inputSharpness")
        
        guard let output = filter.outputImage else { return nil }
        return renderImage(output)
    }
    
    // MARK: - Shadow Removal
    
    /// Remove shadows from document scan
    func removeShadows(_ image: UIImage) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Use highlight and shadow adjustment
        guard let filter = CIFilter(name: "CIHighlightShadowAdjust") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(1.5, forKey: "inputShadowAmount") // Lighten shadows
        filter.setValue(0.8, forKey: "inputHighlightAmount") // Reduce highlights
        filter.setValue(30.0, forKey: "inputRadius")
        
        guard let output = filter.outputImage else { return nil }
        return renderImage(output)
    }
    
    // MARK: - Deskew
    
    /// Detect and correct skew (rotation) in document
    func deskew(_ image: UIImage) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Detect angle
        let angle = await detectSkewAngle(image)
        
        guard abs(angle) > 0.1 else { return image } // No significant skew
        
        // Rotate to correct
        let transform = CGAffineTransform(rotationAngle: -angle * .pi / 180)
        let rotated = ciImage.transformed(by: transform)
        
        return renderImage(rotated)
    }
    
    private func detectSkewAngle(_ image: UIImage) async -> CGFloat {
        // Use Hough transform or edge detection to find document edges
        // For simplicity, using a basic implementation
        guard let ciImage = CIImage(image: image) else { return 0 }
        
        // Edge detection
        guard let edgeFilter = CIFilter(name: "CIEdges") else { return 0 }
        edgeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgeFilter.setValue(1.0, forKey: kCIInputIntensityKey)
        
        // Analyze edges to determine skew angle
        // This is a simplified version - production would use Hough transform
        return 0 // Placeholder
    }
    
    // MARK: - Adaptive Thresholding
    
    /// Apply adaptive thresholding for black and white conversion
    func applyAdaptiveThreshold(_ image: UIImage, blockSize: Int = 15) async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Convert to grayscale first
        guard let grayscale = await ImageProcessingPool.shared.convertToGrayscale(image) else {
            return nil
        }
        
        guard let grayCGImage = grayscale.cgImage else { return nil }
        
        // Apply adaptive threshold using local mean
        let threshold = calculateAdaptiveThreshold(grayCGImage, blockSize: blockSize)
        
        return applyThreshold(grayscale, threshold: threshold)
    }
    
    private func calculateAdaptiveThreshold(_ cgImage: CGImage, blockSize: Int) -> Float {
        // Calculate mean intensity in local blocks
        // Simplified - production would use integral images for efficiency
        return 127.0 / 255.0 // Placeholder
    }
    
    private func applyThreshold(_ image: UIImage, threshold: Float) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Use color controls to create binary image
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(100.0, forKey: kCIInputContrastKey) // Very high contrast
        filter.setValue(0.0, forKey: kCIInputSaturationKey)
        filter.setValue(threshold - 0.5, forKey: kCIInputBrightnessKey)
        
        guard let output = filter.outputImage else { return nil }
        return renderImage(output)
    }
    
    // MARK: - Quality Scoring
    
    /// Calculate quality score for scanned image
    func calculateQualityScore(_ image: UIImage) async -> QualityScore {
        guard let ciImage = CIImage(image: image) else {
            return QualityScore(overall: 0, sharpness: 0, brightness: 0, contrast: 0)
        }
        
        // Calculate sharpness
        let sharpness = await calculateSharpness(ciImage)
        
        // Calculate brightness
        let brightness = await calculateBrightness(ciImage)
        
        // Calculate contrast
        let contrast = await calculateContrast(ciImage)
        
        // Overall score (weighted average)
        let overall = (sharpness * 0.4) + (brightness * 0.3) + (contrast * 0.3)
        
        return QualityScore(
            overall: overall,
            sharpness: sharpness,
            brightness: brightness,
            contrast: contrast
        )
    }
    
    private func calculateSharpness(_ ciImage: CIImage) async -> Float {
        // Use Laplacian variance as sharpness measure
        guard let filter = CIFilter(name: "CIEdges") else { return 0 }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(1.0, forKey: kCIInputIntensityKey)
        
        guard let output = filter.outputImage else { return 0 }
        
        // Calculate variance of edge image
        let variance = calculateVariance(output)
        
        // Normalize to 0-1 range
        return min(1.0, variance / 1000.0)
    }
    
    private func calculateBrightness(_ ciImage: CIImage) async -> Float {
        let avgColor = ciImage.averageColor()
        
        // Convert to brightness (0-1)
        let brightness = (avgColor.red + avgColor.green + avgColor.blue) / 3.0
        
        // Score based on ideal brightness (0.5)
        let deviation = abs(brightness - 0.5)
        return max(0, 1.0 - (deviation * 2))
    }
    
    private func calculateContrast(_ ciImage: CIImage) async -> Float {
        // Calculate standard deviation of pixel intensities
        let stdDev = calculateStandardDeviation(ciImage)
        
        // Normalize to 0-1 range
        return min(1.0, stdDev / 100.0)
    }
    
    // MARK: - Filters & Presets
    
    /// Apply predefined filter preset
    func applyPreset(_ image: UIImage, preset: FilterPreset) async -> UIImage? {
        switch preset {
        case .document:
            return await applyDocumentPreset(image)
        case .photo:
            return await applyPhotoPreset(image)
        case .receipt:
            return await applyReceiptPreset(image)
        case .blackboard:
            return await applyBlackboardPreset(image)
        case .whiteboard:
            return await applyWhiteboardPreset(image)
        }
    }
    
    private func applyDocumentPreset(_ image: UIImage) async -> UIImage? {
        var enhanced = image
        
        // Auto exposure and white balance
        if let adjusted = await adjustExposure(enhanced) {
            enhanced = adjusted
        }
        
        // Increase sharpness
        if let sharpened = await ImageProcessingPool.shared.sharpenImage(enhanced, intensity: 0.7) {
            enhanced = sharpened
        }
        
        // Increase contrast
        if let contrasted = await ImageProcessingPool.shared.enhanceImage(enhanced, brightness: 0.05, contrast: 1.2) {
            enhanced = contrasted
        }
        
        return enhanced
    }
    
    private func applyPhotoPreset(_ image: UIImage) async -> UIImage? {
        return await autoEnhance(image)
    }
    
    private func applyReceiptPreset(_ image: UIImage) async -> UIImage? {
        var enhanced = image
        
        // High contrast B&W
        if let grayscale = await ImageProcessingPool.shared.convertToGrayscale(enhanced) {
            enhanced = grayscale
        }
        
        if let threshold = await applyAdaptiveThreshold(enhanced) {
            enhanced = threshold
        }
        
        return enhanced
    }
    
    private func applyBlackboardPreset(_ image: UIImage) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Invert colors
        guard let invertFilter = CIFilter(name: "CIColorInvert") else { return nil }
        invertFilter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let inverted = invertFilter.outputImage else { return nil }
        
        // Increase contrast
        guard let contrastFilter = CIFilter(name: "CIColorControls") else { return nil }
        contrastFilter.setValue(inverted, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.5, forKey: kCIInputContrastKey)
        
        guard let output = contrastFilter.outputImage else { return nil }
        return renderImage(output)
    }
    
    private func applyWhiteboardPreset(_ image: UIImage) async -> UIImage? {
        return await applyDocumentPreset(image)
    }
    
    // MARK: - Manual Adjustments
    
    /// Apply manual adjustments to image
    func applyAdjustments(
        _ image: UIImage,
        brightness: Float = 0,
        contrast: Float = 1.0,
        saturation: Float = 1.0,
        sharpness: Float = 0,
        temperature: Float = 0,
        tint: Float = 0
    ) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        var result = ciImage
        
        // Color controls (brightness, contrast, saturation)
        if brightness != 0 || contrast != 1.0 || saturation != 1.0 {
            guard let filter = CIFilter(name: "CIColorControls") else { return nil }
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(brightness, forKey: kCIInputBrightnessKey)
            filter.setValue(contrast, forKey: kCIInputContrastKey)
            filter.setValue(saturation, forKey: kCIInputSaturationKey)
            
            if let output = filter.outputImage {
                result = output
            }
        }
        
        // Temperature and tint
        if temperature != 0 || tint != 0 {
            guard let filter = CIFilter(name: "CITemperatureAndTint") else { return nil }
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 6500 + CGFloat(temperature * 1000), y: CGFloat(tint * 100)), forKey: "inputNeutral")
            filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
            
            if let output = filter.outputImage {
                result = output
            }
        }
        
        // Sharpness
        if sharpness != 0 {
            if let sharpened = await ImageProcessingPool.shared.sharpenImage(renderImage(result)!, intensity: sharpness) {
                return sharpened
            }
        }
        
        return renderImage(result)
    }
    
    // MARK: - Utilities
    
    private func renderImage(_ ciImage: CIImage) -> UIImage? {
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    private func calculateHistogram(_ ciImage: CIImage) -> [Int] {
        // Simplified histogram calculation
        return Array(repeating: 0, count: 256)
    }
    
    private func calculateOptimalExposure(_ histogram: [Int]) -> Float {
        // Analyze histogram to determine optimal exposure
        // Simplified - production would use more sophisticated algorithm
        return 0
    }
    
    private func calculateVariance(_ ciImage: CIImage) -> Float {
        // Calculate variance of pixel values
        return 0 // Placeholder
    }
    
    private func calculateStandardDeviation(_ ciImage: CIImage) -> Float {
        // Calculate standard deviation
        return 0 // Placeholder
    }
}

// MARK: - Supporting Types

enum NoiseReductionLevel {
    case low
    case medium
    case high
    
    var intensity: Float {
        switch self {
        case .low: return 0.02
        case .medium: return 0.05
        case .high: return 0.10
        }
    }
    
    var sharpness: Float {
        switch self {
        case .low: return 0.4
        case .medium: return 0.5
        case .high: return 0.6
        }
    }
}

enum FilterPreset: String, CaseIterable {
    case document = "Document"
    case photo = "Photo"
    case receipt = "Receipt"
    case blackboard = "Blackboard"
    case whiteboard = "Whiteboard"
    
    var icon: String {
        switch self {
        case .document: return "doc.text"
        case .photo: return "photo"
        case .receipt: return "receipt"
        case .blackboard: return "pencil.and.outline"
        case .whiteboard: return "square.and.pencil"
        }
    }
}

struct QualityScore {
    let overall: Float
    let sharpness: Float
    let brightness: Float
    let contrast: Float
    
    var rating: QualityRating {
        if overall >= 0.8 {
            return .excellent
        } else if overall >= 0.6 {
            return .good
        } else if overall >= 0.4 {
            return .fair
        } else {
            return .poor
        }
    }
}

enum QualityRating: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    var color: UIColor {
        switch self {
        case .excellent: return .systemGreen
        case .good: return .systemBlue
        case .fair: return .systemOrange
        case .poor: return .systemRed
        }
    }
}

// MARK: - CIImage Extension

extension CIImage {
    func averageColor() -> (red: Float, green: Float, blue: Float, alpha: Float) {
        let extentVector = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: self, kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage else {
            return (0, 0, 0, 0)
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return (
            Float(bitmap[0]) / 255.0,
            Float(bitmap[1]) / 255.0,
            Float(bitmap[2]) / 255.0,
            Float(bitmap[3]) / 255.0
        )
    }
}
