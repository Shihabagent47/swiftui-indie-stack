//
//  BackupSettingsView.swift
//  MyApp
//
//  Backup management and settings for Pro users.
//

import SwiftUI

struct BackupSettingsView: View {
    @ObservedObject var backupManager = BackupManager.shared
    @ObservedObject var quotaManager = QuotaManager.shared

    @State private var showCreateBackup = false
    @State private var showRestoreConfirmation = false
    @State private var selectedBackup: Backup?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showProUpgrade = false

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

            // Auto Backup Section
            if quotaManager.isPro {
                Section {
                    Toggle("Automatic Backup", isOn: $backupManager.autoBackupEnabled)
                        .onChange(of: backupManager.autoBackupEnabled) { _, newValue in
                            Analytics.track(event: "auto_backup_toggled", parameters: ["enabled": newValue])
                        }

                    if backupManager.autoBackupEnabled {
                        Picker("Frequency", selection: $backupManager.backupFrequency) {
                            ForEach(BackupFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.description).tag(frequency)
                            }
                        }
                        .onChange(of: backupManager.backupFrequency) { _, newValue in
                            Analytics.track(event: "backup_frequency_changed", parameters: ["frequency": newValue.rawValue])
                        }
                    }

                    if let lastBackup = backupManager.lastBackupDate {
                        HStack {
                            Text("Last Backup")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(lastBackup, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                } header: {
                    Text("Automatic Backup")
                } footer: {
                    Text("Automatically backup your documents to iCloud at regular intervals")
                        .font(.caption)
                }
            }

            // Manual Backup Section
            if quotaManager.isPro {
                Section {
                    Button {
                        createManualBackup()
                    } label: {
                        HStack {
                            if backupManager.isBackingUp {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 8)
                                Text("Creating Backup...")
                            } else {
                                Label("Create Backup Now", systemImage: "plus.circle.fill")
                            }
                        }
                    }
                    .disabled(backupManager.isBackingUp)

                    if backupManager.isBackingUp {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Progress")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ProgressView(value: backupManager.backupProgress)
                                .tint(.blue)

                            Text("\(Int(backupManager.backupProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                } header: {
                    Text("Manual Backup")
                }
            }

            // Available Backups Section
            if quotaManager.isPro && !backupManager.availableBackups.isEmpty {
                Section {
                    ForEach(backupManager.availableBackups) { backup in
                        BackupRow(backup: backup)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedBackup = backup
                                showRestoreConfirmation = true
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteBackup(backup)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("Available Backups")
                } footer: {
                    Text("Tap a backup to restore. Swipe left to delete.")
                        .font(.caption)
                }
            }

            // Empty State
            if quotaManager.isPro && backupManager.availableBackups.isEmpty && !backupManager.isBackingUp {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text("No Backups Yet")
                            .font(.headline)

                        Text("Create your first backup to protect your documents")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }

            // Error Section
            if let error = backupManager.backupError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if quotaManager.isPro {
                do {
                    try await backupManager.loadAvailableBackups()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            Analytics.trackScreenView("BackupSettings")
        }
        .sheet(isPresented: $showProUpgrade) {
            PaywallView()
        }
        .confirmationDialog("Restore Backup", isPresented: $showRestoreConfirmation, presenting: selectedBackup) { backup in
            Button("Restore", role: .destructive) {
                restoreBackup(backup)
            }
            Button("Cancel", role: .cancel) {}
        } message: { backup in
            Text("This will replace all current documents with the backup from \(backup.date.formatted()). This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions

    private func createManualBackup() {
        Task {
            do {
                try await backupManager.createBackup(automatic: false)
                Haptics.success()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                Haptics.error()
            }
        }
    }

    private func restoreBackup(_ backup: Backup) {
        Task {
            do {
                try await backupManager.restoreBackup(backup)
                Haptics.success()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                Haptics.error()
            }
        }
    }

    private func deleteBackup(_ backup: Backup) {
        Task {
            do {
                try await backupManager.deleteBackup(backup)
                Haptics.medium()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                Haptics.error()
            }
        }
    }
}

// MARK: - Backup Row

struct BackupRow: View {
    let backup: Backup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(backup.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)

                    HStack(spacing: 12) {
                        Label("\(backup.documentCount) docs", systemImage: "doc.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let size = backup.size {
                            Text(backup.sizeFormatted)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Text(backup.typeLabel)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(backup.automatic ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                    .foregroundColor(backup.automatic ? .blue : .green)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        BackupSettingsView()
    }
}
