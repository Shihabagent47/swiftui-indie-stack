//
//  PDFOptimizationView.swift
//  MyApp
//
//  SwiftUI views for PDF optimization and compression.
//

import SwiftUI

// MARK: - PDF Optimization View

struct PDFOptimizationView: View {
    
    let document: Document
    let onComplete: (URL) -> Void
    
    @State private var selectedQuality: PDFQuality = .medium
    @State private var selectedOptions = OptimizationOptions.default
    @State private var preview: SizeReductionPreview?
    @State private var isOptimizing = false
    @State private var result: OptimizationResult?
    @State private var showingResult = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let preview = preview {
                    // Preview section
                    previewSection(preview)
                    
                    Divider()
                }
                
                // Options
                Form {
                    qualitySection
                    optionsSection
                    
                    if let preview = preview {
                        estimatedSavingsSection(preview)
                    }
                }
                
                // Action button
                actionButton
            }
            .navigationTitle("Optimize PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadPreview()
        }
        .onChange(of: selectedQuality) { _, _ in
            Task {
                await loadPreview()
            }
        }
        .sheet(isPresented: $showingResult) {
            if let result = result {
                OptimizationResultView(result: result) {
                    onComplete(result.outputURL)
                    dismiss()
                }
            }
        }
    }
    
    private func previewSection(_ preview: SizeReductionPreview) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Original")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(preview.formattedOriginal)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Estimated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(preview.formattedEstimated)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Estimated Savings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(preview.formattedSavings)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Reduction")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", preview.savingsPercentage))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    private var qualitySection: some View {
        Section {
            Picker("Quality", selection: $selectedQuality) {
                ForEach([PDFQuality.low, .medium, .high, .lossless], id: \.self) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Compression Quality")
        } footer: {
            Text(selectedQuality.description)
        }
    }
    
    private var optionsSection: some View {
        Section("Options") {
            Toggle("Downsample Images", isOn: $selectedOptions.downsampleImages)
            Toggle("Strip Metadata", isOn: $selectedOptions.stripMetadata)
            Toggle("Remove Unused Resources", isOn: $selectedOptions.removeUnusedResources)
            Toggle("Optimize for Web", isOn: $selectedOptions.linearize)
        }
    }
    
    private func estimatedSavingsSection(_ preview: SizeReductionPreview) -> some View {
        Section {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.green)
                Text("You'll save approximately")
                Spacer()
                Text(preview.formattedSavings)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
        }
    }
    
    private var actionButton: some View {
        Button {
            optimizePDF()
        } label: {
            HStack {
                if isOptimizing {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Text("Optimize PDF")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isOptimizing)
        .padding()
    }
    
    // MARK: - Actions
    
    private func loadPreview() async {
        do {
            let newPreview = try await PDFOptimizationManager.shared.previewSizeReduction(
                at: document.fileURL,
                quality: selectedQuality
            )
            
            await MainActor.run {
                preview = newPreview
            }
        } catch {
            debugPrint("❌ Failed to load preview: \(error)")
        }
    }
    
    private func optimizePDF() {
        isOptimizing = true
        
        Task {
            do {
                let optimizationResult = try await PDFOptimizationManager.shared.compressPDF(
                    at: document.fileURL,
                    quality: selectedQuality,
                    options: selectedOptions
                )
                
                await MainActor.run {
                    result = optimizationResult
                    isOptimizing = false
                    showingResult = true
                }
            } catch {
                debugPrint("❌ Failed to optimize PDF: \(error)")
                await MainActor.run {
                    isOptimizing = false
                }
            }
        }
    }
}

// MARK: - Optimization Result View

struct OptimizationResultView: View {
    
    let result: OptimizationResult
    let onUse: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("PDF Optimized!")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Results
                VStack(spacing: 16) {
                    resultRow(
                        label: "Original Size",
                        value: ByteCountFormatter.string(fromByteCount: result.originalSize, countStyle: .file)
                    )
                    
                    resultRow(
                        label: "Optimized Size",
                        value: ByteCountFormatter.string(fromByteCount: result.optimizedSize, countStyle: .file),
                        color: .green
                    )
                    
                    resultRow(
                        label: "Space Saved",
                        value: result.formattedSavings,
                        color: .green
                    )
                    
                    resultRow(
                        label: "Reduction",
                        value: String(format: "%.1f%%", result.savedPercentage),
                        color: .green
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Actions
                VStack(spacing: 16) {
                    Button {
                        onUse()
                    } label: {
                        Text("Use Optimized PDF")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Keep Original") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Optimization Complete")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func resultRow(label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Quality Comparison View

struct QualityComparisonView: View {
    
    let document: Document
    
    @State private var tradeoffs: [QualityTradeoff] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Analyzing...")
                    Spacer()
                }
            } else {
                ForEach(tradeoffs, id: \.quality) { tradeoff in
                    TradeoffRow(tradeoff: tradeoff)
                }
            }
        }
        .navigationTitle("Quality Comparison")
        .task {
            await analyzeTradeoffs()
        }
    }
    
    private func analyzeTradeoffs() async {
        do {
            let results = try await PDFOptimizationManager.shared.analyzeQualityTradeoffs(
                at: document.fileURL
            )
            
            await MainActor.run {
                tradeoffs = results
                isLoading = false
            }
        } catch {
            debugPrint("❌ Failed to analyze tradeoffs: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct TradeoffRow: View {
    
    let tradeoff: QualityTradeoff
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tradeoff.quality.displayName)
                    .font(.headline)
                
                Spacer()
                
                Text(tradeoff.formattedSize)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            HStack {
                Text("Savings:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(tradeoff.formattedSavings) (\(String(format: "%.1f%%", tradeoff.savingsPercentage)))")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Text(tradeoff.quality.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - PDFQuality Extension

extension PDFQuality {
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .lossless: return "Lossless"
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "Smallest file size, lower visual quality. Good for sharing via email."
        case .medium:
            return "Balanced compression. Good for most documents."
        case .high:
            return "High quality with modest compression. Good for archiving."
        case .lossless:
            return "Maximum quality with minimal compression. Only removes metadata."
        }
    }
}

#Preview {
    PDFOptimizationView(document: Document(
        title: "Sample",
        filename: "sample.pdf",
        fileURL: URL(fileURLWithPath: "/tmp/sample.pdf"),
        fileSize: 5_000_000,
        pageCount: 10,
        fileFormat: .pdf
    )) { _ in }
}
