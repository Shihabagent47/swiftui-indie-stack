//
//  ShareHistoryView.swift
//  MyApp
//
//  View showing share history with filtering and search.
//

import SwiftUI

struct ShareHistoryView: View {
    @ObservedObject var shareManager = ShareManager.shared
    @State private var searchText = ""
    @State private var showClearConfirmation = false

    var filteredHistory: [ShareHistoryEntry] {
        if searchText.isEmpty {
            return shareManager.shareHistory
        } else {
            return shareManager.shareHistory.filter {
                $0.documentName.localizedCaseInsensitiveContains(searchText) ||
                $0.methodDisplayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        List {
            if filteredHistory.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text(searchText.isEmpty ? "No Share History" : "No Results")
                            .font(.headline)

                        Text(searchText.isEmpty ? "Documents you share will appear here" : "Try a different search term")
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
                        ShareHistoryRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("Share History")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search history")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !shareManager.shareHistory.isEmpty {
                    Button("Clear") {
                        showClearConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog("Clear Share History", isPresented: $showClearConfirmation) {
            Button("Clear All History", role: .destructive) {
                shareManager.clearShareHistory()
                Haptics.medium()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all share history. This action cannot be undone.")
        }
        .task {
            Analytics.trackScreenView("ShareHistory")
        }
    }
}

struct ShareHistoryRow: View {
    let entry: ShareHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.methodIcon)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text(entry.documentName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()
            }

            HStack(spacing: 12) {
                Text(entry.methodDisplayName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(entry.shareDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        ShareHistoryView()
    }
}
