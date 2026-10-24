//
//  DocumentBrowserView.swift
//  MyApp
//
//  Main document browser interface with grid/list views, sorting, and filtering.
//

import SwiftUI
import SwiftData

struct DocumentBrowserView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allDocuments: [Document]
    
    @StateObject private var viewModel: DocumentBrowserViewModel
    
    @State private var viewMode: ViewMode = .grid
    @State private var sortOption: SortOption = .modifiedDate
    @State private var showFilterSheet = false
    @State private var searchText = ""
    @State private var selectedDocuments: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showActionSheet = false
    
    init(folder: DocumentFolder? = nil) {
        _viewModel = StateObject(wrappedValue: DocumentBrowserViewModel(folder: folder))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if filteredDocuments.isEmpty {
                    emptyStateView
                } else {
                    documentListView
                }
            }
            .navigationTitle(viewModel.folder?.name ?? "Documents")
            .searchable(text: $searchText, prompt: "Search documents")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterView(
                    filters: $viewModel.filters,
                    onApply: { viewModel.applyFilters() }
                )
            }
            .confirmationDialog("Bulk Actions", isPresented: $showActionSheet) {
                bulkActionButtons
            }
        }
        .onAppear {
            viewModel.loadDocuments(allDocuments)
        }
        .onChange(of: allDocuments) { _, newValue in
            viewModel.loadDocuments(newValue)
        }
        .onChange(of: searchText) { _, newText in
            viewModel.searchQuery = newText
        }
        .onChange(of: sortOption) { _, newSort in
            viewModel.sortBy(newSort)
        }
    }
    
    // MARK: - Document List
    
    @ViewBuilder
    private var documentListView: some View {
        ScrollView {
            if viewMode == .grid {
                gridView
            } else {
                listView
            }
        }
    }
    
    private var gridView: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
        ], spacing: 16) {
            ForEach(filteredDocuments) { document in
                DocumentGridCell(
                    document: document,
                    isSelected: selectedDocuments.contains(document.id),
                    isSelectionMode: isSelectionMode,
                    onTap: { handleDocumentTap(document) },
                    onLongPress: { handleDocumentLongPress(document) }
                )
            }
        }
        .padding()
    }
    
    private var listView: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredDocuments) { document in
                DocumentListRow(
                    document: document,
                    isSelected: selectedDocuments.contains(document.id),
                    isSelectionMode: isSelectionMode,
                    onTap: { handleDocumentTap(document) },
                    onLongPress: { handleDocumentLongPress(document) }
                )
                
                if document.id != filteredDocuments.last?.id {
                    Divider()
                        .padding(.leading, 68)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text(searchText.isEmpty ? "No Documents" : "No Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(searchText.isEmpty ? "Scan or import your first document to get started" : "Try adjusting your search or filters")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if searchText.isEmpty {
                Button("Scan Document") {
                    // TODO: Trigger scan
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("View Mode", selection: $viewMode) {
                    Label("Grid", systemImage: "square.grid.2x2")
                        .tag(ViewMode.grid)
                    Label("List", systemImage: "list.bullet")
                        .tag(ViewMode.list)
                }
                
                Divider()
                
                Menu("Sort By") {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            Label(option.displayName, systemImage: sortOption == option ? "checkmark" : "")
                        }
                    }
                }
                
                Button {
                    showFilterSheet = true
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
                
                Divider()
                
                Button {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedDocuments.removeAll()
                    }
                } label: {
                    Label(isSelectionMode ? "Cancel Selection" : "Select", systemImage: "checkmark.circle")
                }
                
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        
        if isSelectionMode && !selectedDocuments.isEmpty {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Text("\(selectedDocuments.count) selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button("Actions") {
                        showActionSheet = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Bulk Actions
    
    @ViewBuilder
    private var bulkActionButtons: some View {
        Button("Move to Folder") {
            // TODO: Show folder picker
        }
        
        Button("Add Tags") {
            // TODO: Show tag picker
        }
        
        Button("Export") {
            // TODO: Trigger bulk export
        }
        
        Button("Delete", role: .destructive) {
            deletSelectedDocuments()
        }
        
        Button("Cancel", role: .cancel) {}
    }
    
    // MARK: - Actions
    
    private func handleDocumentTap(_ document: Document) {
        if isSelectionMode {
            toggleSelection(document)
        } else {
            // TODO: Navigate to document viewer
            print("Open document: \(document.title)")
        }
    }
    
    private func handleDocumentLongPress(_ document: Document) {
        if !isSelectionMode {
            isSelectionMode = true
            selectedDocuments.insert(document.id)
        }
    }
    
    private func toggleSelection(_ document: Document) {
        if selectedDocuments.contains(document.id) {
            selectedDocuments.remove(document.id)
        } else {
            selectedDocuments.insert(document.id)
        }
    }
    
    private func deletSelectedDocuments() {
        let documentsToDelete = allDocuments.filter { selectedDocuments.contains($0.id) }
        
        for document in documentsToDelete {
            modelContext.delete(document)
        }
        
        try? modelContext.save()
        
        selectedDocuments.removeAll()
        isSelectionMode = false
        
        Analytics.track(event: "documents_bulk_deleted", properties: [
            "count": documentsToDelete.count
        ])
    }
    
    // MARK: - Filtered Documents
    
    private var filteredDocuments: [Document] {
        viewModel.filteredDocuments
    }
}

// MARK: - View Mode

enum ViewMode {
    case grid
    case list
}

// MARK: - Sort Option

enum SortOption: String, CaseIterable {
    case title = "Title"
    case modifiedDate = "Modified Date"
    case createdDate = "Created Date"
    case size = "Size"
    case type = "Type"
    
    var displayName: String { rawValue }
}

// MARK: - Document Grid Cell

struct DocumentGridCell: View {
    let document: Document
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                if let thumbnailData = document.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 180)
                        .overlay {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                        }
                }
                
                // Selection indicator
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? .blue : .gray)
                        .padding(8)
                }
                
                // Favorite star
                if document.isFavorite && !isSelectionMode {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .padding(8)
                }
            }
            
            // Title
            Text(document.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Metadata
            HStack(spacing: 4) {
                Image(systemName: "doc.fill")
                    .font(.caption2)
                Text(document.fileFormat.displayName)
                    .font(.caption2)
                
                Spacer()
                
                Text(document.pageCount == 1 ? "1 page" : "\(document.pageCount) pages")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
    }
}

// MARK: - Document List Row

struct DocumentListRow: View {
    let document: Document
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection circle
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .gray)
            }
            
            // Thumbnail
            if let thumbnailData = document.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 56)
                    .clipped()
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 56)
                    .overlay {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.secondary)
                    }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(document.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if document.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(document.fileFormat.displayName)
                        .font(.caption)
                    
                    Text("•")
                        .font(.caption)
                    
                    Text("\(document.pageCount) \(document.pageCount == 1 ? "page" : "pages")")
                        .font(.caption)
                    
                    Text("•")
                        .font(.caption)
                    
                    Text(formatFileSize(document.fileSize))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Modified date
            Text(document.modifiedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
    }
}

// MARK: - Filter View

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: DocumentFilters
    let onApply: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Document Type") {
                    ForEach(DocumentFormat.allCases, id: \.self) { format in
                        Toggle(format.displayName, isOn: Binding(
                            get: { filters.formats.contains(format) },
                            set: { isOn in
                                if isOn {
                                    filters.formats.insert(format)
                                } else {
                                    filters.formats.remove(format)
                                }
                            }
                        ))
                    }
                }
                
                Section("Tags") {
                    // TODO: Show available tags
                    Text("Tag filtering coming soon")
                        .foregroundStyle(.secondary)
                }
                
                Section("Date Range") {
                    DatePicker("From", selection: Binding(
                        get: { filters.dateRange?.lowerBound ?? Date() },
                        set: { filters.dateRange = $0...(filters.dateRange?.upperBound ?? Date()) }
                    ), displayedComponents: .date)
                    
                    DatePicker("To", selection: Binding(
                        get: { filters.dateRange?.upperBound ?? Date() },
                        set: { filters.dateRange = (filters.dateRange?.lowerBound ?? Date())...$0 }
                    ), displayedComponents: .date)
                }
                
                Section {
                    Toggle("Show Favorites Only", isOn: $filters.favoritesOnly)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        filters = DocumentFilters()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Helpers

private func formatFileSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

// Make DocumentFormat CaseIterable for the filter
extension DocumentFormat: CaseIterable {}

#Preview {
    DocumentBrowserView()
        .modelContainer(for: Document.self, inMemory: true)
}
