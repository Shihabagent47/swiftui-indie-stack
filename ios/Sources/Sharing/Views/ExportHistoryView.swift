//
//  ExportHistoryView.swift
//  MyApp
//
//  View showing export history with filtering and search.
//

import SwiftUI

struct ExportHistoryView: View {
    @ObservedObject var exportManager = ExportManager.shared
    @State private var searchText = ""
    @State private var showClearConfirmation = false

    var filteredHistory: [ExportHistoryEntry] {
        if searchText.isEmpty {
            return exportManager.exportHistory
        } else {
            return exportManager.exportHistory.filter {
                $0.documentName.localizedCaseInsensitiveContains(searchText) ||
                $0.destination.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        List {
            if filteredHistory.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text(searchText.isEmpty ? "No Export History" : "No Results")
                            .font(.headline)

                        Text(searchText.isEmpty ? "Documents you export will appear here" : "Try a different search term")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                Section {
                    ForEach(filteredHistory) { entry in
                        ExportHistoryRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("Export History")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search history")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !exportManager.exportHistory.isEmpty {
                    Button("Clear") {
                        showClearConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog("Clear Export History", isPresented: $showClearConfirmation) {
            Button("Clear All History", role: .destructive) {
                exportManager.clearExportHistory()
                Haptics.medium()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all export history. This action cannot be undone.")
        }
        .task {
            Analytics.trackScreenView("ExportHistory")
        }
    }
}

struct ExportHistoryRow: View {
    let entry: ExportHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.up.doc.fill")
                    .foregroundColor(.green)
                    .frame(width: 24)

                Text(entry.documentName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()
            }

            HStack(spacing: 12) {
                Text(entry.destination)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let presetName = entry.presetName {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(presetName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(entry.exportDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        ExportHistoryView()
    }
}
