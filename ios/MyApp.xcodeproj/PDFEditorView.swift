//
//  PDFEditorView.swift
//  MyApp
//
//  SwiftUI views for PDF editing and manipulation.
//

import SwiftUI
import PDFKit

// MARK: - PDF Editor View

struct PDFEditorView: View {
    
    let document: Document
    
    @State private var pdfDocument: PDFDocument?
    @State private var selectedPageIndices: Set<Int> = []
    @State private var editMode: EditMode = .inactive
    @State private var showingAddPage = false
    @State private var showingMerge = false
    @State private var showingAnnotation = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let pdf = pdfDocument {
                    // Page thumbnails
                    pageGridView(pdf)
                    
                    Divider()
                    
                    // Actions toolbar
                    actionsToolbar
                } else {
                    ProgressView("Loading PDF...")
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .environment(\.editMode, $editMode)
        }
        .task {
            await loadPDF()
        }
        .sheet(isPresented: $showingAddPage) {
            AddPageView { image in
                Task {
                    await insertPage(image)
                }
            }
        }
        .sheet(isPresented: $showingAnnotation) {
            if let pdf = pdfDocument {
                AnnotationToolView(pdfDocument: pdf, document: document)
            }
        }
    }
    
    private func pageGridView(_ pdf: PDFDocument) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 120), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(0..<pdf.pageCount, id: \.self) { index in
                    PageThumbnailView(
                        page: pdf.page(at: index)!,
                        pageNumber: index + 1,
                        isSelected: selectedPageIndices.contains(index)
                    )
                    .onTapGesture {
                        if editMode == .active {
                            toggleSelection(index)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var actionsToolbar: some View {
        HStack(spacing: 20) {
            if editMode == .active && !selectedPageIndices.isEmpty {
                // Edit mode actions
                Button(role: .destructive) {
                    deleteSelectedPages()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                
                Spacer()
                
                Button {
                    rotateSelectedPages()
                } label: {
                    Label("Rotate", systemImage: "rotate.right")
                }
            } else {
                // Normal mode actions
                Button {
                    showingAddPage = true
                } label: {
                    Label("Add Page", systemImage: "plus")
                }
                
                Spacer()
                
                Button {
                    showingMerge = true
                } label: {
                    Label("Merge", systemImage: "doc.on.doc")
                }
                
                Spacer()
                
                Button {
                    showingAnnotation = true
                } label: {
                    Label("Annotate", systemImage: "pencil.tip.crop.circle")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Actions
    
    private func loadPDF() async {
        do {
            let data = try await DocumentFileManager.shared.loadDocument(at: document.fileURL)
            if let pdf = PDFDocument(data: data) {
                await MainActor.run {
                    pdfDocument = pdf
                }
            }
        } catch {
            debugPrint("❌ Failed to load PDF: \(error)")
        }
    }
    
    private func toggleSelection(_ index: Int) {
        if selectedPageIndices.contains(index) {
            selectedPageIndices.remove(index)
        } else {
            selectedPageIndices.insert(index)
        }
    }
    
    private func deleteSelectedPages() {
        guard let pdf = pdfDocument else { return }
        
        Task {
            do {
                var newURL = document.fileURL
                for index in selectedPageIndices.sorted(by: >) {
                    newURL = try await PDFManager.shared.deletePage(at: index, from: newURL)
                }
                await loadPDF()
                selectedPageIndices.removeAll()
            } catch {
                debugPrint("❌ Failed to delete pages: \(error)")
            }
        }
    }
    
    private func rotateSelectedPages() {
        Task {
            do {
                var newURL = document.fileURL
                for index in selectedPageIndices {
                    newURL = try await PDFManager.shared.rotatePage(at: index, in: newURL, by: 90)
                }
                await loadPDF()
            } catch {
                debugPrint("❌ Failed to rotate pages: \(error)")
            }
        }
    }
    
    private func insertPage(_ image: UIImage) async {
        do {
            let newURL = try await PDFManager.shared.insertPage(
                image,
                at: pdfDocument?.pageCount ?? 0,
                into: document.fileURL
            )
            await loadPDF()
        } catch {
            debugPrint("❌ Failed to insert page: \(error)")
        }
    }
}

// MARK: - Page Thumbnail View

struct PageThumbnailView: View {
    
    let page: PDFPage
    let pageNumber: Int
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                PDFPageView(page: page)
                    .aspectRatio(page.bounds(for: .mediaBox).size, contentMode: .fit)
                    .frame(height: 150)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
                
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .padding(4)
                        }
                        Spacer()
                    }
                }
            }
            
            Text("Page \(pageNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - PDF Page View (UIViewRepresentable)

struct PDFPageView: UIViewRepresentable {
    
    let page: PDFPage
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        let document = PDFDocument()
        document.insert(page, at: 0)
        pdfView.document = document
    }
}

// MARK: - Add Page View

struct AddPageView: View {
    
    let onAdd: (UIImage) -> Void
    
    @State private var showingImagePicker = false
    @State private var showingScanner = false
    @State private var selectedImage: UIImage?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Button {
                    showingScanner = true
                } label: {
                    Label("Scan Document", systemImage: "doc.text.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                
                Button {
                    showingImagePicker = true
                } label: {
                    Label("Choose from Photos", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            .navigationTitle("Add Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            ScannerView { images in
                if let image = images.first {
                    onAdd(image)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Annotation Tool View

struct AnnotationToolView: View {
    
    let pdfDocument: PDFDocument
    let document: Document
    
    @State private var selectedTool: AnnotationTool = .none
    @State private var selectedPageIndex = 0
    @State private var annotationText = ""
    @State private var showingSignaturePad = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // PDF Preview
                if let page = pdfDocument.page(at: selectedPageIndex) {
                    PDFPageView(page: page)
                        .frame(maxHeight: 400)
                }
                
                Divider()
                
                // Tool selector
                toolSelector
                
                Divider()
                
                // Tool options
                if selectedTool == .text {
                    textToolOptions
                } else if selectedTool == .signature {
                    signatureToolOptions
                }
                
                Spacer()
            }
            .navigationTitle("Annotations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveAnnotations()
                    }
                }
            }
        }
        .sheet(isPresented: $showingSignaturePad) {
            SignaturePadView { signature in
                addSignature(signature)
            }
        }
    }
    
    private var toolSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(AnnotationTool.allCases, id: \.self) { tool in
                    ToolButton(
                        tool: tool,
                        isSelected: selectedTool == tool
                    ) {
                        selectedTool = tool
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }
    
    private var textToolOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Text")
                .font(.headline)
            
            TextField("Enter text", text: $annotationText)
                .textFieldStyle(.roundedBorder)
            
            Button("Add to Page") {
                addTextAnnotation()
            }
            .buttonStyle(.borderedProminent)
            .disabled(annotationText.isEmpty)
        }
        .padding()
    }
    
    private var signatureToolOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Signature")
                .font(.headline)
            
            Button {
                showingSignaturePad = true
            } label: {
                Label("Draw Signature", systemImage: "signature")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func addTextAnnotation() {
        Task {
            do {
                let rect = CGRect(x: 100, y: 100, width: 200, height: 50)
                _ = try await PDFManager.shared.addTextAnnotation(
                    to: document.fileURL,
                    pageIndex: selectedPageIndex,
                    text: annotationText,
                    rect: rect
                )
                annotationText = ""
            } catch {
                debugPrint("❌ Failed to add text annotation: \(error)")
            }
        }
    }
    
    private func addSignature(_ signature: UIImage) {
        Task {
            do {
                let rect = CGRect(x: 100, y: 500, width: 200, height: 100)
                _ = try await PDFManager.shared.addSignature(
                    signature,
                    to: document.fileURL,
                    pageIndex: selectedPageIndex,
                    rect: rect
                )
            } catch {
                debugPrint("❌ Failed to add signature: \(error)")
            }
        }
    }
    
    private func saveAnnotations() {
        // Annotations are saved automatically
        dismiss()
    }
}

// MARK: - Annotation Tool

enum AnnotationTool: String, CaseIterable {
    case none = "None"
    case text = "Text"
    case highlight = "Highlight"
    case signature = "Signature"
    
    var icon: String {
        switch self {
        case .none: return "hand.tap"
        case .text: return "text.cursor"
        case .highlight: return "highlighter"
        case .signature: return "signature"
        }
    }
}

struct ToolButton: View {
    
    let tool: AnnotationTool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: tool.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(tool.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 80, height: 80)
            .background(isSelected ? Color.blue : Color(.tertiarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Signature Pad View

struct SignaturePadView: View {
    
    let onComplete: (UIImage) -> Void
    
    @State private var currentPath = Path()
    @State private var paths: [Path] = []
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Canvas { context, size in
                    for path in paths {
                        context.stroke(path, with: .color(.black), lineWidth: 2)
                    }
                    context.stroke(currentPath, with: .color(.black), lineWidth: 2)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let point = value.location
                            if currentPath.isEmpty {
                                currentPath.move(to: point)
                            } else {
                                currentPath.addLine(to: point)
                            }
                        }
                        .onEnded { _ in
                            paths.append(currentPath)
                            currentPath = Path()
                        }
                )
                .frame(height: 300)
                .background(Color.white)
                .border(Color.gray, width: 1)
                .padding()
                
                HStack {
                    Button("Clear") {
                        paths.removeAll()
                        currentPath = Path()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Done") {
                        saveSignature()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(paths.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Draw Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveSignature() {
        // Convert canvas to image
        let renderer = ImageRenderer(content: signatureView)
        renderer.scale = 3.0
        
        if let image = renderer.uiImage {
            onComplete(image)
            dismiss()
        }
    }
    
    private var signatureView: some View {
        Canvas { context, size in
            for path in paths {
                context.stroke(path, with: .color(.black), lineWidth: 2)
            }
        }
        .frame(width: 400, height: 200)
        .background(Color.white)
    }
}

#Preview {
    PDFEditorView(document: Document(
        title: "Sample",
        filename: "sample.pdf",
        fileURL: URL(fileURLWithPath: "/tmp/sample.pdf"),
        fileSize: 1000,
        pageCount: 3,
        fileFormat: .pdf
    ))
}
