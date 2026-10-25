//
//  SpotlightManager.swift
//  MyApp
//
//  Manages Spotlight indexing for documents to enable system-wide search.
//

import Foundation
import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers
import Combine

@MainActor
final class SpotlightManager: ObservableObject {
    static let shared = SpotlightManager()

    // MARK: - Published Properties

    @Published var isIndexing = false
    @Published var indexedDocumentsCount = 0

    // MARK: - Initialization

    private init() {}

    // MARK: - Index Documents

    /// Index a single document for Spotlight search
    func indexDocument(at url: URL, metadata: DocumentSpotlightMetadata) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SpotlightError.fileNotFound
        }

        let attributeSet = CSSearchableItemAttributeSet(contentType: .pdf)

        // Basic attributes
        attributeSet.title = metadata.title
        attributeSet.contentDescription = metadata.description
        attributeSet.keywords = metadata.keywords
        attributeSet.contentCreationDate = metadata.createdDate
        attributeSet.contentModificationDate = metadata.modifiedDate

        // Document attributes
        attributeSet.displayName = metadata.title
        attributeSet.identifier = url.lastPathComponent

        // Additional metadata
        if let pageCount = metadata.pageCount {
            attributeSet.pageCount = NSNumber(value: pageCount)
        }

        if let author = metadata.author {
            attributeSet.authorNames = [author]
        }

        // Thumbnail
        if let thumbnailData = metadata.thumbnailData {
            attributeSet.thumbnailData = thumbnailData
        }

        // Create searchable item
        let item = CSSearchableItem(
            uniqueIdentifier: url.absoluteString,
            domainIdentifier: "com.myapp.documents",
            attributeSet: attributeSet
        )

        // Index the item
        try await CSSearchableIndex.default().indexSearchableItems([item])

        indexedDocumentsCount += 1

        Analytics.track(event: "spotlight_document_indexed", parameters: [
            "title": metadata.title
        ])
    }

    /// Index multiple documents in batch
    func indexDocuments(_ documents: [(URL, DocumentSpotlightMetadata)]) async throws {
        isIndexing = true
        indexedDocumentsCount = 0

        var items: [CSSearchableItem] = []

        for (url, metadata) in documents {
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }

            let attributeSet = CSSearchableItemAttributeSet(contentType: .pdf)
            attributeSet.title = metadata.title
            attributeSet.contentDescription = metadata.description
            attributeSet.keywords = metadata.keywords
            attributeSet.contentCreationDate = metadata.createdDate
            attributeSet.contentModificationDate = metadata.modifiedDate
            attributeSet.displayName = metadata.title

            if let pageCount = metadata.pageCount {
                attributeSet.pageCount = NSNumber(value: pageCount)
            }

            if let thumbnailData = metadata.thumbnailData {
                attributeSet.thumbnailData = thumbnailData
            }

            let item = CSSearchableItem(
                uniqueIdentifier: url.absoluteString,
                domainIdentifier: "com.myapp.documents",
                attributeSet: attributeSet
            )

            items.append(item)
        }

        // Index in batches of 100
        let batchSize = 100
        for i in stride(from: 0, to: items.count, by: batchSize) {
            let end = min(i + batchSize, items.count)
            let batch = Array(items[i..<end])

            try await CSSearchableIndex.default().indexSearchableItems(batch)

            indexedDocumentsCount += batch.count
        }

        isIndexing = false

        Analytics.track(event: "spotlight_batch_indexed", parameters: [
            "count": items.count
        ])
    }

    // MARK: - Deindex Documents

    /// Remove a document from Spotlight index
    func deindexDocument(at url: URL) async throws {
        try await CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [url.absoluteString]
        )

        Analytics.track(event: "spotlight_document_deindexed")
    }

    /// Remove all documents from Spotlight index
    func deindexAllDocuments() async throws {
        try await CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: ["com.myapp.documents"]
        )

        indexedDocumentsCount = 0

        Analytics.track(event: "spotlight_all_deindexed")
    }

    // MARK: - Handle Spotlight Selection

    /// Handle when user taps a Spotlight search result
    func handleSpotlightSelection(identifier: String) -> URL? {
        guard let url = URL(string: identifier) else {
            return nil
        }

        Analytics.track(event: "spotlight_result_opened", parameters: [
            "identifier": identifier
        ])

        return url
    }

    // MARK: - Reindex All

    /// Reindex all documents in the app
    func reindexAllDocuments() async throws {
        isIndexing = true

        // First, clear existing index
        try await deindexAllDocuments()

        // Get all documents from Documents directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "pdf" }

        // Create metadata for each document
        var documentsToIndex: [(URL, DocumentSpotlightMetadata)] = []

        for url in fileURLs {
            let attributes = try url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])

            let metadata = DocumentSpotlightMetadata(
                title: url.deletingPathExtension().lastPathComponent,
                description: "PDF Document",
                keywords: ["pdf", "document"],
                createdDate: attributes.creationDate ?? Date(),
                modifiedDate: attributes.contentModificationDate ?? Date(),
                pageCount: nil,
                author: nil,
                thumbnailData: nil
            )

            documentsToIndex.append((url, metadata))
        }

        // Index all documents
        try await indexDocuments(documentsToIndex)

        isIndexing = false

        Analytics.track(event: "spotlight_reindex_completed", parameters: [
            "count": documentsToIndex.count
        ])
    }
}

// MARK: - Supporting Types

enum SpotlightError: LocalizedError {
    case fileNotFound
    case indexingFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .indexingFailed:
            return "Failed to index document for Spotlight"
        }
    }
}

struct DocumentSpotlightMetadata {
    let title: String
    let description: String
    let keywords: [String]
    let createdDate: Date
    let modifiedDate: Date
    let pageCount: Int?
    let author: String?
    let thumbnailData: Data?
}
