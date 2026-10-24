//
//  SyncStatusView.swift
//  MyApp
//
//  Displays cloud sync status and controls for Pro users.
//

import SwiftUI

struct SyncStatusView: View {
    @ObservedObject var cloudSync = CloudSyncManager.shared
    @ObservedObject var cloudKit = CloudKitSyncManager.shared
    @ObservedObject var quotaManager = QuotaManager.shared

    @State private var showProUpgrade = false
    @State private var showError = false

    var body: some View {
        List {
            // Pro Status Section
            if !quotaManager.isPro {
                Section {
                    ProUpgradePrompt()
                        .onTapGesture {
                            showProUpgrade = true
                        }
                }
            }

            // iCloud Drive Section
            Section {
                HStack {
                    Image(systemName: "icloud")
                        .foregroundColor(cloudSync.isCloudAvailable ? .blue : .gray)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud Drive")
                            .font(.headline)

                        if cloudSync.isCloudAvailable {
                            Text(cloudSync.isSyncing ? "Syncing..." : "Connected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not Available")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    Spacer()

                    if cloudSync.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if cloudSync.isCloudAvailable {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                if let lastSync = cloudSync.lastSyncDate {
                    HStack {
                        Text("Last Synced")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(lastSync, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if quotaManager.isPro && cloudSync.isCloudAvailable {
                    Button {
                        Task {
                            do {
                                try await cloudSync.syncAllDocuments()
                            } catch {
                                showError = true
                            }
                        }
                    } label: {
                        Label("Sync All Documents", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(cloudSync.isSyncing)
                }

            } header: {
                Text("iCloud Drive Sync")
            } footer: {
                if let error = cloudSync.syncError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            // CloudKit Section
            Section {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                        .foregroundColor(cloudKit.isCloudKitAvailable ? .blue : .gray)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("CloudKit Metadata")
                            .font(.headline)

                        if cloudKit.isCloudKitAvailable {
                            Text(cloudKit.isSyncing ? "Syncing..." : "Connected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not Available")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    Spacer()

                    if cloudKit.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if cloudKit.isCloudKitAvailable {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                if let lastSync = cloudKit.lastSyncDate {
                    HStack {
                        Text("Last Synced")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(lastSync, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if quotaManager.isPro && cloudKit.isCloudKitAvailable {
                    Button {
                        Task {
                            do {
                                try await cloudKit.syncAll()
                            } catch {
                                showError = true
                            }
                        }
                    } label: {
                        Label("Sync All Metadata", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(cloudKit.isSyncing)
                }

            } header: {
                Text("CloudKit Sync")
            } footer: {
                Text("Syncs document metadata, settings, and scan history across devices")
                    .font(.caption)
            }

            // Help Section
            if !cloudSync.isCloudAvailable || !cloudKit.isCloudKitAvailable {
                Section {
                    Link(destination: URL(string: "https://support.apple.com/en-us/HT204025")!) {
                        Label("Enable iCloud Drive", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("Help")
                } footer: {
                    Text("iCloud Drive must be enabled in Settings to use cloud sync features")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Cloud Sync")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProUpgrade) {
            PaywallView()
        }
        .alert("Sync Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cloudSync.syncError ?? cloudKit.syncError ?? "An error occurred during sync")
        }
        .task {
            Analytics.trackScreenView("SyncStatus")
        }
    }
}

// MARK: - Pro Upgrade Prompt

struct ProUpgradePrompt: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundColor(.yellow)
                .shadow(color: .yellow.opacity(0.3), radius: 5)

            VStack(alignment: .leading, spacing: 4) {
                Text("Upgrade to Pro")
                    .font(.headline)

                Text("Unlock cloud sync and backup features")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        SyncStatusView()
    }
}
