//
//  DocumentBrowserViewModel.swift
//  MyApp
//
//  View model for document browser with filtering, sorting, and search.
//

import Foundation
import SwiftUI

@MainActor
class DocumentBrowserViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var documents: [Document] = []
    @Published var filteredDocuments: [Document] = []
    @Published var searchQuery: String = "" {
        didSet { performSearch() }
    }
    @Published var filters: DocumentFilters = DocumentFilters() {
        didSet { applyFilters() }
    }
    @Published var sortOption: SortOption = .modifiedDate {
        didSet { sortDocuments() }
    }
    @Published var isLoading = false
    @Published var error: DocumentError?
    
    // MARK: - Properties
    
    let folder: DocumentFolder?
    private var currentSortDescending = true
    
    // MARK: - Init
    
    init(folder: DocumentFolder? = nil) {
        self.folder = folder
    }
    
    // MARK: - Document Loading
    
    func loadDocuments(_ allDocuments: [Document]) {
        if let folder = folder {
            // Load documents from specific folder
            documents = folder.documents
        } else {
            // Load all documents
            documents = allDocuments
        }
        
        applyFilters()
    }
    
    // MARK: - Search
    
    func performSearch() {
        guard !searchQuery.isEmpty else {
            applyFilters()
            return
        }
        
        let query = searchQuery.lowercased()
        
        filteredDocuments = documents.filter { document in
            // Search in title
            if document.title.lowercased().contains(query) {
                return true
            }
            
            // Search in filename
            if document.filename.lowercased().contains(query) {
                return true
            }
            
            // Search in OCR text
            if let ocrText = document.ocrText,
               ocrText.lowercased().contains(query) {
                return true
            }
            
            // Search in tags
            if document.tags.contains(where: { $0.lowercased().contains(query) }) {
                return true
            }
            
            // Search in custom properties
            if document.customProperties.values.contains(where: { $0.lowercased().contains(query) }) {
                return true
            }
            
            return false
        }
        
        sortDocuments()
        
        Analytics.track(event: "documents_searched", properties: [
            "query_length": query.count,
            "results_count": filteredDocuments.count
        ])
    }
    
    // MARK: - Filtering
    
    func applyFilters() {
        var result = documents
        
        // Apply format filter
        if !filters.formats.isEmpty {
            result = result.filter { filters.formats.contains($0.fileFormat) }
        }
        
        // Apply favorites filter
        if filters.favoritesOnly {
            result = result.filter { $0.isFavorite }
        }
        
        // Apply date range filter
        if let dateRange = filters.dateRange {
            result = result.filter { document in
                dateRange.contains(document.modifiedAt)
            }
        }
        
        // Apply tags filter
        if !filters.tags.isEmpty {
            result = result.filter { document in
                !Set(document.tags).isDisjoint(with: filters.tags)
            }
        }
        
        // Apply color label filter
        if let colorLabel = filters.colorLabel {
            result = result.filter { $0.colorLabel == colorLabel }
        }
        
        // Apply folder filter (if browsing all documents)
        if let filterFolder = filters.folder {
            result = result.filter { $0.folder?.id == filterFolder.id }
        }
        
        filteredDocuments = result
        sortDocuments()
        
        if filters.hasActiveFilters {
            Analytics.track(event: "documents_filtered", properties: [
                "results_count": filteredDocuments.count
            ])
        }
    }
    
    // MARK: - Sorting
    
    func sortBy(_ option: SortOption) {
        sortOption = option
        sortDocuments()
    }
    
    func toggleSortDirection() {
        currentSortDescending.toggle()
        sortDocuments()
    }
    
    private func sortDocuments() {
        filteredDocuments.sort { doc1, doc2 in
            let result: Bool
            
            switch sortOption {
            case .title:
                result = doc1.title.localizedStandardCompare(doc2.title) == .orderedAscending
                
            case .modifiedDate:
                result = doc1.modifiedAt < doc2.modifiedAt
                
            case .createdDate:
                result = doc1.createdAt < doc2.createdAt
                
            case .size:
                result = doc1.fileSize < doc2.fileSize
                
            case .type:
                result = doc1.fileFormat.displayName.localizedStandardCompare(doc2.fileFormat.displayName) == .orderedAscending
            }
            
            return currentSortDescending ? !result : result
        }
    }
    
    // MARK: - Statistics
    
    var totalDocuments: Int {
        documents.count
    }
    
    var totalSize: Int64 {
        documents.reduce(0) { $0 + $1.fileSize }
    }
    
    var favoriteDocuments: [Document] {
        documents.filter { $0.isFavorite }
    }
    
    var recentDocuments: [Document] {
        documents
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(10)
            .map { $0 }
    }
    
    func documentCount(for format: DocumentFormat) -> Int {
        documents.filter { $0.fileFormat == format }.count
    }
}

// MARK: - Document Filters

struct DocumentFilters {
    var formats: Set<DocumentFormat> = []
    var tags: Set<String> = []
    var colorLabel: ColorLabel?
    var dateRange: ClosedRange<Date>?
    var favoritesOnly = false
    var folder: DocumentFolder?
    
    var hasActiveFilters: Bool {
        !formats.isEmpty || !tags.isEmpty || colorLabel != nil || dateRange != nil || favoritesOnly || folder != nil
    }
    
    mutating func reset() {
        formats.removeAll()
        tags.removeAll()
        colorLabel = nil
        dateRange = nil
        favoritesOnly = false
        folder = nil
    }
}
