//
//  ScannerView.swift
//  MyApp
//
//  SwiftUI views for document scanning interface.
//

import SwiftUI
import VisionKit

// MARK: - Scanner View

struct ScannerView: View {
    
    @StateObject private var scannerManager = DocumentScannerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingScannedImages = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onComplete: ([UIImage]) -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                if scannerManager.isDocumentScannerAvailable {
                    scannerButton
                } else {
                    unavailableMessage
                }
            }
        }
        .sheet(isPresented: $showingScannedImages) {
            ScannedImagesReview(
                images: scannerManager.scannedImages,
                onSave: { images in
                    onComplete(images)
                    dismiss()
                },
                onCancel: {
                    scannerManager.scannedImages.removeAll()
                }
            )
        }
        .alert("Scan Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var scannerButton: some View {
        Button {
            openScanner()
        } label: {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("Tap to Scan Document")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Position your document and tap the shutter")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(40)
        }
    }
    
    private var unavailableMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Scanner Unavailable")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Document scanning is not available on this device")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func openScanner() {
        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        do {
            try scannerManager.presentDocumentScanner(from: rootViewController)
            
            // Wait for scan completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                checkScanCompletion()
            }
        } catch let error as ScanError {
            errorMessage = error.localizedDescription ?? "Failed to start scanner"
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func checkScanCompletion() {
        if !scannerManager.isScanning && !scannerManager.scannedImages.isEmpty {
            showingScannedImages = true
        } else if scannerManager.isScanning {
            // Still scanning, check again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkScanCompletion()
            }
        }
    }
}

// MARK: - Scanned Images Review

struct ScannedImagesReview: View {
    
    let images: [UIImage]
    let onSave: ([UIImage]) -> Void
    let onCancel: () -> Void
    
    @State private var currentIndex = 0
    @State private var editedImages: [UIImage]
    @State private var showingImageEditor = false
    
    init(images: [UIImage], onSave: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
        self.images = images
        self.onSave = onSave
        self.onCancel = onCancel
        _editedImages = State(initialValue: images)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Image viewer
                TabView(selection: $currentIndex) {
                    ForEach(Array(editedImages.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                
                // Page counter
                Text("Page \(currentIndex + 1) of \(editedImages.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                
                Divider()
                
                // Action buttons
                HStack(spacing: 20) {
                    Button(role: .destructive) {
                        deletePage()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(editedImages.count <= 1)
                    
                    Spacer()
                    
                    Button {
                        showingImageEditor = true
                    } label: {
                        Label("Edit", systemImage: "slider.horizontal.3")
                    }
                    
                    Spacer()
                    
                    Button {
                        onSave(editedImages)
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Review Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
        .sheet(isPresented: $showingImageEditor) {
            ImageEditorView(
                image: editedImages[currentIndex],
                onSave: { editedImage in
                    editedImages[currentIndex] = editedImage
                }
            )
        }
    }
    
    private func deletePage() {
        guard editedImages.count > 1, currentIndex < editedImages.count else { return }
        
        editedImages.remove(at: currentIndex)
        
        // Adjust current index if needed
        if currentIndex >= editedImages.count {
            currentIndex = editedImages.count - 1
        }
    }
}

// MARK: - Image Editor View

struct ImageEditorView: View {
    
    let image: UIImage
    let onSave: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var brightness: Double = 0.0
    @State private var contrast: Double = 1.0
    @State private var rotation: Double = 0.0
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(rotation))
                    .padding()
                
                Divider()
                
                // Controls
                Form {
                    Section("Adjustments") {
                        VStack(alignment: .leading) {
                            Text("Brightness")
                                .font(.subheadline)
                            Slider(value: $brightness, in: -0.5...0.5)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Contrast")
                                .font(.subheadline)
                            Slider(value: $contrast, in: 0.5...2.0)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Rotation")
                                .font(.subheadline)
                            Slider(value: $rotation, in: -45...45)
                        }
                    }
                    
                    Section {
                        Button("Reset") {
                            brightness = 0.0
                            contrast = 1.0
                            rotation = 0.0
                        }
                    }
                }
            }
            .navigationTitle("Edit Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyEdits()
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }
    
    private func applyEdits() {
        isProcessing = true
        
        Task {
            var editedImage = image
            
            // Apply rotation
            if rotation != 0 {
                editedImage = await ImageProcessingPool.shared.rotateImage(
                    editedImage,
                    degrees: rotation
                ) ?? editedImage
            }
            
            // Apply brightness and contrast
            if brightness != 0 || contrast != 1.0 {
                editedImage = await ImageProcessingPool.shared.enhanceImage(
                    editedImage,
                    brightness: Float(brightness),
                    contrast: Float(contrast)
                ) ?? editedImage
            }
            
            await MainActor.run {
                onSave(editedImage)
                isProcessing = false
                dismiss()
            }
        }
    }
}

// MARK: - Custom Camera Scanner View

struct CustomCameraScannerView: View {
    
    @StateObject private var scanner = CustomCameraScanner()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCapturedImage = false
    
    let onCapture: (UIImage) -> Void
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(scanner: scanner)
                .ignoresSafeArea()
            
            // Overlay controls
            VStack {
                // Top controls
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button {
                        scanner.toggleFlash()
                    } label: {
                        Image(systemName: flashIcon)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                // Detection status
                if scanner.isDetectingDocument {
                    Text("Document Detected")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(20)
                }
                
                Spacer()
                
                // Capture button
                Button {
                    scanner.capturePhoto()
                } label: {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 4)
                        .background(Circle().fill(Color.white.opacity(0.3)))
                        .frame(width: 70, height: 70)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Task {
                try? await scanner.setupCamera()
                scanner.startSession()
            }
        }
        .onDisappear {
            scanner.stopSession()
        }
        .onChange(of: scanner.capturedImage) { _, newImage in
            if let image = newImage {
                onCapture(image)
                dismiss()
            }
        }
    }
    
    private var flashIcon: String {
        switch scanner.flashMode {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.a"
        @unknown default: return "bolt.slash"
        }
    }
}

#Preview {
    ScannerView { images in
        print("Scanned \(images.count) images")
    }
}
