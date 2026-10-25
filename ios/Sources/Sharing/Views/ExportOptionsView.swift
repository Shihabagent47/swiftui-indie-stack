//
//  ExportOptionsView.swift
//  MyApp
//
//  Export options and settings for documents.
//

import SwiftUI

struct ExportOptionsView: View {
    let documentURL: URL

    @ObservedObject var exportManager = ExportManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportFormat = .pdf
    @State private var selectedQuality: ExportQuality = .high
    @State private var enableCompression = false
    @State private var selectedDestination: ExportDestination = .filesApp
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            // Quick Export
            Section {
                Button {
                    exportToFiles()
                } label: {
                    HStack {
                        if exportManager.isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 8)
                            Text("Exporting...")
                        } else {
                            Label("Export to Files", systemImage: "folder.fill")
                        }
                    }
                }
                .disabled(exportManager.isExporting)

            } header: {
                Text("Quick Export")
            }

            // Export Settings
            Section {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }

                Picker("Quality", selection: $selectedQuality) {
                    ForEach(ExportQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }

                Toggle("Enable Compression", isOn: $enableCompression)

            } header: {
                Text("Export Settings")
            } footer: {
                Text("Higher quality results in larger file sizes")
                    .font(.caption)
            }

            // Destination
            Section {
                Picker("Destination", selection: $selectedDestination) {
                    ForEach(ExportDestination.allCases, id: \.self) { destination in
                        Label(destination.rawValue, systemImage: destination.icon)
                            .tag(destination)
                    }
                }

                Button {
                    exportWithSettings()
                } label: {
                    Label("Export with Settings", systemImage: "arrow.up.doc.fill")
                }
                .disabled(exportManager.isExporting)

            } header: {
                Text("Destination")
            }

            // Export Progress
            if exportManager.isExporting && exportManager.exportProgress > 0 {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exporting...")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ProgressView(value: exportManager.exportProgress)
                            .tint(.blue)

                        Text("\(Int(exportManager.exportProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Progress")
                }
            }

            // Export Presets
            if !exportManager.exportPresets.isEmpty {
                Section {
                    ForEach(exportManager.exportPresets) { preset in
                        Button {
                            applyPreset(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.name)
                                    .font(.headline)

                                HStack(spacing: 12) {
                                    Text(preset.format.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text(preset.quality.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if preset.compression {
                                        Text("Compressed")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                exportManager.deletePreset(preset)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        saveAsPreset()
                    } label: {
                        Label("Save as Preset", systemImage: "plus.circle")
                    }

                } header: {
                    Text("Presets")
                } footer: {
                    Text("Tap a preset to apply these settings")
                        .font(.caption)
                }
            }

            // Export History
            if !exportManager.exportHistory.isEmpty {
                Section {
                    NavigationLink {
                        ExportHistoryView()
                    } label: {
                        Label("Export History", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
        }
        .navigationTitle("Export Options")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Export Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            Analytics.trackScreenView("ExportOptions")
        }
    }

    // MARK: - Actions

    private func exportToFiles() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        Task {
            do {
                try await exportManager.exportToFiles(url: documentURL, from: rootViewController)
                Haptics.success()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                Haptics.error()
            }
        }
    }

    private func exportWithSettings() {
        let settings = ExportSettings(
            format: selectedFormat,
            quality: selectedQuality,
            compression: enableCompression,
            includeMetadata: true,
            pageRange: nil
        )

        Task {
            do {
                try await exportManager.exportWithSettings(url: documentURL, settings: settings)
                Haptics.success()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                Haptics.error()
            }
        }
    }

    private func applyPreset(_ preset: ExportPreset) {
        selectedFormat = preset.format
        selectedQuality = preset.quality
        enableCompression = preset.compression
        Haptics.light()
    }

    private func saveAsPreset() {
        exportManager.createPreset(
            name: "Custom \(selectedFormat.rawValue)",
            format: selectedFormat,
            quality: selectedQuality,
            compression: enableCompression
        )
        Haptics.success()
    }
}

#Preview {
    NavigationView {
        ExportOptionsView(documentURL: URL(fileURLWithPath: "/tmp/sample.pdf"))
    }
}
