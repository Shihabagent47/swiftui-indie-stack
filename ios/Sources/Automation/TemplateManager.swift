//
//  TemplateManager.swift
//  MyApp
//
//  Manages document templates and preset configurations.
//

import Foundation
import PDFKit
import Combine

@MainActor
final class TemplateManager: ObservableObject {
    static let shared = TemplateManager()

    // MARK: - Published Properties

    @Published var templates: [DocumentTemplate] = []
    @Published var presetConfigurations: [PresetConfiguration] = []

    // MARK: - Private Properties

    private let fileManager = FileManager.default

    // Storage keys
    private enum StorageKeys {
        static let templates = "document_templates"
        static let presetConfigurations = "preset_configurations"
    }

    // MARK: - Initialization

    private init() {
        loadTemplates()
        loadPresetConfigurations()
        setupDefaultTemplates()
        setupDefaultPresets()
    }

    // MARK: - Document Templates

    /// Create a new document template
    func createTemplate(
        name: String,
        type: TemplateType,
        pageSize: PageSize,
        orientation: PageOrientation,
        content: TemplateContent?
    ) {
        let template = DocumentTemplate(
            id: UUID(),
            name: name,
            type: type,
            pageSize: pageSize,
            orientation: orientation,
            content: content,
            createdDate: Date()
        )

        templates.append(template)
        saveTemplates()

        Analytics.track(event: "template_created", parameters: ["name": name])
    }

    /// Generate document from template
    func generateDocument(from template: DocumentTemplate) async throws -> URL {
        let pdfDocument = PDFDocument()

        // Create page with template settings
        let pageRect: CGRect
        switch template.pageSize {
        case .letter:
            pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        case .a4:
            pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        case .legal:
            pageRect = CGRect(x: 0, y: 0, width: 612, height: 1008)
        case .custom(let width, let height):
            pageRect = CGRect(x: 0, y: 0, width: width, height: height)
        }

        // Create PDF context
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            // Draw template content if available
            if let content = template.content {
                drawTemplateContent(content, in: pageRect, context: context.cgContext)
            }
        }

        // Save to temporary directory
        let fileName = "\(template.name)_\(UUID().uuidString).pdf"
        let outputURL = fileManager.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: outputURL)

        Analytics.track(event: "document_generated_from_template", parameters: [
            "template": template.name
        ])

        return outputURL
    }

    private func drawTemplateContent(_ content: TemplateContent, in rect: CGRect, context: CGContext) {
        switch content {
        case .blank:
            // Just white background
            UIColor.white.setFill()
            context.fill(rect)

        case .lined(let spacing):
            UIColor.white.setFill()
            context.fill(rect)

            UIColor.lightGray.setStroke()
            context.setLineWidth(0.5)

            var y: CGFloat = spacing
            while y < rect.height {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: rect.width, y: y))
                y += spacing
            }
            context.strokePath()

        case .grid(let spacing):
            UIColor.white.setFill()
            context.fill(rect)

            UIColor.lightGray.setStroke()
            context.setLineWidth(0.5)

            // Vertical lines
            var x: CGFloat = spacing
            while x < rect.width {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: rect.height))
                x += spacing
            }

            // Horizontal lines
            var y: CGFloat = spacing
            while y < rect.height {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: rect.width, y: y))
                y += spacing
            }
            context.strokePath()

        case .custom(let text):
            UIColor.white.setFill()
            context.fill(rect)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]

            let attributedString = NSAttributedString(string: text, attributes: attributes)
            attributedString.draw(in: rect.insetBy(dx: 20, dy: 20))
        }
    }

    /// Delete a template
    func deleteTemplate(_ template: DocumentTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()

        Analytics.track(event: "template_deleted", parameters: ["name": template.name])
    }

    private func setupDefaultTemplates() {
        guard templates.isEmpty else { return }

        // Blank Letter
        createTemplate(
            name: "Blank Letter",
            type: .blank,
            pageSize: .letter,
            orientation: .portrait,
            content: .blank
        )

        // Lined Paper
        createTemplate(
            name: "Lined Paper",
            type: .lined,
            pageSize: .letter,
            orientation: .portrait,
            content: .lined(spacing: 25)
        )

        // Grid Paper
        createTemplate(
            name: "Grid Paper",
            type: .grid,
            pageSize: .letter,
            orientation: .portrait,
            content: .grid(spacing: 20)
        )

        // A4 Blank
        createTemplate(
            name: "Blank A4",
            type: .blank,
            pageSize: .a4,
            orientation: .portrait,
            content: .blank
        )
    }

    // MARK: - Preset Configurations

    /// Create a preset configuration
    func createPresetConfiguration(
        name: String,
        scanSettings: ScanSettings?,
        exportSettings: ExportSettings?,
        processingSettings: ProcessingSettings?
    ) {
        let preset = PresetConfiguration(
            id: UUID(),
            name: name,
            scanSettings: scanSettings,
            exportSettings: exportSettings,
            processingSettings: processingSettings,
            createdDate: Date()
        )

        presetConfigurations.append(preset)
        savePresetConfigurations()

        Analytics.track(event: "preset_created", parameters: ["name": name])
    }

    /// Apply preset configuration
    func applyPreset(_ preset: PresetConfiguration) {
        // This would apply the preset settings to the app's current configuration
        // For now, just track the event
        Analytics.track(event: "preset_applied", parameters: ["name": preset.name])
    }

    /// Delete a preset configuration
    func deletePresetConfiguration(_ preset: PresetConfiguration) {
        presetConfigurations.removeAll { $0.id == preset.id }
        savePresetConfigurations()

        Analytics.track(event: "preset_deleted", parameters: ["name": preset.name])
    }

    private func setupDefaultPresets() {
        guard presetConfigurations.isEmpty else { return }

        // High Quality Scan & Export
        createPresetConfiguration(
            name: "High Quality",
            scanSettings: ScanSettings(mode: .color, resolution: .high),
            exportSettings: ExportSettings(
                format: .pdf,
                quality: .high,
                compression: false,
                includeMetadata: true,
                pageRange: nil
            ),
            processingSettings: nil
        )

        // Quick Scan
        createPresetConfiguration(
            name: "Quick Scan",
            scanSettings: ScanSettings(mode: .grayscale, resolution: .medium),
            exportSettings: ExportSettings(
                format: .jpeg,
                quality: .medium,
                compression: true,
                includeMetadata: false,
                pageRange: nil
            ),
            processingSettings: nil
        )

        // Archive Quality
        createPresetConfiguration(
            name: "Archive",
            scanSettings: ScanSettings(mode: .color, resolution: .maximum),
            exportSettings: ExportSettings(
                format: .pdf,
                quality: .maximum,
                compression: false,
                includeMetadata: true,
                pageRange: nil
            ),
            processingSettings: ProcessingSettings(
                autoRotate: true,
                autoCrop: true,
                enhanceContrast: false,
                ocrEnabled: true
            )
        )
    }

    // MARK: - Persistence

    private func loadTemplates() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.templates),
           let templates = try? JSONDecoder().decode([DocumentTemplate].self, from: data) {
            self.templates = templates
        }
    }

    private func saveTemplates() {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: StorageKeys.templates)
        }
    }

    private func loadPresetConfigurations() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.presetConfigurations),
           let presets = try? JSONDecoder().decode([PresetConfiguration].self, from: data) {
            self.presetConfigurations = presets
        }
    }

    private func savePresetConfigurations() {
        if let data = try? JSONEncoder().encode(presetConfigurations) {
            UserDefaults.standard.set(data, forKey: StorageKeys.presetConfigurations)
        }
    }
}

// MARK: - Document Template

struct DocumentTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: TemplateType
    let pageSize: PageSize
    let orientation: PageOrientation
    let content: TemplateContent?
    let createdDate: Date
}

enum TemplateType: String, Codable, CaseIterable {
    case blank = "Blank"
    case lined = "Lined"
    case grid = "Grid"
    case letterhead = "Letterhead"
    case invoice = "Invoice"
    case custom = "Custom"
}

enum PageSize: Codable {
    case letter
    case a4
    case legal
    case custom(width: CGFloat, height: CGFloat)

    var displayName: String {
        switch self {
        case .letter: return "Letter (8.5\" × 11\")"
        case .a4: return "A4 (210mm × 297mm)"
        case .legal: return "Legal (8.5\" × 14\")"
        case .custom(let width, let height): return "Custom (\(Int(width)) × \(Int(height)))"
        }
    }
}

enum PageOrientation: String, Codable, CaseIterable {
    case portrait = "Portrait"
    case landscape = "Landscape"
}

enum TemplateContent: Codable {
    case blank
    case lined(spacing: CGFloat)
    case grid(spacing: CGFloat)
    case custom(text: String)
}

// MARK: - Preset Configuration

struct PresetConfiguration: Identifiable, Codable {
    let id: UUID
    let name: String
    let scanSettings: ScanSettings?
    let exportSettings: ExportSettings?
    let processingSettings: ProcessingSettings?
    let createdDate: Date
}

struct ScanSettings: Codable {
    let mode: ScanColorMode
    let resolution: ScanResolution

    enum ScanColorMode: String, Codable {
        case color = "Color"
        case grayscale = "Grayscale"
        case blackAndWhite = "Black & White"
    }

    enum ScanResolution: String, Codable {
        case low = "Low (150 DPI)"
        case medium = "Medium (300 DPI)"
        case high = "High (600 DPI)"
        case maximum = "Maximum (1200 DPI)"
    }
}

struct ProcessingSettings: Codable {
    let autoRotate: Bool
    let autoCrop: Bool
    let enhanceContrast: Bool
    let ocrEnabled: Bool
}
