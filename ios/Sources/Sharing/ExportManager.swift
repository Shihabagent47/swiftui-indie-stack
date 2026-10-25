//
//  ExportManager.swift
//  MyApp
//
//  Manages document export workflows including Files app, cloud services, and batch operations.
//

import Foundation
import UIKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
final class ExportManager: NSObject, ObservableObject {
    static let shared = ExportManager()

    // MARK: - Published Properties

    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportError: String?
    @Published var exportPresets: [ExportPreset] = []
    @Published var exportHistory: [ExportHistoryEntry] = []

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private let maxHistoryItems = 100

    // Storage keys
    private enum StorageKeys {
        static let exportPresets = "exportPresets"
        static let exportHistory = "exportHistory"
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        loadExportPresets()
        loadExportHistory()
        setupDefaultPresets()
    }

    // MARK: - Export to Files App

    /// Export document to Files app using UIDocumentPickerViewController
    func exportToFiles(url: URL, from viewController: UIViewController) async throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ExportError.fileNotFound
        }

        isExporting = true

        // Create a temporary copy for export
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? fileManager.removeItem(at: tempURL)
        try fileManager.copyItem(at: url, to: tempURL)

        let documentPicker = UIDocumentPickerViewController(forExporting: [tempURL])
        documentPicker.delegate = self

        viewController.present(documentPicker, animated: true)

        recordExport(url: url, destination: "Files App", preset: nil)
        Analytics.track(event: "exported_to_files", parameters: ["filename": url.lastPathComponent])
    }

    // MARK: - Batch Export

    /// Export multiple documents with progress tracking
    func batchExport(urls: [URL], destination: ExportDestination, preset: ExportPreset? = nil) async throws {
        guard !urls.isEmpty else {
            throw ExportError.noFilesToExport
        }

        isExporting = true
        exportProgress = 0.0
        exportError = nil

        let total = Double(urls.count)

        do {
            for (index, url) in urls.enumerated() {
                exportProgress = Double(index) / total

                switch destination {
                case .filesApp:
                    // For batch export to Files, we'd need to create a folder
                    break
                case .iCloudDrive:
                    try await exportToiCloud(url: url)
                case .localDocuments:
                    try await exportToLocalDocuments(url: url, preset: preset)
                }

                try await Task.sleep(nanoseconds: 100_000_000) // Small delay for UI updates
            }

            exportProgress = 1.0

            Analytics.track(event: "batch_export_completed", parameters: [
                "count": urls.count,
                "destination": destination.rawValue
            ])

            isExporting = false
            exportProgress = 0.0

        } catch {
            exportError = error.localizedDescription
            isExporting = false
            exportProgress = 0.0
            Analytics.track(event: "batch_export_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    // MARK: - Export to Cloud Services

    /// Export to iCloud Drive
    private func exportToiCloud(url: URL) async throws {
        guard let ubiquityURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            throw ExportError.cloudNotAvailable
        }

        let documentsURL = ubiquityURL.appendingPathComponent("Documents")
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)

        let fileName = url.lastPathComponent
        let destinationURL = documentsURL.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: url, to: destinationURL)

        recordExport(url: url, destination: "iCloud Drive", preset: nil)
        Analytics.track(event: "exported_to_icloud", parameters: ["filename": fileName])
    }

    // MARK: - Export to Local Documents

    /// Export to app's Documents directory with optional processing
    private func exportToLocalDocuments(url: URL, preset: ExportPreset?) async throws {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = url.lastPathComponent
        let destinationURL = documentsURL.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: url, to: destinationURL)

        recordExport(url: url, destination: "Documents", preset: preset)
    }

    // MARK: - Export Presets

    /// Create a new export preset
    func createPreset(name: String, format: ExportFormat, quality: ExportQuality, compression: Bool) {
        let preset = ExportPreset(
            id: UUID(),
            name: name,
            format: format,
            quality: quality,
            compression: compression,
            createdDate: Date()
        )

        exportPresets.append(preset)
        saveExportPresets()

        Analytics.track(event: "export_preset_created", parameters: ["name": name])
    }

    /// Delete an export preset
    func deletePreset(_ preset: ExportPreset) {
        exportPresets.removeAll { $0.id == preset.id }
        saveExportPresets()

        Analytics.track(event: "export_preset_deleted")
    }

    private func setupDefaultPresets() {
        guard exportPresets.isEmpty else { return }

        // High Quality preset
        createPreset(
            name: "High Quality PDF",
            format: .pdf,
            quality: .high,
            compression: false
        )

        // Compressed preset
        createPreset(
            name: "Compressed PDF",
            format: .pdf,
            quality: .medium,
            compression: true
        )

        // Image preset
        createPreset(
            name: "JPEG Images",
            format: .jpeg,
            quality: .high,
            compression: false
        )
    }

    // MARK: - Export with Settings

    /// Export document with custom settings
    func exportWithSettings(url: URL, settings: ExportSettings) async throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ExportError.fileNotFound
        }

        isExporting = true
        exportError = nil

        do {
            // Apply settings and export
            // In a real implementation, this would process the PDF according to settings

            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = url.deletingPathExtension().lastPathComponent + "_exported." + settings.format.fileExtension
            let destinationURL = documentsURL.appendingPathComponent(fileName)

            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.copyItem(at: url, to: destinationURL)

            recordExport(url: url, destination: "Local", preset: nil)
            Analytics.track(event: "exported_with_settings", parameters: [
                "format": settings.format.rawValue,
                "quality": settings.quality.rawValue
            ])

            isExporting = false

        } catch {
            exportError = error.localizedDescription
            isExporting = false
            Analytics.track(event: "export_settings_error", parameters: ["error": error.localizedDescription])
            throw error
        }
    }

    // MARK: - Export History

    private func recordExport(url: URL, destination: String, preset: ExportPreset?) {
        let entry = ExportHistoryEntry(
            id: UUID(),
            documentName: url.lastPathComponent,
            destination: destination,
            presetName: preset?.name,
            exportDate: Date()
        )

        exportHistory.insert(entry, at: 0)

        if exportHistory.count > maxHistoryItems {
            exportHistory = Array(exportHistory.prefix(maxHistoryItems))
        }

        saveExportHistory()
    }

    func clearExportHistory() {
        exportHistory.removeAll()
        saveExportHistory()
        Analytics.track(event: "export_history_cleared")
    }

    // MARK: - Persistence

    private func loadExportPresets() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.exportPresets),
           let presets = try? JSONDecoder().decode([ExportPreset].self, from: data) {
            exportPresets = presets
        }
    }

    private func saveExportPresets() {
        if let data = try? JSONEncoder().encode(exportPresets) {
            UserDefaults.standard.set(data, forKey: StorageKeys.exportPresets)
        }
    }

    private func loadExportHistory() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.exportHistory),
           let history = try? JSONDecoder().decode([ExportHistoryEntry].self, from: data) {
            exportHistory = history
        }
    }

    private func saveExportHistory() {
        if let data = try? JSONEncoder().encode(exportHistory) {
            UserDefaults.standard.set(data, forKey: StorageKeys.exportHistory)
        }
    }
}

// MARK: - UIDocumentPickerDelegate

extension ExportManager: UIDocumentPickerDelegate {
    nonisolated func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Task { @MainActor in
            isExporting = false
        }
    }

    nonisolated func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        Task { @MainActor in
            isExporting = false
        }
    }
}

// MARK: - Supporting Types

enum ExportError: LocalizedError {
    case fileNotFound
    case noFilesToExport
    case cloudNotAvailable
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .noFilesToExport:
            return "No files to export"
        case .cloudNotAvailable:
            return "iCloud Drive is not available"
        case .exportFailed:
            return "Export failed"
        }
    }
}

enum ExportDestination: String, CaseIterable {
    case filesApp = "Files App"
    case iCloudDrive = "iCloud Drive"
    case localDocuments = "Local Documents"

    var icon: String {
        switch self {
        case .filesApp: return "folder.fill"
        case .iCloudDrive: return "icloud.fill"
        case .localDocuments: return "doc.fill"
        }
    }
}

enum ExportFormat: String, Codable, CaseIterable {
    case pdf = "PDF"
    case jpeg = "JPEG"
    case png = "PNG"

    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .jpeg: return "jpg"
        case .png: return "png"
        }
    }
}

enum ExportQuality: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case maximum = "Maximum"

    var compressionQuality: CGFloat {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.8
        case .maximum: return 1.0
        }
    }
}

struct ExportPreset: Identifiable, Codable {
    let id: UUID
    let name: String
    let format: ExportFormat
    let quality: ExportQuality
    let compression: Bool
    let createdDate: Date
}

struct ExportSettings: Codable {
    let format: ExportFormat
    let quality: ExportQuality
    let compression: Bool
    let includeMetadata: Bool
    let pageRange: PageRange?

    enum PageRange: Codable {
        case all
        case range(from: Int, to: Int)
        case specific([Int])

        enum CodingKeys: String, CodingKey {
            case type, from, to, pages
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "all":
                self = .all
            case "range":
                let from = try container.decode(Int.self, forKey: .from)
                let to = try container.decode(Int.self, forKey: .to)
                self = .range(from: from, to: to)
            case "specific":
                let pages = try container.decode([Int].self, forKey: .pages)
                self = .specific(pages)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .all:
                try container.encode("all", forKey: .type)
            case .range(let from, let to):
                try container.encode("range", forKey: .type)
                try container.encode(from, forKey: .from)
                try container.encode(to, forKey: .to)
            case .specific(let pages):
                try container.encode("specific", forKey: .type)
                try container.encode(pages, forKey: .pages)
            }
        }
    }
}

struct ExportHistoryEntry: Identifiable, Codable {
    let id: UUID
    let documentName: String
    let destination: String
    let presetName: String?
    let exportDate: Date
}
