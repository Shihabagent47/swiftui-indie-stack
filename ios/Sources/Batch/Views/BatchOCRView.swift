//
//  BatchOCRView.swift
//  MyApp
//
//  Batch OCR text extraction from documents.
//

import SwiftUI

struct BatchOCRView: View {
    let documents: [URL]

    @ObservedObject var batchManager = BatchProcessingManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var ocrResults: [OCRResult] = []
    @State private var showSuccess = false

    var body: some View {
        List {
            Section {
                Text("\(documents.count) documents will be processed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

            } header: {
                Text("OCR Settings")
            } footer: {
                Text("Text will be extracted from all pages")
                    .font(.caption)
            }

            Section {
                Button {
                    startOCR()
                } label: {
                    HStack {
                        if batchManager.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Extracting Text...")
                        } else {
                            Label("Start OCR", systemImage: "text.viewfinder")
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

            if !ocrResults.isEmpty {
                Section {
                    ForEach(ocrResults) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(result.documentURL.lastPathComponent)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            Text(result.text)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(3)

                            HStack {
                                Text("Confidence: \(Int(result.confidence * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Text("Language: \(result.language)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("OCR Results")
                }
            }
        }
        .navigationTitle("Extract Text (OCR)")
        .navigationBarTitleDisplayMode(.inline)
        .alert("OCR Complete", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Successfully extracted text from \(ocrResults.count) documents")
        }
    }

    private func startOCR() {
        Task {
            do {
                ocrResults = try await batchManager.batchOCR(urls: documents)
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
        BatchOCRView(documents: [])
    }
}
