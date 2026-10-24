//
//  TextExtractionView.swift
//  MyApp
//
//  SwiftUI views for displaying and interacting with OCR results.
//

import SwiftUI
import AVFoundation

// MARK: - Text Extraction View

struct TextExtractionView: View {
    
    let document: Document
    
    @State private var extractedText = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var confidence: Float = 0
    @State private var detectedLanguage: String?
    
    @State private var showingCopiedAlert = false
    @State private var isSpeaking = false
    
    private let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if !extractedText.isEmpty {
                textView
            } else {
                emptyView
            }
        }
        .navigationTitle("Extracted Text")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        copyText()
                    } label: {
                        Label("Copy Text", systemImage: "doc.on.doc")
                    }
                    
                    Button {
                        speakText()
                    } label: {
                        Label(isSpeaking ? "Stop Reading" : "Read Aloud", systemImage: isSpeaking ? "stop.circle" : "speaker.wave.2")
                    }
                    
                    Button {
                        shareText()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await extractText()
        }
        .alert("Extraction Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Text Copied", isPresented: $showingCopiedAlert) {
            Button("OK") { }
        } message: {
            Text("The text has been copied to your clipboard")
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Extracting text...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var textView: some View {
        VStack(spacing: 0) {
            // Info bar
            HStack {
                if let language = detectedLanguage {
                    Label(language, systemImage: "globe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Label("\(Int(confidence * 100))% confident", systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundColor(confidenceColor)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            Divider()
            
            // Text content
            ScrollView {
                Text(extractedText)
                    .textSelection(.enabled)
                    .padding()
            }
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Text Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("This document doesn't contain any readable text")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await extractText()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Actions
    
    private func extractText() async {
        isLoading = true
        
        do {
            let text = try await OCRManager.shared.extractText(from: document)
            
            extractedText = text
            
            // Get additional info if available from document
            if let ocrText = document.ocrText {
                confidence = 1.0 // Assume high confidence for cached OCR
            } else {
                confidence = 0.85 // Default confidence
            }
            
            detectedLanguage = OCRManager.shared.detectLanguage(from: text)
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isLoading = false
    }
    
    private func copyText() {
        await OCRManager.shared.copyToClipboard(extractedText)
        showingCopiedAlert = true
    }
    
    private func speakText() {
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        } else {
            let cleanText = await OCRManager.shared.prepareTextForSpeech(extractedText)
            let utterance = AVSpeechUtterance(string: cleanText)
            utterance.rate = 0.5
            
            synthesizer.speak(utterance)
            isSpeaking = true
        }
    }
    
    private func shareText() {
        let activityVC = UIActivityViewController(
            activityItems: [extractedText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - OCR Settings View

struct OCRSettingsView: View {
    
    @AppStorage("ocrRecognitionLevel") private var recognitionLevel: Int = 1 // 0=fast, 1=accurate
    @AppStorage("ocrLanguageCorrection") private var useLanguageCorrection = true
    @AppStorage("ocrAutoDetectLanguage") private var autoDetectLanguage = true
    
    @State private var supportedLanguages: [String] = []
    @State private var selectedLanguages: Set<String> = ["en-US"]
    
    var body: some View {
        Form {
            Section {
                Picker("Recognition Quality", selection: $recognitionLevel) {
                    Text("Fast").tag(0)
                    Text("Accurate").tag(1)
                }
                .onChange(of: recognitionLevel) { _, newValue in
                    updateRecognitionLevel(newValue)
                }
                
                Toggle("Language Correction", isOn: $useLanguageCorrection)
                    .onChange(of: useLanguageCorrection) { _, newValue in
                        Task {
                            await OCRManager.shared.setUseLanguageCorrection(newValue)
                        }
                    }
            } header: {
                Text("Recognition Settings")
            } footer: {
                Text("Accurate mode provides better results but takes longer to process")
            }
            
            Section {
                Toggle("Auto-detect Language", isOn: $autoDetectLanguage)
                
                if !autoDetectLanguage {
                    NavigationLink("Select Languages") {
                        LanguageSelectionView(
                            supportedLanguages: supportedLanguages,
                            selectedLanguages: $selectedLanguages
                        )
                    }
                }
            } header: {
                Text("Language Settings")
            } footer: {
                Text("Auto-detect will automatically determine the language of the text")
            }
            
            Section {
                HStack {
                    Text("Version")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Vision OCR")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .navigationTitle("OCR Settings")
        .task {
            await loadSupportedLanguages()
        }
    }
    
    private func updateRecognitionLevel(_ level: Int) {
        Task {
            let visionLevel: VNRequestTextRecognitionLevel = level == 0 ? .fast : .accurate
            await OCRManager.shared.setRecognitionLevel(visionLevel)
        }
    }
    
    private func loadSupportedLanguages() async {
        supportedLanguages = await OCRManager.shared.getSupportedLanguages()
    }
}

// MARK: - Language Selection View

struct LanguageSelectionView: View {
    
    let supportedLanguages: [String]
    @Binding var selectedLanguages: Set<String>
    
    var body: some View {
        List(supportedLanguages, id: \.self) { language in
            Button {
                toggleLanguage(language)
            } label: {
                HStack {
                    Text(formatLanguageName(language))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if selectedLanguages.contains(language) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Select Languages")
    }
    
    private func toggleLanguage(_ language: String) {
        if selectedLanguages.contains(language) {
            selectedLanguages.remove(language)
        } else {
            selectedLanguages.insert(language)
        }
        
        // Update OCR manager
        Task {
            await OCRManager.shared.setLanguages(Array(selectedLanguages))
        }
    }
    
    private func formatLanguageName(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code) ?? code
    }
}

// MARK: - Live OCR View (Real-time text recognition)

struct LiveOCRView: View {
    
    @StateObject private var scanner = CustomCameraScanner()
    @State private var recognizedText = ""
    @State private var isRecognizing = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(scanner: scanner)
                .ignoresSafeArea()
            
            // Overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Recognized text overlay
                if !recognizedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recognized Text")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button {
                                Task {
                                    await OCRManager.shared.copyToClipboard(recognizedText)
                                }
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Text(recognizedText)
                            .font(.body)
                            .foregroundColor(.white)
                            .lineLimit(5)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
        .onAppear {
            Task {
                try? await scanner.setupCamera()
                scanner.startSession()
                startLiveRecognition()
            }
        }
        .onDisappear {
            scanner.stopSession()
        }
    }
    
    private func startLiveRecognition() {
        // Perform OCR every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            guard let image = scanner.capturedImage, !isRecognizing else { return }
            
            isRecognizing = true
            
            Task {
                do {
                    let result = try await OCRManager.shared.recognizeText(from: image)
                    await MainActor.run {
                        recognizedText = result.text
                        isRecognizing = false
                    }
                } catch {
                    await MainActor.run {
                        isRecognizing = false
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        OCRSettingsView()
    }
}
