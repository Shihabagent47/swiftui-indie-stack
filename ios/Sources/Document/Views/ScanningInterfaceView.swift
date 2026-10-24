//
//  ScanningInterfaceView.swift
//  MyApp
//
//  Complete scanning interface with camera viewfinder, edge detection, and controls.
//

import SwiftUI
import VisionKit
import Combine

// MARK: - Scanning Interface View

struct ScanningInterfaceView: View {
    @StateObject private var viewModel = ScanningViewModel()
    @ObservedObject var quotaManager = QuotaManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showQuotaExceeded = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top toolbar
                topToolbar

                // Camera viewfinder or scanner
                scannerContent

                // Bottom controls
                bottomControls
            }
        }
        .sheet(isPresented: $viewModel.showPreview) {
            if let scan = viewModel.currentScan {
                ScanPreviewView(scan: scan) { processedScan in
                    viewModel.saveScan(processedScan)
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $viewModel.showHistory) {
            ScanHistoryView(scans: viewModel.recentScans)
        }
        .sheet(isPresented: $showQuotaExceeded) {
            QuotaExceededView(quotaType: .scans)
        }
        .alert("Scan Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred while scanning")
        }
        .onAppear {
            // Check quota on appear
            if !quotaManager.canScan {
                showQuotaExceeded = true
                dismiss()
            }
        }
    }

    // MARK: - Top Toolbar

    private var topToolbar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Cancel scanning")

            Spacer()

            // Flash control
            Button {
                viewModel.toggleFlash()
                Haptics.light()
            } label: {
                Image(systemName: viewModel.flashMode.iconName)
                    .font(.title3)
                    .foregroundColor(viewModel.flashMode == .on ? .yellow : .white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Flash: \(viewModel.flashMode.description)")

            // Scan mode
            Menu {
                ForEach(ScanMode.allCases, id: \.self) { mode in
                    Button {
                        viewModel.scanMode = mode
                        Haptics.light()
                    } label: {
                        Label(
                            mode.rawValue,
                            systemImage: viewModel.scanMode == mode ? "checkmark" : ""
                        )
                    }
                }
            } label: {
                Image(systemName: "wand.and.stars")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Scan mode: \(viewModel.scanMode.rawValue)")

            // History
            Button {
                viewModel.showHistory = true
                Haptics.light()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())

                    if !viewModel.recentScans.isEmpty {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .accessibilityLabel("Scan history")
        }
        .padding()
    }

    // MARK: - Scanner Content

    private var scannerContent: some View {
        ZStack {
            if viewModel.useNativeScanner {
                // VisionKit scanner
                DocumentCameraView(
                    onScan: { scan in
                        viewModel.handleNativeScan(scan)
                    },
                    onError: { error in
                        viewModel.handleError(error)
                    }
                )
            } else {
                // Custom camera scanner
                CustomCameraScannerView(
                    showEdgeDetection: viewModel.showEdgeDetection,
                    flashMode: viewModel.flashMode,
                    scanMode: viewModel.scanMode,
                    onCapture: { image in
                        viewModel.captureImage(image)
                    }
                )
            }

            // Edge detection overlay
            if viewModel.showEdgeDetection && viewModel.detectedRectangle != nil {
                EdgeDetectionOverlay(rectangle: viewModel.detectedRectangle!)
            }

            // Multi-page indicator
            if viewModel.capturedPages.count > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Text("\(viewModel.capturedPages.count) page\(viewModel.capturedPages.count == 1 ? "" : "s")")
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(20)
                        Spacer()
                    }
                    .padding(.bottom, 100)
                    .padding(.leading)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera viewfinder")
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 32) {
            // Scanner mode toggle
            Button {
                viewModel.useNativeScanner.toggle()
                Haptics.medium()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: viewModel.useNativeScanner ? "camera.viewfinder" : "camera.aperture")
                        .font(.title2)
                    Text(viewModel.useNativeScanner ? "Native" : "Custom")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(width: 60)
            }
            .accessibilityLabel(viewModel.useNativeScanner ? "Using native scanner" : "Using custom scanner")

            Spacer()

            // Capture button
            Button {
                // Check quota before capturing
                if quotaManager.canScan {
                    viewModel.capture()
                    Haptics.heavy()
                } else {
                    showQuotaExceeded = true
                    Haptics.medium()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 76, height: 76)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                        .opacity(viewModel.isCapturing ? 0.5 : 1.0)
                }
            }
            .disabled(viewModel.isCapturing)
            .accessibilityLabel("Capture document")

            Spacer()

            // Done/Preview button
            Button {
                if !viewModel.capturedPages.isEmpty {
                    viewModel.finishScanning()
                    Haptics.medium()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                    Text("Done")
                        .font(.caption2)
                }
                .foregroundColor(viewModel.capturedPages.isEmpty ? .gray : .white)
                .frame(width: 60)
            }
            .disabled(viewModel.capturedPages.isEmpty)
            .accessibilityLabel("Finish scanning")
            .accessibilityHint("\(viewModel.capturedPages.count) pages captured")
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(Color.black.opacity(0.7))
    }
}

// MARK: - Scanning ViewModel

@MainActor
class ScanningViewModel: ObservableObject {
    @Published var useNativeScanner = true
    @Published var showEdgeDetection = true
    @Published var flashMode: FlashMode = .auto
    @Published var scanMode: ScanMode = .color
    @Published var capturedPages: [ScannedPage] = []
    @Published var currentScan: DocumentScan?
    @Published var showPreview = false
    @Published var showHistory = false
    @Published var isCapturing = false
    @Published var detectedRectangle: DetectedRectangle?
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var recentScans: [DocumentScan] = []

    func toggleFlash() {
        switch flashMode {
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        case .off:
            flashMode = .auto
        }
    }

    func capture() {
        isCapturing = true
        // Capture will be handled by the camera view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isCapturing = false
        }
    }

    func captureImage(_ image: UIImage) {
        let page = ScannedPage(
            id: UUID(),
            image: image,
            pageNumber: capturedPages.count,
            detectedRectangle: detectedRectangle
        )
        capturedPages.append(page)
        Analytics.track(event: "page_scanned", parameters: ["page_count": capturedPages.count])
    }

    func finishScanning() {
        currentScan = DocumentScan(
            id: UUID(),
            pages: capturedPages,
            scanMode: scanMode,
            createdAt: Date()
        )
        showPreview = true
    }

    func handleNativeScan(_ scan: VNDocumentCameraScan) {
        var pages: [ScannedPage] = []
        for i in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: i)
            let page = ScannedPage(
                id: UUID(),
                image: image,
                pageNumber: i,
                detectedRectangle: nil
            )
            pages.append(page)
        }
        capturedPages = pages
        finishScanning()
        Analytics.track(event: "native_scan_completed", parameters: ["page_count": pages.count])
    }

    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        Analytics.track(event: "scan_error", parameters: ["error": error.localizedDescription])
    }

    func saveScan(_ scan: DocumentScan) {
        recentScans.insert(scan, at: 0)
        if recentScans.count > 10 {
            recentScans = Array(recentScans.prefix(10))
        }

        // Record scan in quota manager
        QuotaManager.shared.recordScan()

        Analytics.track(event: "scan_saved", parameters: ["page_count": scan.pages.count])
    }
}

// MARK: - Supporting Types

enum FlashMode: String, CaseIterable {
    case auto = "Auto"
    case on = "On"
    case off = "Off"

    var iconName: String {
        switch self {
        case .auto: return "bolt.badge.automatic"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        }
    }

    var description: String {
        rawValue
    }
}

struct ScannedPage: Identifiable {
    let id: UUID
    let image: UIImage
    let pageNumber: Int
    let detectedRectangle: DetectedRectangle?
}

struct DocumentScan: Identifiable {
    let id: UUID
    let pages: [ScannedPage]
    let scanMode: ScanMode
    let createdAt: Date
}

struct DetectedRectangle {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint
}

// MARK: - Document Camera View (VisionKit Wrapper)

struct DocumentCameraView: UIViewControllerRepresentable {
    let onScan: (VNDocumentCameraScan) -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onError: onError)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (VNDocumentCameraScan) -> Void
        let onError: (Error) -> Void

        init(onScan: @escaping (VNDocumentCameraScan) -> Void, onError: @escaping (Error) -> Void) {
            self.onScan = onScan
            self.onError = onError
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onScan(scan)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onError(error)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            // Handle cancellation
        }
    }
}

// MARK: - Custom Camera Scanner View (Placeholder)

struct CustomCameraScannerView: View {
    let showEdgeDetection: Bool
    let flashMode: FlashMode
    let scanMode: ScanMode
    let onCapture: (UIImage) -> Void

    var body: some View {
        // This would integrate with CustomCameraScanner from the utilities
        // For now, showing a placeholder that can be replaced with actual implementation
        ZStack {
            Color.gray.opacity(0.3)

            VStack {
                Text("Custom Camera View")
                    .foregroundColor(.white)
                Text("Edge Detection: \(showEdgeDetection ? "On" : "Off")")
                    .foregroundColor(.white)
                    .font(.caption)
                Text("Mode: \(scanMode.rawValue)")
                    .foregroundColor(.white)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Edge Detection Overlay

struct EdgeDetectionOverlay: View {
    let rectangle: DetectedRectangle

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: rectangle.topLeft)
                path.addLine(to: rectangle.topRight)
                path.addLine(to: rectangle.bottomRight)
                path.addLine(to: rectangle.bottomLeft)
                path.closeSubpath()
            }
            .stroke(Color.green, lineWidth: 3)

            // Corner indicators
            ForEach([rectangle.topLeft, rectangle.topRight, rectangle.bottomLeft, rectangle.bottomRight], id: \.self) { point in
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .position(point)
            }
        }
    }
}

// MARK: - Scan History View

struct ScanHistoryView: View {
    let scans: [DocumentScan]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(scans) { scan in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(scan.pages.count) page\(scan.pages.count == 1 ? "" : "s")")
                        .font(.headline)
                    Text(scan.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(scan.scanMode.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Recent Scans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScanningInterfaceView()
}
