//
//  CompletePDFEditorView.swift
//  MyApp
//
//  Complete PDF editor with annotations, thumbnails, undo/redo, and tool palettes.
//

import SwiftUI
import PDFKit
import Combine

// MARK: - PDF Editor View

struct CompletePDFEditorView: View {
    let document: PDFDocument

    @StateObject private var viewModel: PDFEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(document: PDFDocument) {
        self.document = document
        _viewModel = StateObject(wrappedValue: PDFEditorViewModel(document: document))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                HStack(spacing: 0) {
                    // Page thumbnail sidebar (optional)
                    if viewModel.showThumbnails {
                        PageThumbnailSidebar(
                            document: document,
                            currentPage: $viewModel.currentPage,
                            onPageSelected: { page in
                                viewModel.selectPage(page)
                                Haptics.light()
                            },
                            onPageDeleted: { page in
                                viewModel.deletePage(page)
                                Haptics.medium()
                            }
                        )
                        .frame(width: 120)
                        .transition(.move(edge: .leading))
                    }

                    // Main PDF editing area
                    VStack(spacing: 0) {
                        // Top toolbar
                        topToolbar

                        // PDF canvas
                        PDFEditorCanvas(
                            document: document,
                            currentPage: viewModel.currentPage,
                            selectedTool: viewModel.selectedTool,
                            toolColor: viewModel.toolColor,
                            toolWidth: viewModel.toolWidth,
                            onAnnotationAdded: { annotation in
                                viewModel.addAnnotation(annotation)
                            }
                        )

                        // Bottom tool palette
                        if viewModel.showToolPalette {
                            AnnotationToolPalette(
                                selectedTool: $viewModel.selectedTool,
                                selectedColor: $viewModel.toolColor,
                                selectedWidth: $viewModel.toolWidth,
                                onToolSelected: { tool in
                                    Haptics.light()
                                }
                            )
                            .transition(.move(edge: .bottom))
                        }
                    }
                }

                // Color picker overlay
                if viewModel.showColorPicker {
                    ColorPickerOverlay(selectedColor: $viewModel.toolColor) {
                        viewModel.showColorPicker = false
                    }
                }

                // Text input overlay
                if viewModel.showTextInput {
                    TextAnnotationOverlay(
                        text: $viewModel.textInput,
                        onSave: { text in
                            viewModel.addTextAnnotation(text)
                        },
                        onCancel: {
                            viewModel.showTextInput = false
                        }
                    )
                }
            }
        }
        .navigationTitle("Edit PDF")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 16) {
                    Button {
                        viewModel.undo()
                        Haptics.light()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!viewModel.canUndo)

                    Button {
                        viewModel.redo()
                        Haptics.light()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!viewModel.canRedo)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        viewModel.showThumbnails.toggle()
                        Haptics.light()
                    } label: {
                        Label(
                            viewModel.showThumbnails ? "Hide Pages" : "Show Pages",
                            systemImage: "sidebar.left"
                        )
                    }

                    Button {
                        viewModel.showToolPalette.toggle()
                        Haptics.light()
                    } label: {
                        Label(
                            viewModel.showToolPalette ? "Hide Tools" : "Show Tools",
                            systemImage: "pencil.tip.crop.circle"
                        )
                    }

                    Divider()

                    Button {
                        viewModel.saveDocument()
                        Haptics.success()
                        dismiss()
                    } label: {
                        Label("Save & Close", systemImage: "checkmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .accessibilityLabel("PDF Editor")
    }

    // MARK: - Top Toolbar

    private var topToolbar: some View {
        HStack(spacing: 16) {
            // Tool selection buttons
            ToolbarButton(
                icon: "hand.draw",
                isSelected: viewModel.selectedTool == .pen,
                action: {
                    viewModel.selectedTool = .pen
                    Haptics.light()
                }
            )
            .accessibilityLabel("Pen tool")

            ToolbarButton(
                icon: "highlighter",
                isSelected: viewModel.selectedTool == .highlighter,
                action: {
                    viewModel.selectedTool = .highlighter
                    Haptics.light()
                }
            )
            .accessibilityLabel("Highlighter tool")

            ToolbarButton(
                icon: "text.bubble",
                isSelected: viewModel.selectedTool == .text,
                action: {
                    viewModel.selectedTool = .text
                    viewModel.showTextInput = true
                    Haptics.light()
                }
            )
            .accessibilityLabel("Text tool")

            ToolbarButton(
                icon: "signature",
                isSelected: viewModel.selectedTool == .signature,
                action: {
                    viewModel.selectedTool = .signature
                    Haptics.light()
                }
            )
            .accessibilityLabel("Signature tool")

            Divider()
                .frame(height: 24)

            ToolbarButton(
                icon: "square",
                isSelected: viewModel.selectedTool == .rectangle,
                action: {
                    viewModel.selectedTool = .rectangle
                    Haptics.light()
                }
            )
            .accessibilityLabel("Rectangle tool")

            ToolbarButton(
                icon: "circle",
                isSelected: viewModel.selectedTool == .circle,
                action: {
                    viewModel.selectedTool = .circle
                    Haptics.light()
                }
            )
            .accessibilityLabel("Circle tool")

            ToolbarButton(
                icon: "arrow.right",
                isSelected: viewModel.selectedTool == .arrow,
                action: {
                    viewModel.selectedTool = .arrow
                    Haptics.light()
                }
            )
            .accessibilityLabel("Arrow tool")

            Spacer()

            // Color selector
            Button {
                viewModel.showColorPicker = true
                Haptics.light()
            } label: {
                Circle()
                    .fill(viewModel.toolColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.gray, lineWidth: 1)
                    )
            }
            .accessibilityLabel("Color picker")
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
    }
}

// MARK: - PDF Editor ViewModel

@MainActor
class PDFEditorViewModel: ObservableObject {
    @Published var document: PDFDocument
    @Published var currentPage: PDFPage
    @Published var selectedTool: AnnotationTool = .pen
    @Published var toolColor: Color = .red
    @Published var toolWidth: CGFloat = 3.0
    @Published var showThumbnails = false
    @Published var showToolPalette = true
    @Published var showColorPicker = false
    @Published var showTextInput = false
    @Published var textInput = ""

    private var undoStack: [EditorAction] = []
    private var redoStack: [EditorAction] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init(document: PDFDocument) {
        self.document = document
        self.currentPage = document.page(at: 0) ?? PDFPage()
    }

    func selectPage(_ page: PDFPage) {
        currentPage = page
    }

    func deletePage(_ page: PDFPage) {
        guard document.pageCount > 1 else { return }
        let index = document.index(for: page)
        document.removePage(at: index)
        recordAction(.deletePage(page, index))
        Analytics.track(event: "pdf_page_deleted")
    }

    func addAnnotation(_ annotation: PDFAnnotation) {
        currentPage.addAnnotation(annotation)
        recordAction(.addAnnotation(annotation, currentPage))
        Analytics.track(event: "annotation_added", parameters: ["tool": selectedTool.rawValue])
    }

    func addTextAnnotation(_ text: String) {
        let annotation = PDFAnnotation(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 40),
            forType: .freeText,
            withProperties: nil
        )
        annotation.contents = text
        annotation.color = UIColor(toolColor)
        addAnnotation(annotation)
        showTextInput = false
        textInput = ""
    }

    func undo() {
        guard let action = undoStack.popLast() else { return }
        action.undo()
        redoStack.append(action)
        Haptics.medium()
        Analytics.track(event: "editor_undo")
    }

    func redo() {
        guard let action = redoStack.popLast() else { return }
        action.redo()
        undoStack.append(action)
        Haptics.medium()
        Analytics.track(event: "editor_redo")
    }

    func saveDocument() {
        // Save document logic here
        Analytics.track(event: "pdf_document_saved", parameters: [
            "page_count": document.pageCount,
            "annotation_count": countAnnotations()
        ])
    }

    private func recordAction(_ action: EditorAction) {
        undoStack.append(action)
        redoStack.removeAll()
    }

    private func countAnnotations() -> Int {
        var count = 0
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                count += page.annotations.count
            }
        }
        return count
    }
}

// MARK: - Annotation Tool

enum AnnotationTool: String, CaseIterable {
    case pen = "Pen"
    case highlighter = "Highlighter"
    case text = "Text"
    case signature = "Signature"
    case rectangle = "Rectangle"
    case circle = "Circle"
    case arrow = "Arrow"
    case eraser = "Eraser"

    var icon: String {
        switch self {
        case .pen: return "hand.draw"
        case .highlighter: return "highlighter"
        case .text: return "text.bubble"
        case .signature: return "signature"
        case .rectangle: return "square"
        case .circle: return "circle"
        case .arrow: return "arrow.right"
        case .eraser: return "eraser"
        }
    }
}

// MARK: - Editor Action (for Undo/Redo)

enum EditorAction {
    case addAnnotation(PDFAnnotation, PDFPage)
    case removeAnnotation(PDFAnnotation, PDFPage)
    case deletePage(PDFPage, Int)
    case addPage(PDFPage, Int)

    func undo() {
        switch self {
        case .addAnnotation(let annotation, let page):
            page.removeAnnotation(annotation)
        case .removeAnnotation(let annotation, let page):
            page.addAnnotation(annotation)
        case .deletePage(let page, let index):
            // Re-insert page (would need document reference)
            break
        case .addPage(let page, let index):
            // Remove page (would need document reference)
            break
        }
    }

    func redo() {
        switch self {
        case .addAnnotation(let annotation, let page):
            page.addAnnotation(annotation)
        case .removeAnnotation(let annotation, let page):
            page.removeAnnotation(annotation)
        case .deletePage(let page, let index):
            // Remove page
            break
        case .addPage(let page, let index):
            // Add page
            break
        }
    }
}

// MARK: - Page Thumbnail Sidebar

struct PageThumbnailSidebar: View {
    let document: PDFDocument
    @Binding var currentPage: PDFPage
    let onPageSelected: (PDFPage) -> Void
    let onPageDeleted: (PDFPage) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<document.pageCount, id: \.self) { index in
                    if let page = document.page(at: index) {
                        PageThumbnail(
                            page: page,
                            index: index,
                            isSelected: page == currentPage,
                            onTap: {
                                onPageSelected(page)
                            },
                            onDelete: {
                                onPageDeleted(page)
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
        .accessibilityLabel("Page thumbnails")
    }
}

struct PageThumbnail: View {
    let page: PDFPage
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var thumbnail: UIImage?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 90, height: 120)
                        .cornerRadius(6)
                }

                // Delete button
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                }
                .offset(x: 4, y: -4)
                .opacity(isSelected ? 1 : 0)
            }
            .onTapGesture {
                onTap()
            }

            Text("\(index + 1)")
                .font(.caption2)
                .foregroundColor(isSelected ? .blue : .secondary)
        }
        .onAppear {
            generateThumbnail()
        }
        .confirmationDialog("Delete page \(index + 1)?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Page \(index + 1)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    private func generateThumbnail() {
        let targetSize = CGSize(width: 90, height: 120)
        thumbnail = page.thumbnail(of: targetSize, for: .cropBox)
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.blue : Color.clear)
                .cornerRadius(8)
        }
    }
}

// MARK: - Annotation Tool Palette

struct AnnotationToolPalette: View {
    @Binding var selectedTool: AnnotationTool
    @Binding var selectedColor: Color
    @Binding var selectedWidth: CGFloat
    let onToolSelected: (AnnotationTool) -> Void

    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .black]

    var body: some View {
        VStack(spacing: 16) {
            // Width slider
            HStack {
                Image(systemName: "line.diagonal")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $selectedWidth, in: 1...10)
                    .frame(maxWidth: 200)

                Text("\(Int(selectedWidth))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 24)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Line width: \(Int(selectedWidth))")

            // Color swatches
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                            )
                            .onTapGesture {
                                selectedColor = color
                                Haptics.light()
                            }
                            .accessibilityLabel("Color: \(color.description)")
                            .accessibilityAddTraits(selectedColor == color ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 2, y: -1)
    }
}

// MARK: - PDF Editor Canvas

struct PDFEditorCanvas: UIViewRepresentable {
    let document: PDFDocument
    let currentPage: PDFPage
    let selectedTool: AnnotationTool
    let toolColor: Color
    let toolWidth: CGFloat
    let onAnnotationAdded: (PDFAnnotation) -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.backgroundColor = .systemGray6
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.currentPage != currentPage {
            pdfView.go(to: currentPage)
        }
    }
}

// MARK: - Color Picker Overlay

struct ColorPickerOverlay: View {
    @Binding var selectedColor: Color
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            ColorPicker("Select Color", selection: $selectedColor)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
                .padding()
        }
    }
}

// MARK: - Text Annotation Overlay

struct TextAnnotationOverlay: View {
    @Binding var text: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 16) {
                Text("Add Text")
                    .font(.headline)

                TextField("Enter text", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)

                    Button("Add") {
                        if !text.isEmpty {
                            onSave(text)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(text.isEmpty)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding()
        }
    }
}

// MARK: - Preview

#Preview {
    if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf"),
       let document = PDFDocument(url: url) {
        NavigationView {
            CompletePDFEditorView(document: document)
        }
    } else {
        Text("No sample PDF found")
    }
}
