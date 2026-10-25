//
//  BatchOrganizeView.swift
//  MyApp
//
//  Batch organize documents into folders.
//

import SwiftUI

struct BatchOrganizeView: View {
    let documents: [URL]

    @ObservedObject var batchManager = BatchProcessingManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var organizationStrategy: OrganizationStrategy = .byDate
    @State private var showSuccess = false

    var body: some View {
        List {
            Section {
                Picker("Organization Strategy", selection: $organizationStrategy) {
                    Text(OrganizationStrategy.byDate.displayName)
                        .tag(OrganizationStrategy.byDate)
                    Text(OrganizationStrategy.byType.displayName)
                        .tag(OrganizationStrategy.byType)
                    Text(OrganizationStrategy.bySize.displayName)
                        .tag(OrganizationStrategy.bySize)
                }

            } header: {
                Text("Strategy")
            } footer: {
                Text("\(documents.count) documents will be organized into folders")
                    .font(.caption)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    switch organizationStrategy {
                    case .byDate:
                        Text("Documents → 2026-10/ → document.pdf")
                            .font(.caption)
                            .foregroundColor(.secondary)

                    case .byType:
                        Text("Documents → PDF/ → document.pdf")
                            .font(.caption)
                            .foregroundColor(.secondary)

                    case .bySize:
                        Text("Documents → Medium/ → document.pdf")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                Button {
                    startOrganizing()
                } label: {
                    HStack {
                        if batchManager.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Organizing...")
                        } else {
                            Label("Start Organizing", systemImage: "folder")
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
        .navigationTitle("Organize Documents")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Organization Complete", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Successfully organized \(documents.count) documents")
        }
    }

    private func startOrganizing() {
        Task {
            do {
                try await batchManager.batchOrganize(
                    urls: documents,
                    strategy: organizationStrategy
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
        BatchOrganizeView(documents: [])
    }
}
