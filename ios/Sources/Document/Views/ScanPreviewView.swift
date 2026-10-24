//
//  ScanPreviewView.swift
//  MyApp
//
//  Preview and edit scanned pages before saving.
//

import SwiftUI
import Combine

// MARK: - Scan Preview View

struct ScanPreviewView: View {
    let scan: DocumentScan
    let onSave: (DocumentScan) -> Void

    @StateObject private var viewModel: ScanPreviewViewModel
    @Environment(\.dismiss) private var dismiss

    init(scan: DocumentScan, onSave: @escaping (DocumentScan) -> Void) {
        self.scan = scan
        self.onSave = onSave
        _viewModel = StateObject(wrappedValue: ScanPreviewViewModel(scan: scan))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Page carousel
                pageCarousel

                // Thumbnail strip
                thumbnailStrip

                // Editing tools
                editingTools
            }
            .navigationTitle("Scan Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveScan()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $viewModel.showCropEditor) {
                if let page = viewModel.currentPage {
                    CropEditorView(page: page) { croppedPage in
                        viewModel.updatePage(croppedPage)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showFilterOptions) {
                FilterOptionsView(selectedMode: $viewModel.filterMode)
            }
        }
    }

    // MARK: - Page Carousel

    private var pageCarousel: some View {
        TabView(selection: $viewModel.currentPageIndex) {
            ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                ZStack {
                    Color.black

                    Image(uiImage: page.image)
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(.degrees(Double(viewModel.rotations[page.id] ?? 0) * 90))
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black)
        .accessibilityLabel("Page \(viewModel.currentPageIndex + 1) of \(viewModel.pages.count)")
    }

    // MARK: - Thumbnail Strip

    private var thumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                        ThumbnailView(
                            page: page,
                            index: index,
                            isSelected: index == viewModel.currentPageIndex,
                            rotation: viewModel.rotations[page.id] ?? 0
                        ) {
                            withAnimation {
                                viewModel.currentPageIndex = index
                            }
                            Haptics.light()
                        } onDelete: {
                            viewModel.deletePage(at: index)
                            Haptics.medium()
                        }
                        .id(index)
                    }

                    // Add page button
                    Button {
                        viewModel.showAddPage = true
                        Haptics.light()
                    } label: {
                        VStack {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 60, height: 80)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)

                            Text("Add")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 110)
            .background(Color(.systemGroupedBackground))
            .onChange(of: viewModel.currentPageIndex) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - Editing Tools

    private var editingTools: some View {
        VStack(spacing: 16) {
            // Main tool buttons
            HStack(spacing: 20) {
                ToolButton(
                    icon: "crop",
                    title: "Crop",
                    action: {
                        viewModel.showCropEditor = true
                        Haptics.light()
                    }
                )

                ToolButton(
                    icon: "rotate.right",
                    title: "Rotate",
                    action: {
                        viewModel.rotateCurrentPage()
                        Haptics.medium()
                    }
                )

                ToolButton(
                    icon: "wand.and.stars",
                    title: "Filter",
                    action: {
                        viewModel.showFilterOptions = true
                        Haptics.light()
                    }
                )

                ToolButton(
                    icon: "slider.horizontal.3",
                    title: "Adjust",
                    action: {
                        viewModel.showAdjustments.toggle()
                        Haptics.light()
                    }
                )
            }

            // Adjustment sliders (if shown)
            if viewModel.showAdjustments {
                AdjustmentControlsView(
                    brightness: $viewModel.brightness,
                    contrast: $viewModel.contrast,
                    sharpness: $viewModel.sharpness
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func saveScan() {
        let processedScan = viewModel.getProcessedScan()
        onSave(processedScan)
        dismiss()
        Haptics.success()
        Analytics.track(event: "scan_preview_saved", parameters: [
            "page_count": processedScan.pages.count,
            "filter_mode": viewModel.filterMode.rawValue
        ])
    }
}

// MARK: - Scan Preview ViewModel

@MainActor
class ScanPreviewViewModel: ObservableObject {
    @Published var pages: [ScannedPage]
    @Published var currentPageIndex = 0
    @Published var showCropEditor = false
    @Published var showFilterOptions = false
    @Published var showAdjustments = false
    @Published var showAddPage = false
    @Published var filterMode: ScanMode = .color
    @Published var rotations: [UUID: Int] = [:] // Page ID -> rotation count (0-3)
    @Published var brightness: Double = 0
    @Published var contrast: Double = 1.0
    @Published var sharpness: Double = 0

    private let originalScan: DocumentScan

    var currentPage: ScannedPage? {
        guard currentPageIndex < pages.count else { return nil }
        return pages[currentPageIndex]
    }

    init(scan: DocumentScan) {
        self.originalScan = scan
        self.pages = scan.pages
        self.filterMode = scan.scanMode
    }

    func rotateCurrentPage() {
        guard let page = currentPage else { return }
        let currentRotation = rotations[page.id] ?? 0
        rotations[page.id] = (currentRotation + 1) % 4
    }

    func deletePage(at index: Int) {
        guard pages.count > 1 else { return } // Don't delete last page
        pages.remove(at: index)
        if currentPageIndex >= pages.count {
            currentPageIndex = pages.count - 1
        }
    }

    func updatePage(_ page: ScannedPage) {
        if let index = pages.firstIndex(where: { $0.id == page.id }) {
            pages[index] = page
        }
    }

    func getProcessedScan() -> DocumentScan {
        // Apply all transformations and return final scan
        return DocumentScan(
            id: originalScan.id,
            pages: pages,
            scanMode: filterMode,
            createdAt: originalScan.createdAt
        )
    }
}

// MARK: - Thumbnail View

struct ThumbnailView: View {
    let page: ScannedPage
    let index: Int
    let isSelected: Bool
    let rotation: Int
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: page.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .rotationEffect(.degrees(Double(rotation) * 90))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
                    .onTapGesture {
                        onTap()
                    }

                // Delete button
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                }
                .offset(x: 8, y: -8)
                .confirmationDialog("Delete this page?", isPresented: $showDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }

            Text("\(index + 1)")
                .font(.caption2)
                .foregroundColor(isSelected ? .blue : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Page \(index + 1)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.blue)
        }
        .accessibilityLabel(title)
    }
}

// MARK: - Adjustment Controls

struct AdjustmentControlsView: View {
    @Binding var brightness: Double
    @Binding var contrast: Double
    @Binding var sharpness: Double

    var body: some View {
        VStack(spacing: 12) {
            AdjustmentSlider(
                icon: "sun.max",
                value: $brightness,
                range: -1...1,
                label: "Brightness"
            )

            AdjustmentSlider(
                icon: "circle.lefthalf.filled",
                value: $contrast,
                range: 0.5...1.5,
                label: "Contrast"
            )

            AdjustmentSlider(
                icon: "sparkles",
                value: $sharpness,
                range: 0...1,
                label: "Sharpness"
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AdjustmentSlider: View {
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Slider(value: $value, in: range)
                .tint(.blue)

            Text(String(format: "%.1f", value))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(String(format: "%.1f", value))")
    }
}

// MARK: - Crop Editor View

struct CropEditorView: View {
    let page: ScannedPage
    let onSave: (ScannedPage) -> Void

    @State private var cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: page.image)
                    .resizable()
                    .scaledToFit()

                // Crop overlay would go here
                // This is a simplified version
            }
            .navigationTitle("Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Apply crop and save
                        onSave(page)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Filter Options View

struct FilterOptionsView: View {
    @Binding var selectedMode: ScanMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(ScanMode.allCases, id: \.self) { mode in
                    Button {
                        selectedMode = mode
                        Haptics.light()
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(mode.rawValue)
                                    .foregroundColor(.primary)
                                Text(mode.descriptionText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scan Mode")
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

// MARK: - ScanMode Extension

extension ScanMode {
    var description: String {
        switch self {
        case .color:
            return "Full color scan"
        case .grayscale:
            return "Black and white with shades of gray"
        case .blackAndWhite:
            return "Pure black and white, no gray"
        case .photo:
            return "Optimized for photos"
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleImage = UIImage(systemName: "doc.text.fill")!
    let pages = [
        ScannedPage(id: UUID(), image: sampleImage, pageNumber: 0, detectedRectangle: nil),
        ScannedPage(id: UUID(), image: sampleImage, pageNumber: 1, detectedRectangle: nil)
    ]
    let scan = DocumentScan(id: UUID(), pages: pages, scanMode: .color, createdAt: Date())

    ScanPreviewView(scan: scan) { _ in }
}
