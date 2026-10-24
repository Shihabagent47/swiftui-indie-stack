//
//  Haptics.swift
//  MyApp
//
//  Haptic feedback utilities using UIImpactFeedbackGenerator and CoreHaptics.
//

import Foundation
import UIKit
import CoreHaptics

enum Haptics: String, CaseIterable, Identifiable {
    case light
    case medium
    case heavy

    var id: String { rawValue }

    // MARK: - Basic Haptics

    /// Trigger haptic feedback at specified intensity
    static func triggerHapticFeedback(impactLevel: Haptics) {
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle

        switch impactLevel {
        case .light:
            feedbackStyle = .light
        case .medium:
            feedbackStyle = .medium
        case .heavy:
            feedbackStyle = .heavy
        }

        let feedbackGenerator = UIImpactFeedbackGenerator(style: feedbackStyle)
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred()
    }

    /// Trigger notification haptic (success, warning, error)
    static func triggerNotificationHaptic(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    /// Trigger success haptic
    static func success() {
        triggerNotificationHaptic(type: .success)
    }

    /// Trigger warning haptic
    static func warning() {
        triggerNotificationHaptic(type: .warning)
    }

    /// Trigger error haptic
    static func error() {
        triggerNotificationHaptic(type: .error)
    }

    /// Trigger selection changed haptic (light tap)
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // MARK: - Convenience Methods

    /// Trigger light haptic feedback
    static func light() {
        triggerHapticFeedback(impactLevel: .light)
    }

    /// Trigger medium haptic feedback
    static func medium() {
        triggerHapticFeedback(impactLevel: .medium)
    }

    /// Trigger heavy haptic feedback
    static func heavy() {
        triggerHapticFeedback(impactLevel: .heavy)
    }

    // MARK: - Document-Specific Haptics

    /// Haptic for successful document scan
    static func documentScanned() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)

        // Add a slight delay and then a light impact for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            triggerHapticFeedback(impactLevel: .light)
        }
    }

    /// Haptic for page turn
    static func pageTurn() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// Haptic for annotation added
    static func annotationAdded() {
        triggerHapticFeedback(impactLevel: .medium)
    }

    /// Haptic for document deleted
    static func documentDeleted() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Haptic for undo/redo
    static func undoRedo() {
        triggerHapticFeedback(impactLevel: .light)
    }

    /// Haptic for document saved
    static func documentSaved() {
        success()
    }

    /// Haptic for edge detection
    static func edgeDetected() {
        triggerHapticFeedback(impactLevel: .light)
    }

    /// Haptic for processing complete
    static func processingComplete() {
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            triggerHapticFeedback(impactLevel: .light)
        }
    }

    // MARK: - Advanced Core Haptics

    private static var hapticEngine: CHHapticEngine?

    /// Initialize haptic engine for advanced patterns
    static func initializeHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine initialization failed: \(error)")
        }
    }

    /// Play a custom haptic pattern for multi-page scan completion
    static func multiPageScanComplete(pageCount: Int) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            success()
            return
        }

        var events = [CHHapticEvent]()

        // Create a pattern: light taps for each page, then a strong tap for completion
        for i in 0..<min(pageCount, 5) {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: Double(i) * 0.1
            )
            events.append(event)
        }

        // Final strong tap
        let finalIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let finalSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let finalEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [finalIntensity, finalSharpness],
            relativeTime: Double(min(pageCount, 5)) * 0.1 + 0.2
        )
        events.append(finalEvent)

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
            success() // Fallback to simple success haptic
        }
    }

    /// Continuous haptic for scanning in progress
    static func startContinuousHaptic() -> CHHapticPatternPlayer? {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return nil }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: 10.0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            return player
        } catch {
            print("Failed to start continuous haptic: \(error)")
            return nil
        }
    }

    /// Stop continuous haptic
    static func stopContinuousHaptic(_ player: CHHapticPatternPlayer?) {
        do {
            try player?.stop(atTime: 0)
        } catch {
            print("Failed to stop haptic: \(error)")
        }
    }
}

// MARK: - Haptic Preferences

extension Haptics {
    /// Check if haptics are enabled in system settings
    static var isHapticsEnabled: Bool {
        // Check if device supports haptics
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Check if user has reduced motion enabled (may want to reduce haptics too)
    static var shouldReduceHaptics: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    /// Safe haptic trigger that respects accessibility settings
    static func trigger(_ haptic: @escaping () -> Void) {
        guard isHapticsEnabled, !shouldReduceHaptics else { return }
        haptic()
    }
}
