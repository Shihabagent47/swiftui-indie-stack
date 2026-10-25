//
//  BatchRenameView.swift
//  MyApp
//
//  Batch rename documents with patterns.
//

import SwiftUI

struct BatchRenameView: View {
    let documents: [URL]

    @ObservedObject var batchManager = BatchProcessingManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPattern: NamingPattern = .sequential(prefix: "Document")
    @State private var customPrefix = "Document"
    @State private var customTemplate = "{date}_{index}"
    @State private var renamedURLs: [URL] = []
    @State private var showSuccess = false

    var body: some View {
        List {
            Section {
                Picker("Naming Pattern", selection: Binding(
                    get: { patternType },
                    set: { updatePattern($0) }
                )) {
                    Text("Sequential").tag("sequential")
                    Text("Date").tag("date")
                    Text("Timestamp").tag("timestamp")
                    Text("Custom").tag("custom")
                }

                TextField("Prefix", text: $customPrefix)
                    .onChange(of: customPrefix) { _, newValue in
                        updatePatternWithPrefix(newValue)
                    }

                if patternType == "custom" {
                    TextField("Template", text: $customTemplate)
                        .onChange(of: customTemplate) { _, newValue in
                            selectedPattern = .custom(template: newValue)
                        }

                    Text("Available variables: {index}, {date}")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            } header: {
                Text("Naming Pattern")
            } footer: {
                Text(patternExample)
                    .font(.caption)
            }

            Section {
                Button {
                    startRename()
                } label: {
                    HStack {
                        if batchManager.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Renaming...")
                        } else {
                            Label("Start Renaming", systemImage: "pencil")
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
        .navigationTitle("Rename Documents")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename Complete", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Successfully renamed \(renamedURLs.count) documents")
        }
    }

    private var patternType: String {
        switch selectedPattern {
        case .sequential: return "sequential"
        case .date: return "date"
        case .timestamp: return "timestamp"
        case .custom: return "custom"
        }
    }

    private var patternExample: String {
        "Example: " + selectedPattern.displayName
    }

    private func updatePattern(_ type: String) {
        switch type {
        case "sequential":
            selectedPattern = .sequential(prefix: customPrefix)
        case "date":
            selectedPattern = .date(prefix: customPrefix)
        case "timestamp":
            selectedPattern = .timestamp(prefix: customPrefix)
        case "custom":
            selectedPattern = .custom(template: customTemplate)
        default:
            break
        }
    }

    private func updatePatternWithPrefix(_ prefix: String) {
        switch selectedPattern {
        case .sequential:
            selectedPattern = .sequential(prefix: prefix)
        case .date:
            selectedPattern = .date(prefix: prefix)
        case .timestamp:
            selectedPattern = .timestamp(prefix: prefix)
        case .custom:
            break
        }
    }

    private func startRename() {
        Task {
            do {
                renamedURLs = try await batchManager.batchRename(
                    urls: documents,
                    pattern: selectedPattern
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
        BatchRenameView(documents: [])
    }
}
