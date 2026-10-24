//
//  OCRManager.swift
//  MyApp
//
//  Manages OCR (Optical Character Recognition) using Vision framework.
//

import Foundation
import UIKit
import Vision
import PDFKit

/// Manages OCR text recognition from images and documents
actor OCRManager {
    
    static let shared = OCRManager()
    
    // MARK: - Configuration
    
    private var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    private var supportedLanguages: [String] = ["en-US"] // Default to English
    private var useLanguageCorrection = true
    
    private init() {}
    
    // MARK: - Text Recognition
    
    /// Recognize text from image
    func recognizeText(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw DocumentError.processingFailed(reason: "Invalid image format")
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        request.recognitionLanguages = supportedLanguages
        request.usesLanguageCorrection = useLanguageCorrection
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let observations = request.results else {
                throw DocumentError.processingFailed(reason: "No text recognized")
            }
            
            let recognizedText = extractText(from: observations)
            let confidence = calculateAverageConfidence(from: observations)
            let detectedLanguage = detectLanguage(from: recognizedText)
            
            Analytics.track(event: "ocr_completed", properties: [
                "text_length": recognizedText.count,
                "confidence": confidence,
                "language": detectedLanguage ?? "unknown"
            ])
            
            return OCRResult(
                text: recognizedText,
                confidence: confidence,
                language: detectedLanguage,
                textObservations: observations
            )
            
        } catch {
            debugPrint("❌ OCR failed: \(error)")
            throw DocumentError.processingFailed(reason: "Text recognition failed: \(error.localizedDescription)")
        }
    }
    
    /// Recognize text from multiple images (batch processing)
    func recognizeTextBatch(from images: [UIImage]) async throws -> [OCRResult] {
        var results: [OCRResult] = []
        
        for image in images {
            let result = try await recognizeText(from: image)
            results.append(result)
        }
        
        return results
    }
    
    /// Recognize text from PDF document
    func recognizeText(from pdfURL: URL) async throws -> [OCRPageResult] {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidFormat
        }
        
        var pageResults: [OCRPageResult] = []
        
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            // First, try to extract existing text (for digital PDFs)
            let existingText = page.string ?? ""
            
            var ocrResult: OCRResult?
            
            // If no text exists, perform OCR (for scanned PDFs)
            if existingText.isEmpty {
                if let pageImage = renderPageToImage(page) {
                    ocrResult = try? await recognizeText(from: pageImage)
                }
            }
            
            let pageResult = OCRPageResult(
                pageNumber: pageIndex,
                existingText: existingText,
                ocrResult: ocrResult
            )
            
            pageResults.append(pageResult)
        }
        
        return pageResults
    }
    
    // MARK: - Language Detection
    
    /// Detect the primary language in text
    func detectLanguage(from text: String) -> String? {
        guard !text.isEmpty else { return nil }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        if let language = recognizer.dominantLanguage {
            return language.rawValue
        }
        
        return nil
    }
    
    /// Get supported languages for OCR
    func getSupportedLanguages() async -> [String] {
        if #available(iOS 16.0, *) {
            do {
                let languages = try await VNRecognizeTextRequest.supportedRecognitionLanguages(
                    for: recognitionLevel,
                    revision: VNRecognizeTextRequestRevision3
                )
                return languages
            } catch {
                debugPrint("❌ Failed to get supported languages: \(error)")
                return ["en-US"]
            }
        } else {
            return ["en-US", "fr-FR", "it-IT", "de-DE", "es-ES", "pt-BR", "zh-Hans", "zh-Hant"]
        }
    }
    
    /// Set recognition languages
    func setLanguages(_ languages: [String]) {
        self.supportedLanguages = languages
    }
    
    // MARK: - Text Extraction
    
    /// Extract text from observations
    private func extractText(from observations: [VNRecognizedTextObservation]) -> String {
        let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        
        return recognizedStrings.joined(separator: "\n")
    }
    
    /// Extract text with bounding boxes
    func extractTextWithBounds(from observations: [VNRecognizedTextObservation]) -> [TextBoundingBox] {
        var textBoxes: [TextBoundingBox] = []
        
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            
            let boundingBox = TextBoundingBox(
                text: candidate.string,
                boundingBox: observation.boundingBox,
                confidence: candidate.confidence
            )
            
            textBoxes.append(boundingBox)
        }
        
        return textBoxes
    }
    
    // MARK: - Confidence Calculation
    
    private func calculateAverageConfidence(from observations: [VNRecognizedTextObservation]) -> Float {
        guard !observations.isEmpty else { return 0 }
        
        let confidences = observations.compactMap { observation in
            observation.topCandidates(1).first?.confidence
        }
        
        guard !confidences.isEmpty else { return 0 }
        
        let sum = confidences.reduce(0, +)
        return sum / Float(confidences.count)
    }
    
    // MARK: - Searchable PDF Generation
    
    /// Create a searchable PDF from images with OCR
    func createSearchablePDF(
        from images: [UIImage],
        title: String? = nil
    ) async throws -> URL {
        var pagesData: [(image: UIImage, text: String)] = []
        
        // Perform OCR on all images
        for image in images {
            let result = try await recognizeText(from: image)
            pagesData.append((image: image, text: result.text))
        }
        
        // Create PDF with text layer
        let pdfData = try await createPDFWithTextLayer(pages: pagesData, title: title)
        
        // Save PDF
        let filename = "\(title ?? "Searchable")_\(UUID().uuidString).pdf"
        let fileURL = try await DocumentFileManager.shared.saveDocument(
            data: pdfData,
            filename: filename,
            format: .pdf
        )
        
        Analytics.track(event: "searchable_pdf_created", properties: [
            "page_count": images.count
        ])
        
        return fileURL
    }
    
    private func createPDFWithTextLayer(
        pages: [(image: UIImage, text: String)],
        title: String?
    ) async throws -> Data {
        let pdfMetadata = [
            kCGPDFContextTitle: title ?? "Searchable PDF",
            kCGPDFContextCreator: "MyApp OCR"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetadata as [String: Any]
        
        guard let firstImage = pages.first?.image else {
            throw DocumentError.processingFailed(reason: "No images provided")
        }
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: firstImage.size), format: format)
        
        let data = renderer.pdfData { context in
            for (image, text) in pages {
                context.beginPage()
                
                // Draw image
                image.draw(in: CGRect(origin: .zero, size: image.size))
                
                // Add invisible text layer for searchability
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.clear // Invisible text
                ]
                
                let attributedString = NSAttributedString(string: text, attributes: attributes)
                attributedString.draw(at: .zero)
            }
        }
        
        return data
    }
    
    // MARK: - Text Extraction API
    
    /// Extract text from document (convenience method)
    func extractText(from document: Document) async throws -> String {
        let data = try await DocumentFileManager.shared.loadDocument(at: document.fileURL)
        
        switch document.fileFormat {
        case .pdf:
            let pageResults = try await recognizeText(from: document.fileURL)
            return pageResults.map { $0.fullText }.joined(separator: "\n\n")
            
        case .jpeg, .png, .heic, .tiff:
            guard let image = UIImage(data: data) else {
                throw DocumentError.invalidFormat
            }
            let result = try await recognizeText(from: image)
            return result.text
            
        default:
            throw DocumentError.invalidFormat
        }
    }
    
    // MARK: - Copy Text Functionality
    
    /// Copy recognized text to clipboard
    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        
        Analytics.track(event: "ocr_text_copied", properties: [
            "text_length": text.count
        ])
    }
    
    // MARK: - Text-to-Speech
    
    /// Get text for speech synthesis
    func prepareTextForSpeech(_ text: String) -> String {
        // Clean up text for better speech
        var cleanText = text
        
        // Remove excessive whitespace
        cleanText = cleanText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Remove special characters that don't sound good
        cleanText = cleanText.replacingOccurrences(of: "[^a-zA-Z0-9\\s.,!?]", with: "", options: .regularExpression)
        
        return cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Utilities
    
    private func renderPageToImage(_ page: PDFPage) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(pageRect)
            
            context.cgContext.translateBy(x: 0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return image
    }
    
    // MARK: - Configuration
    
    func setRecognitionLevel(_ level: VNRequestTextRecognitionLevel) {
        self.recognitionLevel = level
    }
    
    func setUseLanguageCorrection(_ enabled: Bool) {
        self.useLanguageCorrection = enabled
    }
}

// MARK: - OCR Result Models

struct OCRResult {
    let text: String
    let confidence: Float
    let language: String?
    let textObservations: [VNRecognizedTextObservation]
    
    var isHighConfidence: Bool {
        confidence >= 0.8
    }
}

struct OCRPageResult {
    let pageNumber: Int
    let existingText: String
    let ocrResult: OCRResult?
    
    var fullText: String {
        if !existingText.isEmpty {
            return existingText
        }
        return ocrResult?.text ?? ""
    }
    
    var hasText: Bool {
        !fullText.isEmpty
    }
}

struct TextBoundingBox {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

// MARK: - OCR Errors

extension ScanError {
    static var ocrNotAvailable: ScanError {
        .scanFailed(reason: "OCR is not available")
    }
}
