//
//  CustomCameraScanner.swift
//  MyApp
//
//  Custom camera implementation with real-time edge detection overlay.
//

import Foundation
import UIKit
import AVFoundation
import Vision
import Combine

/// Custom camera scanner with real-time document detection
@MainActor
class CustomCameraScanner: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var capturedImage: UIImage?
    @Published var detectedRectangle: VNRectangleObservation?
    @Published var isDetectingDocument = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var exposureLevel: Float = 0.0
    
    // MARK: - Camera Session
    
    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    
    private let sessionQueue = DispatchQueue(label: "com.yourapp.cameraQueue")
    
    // MARK: - Vision
    
    private var rectangleDetectionRequest: VNDetectRectanglesRequest?
    private let visionQueue = DispatchQueue(label: "com.yourapp.visionQueue")
    
    // MARK: - Configuration
    
    var enableEdgeDetection = true
    var enableAutoFocus = true
    var enableAutoExposure = true
    
    // MARK: - Setup
    
    func setupCamera() async throws {
        guard await checkCameraPermission() else {
            throw ScanError.permissionDenied
        }
        
        await setupCaptureSession()
        setupVision()
    }
    
    private func checkCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
    
    private func setupCaptureSession() async {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        // Add video input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: camera) else {
            debugPrint("❌ Failed to create camera input")
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }
        
        // Configure camera settings
        do {
            try camera.lockForConfiguration()
            
            if camera.isFocusModeSupported(.continuousAutoFocus) && enableAutoFocus {
                camera.focusMode = .continuousAutoFocus
            }
            
            if camera.isExposureModeSupported(.continuousAutoExposure) && enableAutoExposure {
                camera.exposureMode = .continuousAutoExposure
            }
            
            camera.unlockForConfiguration()
        } catch {
            debugPrint("❌ Failed to configure camera: \(error)")
        }
        
        // Add photo output
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }
        
        // Add video output for edge detection
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }
        
        self.captureSession = session
    }
    
    private func setupVision() {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                debugPrint("❌ Rectangle detection error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNRectangleObservation],
                  let bestObservation = observations.first else {
                Task { @MainActor in
                    self.detectedRectangle = nil
                }
                return
            }
            
            // Update on main thread
            Task { @MainActor in
                self.detectedRectangle = bestObservation
                self.isDetectingDocument = true
            }
        }
        
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.3
        request.maximumObservations = 1
        
        rectangleDetectionRequest = request
    }
    
    // MARK: - Session Control
    
    func startSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    // MARK: - Preview Layer
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        return previewLayer
    }
    
    // MARK: - Capture Photo
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        
        photoOutput.capturePhoto(with: settings, delegate: self)
        
        Analytics.track(event: "custom_camera_capture", properties: [
            "flash": flashMode.rawValue,
            "edge_detection": enableEdgeDetection
        ])
    }
    
    // MARK: - Flash Control
    
    func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
    }
    
    // MARK: - Exposure Control
    
    func adjustExposure(to level: Float) async {
        guard let camera = captureSession?.inputs.first as? AVCaptureDeviceInput else { return }
        
        do {
            try camera.device.lockForConfiguration()
            
            if camera.device.isExposureModeSupported(.custom) {
                let clampedLevel = max(-2.0, min(2.0, level))
                camera.device.setExposureTargetBias(clampedLevel)
                exposureLevel = clampedLevel
            }
            
            camera.device.unlockForConfiguration()
        } catch {
            debugPrint("❌ Failed to adjust exposure: \(error)")
        }
    }
    
    // MARK: - White Balance
    
    func adjustWhiteBalance(temperature: Float, tint: Float) async {
        guard let camera = captureSession?.inputs.first as? AVCaptureDeviceInput else { return }
        
        do {
            try camera.device.lockForConfiguration()
            
            if camera.device.isWhiteBalanceModeSupported(.locked) {
                let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                    temperature: temperature,
                    tint: tint
                )
                let gains = camera.device.deviceWhiteBalanceGains(for: temperatureAndTint)
                camera.device.setWhiteBalanceModeLocked(with: gains)
            }
            
            camera.device.unlockForConfiguration()
        } catch {
            debugPrint("❌ Failed to adjust white balance: \(error)")
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CustomCameraScanner: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            debugPrint("❌ Photo capture error: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            debugPrint("❌ Failed to create image from photo data")
            return
        }
        
        Task { @MainActor in
            self.capturedImage = image
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CustomCameraScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard enableEdgeDetection,
              let request = rectangleDetectionRequest,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        visionQueue.async {
            do {
                try handler.perform([request])
            } catch {
                // Silently fail for real-time detection
            }
        }
    }
}

// MARK: - Camera Overlay View

/// SwiftUI view for camera preview with edge detection overlay
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    
    @ObservedObject var scanner: CustomCameraScanner
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.scanner = scanner
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updateOverlay(rectangle: scanner.detectedRectangle)
    }
}

class CameraPreviewUIView: UIView {
    
    weak var scanner: CustomCameraScanner?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var overlayLayer: CAShapeLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        // Setup will happen when scanner is set
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if previewLayer == nil, let scanner = scanner {
            let layer = scanner.getPreviewLayer()
            layer?.frame = bounds
            
            if let layer = layer {
                self.layer.addSublayer(layer)
                previewLayer = layer
            }
        } else {
            previewLayer?.frame = bounds
        }
        
        if overlayLayer == nil {
            let overlay = CAShapeLayer()
            overlay.strokeColor = UIColor.green.cgColor
            overlay.lineWidth = 3
            overlay.fillColor = UIColor.green.withAlphaComponent(0.2).cgColor
            self.layer.addSublayer(overlay)
            overlayLayer = overlay
        }
    }
    
    func updateOverlay(rectangle: VNRectangleObservation?) {
        guard let rectangle = rectangle,
              let previewLayer = previewLayer else {
            overlayLayer?.path = nil
            return
        }
        
        let path = UIBezierPath()
        
        let topLeft = previewLayer.layerPointConverted(fromCaptureDevicePoint: rectangle.topLeft)
        let topRight = previewLayer.layerPointConverted(fromCaptureDevicePoint: rectangle.topRight)
        let bottomLeft = previewLayer.layerPointConverted(fromCaptureDevicePoint: rectangle.bottomLeft)
        let bottomRight = previewLayer.layerPointConverted(fromCaptureDevicePoint: rectangle.bottomRight)
        
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.close()
        
        overlayLayer?.path = path.cgPath
    }
}
