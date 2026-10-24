//
//  ConversionPresets.swift
//  MyApp
//
//  Provides preset templates and custom settings for document conversion.
//

import Foundation

/// Manages conversion presets and templates
struct ConversionPresets {
    
    // MARK: - Common Presets
    
    /// Get all available presets
    static let allPresets: [ConversionPreset] = [
        .webOptimized,
        .printQuality,
        .emailFriendly,
        .archiveQuality,
        .mobileOptimized,
        .highCompression,
        .maximumQuality,
        .blackAndWhite,
        .ocr Ready,
        .presentation
    ]
    
    /// Web-optimized PDF (small size, good quality)
    static let webOptimized = ConversionPreset(
        id: "web_optimized",
        name: "Web Optimized",
        description: "Optimized for web viewing with fast loading",
        icon: "globe",
        settings: ConversionSettings(
            quality: .medium,
            preserveMetadata: false,
            compression: true,
            colorSpace: .rgb
        ),
        targetFormats: [.pdf, .jpeg],
        maxFileSize: 5_000_000, // 5 MB
        recommendedFor: ["Sharing online", "Email attachments", "Quick viewing"]
    )
    
    /// Print-quality export
    static let printQuality = ConversionPreset(
        id: "print_quality",
        name: "Print Quality",
        description: "High quality for professional printing",
        icon: "printer",
        settings: ConversionSettings(
            quality: .high,
            preserveMetadata: true,
            compression: false,
            colorSpace: .cmyk
        ),
        targetFormats: [.pdf, .tiff],
        maxFileSize: nil,
        recommendedFor: ["Professional printing", "Publishing", "High-res output"]
    )
    
    /// Email-friendly (small size)
    static let emailFriendly = ConversionPreset(
        id: "email_friendly",
        name: "Email Friendly",
        description: "Compressed for easy email sharing",
        icon: "envelope",
        settings: ConversionSettings(
            quality: .medium,
            preserveMetadata: false,
            compression: true,
            colorSpace: .rgb
        ),
        targetFormats: [.pdf, .jpeg],
        maxFileSize: 10_000_000, // 10 MB
        recommendedFor: ["Email attachments", "Quick sharing", "Mobile viewing"]
    )
    
    /// Archive quality (maximum preservation)
    static let archiveQuality = ConversionPreset(
        id: "archive_quality",
        name: "Archive Quality",
        description: "Maximum quality for long-term storage",
        icon: "archivebox",
        settings: ConversionSettings(
            quality: .maximum,
            preserveMetadata: true,
            compression: false,
            colorSpace: .rgb
        ),
        targetFormats: [.pdf, .tiff],
        maxFileSize: nil,
        recommendedFor: ["Long-term storage", "Master copies", "Legal documents"]
    )
    
    /// Mobile-optimized
    static let mobileOptimized = ConversionPreset(
        id: "mobile_optimized",
        name: "Mobile Optimized",
        description: "Optimized for mobile devices",
        icon: "iphone",
        settings: ConversionSettings(
            quality: .medium,
            preserveMetadata: false,
            compression: true,
            colorSpace: .rgb
        ),
        targetFormats: [.pdf, .jpeg, .png],
        maxFileSize: 3_000_000, // 3 MB
        recommendedFor: ["Mobile viewing", "Quick downloads", "Limited storage"]
    )
    
    /// High compression
    static let highCompression = ConversionPreset(
        id: "high_compression",
        name: "High Compression",
        description: "Maximum compression for smallest file size",
        icon: "arrow.down.circle",
        settings: ConversionSettings(
            quality: .low,
            preserveMetadata: false,
            compression: true,
            colorSpace: .grayscale
        ),
        targetFormats: [.pdf, .jpeg],
        maxFileSize: 1_000_000, // 1 MB
        recommendedFor: ["Minimal storage", "Fast uploads", "Backups"]
    )
    
    /// Maximum quality (no compression)
    static let maximumQuality = ConversionPreset(
        id: "maximum_quality",
        name: "Maximum Quality",
        description: "Best possible quality, largest file size",
        icon: "sparkles",
        settings: ConversionSettings(
            quality: .maximum,
            preserveMetadata: true,
            compression: false,
            colorSpace: .rgb
        ),
        targetFormats: [.pdf, .png, .tiff],
        maxFileSize: nil,
        recommendedFor: ["Professional use", "Editing", "High-end printing"]
    )
    
    /// Black and white
    static let blackAndWhite = ConversionPreset(
        id: "black_and_white",
        name: "Black & White",
        description: "Grayscale for documents and text",
        icon: "textformat",
        settings: ConversionSettings(
            quality: .high,
            preserveMetadata: true,
            compression: true,
            colorSpace: .grayscale
        ),
        targetFormats: [.pdf, .tiff],
        maxFileSize: 5_000_000, // 5 MB
        recommendedFor: ["Text documents", "Scanned books", "Smaller file sizes"]
    )
    
    /// OCR-ready (optimized for text recognition)
    static let ocrReady = ConversionPreset(
        id: "ocr_ready",
        name: "OCR Ready",
        description: "Optimized for text recognition",
        icon: "doc.text.magnifyingglass",
        settings: ConversionSettings(
            quality: .high,
            preserveMetadata: true,
            compression: false,
            colorSpace: .grayscale
        ),
        targetFormats: [.pdf, .tiff],
        maxFileSize: nil,
        recommendedFor: ["Text extraction", "Searchable PDFs", "Document scanning"]
    )
    
    /// Presentation (balanced for slides)
    static let presentation = ConversionPreset(
        id: "presentation",
        name: "Presentation",
        description: "Balanced quality for presentations",
        icon: "play.rectangle",
        settings: ConversionSettings(
            quality: .high,
            preserveMetadata: true,
            compression: true,
            colorSpace: .rgb
        ),
        targetFormats: [.pdf, .jpeg],
        maxFileSize: 20_000_000, // 20 MB
        recommendedFor: ["Slideshows", "Screen sharing", "Presentations"]
    )
    
    // MARK: - Preset Retrieval
    
    /// Get preset by ID
    static func preset(withID id: String) -> ConversionPreset? {
        allPresets.first { $0.id == id }
    }
    
    /// Get presets for a specific target format
    static func presets(for format: ExportFormat) -> [ConversionPreset] {
        allPresets.filter { $0.targetFormats.contains(format) }
    }
    
    /// Get presets within file size limit
    static func presets(maxFileSize: Int) -> [ConversionPreset] {
        allPresets.filter { preset in
            guard let limit = preset.maxFileSize else { return true }
            return limit <= maxFileSize
        }
    }
    
    // MARK: - Custom Preset Creation
    
    /// Create a custom preset
    static func createCustomPreset(
        name: String,
        description: String,
        settings: ConversionSettings,
        targetFormats: [ExportFormat],
        icon: String = "star.fill"
    ) -> ConversionPreset {
        ConversionPreset(
            id: "custom_\(UUID().uuidString)",
            name: name,
            description: description,
            icon: icon,
            settings: settings,
            targetFormats: targetFormats,
            maxFileSize: nil,
            recommendedFor: []
        )
    }
}

// MARK: - Preset Model

struct ConversionPreset: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let settings: ConversionSettings
    let targetFormats: [ExportFormat]
    let maxFileSize: Int? // in bytes
    let recommendedFor: [String]
    
    var displayFileSize: String? {
        guard let size = maxFileSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

// MARK: - Codable Conformance

extension ConversionSettings: Codable {}
extension ExportFormat: Codable {}
extension ColorSpace: Codable {}
extension ExportQuality: Codable {}

// MARK: - Preset Manager

/// Manages user's saved presets
actor ConversionPresetManager {
    
    static let shared = ConversionPresetManager()
    
    private let userDefaultsKey = "com.myapp.conversion_presets"
    private var customPresets: [ConversionPreset] = []
    
    private init() {
        Task {
            await loadCustomPresets()
        }
    }
    
    // MARK: - Custom Preset Management
    
    /// Get all presets (built-in + custom)
    func getAllPresets() async -> [ConversionPreset] {
        ConversionPresets.allPresets + customPresets
    }
    
    /// Get only custom presets
    func getCustomPresets() async -> [ConversionPreset] {
        customPresets
    }
    
    /// Save a custom preset
    func savePreset(_ preset: ConversionPreset) async throws {
        // Check if preset with same ID exists
        if let index = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[index] = preset
        } else {
            customPresets.append(preset)
        }
        
        try await persistCustomPresets()
        
        Analytics.track(event: "custom_preset_saved", properties: [
            "preset_name": preset.name
        ])
    }
    
    /// Delete a custom preset
    func deletePreset(withID id: String) async throws {
        customPresets.removeAll { $0.id == id }
        try await persistCustomPresets()
        
        Analytics.track(event: "custom_preset_deleted", properties: [:])
    }
    
    /// Get preset by ID (checks both built-in and custom)
    func getPreset(withID id: String) async -> ConversionPreset? {
        if let builtIn = ConversionPresets.preset(withID: id) {
            return builtIn
        }
        return customPresets.first { $0.id == id }
    }
    
    // MARK: - Persistence
    
    private func loadCustomPresets() async {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }
        
        do {
            customPresets = try JSONDecoder().decode([ConversionPreset].self, from: data)
        } catch {
            debugPrint("❌ Failed to load custom presets: \(error)")
        }
    }
    
    private func persistCustomPresets() async throws {
        let data = try JSONEncoder().encode(customPresets)
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
    
    // MARK: - Preset Recommendations
    
    /// Recommend preset based on source file
    func recommendPreset(for sourceURL: URL, targetFormat: ExportFormat) async -> ConversionPreset {
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int) ?? 0
        
        // For large files, recommend compression
        if fileSize > 50_000_000 { // > 50 MB
            return ConversionPresets.highCompression
        }
        
        // Based on target format
        switch targetFormat {
        case .pdf:
            return ConversionPresets.webOptimized
        case .jpeg:
            return ConversionPresets.emailFriendly
        case .png:
            return ConversionPresets.maximumQuality
        case .tiff:
            return ConversionPresets.archiveQuality
        case .text, .html, .rtf, .word:
            return ConversionPresets.ocrReady
        }
    }
    
    /// Get frequently used presets
    func getFrequentPresets(limit: Int = 5) async -> [ConversionPreset] {
        // In a full implementation, this would track usage
        // For now, return most commonly used presets
        Array(ConversionPresets.allPresets.prefix(limit))
    }
}

// MARK: - Preset Templates for Specific Use Cases

extension ConversionPresets {
    
    /// Presets grouped by use case
    struct UseCasePresets {
        static let business: [ConversionPreset] = [
            .printQuality,
            .emailFriendly,
            .archiveQuality
        ]
        
        static let personal: [ConversionPreset] = [
            .webOptimized,
            .mobileOptimized,
            .emailFriendly
        ]
        
        static let professional: [ConversionPreset] = [
            .maximumQuality,
            .printQuality,
            .archiveQuality
        ]
        
        static let sharing: [ConversionPreset] = [
            .emailFriendly,
            .webOptimized,
            .mobileOptimized
        ]
        
        static let storage: [ConversionPreset] = [
            .highCompression,
            .archiveQuality,
            .blackAndWhite
        ]
    }
    
    /// Get presets for a use case
    static func presets(for useCase: UseCase) -> [ConversionPreset] {
        switch useCase {
        case .business: return UseCasePresets.business
        case .personal: return UseCasePresets.personal
        case .professional: return UseCasePresets.professional
        case .sharing: return UseCasePresets.sharing
        case .storage: return UseCasePresets.storage
        }
    }
}

enum UseCase: String, CaseIterable {
    case business = "Business"
    case personal = "Personal"
    case professional = "Professional"
    case sharing = "Sharing"
    case storage = "Storage"
    
    var icon: String {
        switch self {
        case .business: return "briefcase"
        case .personal: return "person"
        case .professional: return "star"
        case .sharing: return "square.and.arrow.up"
        case .storage: return "internaldrive"
        }
    }
}
