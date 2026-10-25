//
//  ShareOptionsView.swift
//  MyApp
//
//  Share options menu for documents.
//

import SwiftUI

struct ShareOptionsView: View {
    let documentURL: URL
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var shareManager = ShareManager.shared

    @State private var showShareSheet = false
    @State private var showError = false

    var body: some View {
        NavigationView {
            List {
                // Quick Actions
                Section {
                    Button {
                        shareViaShareSheet()
                    } label: {
                        Label("Share...", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        shareViaEmail()
                    } label: {
                        Label("Email", systemImage: "envelope.fill")
                    }

                    Button {
                        shareViaAirDrop()
                    } label: {
                        Label("AirDrop", systemImage: "airplayvideo")
                    }

                } header: {
                    Text("Share Methods")
                }

                // Document Actions
                Section {
                    Button {
                        printDocument()
                    } label: {
                        Label("Print", systemImage: "printer.fill")
                    }

                    Button {
                        openInAnotherApp()
                    } label: {
                        Label("Open In...", systemImage: "square.and.arrow.up.on.square")
                    }

                } header: {
                    Text("Actions")
                }

                // Export
                Section {
                    NavigationLink {
                        ExportOptionsView(documentURL: documentURL)
                    } label: {
                        Label("Export Options", systemImage: "arrow.up.doc")
                    }

                } header: {
                    Text("Export")
                }

                // Share History
                if !shareManager.shareHistory.isEmpty {
                    Section {
                        NavigationLink {
                            ShareHistoryView()
                        } label: {
                            Label("Share History", systemImage: "clock.arrow.circlepath")
                        }
                    }
                }
            }
            .navigationTitle("Share Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Share Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareManager.shareError ?? "An error occurred while sharing")
        }
        .task {
            Analytics.trackScreenView("ShareOptions")
        }
    }

    // MARK: - Actions

    private func shareViaShareSheet() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shareManager.shareDocument(at: documentURL)
        }
    }

    private func shareViaEmail() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shareManager.shareViaEmail(url: documentURL, from: rootViewController)
        }
    }

    private func shareViaAirDrop() {
        shareViaShareSheet() // AirDrop is part of the share sheet
    }

    private func printDocument() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shareManager.printDocument(at: documentURL)
        }
    }

    private func openInAnotherApp() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shareManager.openInApp(url: documentURL, from: rootViewController)
        }
    }
}

#Preview {
    ShareOptionsView(documentURL: URL(fileURLWithPath: "/tmp/sample.pdf"))
}
