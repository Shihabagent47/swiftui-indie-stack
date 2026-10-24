//
//  ConversionView.swift
//  MyApp
//
//  UI for document conversion features.
//

import SwiftUI
import UniformTypeIdentifiers

struct ConversionView: View {
    @StateObject private var viewModel = ConversionViewModel()
    @State private var showingFilePicker = false
    @State private var showingPresetPicker = false
    @State private var selectedTargetFormat: ExportFormat = .pdf
    @State private var selectedPreset: ConversionPreset?
    
    var body: some View {
        NavigationStack {
            List {
                // Quick Actions Section
                Section {
                    Button(action: { showingFilePicker = true }) {
                        Label("Import Document", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: { showingPresetPicker = true }) {
                        Label("Choose Preset", systemImage: "slider.horizontal.3")
                    }
                } header: {
                    Text("Quick Actions")
                }
                
                // Active Conversions
                if !viewModel.activeJobs.isEmpty {
                    Section {
                        ForEach(viewModel.activeJobs) { job in
                            ConversionJobRow(job: job)
                        }
                    } header: {
                        Text("Active Conversions")
                    }
                }
                
                // Queued Conversions
                if !viewModel.queuedJobs.isEmpty {
                    Section {
                        ForEach(viewModel.queuedJobs) { job in
                            ConversionJobRow(job: job)
                        }
                    } header: {
                        Text("Queued (\(viewModel.queuedJobs.count))")
                    }
                }
                
                // Recent Conversions
                if !viewModel.recentConversions.isEmpty {
                    Section {
                        ForEach(viewModel.recentConversions) { job in
                            ConversionHistoryRow(job: job)
                        }
                    } header: {
                        Text("Recent")
                    }
                }
                
                // Statistics
                Section {
                    HStack {
                        Text("Completed")
                        Spacer()
                        Text("\(viewModel.statistics.totalCompleted)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Failed")
                        Spacer()
                        Text("\(viewModel.statistics.totalFailed)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Success Rate")
                        Spacer()
                        Text("\(Int(viewModel.statistics.successRate * 100))%")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Statistics")
                }
            }
            .navigationTitle("Conversions")
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(
                    supportedTypes: [.pdf, .image, .text],
                    onDocumentPicked: { urls in
                        Task {
                            await viewModel.importDocuments(urls, targetFormat: selectedTargetFormat)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingPresetPicker) {
                PresetPickerView(selectedPreset: $selectedPreset)
            }
        }
        .task {
            await viewModel.startMonitoring()
        }
    }
}

// MARK: - Conversion Job Row

struct ConversionJobRow: View {
    let job: ConversionJob
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: job.status.iconName)
                    .foregroundStyle(statusColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.request.sourceURL.lastPathComponent)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Text("\(job.request.sourceFormat.uppercased()) → \(job.request.targetFormat.rawValue.uppercased())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if job.status == .processing {
                    ProgressView(value: job.progress)
                        .progressViewStyle(.circular)
                        .frame(width: 24, height: 24)
                }
            }
            
            if job.status == .processing {
                ProgressView(value: job.progress)
                    .progressViewStyle(.linear)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch job.status {
        case .completed: return .green
        case .failed: return .red
        case .processing: return .blue
        case .queued: return .orange
        case .cancelled: return .gray
        }
    }
}

// MARK: - Conversion History Row

struct ConversionHistoryRow: View {
    let job: ConversionJob
    
    var body: some View {
        HStack {
            Image(systemName: job.status.iconName)
                .foregroundStyle(job.status == .completed ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(job.request.sourceURL.lastPathComponent)
                    .font(.subheadline)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let duration = job.duration {
                Text(String(format: "%.1fs", duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: job.createdAt, relativeTo: Date())
    }
}

// MARK: - Preset Picker View

struct PresetPickerView: View {
    @Binding var selectedPreset: ConversionPreset?
    @Environment(\.dismiss) private var dismiss
    @State private var presets: [ConversionPreset] = []
    @State private var customPresets: [ConversionPreset] = []
    
    var body: some View {
        NavigationStack {
            List {
                // Built-in Presets
                Section {
                    ForEach(presets) { preset in
                        PresetRow(preset: preset, isSelected: selectedPreset?.id == preset.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPreset = preset
                                dismiss()
                            }
                    }
                } header: {
                    Text("Built-in Presets")
                }
                
                // Custom Presets
                if !customPresets.isEmpty {
                    Section {
                        ForEach(customPresets) { preset in
                            PresetRow(preset: preset, isSelected: selectedPreset?.id == preset.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedPreset = preset
                                    dismiss()
                                }
                        }
                    } header: {
                        Text("Custom Presets")
                    }
                }
            }
            .navigationTitle("Choose Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadPresets()
            }
        }
    }
    
    private func loadPresets() async {
        presets = ConversionPresets.allPresets
        customPresets = await ConversionPresetManager.shared.getCustomPresets()
    }
}

struct PresetRow: View {
    let preset: ConversionPreset
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: preset.icon)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.headline)
                
                Text(preset.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let fileSize = preset.displayFileSize {
                    Text("Max: \(fileSize)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let supportedTypes: [UTType]
    let onDocumentPicked: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: ([URL]) -> Void
        
        init(onDocumentPicked: @escaping ([URL]) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onDocumentPicked(urls)
        }
    }
}

// MARK: - View Model

@MainActor
class ConversionViewModel: ObservableObject {
    @Published var activeJobs: [ConversionJob] = []
    @Published var queuedJobs: [ConversionJob] = []
    @Published var recentConversions: [ConversionJob] = []
    @Published var statistics = ConversionStatistics(
        totalCompleted: 0,
        totalFailed: 0,
        activeJobs: 0,
        queuedJobs: 0,
        averageDuration: 0
    )
    
    private var monitoringTask: Task<Void, Never>?
    
    func startMonitoring() async {
        await refresh()
        
        // Start periodic refresh
        monitoringTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await refresh()
            }
        }
    }
    
    func refresh() async {
        activeJobs = await ConversionEngine.shared.getActiveJobs()
        queuedJobs = await ConversionEngine.shared.getQueuedJobs()
        recentConversions = await ConversionEngine.shared.getHistory(limit: 20)
        statistics = await ConversionEngine.shared.getStatistics()
    }
    
    func importDocuments(_ urls: [URL], targetFormat: ExportFormat) async {
        for url in urls {
            let request = ConversionRequest(
                sourceURL: url,
                targetFormat: targetFormat,
                operation: .importToPDF
            )
            
            do {
                try await ConversionEngine.shared.enqueueConversion(request)
            } catch {
                debugPrint("❌ Failed to enqueue conversion: \(error)")
            }
        }
        
        await refresh()
    }
    
    deinit {
        monitoringTask?.cancel()
    }
}

// MARK: - Preview

#Preview {
    ConversionView()
}
