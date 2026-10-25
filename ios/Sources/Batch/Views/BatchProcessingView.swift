//
//  BatchProcessingView.swift
//  MyApp
//
//  Main UI for batch processing operations.
//

import SwiftUI

struct BatchProcessingView: View {
    @ObservedObject var batchManager = BatchProcessingManager.shared
    @ObservedObject var quotaManager = QuotaManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDocuments: [URL] = []
    @State private var showProUpgrade = false
    @State private var showDocumentPicker = false

    var body: some View {
        NavigationView {
            List {
                // Pro Status
                if !quotaManager.isPro {
                    Section {
                        ProUpgradePrompt()
                            .onTapGesture {
                                showProUpgrade = true
                            }
                    }
                }

                // Document Selection
                Section {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label(
                            selectedDocuments.isEmpty ? "Select Documents" : "\(selectedDocuments.count) documents selected",
                            systemImage: "doc.badge.plus"
                        )
                    }

                    if !selectedDocuments.isEmpty {
                        Button(role: .destructive) {
                            selectedDocuments.removeAll()
                        } label: {
                            Label("Clear Selection", systemImage: "trash")
                        }
                    }

                } header: {
                    Text("Documents")
                }

                // Batch Operations
                if quotaManager.isPro && !selectedDocuments.isEmpty {
                    Section {
                        NavigationLink {
                            BatchConversionView(documents: selectedDocuments)
                        } label: {
                            Label("Convert to Images", systemImage: "arrow.triangle.2.circlepath")
                        }

                        NavigationLink {
                            BatchCompressionView(documents: selectedDocuments)
                        } label: {
                            Label("Compress PDFs", systemImage: "arrow.down.circle")
                        }

                        NavigationLink {
                            BatchOCRView(documents: selectedDocuments)
                        } label: {
                            Label("Extract Text (OCR)", systemImage: "text.viewfinder")
                        }

                        NavigationLink {
                            BatchRenameView(documents: selectedDocuments)
                        } label: {
                            Label("Rename Documents", systemImage: "pencil")
                        }

                        NavigationLink {
                            BatchOrganizeView(documents: selectedDocuments)
                        } label: {
                            Label("Organize Documents", systemImage: "folder")
                        }

                    } header: {
                        Text("Batch Operations")
                    }
                }

                // Progress
                if batchManager.isProcessing {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(batchManager.currentOperation)
                                .font(.headline)

                            ProgressView(value: batchManager.progress)
                                .tint(.blue)

                            HStack {
                                Text("\(batchManager.processedCount) / \(batchManager.totalCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(Int(batchManager.progress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Progress")
                    }
                }

                // Errors
                if !batchManager.errors.isEmpty {
                    Section {
                        ForEach(batchManager.errors) { error in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(error.errorDescription ?? "Unknown error")
                                        .font(.caption)
                                }
                            }
                        }

                        Button(role: .destructive) {
                            batchManager.errors.removeAll()
                        } label: {
                            Text("Clear Errors")
                        }

                    } header: {
                        Text("Errors")
                    }
                }
            }
            .navigationTitle("Batch Processing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showProUpgrade) {
            PaywallView()
        }
        .task {
            Analytics.trackScreenView("BatchProcessing")
        }
    }
}

#Preview {
    BatchProcessingView()
}
