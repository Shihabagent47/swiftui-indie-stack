//
//  BatchConversionView.swift
//  MyApp
//
//  Batch conversion of PDFs to images.
//

import SwiftUI

struct BatchConversionView: View {
    let documents: [URL]

    @ObservedObject var batchManager = BatchProcessingManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportFormat = .jpeg
    @State private var selectedQuality: ExportQuality = .high
    @State private var convertedURLs: [URL] = []
    @State private var showSuccess = false

    var body: some View {
        List {
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

            } header: {
                Text("Conversion Settings")
            } footer: {
                Text("\(documents.count) documents will be converted to \(selectedFormat.rawValue)")
                    .font(.caption)
            }

            Section {
                Button {
                    startConversion()
                } label: {
                    HStack {
                        if batchManager.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Converting...")
                        } else {
                            Label("Start Conversion", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }
                .disabled(batchManager.isProcessing)

            } header: {
                Text("Action")
            }

            if batchManager.isProcessing {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        ProgressView(value: batchManager.progress)
                            .tint(.blue)

                        Text("\(batchManager.processedCount) / \(batchManager.totalCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Progress")
                }
            }

            if !convertedURLs.isEmpty {
                Section {
                    ForEach(convertedURLs, id: \.self) { url in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(url.lastPathComponent)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Converted Files")
                }
            }
        }
        .navigationTitle("Convert to Images")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Conversion Complete", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Successfully converted \(convertedURLs.count) documents")
        }
    }

    private func startConversion() {
        Task {
            do {
                convertedURLs = try await batchManager.batchConvertToImages(
                    urls: documents,
                    format: selectedFormat,
                    quality: selectedQuality
                )
                Haptics.success()
                showSuccess = true
            } catch {
                Haptics.error()
            }
        }
    }
}

#Preview {
    NavigationView {
        BatchConversionView(documents: [])
    }
}
