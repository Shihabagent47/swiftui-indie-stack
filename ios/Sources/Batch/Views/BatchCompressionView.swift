//
//  BatchCompressionView.swift
//  MyApp
//
//  Batch compression of PDF documents.
//

import SwiftUI

struct BatchCompressionView: View {
    let documents: [URL]

    @ObservedObject var batchManager = BatchProcessingManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var compressionLevel: BatchCompressionLevel = .medium
    @State private var compressedURLs: [URL] = []
    @State private var showSuccess = false

    var body: some View {
        List {
            Section {
                Picker("Compression Level", selection: $compressionLevel) {
                    ForEach(BatchCompressionLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }

            } header: {
                Text("Settings")
            } footer: {
                Text("\(documents.count) documents will be compressed")
                    .font(.caption)
            }

            Section {
                Button {
                    startCompression()
                } label: {
                    HStack {
                        if batchManager.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Compressing...")
                        } else {
                            Label("Start Compression", systemImage: "arrow.down.circle")
                        }
                    }
                }
                .disabled(batchManager.isProcessing)
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
        }
        .navigationTitle("Compress PDFs")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Compression Complete", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Successfully compressed \(compressedURLs.count) documents")
        }
    }

    private func startCompression() {
        Task {
            do {
                compressedURLs = try await batchManager.batchCompress(
                    urls: documents,
                    compressionLevel: compressionLevel
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
        BatchCompressionView(documents: [])
    }
}
