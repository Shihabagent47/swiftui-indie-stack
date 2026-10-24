//
//  EnhancementControlsView.swift
//  MyApp
//
//  SwiftUI views for image enhancement controls and presets.
//

import SwiftUI

// MARK: - Enhancement Controls View

struct EnhancementControlsView: View {
    
    @Binding var image: UIImage
    let onApply: (UIImage) -> Void
    
    @State private var brightness: Double = 0.0
    @State private var contrast: Double = 1.0
    @State private var saturation: Double = 1.0
    @State private var sharpness: Double = 0.0
    @State private var temperature: Double = 0.0
    @State private var tint: Double = 0.0
    
    @State private var selectedPreset: FilterPreset?
    @State private var isProcessing = false
    @State private var previewImage: UIImage?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Preview
                imagePreview
                
                Divider()
                
                // Controls
                controlsSection
            }
            .navigationTitle("Enhance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyEnhancements()
                    }
                    .disabled(isProcessing)
                }
            }
        }
        .onAppear {
            previewImage = image
        }
    }
    
    private var imagePreview: some View {
        GeometryReader { geometry in
            Image(uiImage: previewImage ?? image)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxHeight: 300)
        .background(Color.black)
    }
    
    private var controlsSection: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Presets
                presetsSection
                
                Divider()
                
                // Manual controls
                manualControlsSection
                
                // Quality indicator
                if !isProcessing {
                    qualitySection
                }
            }
            .padding()
        }
    }
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FilterPreset.allCases, id: \.self) { preset in
                        PresetButton(
                            preset: preset,
                            isSelected: selectedPreset == preset
                        ) {
                            applyPreset(preset)
                        }
                    }
                }
            }
        }
    }
    
    private var manualControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adjustments")
                .font(.headline)
            
            SliderControl(
                label: "Brightness",
                value: $brightness,
                range: -0.5...0.5,
                icon: "sun.max"
            ) { _ in
                updatePreview()
            }
            
            SliderControl(
                label: "Contrast",
                value: $contrast,
                range: 0.5...2.0,
                icon: "circle.lefthalf.filled"
            ) { _ in
                updatePreview()
            }
            
            SliderControl(
                label: "Saturation",
                value: $saturation,
                range: 0.0...2.0,
                icon: "paintpalette"
            ) { _ in
                updatePreview()
            }
            
            SliderControl(
                label: "Sharpness",
                value: $sharpness,
                range: 0.0...2.0,
                icon: "camera.filters"
            ) { _ in
                updatePreview()
            }
            
            SliderControl(
                label: "Temperature",
                value: $temperature,
                range: -1.0...1.0,
                icon: "thermometer"
            ) { _ in
                updatePreview()
            }
            
            SliderControl(
                label: "Tint",
                value: $tint,
                range: -1.0...1.0,
                icon: "eyedropper"
            ) { _ in
                updatePreview()
            }
            
            Button("Reset All") {
                resetAdjustments()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.bordered)
        }
    }
    
    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Image Quality")
                .font(.headline)
            
            // Placeholder - would show actual quality score
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("Good Quality")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
        }
    }
    
    // MARK: - Actions
    
    private func applyPreset(_ preset: FilterPreset) {
        selectedPreset = preset
        isProcessing = true
        
        Task {
            let enhanced = await ImageEnhancementManager.shared.applyPreset(image, preset: preset)
            
            await MainActor.run {
                if let enhanced = enhanced {
                    previewImage = enhanced
                }
                isProcessing = false
            }
        }
    }
    
    private func updatePreview() {
        selectedPreset = nil
        
        // Debounce updates
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            await applyManualAdjustments()
        }
    }
    
    private func applyManualAdjustments() async {
        isProcessing = true
        
        let enhanced = await ImageEnhancementManager.shared.applyAdjustments(
            image,
            brightness: Float(brightness),
            contrast: Float(contrast),
            saturation: Float(saturation),
            sharpness: Float(sharpness),
            temperature: Float(temperature),
            tint: Float(tint)
        )
        
        await MainActor.run {
            if let enhanced = enhanced {
                previewImage = enhanced
            }
            isProcessing = false
        }
    }
    
    private func resetAdjustments() {
        brightness = 0.0
        contrast = 1.0
        saturation = 1.0
        sharpness = 0.0
        temperature = 0.0
        tint = 0.0
        selectedPreset = nil
        previewImage = image
    }
    
    private func applyEnhancements() {
        if let preview = previewImage {
            onApply(preview)
        }
        dismiss()
    }
}

// MARK: - Slider Control

struct SliderControl: View {
    
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let icon: String
    let onChange: (Double) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                Text(label)
                    .font(.subheadline)
                
                Spacer()
                
                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range) { _ in
                onChange(value)
            }
        }
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    
    let preset: FilterPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(preset.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 80, height: 80)
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Quick Enhancement View

struct QuickEnhanceView: View {
    
    let image: UIImage
    let onComplete: (UIImage) -> Void
    
    @State private var isEnhancing = false
    @State private var enhancedImage: UIImage?
    @State private var showingControls = false
    
    var body: some View {
        VStack(spacing: 20) {
            if isEnhancing {
                ProgressView("Enhancing...")
            } else if let enhanced = enhancedImage {
                // Before/After comparison
                beforeAfterView(original: image, enhanced: enhanced)
                
                HStack(spacing: 16) {
                    Button("Use Original") {
                        onComplete(image)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Use Enhanced") {
                        onComplete(enhanced)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        showingControls = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .task {
            await autoEnhance()
        }
        .sheet(isPresented: $showingControls) {
            if let enhanced = enhancedImage {
                EnhancementControlsView(image: .constant(enhanced)) { finalImage in
                    enhancedImage = finalImage
                }
            }
        }
    }
    
    private func beforeAfterView(original: UIImage, enhanced: UIImage) -> some View {
        HStack(spacing: 16) {
            VStack {
                Text("Original")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Image(uiImage: original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(8)
            }
            
            VStack {
                Text("Enhanced")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Image(uiImage: enhanced)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(8)
            }
        }
    }
    
    private func autoEnhance() async {
        isEnhancing = true
        
        let enhanced = await ImageEnhancementManager.shared.autoEnhance(image)
        
        await MainActor.run {
            enhancedImage = enhanced ?? image
            isEnhancing = false
        }
    }
}

// MARK: - Quality Indicator View

struct QualityIndicatorView: View {
    
    let image: UIImage
    
    @State private var qualityScore: QualityScore?
    @State private var isAnalyzing = true
    
    var body: some View {
        VStack(spacing: 12) {
            if isAnalyzing {
                ProgressView("Analyzing quality...")
                    .font(.caption)
            } else if let score = qualityScore {
                HStack(spacing: 16) {
                    // Overall
                    QualityMeter(
                        label: "Overall",
                        value: score.overall,
                        color: Color(score.rating.color)
                    )
                    
                    // Sharpness
                    QualityMeter(
                        label: "Sharpness",
                        value: score.sharpness,
                        color: .blue
                    )
                    
                    // Brightness
                    QualityMeter(
                        label: "Brightness",
                        value: score.brightness,
                        color: .orange
                    )
                    
                    // Contrast
                    QualityMeter(
                        label: "Contrast",
                        value: score.contrast,
                        color: .purple
                    )
                }
                
                Text(score.rating.rawValue)
                    .font(.caption)
                    .foregroundColor(Color(score.rating.color))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .task {
            await analyzeQuality()
        }
    }
    
    private func analyzeQuality() async {
        let score = await ImageEnhancementManager.shared.calculateQualityScore(image)
        
        await MainActor.run {
            qualityScore = score
            isAnalyzing = false
        }
    }
}

struct QualityMeter: View {
    
    let label: String
    let value: Float
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: CGFloat(value))
                    .stroke(color, lineWidth: 4)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(value * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .frame(width: 50, height: 50)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    QuickEnhanceView(image: UIImage(systemName: "photo")!) { _ in }
}
