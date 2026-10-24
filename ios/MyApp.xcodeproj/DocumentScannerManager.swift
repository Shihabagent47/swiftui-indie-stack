//
//  DocumentScannerManager.swift
//  MyApp
//
//  Manages document scanning using VisionKit and custom Vision-based detection.
//

import Foundation
import UIKit
import VisionKit
import Vision
import AVFoundation

/// Manages document scanning functionality
@MainActor
class DocumentScannerManager: NSObject, ObservableObject {
    
    static let shared = DocumentScannerManager()
    
    @Published var isScanning = false
    @Published var scannedImages: [UIImage] = []
    @Published var currentScanSession: ScanSession?
    
    // Scanner configuration
    var scanMode: ScanMode = .color
    var scanQuality: ScanQuality = .high
    var enableAutoEnhancement = true
    var enableEdgeDetection = true
    var enablePerspectiveCorrection = true
    
    private var scannerViewController: VNDocumentCameraViewController?
    
    private override init() {
        super.init()
    }
    
    // MARK: - VisionKit Scanner
    
    /// Check if document scanner is available
    var isDocumentScannerAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }
    
    /// Present VisionKit document scanner
    func presentDocumentScanner(
        from viewController: UIViewController,
        multiPage: Bool = true
    ) throws {
        guard isDocumentScannerAvailable else {
            throw ScanError.cameraUnavailable
        }
        
        guard checkCameraPermission() else {
            throw ScanError.permissionDenied
        }
        
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = self
        
        scannerViewController = scanner
        isScanning = true
        
        // Create scan session
        let session = ScanSession(
            isMultiPage: multiPage,
            scanMode: scanMode,
            scanQuality: scanQuality
        )
        currentScanSession = session
        
        viewController.present(scanner, animated: true)
        
        Analytics.track(event: "scanner_opened", properties: [
            "multi_page": multiPage,
            "scan_mode": scanMode.rawValue
        ])
    }
    
    // MARK: - Camera Permission
    
    func checkCameraPermission() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined, .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    func requestCameraPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
    
    // MARK: - Image Processing
    
    /// Process scanned image with enhancements
    func processScannedImage(
        _ image: UIImage,
        applyEnhancements: Bool = true
    ) async -> UIImage {
        var processedImage = image
        
        // Apply edge detection and perspective correction
        if enableEdgeDetection {
            if let detected = await detectAndCropDocument(image) {
                processedImage = detected
            }
        }
        
        // Apply color mode
        processedImage = await applyColorMode(processedImage, mode: scanMode)
        
        // Apply enhancements
        if applyEnhancements && enableAutoEnhancement {
            processedImage = await enhanceImage(processedImage)
        }
        
        return processedImage
    }
    
    /// Apply color mode to image
    private func applyColorMode(_ image: UIImage, mode: ScanMode) async -> UIImage {
        switch mode {
        case .color:
            return image
            
        case .grayscale:
            return await ImageProcessingPool.shared.convertToGrayscale(image) ?? image
            
        case .blackAndWhite:
            return await applyBlackAndWhiteThreshold(image)
        }
    }
    
    /// Apply black and white threshold
    private func applyBlackAndWhiteThreshold(_ image: UIImage) async -> UIImage {
        guard let grayscale = await ImageProcessingPool.shared.convertToGrayscale(image),
              let cgImage = grayscale.cgImage else {
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.5, forKey: kCIInputContrastKey) // Increase contrast
        filter?.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color
        
        guard let outputImage = filter?.outputImage,
              let outputCGImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: outputCGImage)
    }
    
    /// Enhance image (brightness, contrast, sharpness)
    private func enhanceImage(_ image: UIImage) async -> UIImage {
        // Apply auto-enhancement
        var enhanced = await ImageProcessingPool.shared.enhanceImage(
            image,
            brightness: 0.05,
            contrast: 1.1
        ) ?? image
        
        // Apply sharpening
        enhanced = await ImageProcessingPool.shared.sharpenImage(
            enhanced,
            intensity: 0.5
        ) ?? enhanced
        
        return enhanced
    }
    
    // MARK: - Document Detection
    
    /// Detect document edges and crop
    func detectAndCropDocument(_ image: UIImage) async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let request = VNDetectDocumentSegmentationRequest()
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let observation = request.results?.first else {
                return nil
            }
            
            // Get the segmented document
            let maskedImage = try? observation.generateScaledMaskForImage(
                forInstances: observation.allInstances,
                from: handler
            )
            
            if let mask = maskedImage {
                return applyMaskToImage(cgImage: cgImage, mask: mask)
            }
            
        } catch {
            debugPrint("❌ Document detection failed: \(error)")
        }
        
        return nil
    }
    
    private func applyMaskToImage(cgImage: CGImage, mask: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cgImage: cgImage)
        let maskImage = CIImage(cvPixelBuffer: mask)
        
        let filter = CIFilter(name: "CIBlendWithMask")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(maskImage, forKey: kCIInputMaskImageKey)
        
        guard let outputImage = filter?.outputImage,
              let outputCGImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage)
    }
    
    /// Detect rectangle in image for manual cropping
    func detectRectangle(in image: UIImage) async -> VNRectangleObservation? {
        guard let cgImage = image.cgImage else { return nil }
        
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.3
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            return request.results?.first
        } catch {
            debugPrint("❌ Rectangle detection failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Perspective Correction
    
    /// Apply perspective correction based on detected rectangle
    func correctPerspective(
        image: UIImage,
        rectangle: VNRectangleObservation
    ) async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        // Convert normalized coordinates to image coordinates
        let topLeft = convertPoint(rectangle.topLeft, imageSize: imageSize)
        let topRight = convertPoint(rectangle.topRight, imageSize: imageSize)
        let bottomLeft = convertPoint(rectangle.bottomLeft, imageSize: imageSize)
        let bottomRight = convertPoint(rectangle.bottomRight, imageSize: imageSize)
        
        // Calculate destination rectangle size
        let width = max(
            distance(from: topLeft, to: topRight),
            distance(from: bottomLeft, to: bottomRight)
        )
        let height = max(
            distance(from: topLeft, to: bottomLeft),
            distance(from: topRight, to: bottomRight)
        )
        
        let destSize = CGSize(width: width, height: height)
        
        // Create perspective transform
        let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection")
        perspectiveCorrection?.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        perspectiveCorrection?.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        perspectiveCorrection?.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        perspectiveCorrection?.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        perspectiveCorrection?.setValue(CIImage(cgImage: cgImage), forKey: kCIInputImageKey)
        
        guard let outputImage = perspectiveCorrection?.outputImage,
              let outputCGImage = CIContext().createCGImage(
                outputImage,
                from: CGRect(origin: .zero, size: destSize)
              ) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage)
    }
    
    // MARK: - Save Scan
    
    /// Save scanned images as a document
    func saveScan(
        images: [UIImage],
        title: String? = nil
    ) async throws -> Document {
        // Check quota
        let repository = DocumentRepository()
        guard try await repository.canPerformScan() else {
            throw DocumentError.quotaExceeded(type: .scan)
        }
        
        // Save scan images
        var scanPages: [ScanPage] = []
        
        for (index, image) in images.enumerated() {
            let imageURL = try await DocumentFileManager.shared.saveScanImage(
                image: image,
                quality: scanQuality,
                format: .jpeg
            )
            
            let fileSize = try await DocumentFileManager.shared.getFileSize(at: imageURL)
            
            let scanPage = ScanPage(
                pageNumber: index,
                imageURL: imageURL,
                imageSize: fileSize,
                scanQuality: scanQuality,
                scanMode: scanMode
            )
            
            scanPages.append(scanPage)
        }
        
        // Create PDF from images
        let pdfURL = try await createPDF(from: images, title: title)
        let pdfSize = try await DocumentFileManager.shared.getFileSize(at: pdfURL)
        
        // Generate thumbnail
        let thumbnailData = try await DocumentFileManager.shared.saveThumbnail(
            image: images.first!,
            documentID: UUID()
        )
        
        // Create document
        let documentTitle = title ?? generateScanTitle()
        let document = Document(
            title: documentTitle,
            filename: pdfURL.lastPathComponent,
            fileURL: pdfURL,
            fileSize: pdfSize,
            pageCount: images.count,
            fileFormat: .pdf,
            scans: scanPages
        )
        document.thumbnailData = thumbnailData
        document.scannedAt = Date()
        document.scanQuality = scanQuality
        document.scanMode = scanMode
        
        // Save to repository
        try await repository.saveDocument(document)
        
        // Record quota usage
        try await repository.recordScanUsage()
        
        Analytics.track(event: "scan_saved", properties: [
            "page_count": images.count,
            "scan_mode": scanMode.rawValue,
            "quality": scanQuality.rawValue
        ])
        
        return document
    }
    
    private func generateScanTitle() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "Scan \(dateFormatter.string(from: Date()))"
    }
    
    // MARK: - PDF Creation
    
    private func createPDF(from images: [UIImage], title: String?) async throws -> URL {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: images[0].size))
        
        let data = pdfRenderer.pdfData { context in
            for image in images {
                context.beginPage()
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        }
        
        let filename = "\(title ?? "Scan")_\(UUID().uuidString).pdf"
        let fileURL = try await DocumentFileManager.shared.saveDocument(
            data: data,
            filename: filename,
            format: .pdf
        )
        
        return fileURL
    }
    
    // MARK: - Utilities
    
    private func convertPoint(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * imageSize.width,
            y: (1 - point.y) * imageSize.height
        )
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = to.x - from.x
        let dy = to.y - from.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate

extension DocumentScannerManager: VNDocumentCameraViewControllerDelegate {
    
    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFinishWith scan: VNDocumentCameraScan
    ) {
        controller.dismiss(animated: true)
        
        isScanning = false
        scannedImages.removeAll()
        
        // Extract scanned images
        Task {
            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                let processed = await processScannedImage(image)
                scannedImages.append(processed)
            }
            
            // Update session
            currentScanSession?.pageCount = scannedImages.count
            
            Analytics.track(event: "scan_completed", properties: [
                "page_count": scan.pageCount
            ])
        }
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
        
        isScanning = false
        scannedImages.removeAll()
        currentScanSession = nil
        
        Analytics.track(event: "scan_cancelled")
    }
    
    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFailWithError error: Error
    ) {
        controller.dismiss(animated: true)
        
        isScanning = false
        scannedImages.removeAll()
        currentScanSession = nil
        
        debugPrint("❌ Document scanner failed: \(error)")
        
        Analytics.track(event: "scan_failed", properties: [
            "error": error.localizedDescription
        ])
    }
}
