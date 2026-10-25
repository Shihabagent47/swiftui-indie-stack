//
//  PresetsListView.swift
//  MyApp
//
//  List and manage preset configurations.
//

import SwiftUI

struct PresetsListView: View {
    @ObservedObject var templateManager = TemplateManager.shared

    var body: some View {
        List {
            if templateManager.presetConfigurations.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text("No Presets")
                            .font(.headline)

                        Text("Create presets to save your favorite settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                Section {
                    ForEach(templateManager.presetConfigurations) { preset in
                        Button {
                            templateManager.applyPreset(preset)
                            Haptics.success()
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(preset.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                HStack(spacing: 12) {
                                    if preset.scanSettings != nil {
                                        Label("Scan", systemImage: "doc.viewfinder")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    if preset.exportSettings != nil {
                                        Label("Export", systemImage: "arrow.up.doc")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    if preset.processingSettings != nil {
                                        Label("Process", systemImage: "wand.and.stars")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                templateManager.deletePresetConfiguration(preset)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Presets")
                }
            }
        }
        .navigationTitle("Preset Configurations")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        PresetsListView()
    }
}
