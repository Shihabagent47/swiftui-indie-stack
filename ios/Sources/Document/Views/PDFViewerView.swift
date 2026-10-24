//
//  PDFViewerView.swift
//  MyApp
//
//  Interactive PDF viewer with pinch-to-zoom, swipe navigation, and gestures.
//

import SwiftUI
import PDFKit

// MARK: - PDF Viewer View

struct PDFViewerView: View {
    let document: PDFDocument
    let initialPage: Int

    @State private var currentPage: Int
    @State private var showControls = true
    @State private var scale: CGFloat = 1.0
    @Environment(\.dismiss) private var dismiss

    init(document: PDFDocument, initialPage: Int = 0) {
        self.document = document
        self.initialPage = initialPage
        _currentPage = State(initialValue: initialPage)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // PDF View
            PDFKitView(
                document: document,
                currentPage: $currentPage,
                scale: $scale,
                showControls: $showControls
            )
            .ignoresSafeArea()

            // Controls Overlay
            if showControls {
                VStack {
                    // Top toolbar
                    topToolbar

                    Spacer()

                    // Bottom controls
                    bottomControls
                }
                .transition(.opacity)
            }
        }
        .statusBar(hidden: !showControls)
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
        .accessibilityLabel("PDF Viewer")
        .accessibilityHint("Tap to show or hide controls, pinch to zoom, swipe to navigate pages")
    }

    // MARK: - Top Toolbar

    private var topToolbar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close")

            Spacer()

            Text("Page \(currentPage + 1) of \(document.pageCount)")
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(20)

            Spacer()

            Menu {
                Button {
                    shareDocument()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                Button {
                    printDocument()
                } label: {
                    Label("Print", systemImage: "printer")
                }

                Divider()

                Button {
                    resetZoom()
                } label: {
                    Label("Reset Zoom", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Options")
        }
        .padding()
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 24) {
            // Previous page
            Button {
                goToPreviousPage()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(currentPage == 0)
            .opacity(currentPage == 0 ? 0.5 : 1.0)
            .accessibilityLabel("Previous page")

            // Page slider
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { Double(currentPage) },
                        set: { currentPage = Int($0) }
                    ),
                    in: 0...Double(max(0, document.pageCount - 1)),
                    step: 1
                )
                .tint(.white)
                .accessibilityLabel("Page navigation")
                .accessibilityValue("Page \(currentPage + 1) of \(document.pageCount)")
            }
            .frame(maxWidth: 200)

            // Next page
            Button {
                goToNextPage()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(currentPage >= document.pageCount - 1)
            .opacity(currentPage >= document.pageCount - 1 ? 0.5 : 1.0)
            .accessibilityLabel("Next page")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
        )
        .padding(.horizontal)
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func goToNextPage() {
        guard currentPage < document.pageCount - 1 else { return }
        withAnimation {
            currentPage += 1
        }
        Haptics.light()
    }

    private func goToPreviousPage() {
        guard currentPage > 0 else { return }
        withAnimation {
            currentPage -= 1
        }
        Haptics.light()
    }

    private func resetZoom() {
        scale = 1.0
        Haptics.medium()
    }

    private func shareDocument() {
        // TODO: Implement share sheet
        Haptics.light()
    }

    private func printDocument() {
        // TODO: Implement printing
        Haptics.light()
    }
}

// MARK: - PDFKit View Wrapper

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    @Binding var scale: CGFloat
    @Binding var showControls: Bool

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()

        // Configure PDF view
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true, withViewOptions: nil)
        pdfView.backgroundColor = .black

        // Enable gestures
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.maxScaleFactor = 4.0

        // Set initial page
        if let page = document.page(at: currentPage) {
            pdfView.go(to: page)
        }

        // Add page change notification
        NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: pdfView,
            queue: .main
        ) { _ in
            if let currentPDFPage = pdfView.currentPage {
                context.coordinator.parent.currentPage = document.index(for: currentPDFPage)
            }
        }

        // Add scale change notification
        NotificationCenter.default.addObserver(
            forName: .PDFViewScaleChanged,
            object: pdfView,
            queue: .main
        ) { _ in
            context.coordinator.parent.scale = pdfView.scaleFactor
        }

        // Add tap gesture to toggle controls
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap)
        )
        tapGesture.numberOfTapsRequired = 1
        pdfView.addGestureRecognizer(tapGesture)

        context.coordinator.pdfView = pdfView

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Update page if changed externally
        if let page = document.page(at: currentPage),
           pdfView.currentPage != page {
            pdfView.go(to: page)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: PDFKitView
        weak var pdfView: PDFView?

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        @objc func handleTap() {
            // Let the SwiftUI gesture handler manage this
        }
    }
}

// MARK: - Preview

#Preview {
    if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf"),
       let document = PDFDocument(url: url) {
        PDFViewerView(document: document)
    } else {
        Text("No sample PDF found")
    }
}
