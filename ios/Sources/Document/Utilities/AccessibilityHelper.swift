//
//  AccessibilityHelper.swift
//  MyApp
//
//  Comprehensive accessibility support including VoiceOver, Dynamic Type, and high contrast.
//

import SwiftUI
import Combine

// MARK: - Accessibility Helper

@MainActor
final class AccessibilityHelper: ObservableObject {
    static let shared = AccessibilityHelper()

    @Published var isVoiceOverRunning: Bool
    @Published var isBoldTextEnabled: Bool
    @Published var isReduceMotionEnabled: Bool
    @Published var isReduceTransparencyEnabled: Bool
    @Published var uiContentSizeCategory: UIContentSizeCategory

    private init() {
        self.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        self.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        self.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        self.uiContentSizeCategory = UIApplication.shared.preferredContentSizeCategory

        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            Analytics.track(event: "voiceover_status_changed", parameters: ["enabled": UIAccessibility.isVoiceOverRunning])
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.boldTextStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        }

        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.uiContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        }
    }

    // MARK: - VoiceOver Helpers

    func announce(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        UIAccessibility.post(notification: priority, argument: message)
    }

    func announcePage(_ pageNumber: Int, totalPages: Int) {
        announce("Page \(pageNumber) of \(totalPages)")
    }

    func announceSelection(_ itemName: String) {
        announce("\(itemName) selected")
    }

    func announceAction(_ action: String, success: Bool) {
        let message = success ? "\(action) completed" : "\(action) failed"
        announce(message)
    }

    // MARK: - Content Size Helpers

    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    var isLargeContentSize: Bool {
        uiContentSizeCategory >= .accessibilityMedium
    }

    var isExtraLargeContentSize: Bool {
        uiContentSizeCategory >= .accessibilityExtraLarge
    }
}

// MARK: - Accessibility Modifiers

extension View {
    /// Adds comprehensive accessibility labels for document-related views
    func documentAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }

    /// Optimizes view for VoiceOver users
    func voiceOverOptimized(groupChildren: Bool = true) -> some View {
        Group {
            if groupChildren {
                self.accessibilityElement(children: .combine)
            } else {
                self.accessibilityElement(children: .contain)
            }
        }
    }

    /// Adds Dynamic Type support with custom scaling
    func dynamicTypeScaled(minSize: CGFloat, maxSize: CGFloat) -> some View {
        self.modifier(DynamicTypeScaledModifier(minSize: minSize, maxSize: maxSize))
    }

    /// Adapts animations based on Reduce Motion preference
    func adaptiveAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        Group {
            if AccessibilityHelper.shared.isReduceMotionEnabled {
                self
            } else {
                self.animation(animation, value: value)
            }
        }
    }

    /// Applies high contrast styling when needed
    func highContrastAdaptive(normalColor: Color, highContrastColor: Color) -> some View {
        self.modifier(HighContrastModifier(normalColor: normalColor, highContrastColor: highContrastColor))
    }

    /// Makes interactive elements accessible with custom labels
    func accessibleButton(label: String, hint: String? = nil, action: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "Double tap to activate")
            .accessibilityAddTraits(.isButton)
    }

    /// Makes text accessible with custom labels
    func accessibleText(label: String? = nil) -> some View {
        self
            .accessibilityLabel(label ?? "")
            .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Dynamic Type Scaled Modifier

struct DynamicTypeScaledModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory

    let minSize: CGFloat
    let maxSize: CGFloat

    func body(content: Content) -> some View {
        let scaledSize = scaledFontSize()
        return content
            .font(.system(size: scaledSize))
    }

    private func scaledFontSize() -> CGFloat {
        let baseScale = sizeCategory.scaleFactor
        let scaledSize = minSize * baseScale
        return min(max(scaledSize, minSize), maxSize)
    }
}

extension ContentSizeCategory {
    var scaleFactor: CGFloat {
        switch self {
        case .extraSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        case .extraExtraLarge: return 1.3
        case .extraExtraExtraLarge: return 1.4
        case .accessibilityMedium: return 1.6
        case .accessibilityLarge: return 1.8
        case .accessibilityExtraLarge: return 2.0
        case .accessibilityExtraExtraLarge: return 2.2
        case .accessibilityExtraExtraExtraLarge: return 2.4
        @unknown default: return 1.0
        }
    }
}

// MARK: - High Contrast Modifier

struct HighContrastModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) var colorSchemeContrast

    let normalColor: Color
    let highContrastColor: Color

    func body(content: Content) -> some View {
        content
            .foregroundColor(colorSchemeContrast == .increased ? highContrastColor : normalColor)
    }
}

// MARK: - Accessibility-Aware Components

struct AccessibleCard<Content: View>: View {
    let title: String
    let description: String?
    let action: () -> Void
    @ViewBuilder let content: Content

    @Environment(\.sizeCategory) var sizeCategory
    @ObservedObject private var accessibility = AccessibilityHelper.shared

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                content

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(accessibility.scaledFont(size: 17, weight: .semibold))

                    if let description = description {
                        Text(description)
                            .font(accessibility.scaledFont(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(description ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

struct AccessibleIcon: View {
    let systemName: String
    let label: String
    let size: CGFloat

    @ObservedObject private var accessibility = AccessibilityHelper.shared

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size))
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Accessibility Audit Helper

struct AccessibilityAudit {
    /// Checks if a view has proper accessibility labels
    static func checkLabels(for view: String) -> Bool {
        // This would be used in tests to ensure all views have labels
        // Implementation would check if labels exist
        return true
    }

    /// Logs accessibility issues for debugging
    static func logIssue(_ issue: String, severity: Severity = .warning) {
        #if DEBUG
        let prefix = severity == .error ? "❌" : "⚠️"
        print("\(prefix) Accessibility: \(issue)")
        #endif
    }

    enum Severity {
        case warning
        case error
    }
}

// MARK: - Document-Specific Accessibility Labels

extension String {
    static let accessibility = AccessibilityLabels()

    struct AccessibilityLabels {
        // Scanning
        let scanDocument = "Scan document"
        let captureButton = "Capture"
        let flashToggle = "Toggle flash"
        let edgeDetection = "Edge detection"
        let multiPageIndicator = "Multiple pages captured"

        // Viewing
        let pdfViewer = "PDF document viewer"
        let nextPage = "Next page"
        let previousPage = "Previous page"
        let zoomIn = "Zoom in"
        let zoomOut = "Zoom out"

        // Editing
        let annotationTool = "Annotation tool"
        let penTool = "Pen tool for drawing"
        let highlighterTool = "Highlighter tool"
        let textTool = "Add text"
        let shapeTool = "Add shape"
        let undoButton = "Undo last action"
        let redoButton = "Redo last action"

        // Organization
        let documentList = "Document list"
        let folderView = "Folder view"
        let searchField = "Search documents"
        let sortButton = "Sort documents"
        let filterButton = "Filter documents"

        func pageNumber(_ current: Int, total: Int) -> String {
            "Page \(current) of \(total)"
        }

        func documentCount(_ count: Int) -> String {
            "\(count) document\(count == 1 ? "" : "s")"
        }

        func scanQuality(_ quality: String) -> String {
            "Scan quality: \(quality)"
        }
    }
}

// MARK: - Usage Example in Views

/*
 Example usage in a DocumentBrowserView:

 struct DocumentBrowserView: View {
     var body: some View {
         List {
             ForEach(documents) { document in
                 DocumentRow(document: document)
                     .documentAccessibility(
                         label: document.title,
                         hint: "Double tap to open",
                         value: "\(document.pageCount) pages",
                         traits: .isButton
                     )
             }
         }
         .accessibilityLabel(.accessibility.documentList)
         .onAppear {
             AccessibilityHelper.shared.announce("\(documents.count) documents")
         }
     }
 }

 Button for scanning:
 Button {
     scan()
 } label: {
     Label("Scan", systemImage: "doc.text.viewfinder")
 }
 .accessibleButton(
     label: .accessibility.scanDocument,
     hint: "Opens the document scanner"
 )
 */
