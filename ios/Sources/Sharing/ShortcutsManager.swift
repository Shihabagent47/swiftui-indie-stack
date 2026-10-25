//
//  ShortcutsManager.swift
//  MyApp
//
//  Manages Siri Shortcuts and App Shortcuts integration.
//

import Foundation
import Intents
import AppIntents
import Combine
import CoreSpotlight
import UIKit

@MainActor
final class ShortcutsManager: ObservableObject {
    static let shared = ShortcutsManager()

    // MARK: - Published Properties

    @Published var donatedActivities: [NSUserActivity] = []

    // MARK: - Initialization

    private init() {}

    // MARK: - Donate User Activities

    /// Donate scan activity for Siri Shortcuts
    func donateScanActivity() {
        let activity = NSUserActivity(activityType: "com.myapp.scan")
        activity.title = "Scan Document"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = "scan_document"

        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.contentDescription = "Quickly scan a new document"
        attributes.thumbnailData = UIImage(systemName: "doc.text.viewfinder")?.pngData()

        activity.contentAttributeSet = attributes

        activity.becomeCurrent()

        donatedActivities.append(activity)

        Analytics.track(event: "shortcuts_scan_donated")
    }

    /// Donate export activity
    func donateExportActivity(documentName: String) {
        let activity = NSUserActivity(activityType: "com.myapp.export")
        activity.title = "Export \(documentName)"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.userInfo = ["documentName": documentName]

        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.contentDescription = "Export document to Files"
        attributes.thumbnailData = UIImage(systemName: "arrow.up.doc")?.pngData()

        activity.contentAttributeSet = attributes

        activity.becomeCurrent()

        Analytics.track(event: "shortcuts_export_donated", parameters: ["document": documentName])
    }

    /// Donate share activity
    func donateShareActivity(documentName: String) {
        let activity = NSUserActivity(activityType: "com.myapp.share")
        activity.title = "Share \(documentName)"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.userInfo = ["documentName": documentName]

        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.contentDescription = "Share document with others"
        attributes.thumbnailData = UIImage(systemName: "square.and.arrow.up")?.pngData()

        activity.contentAttributeSet = attributes

        activity.becomeCurrent()

        Analytics.track(event: "shortcuts_share_donated", parameters: ["document": documentName])
    }

    // MARK: - Handle User Activity

    /// Handle incoming user activity from Shortcuts
    func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
        switch userActivity.activityType {
        case "com.myapp.scan":
            handleScanShortcut()
            return true

        case "com.myapp.export":
            if let documentName = userActivity.userInfo?["documentName"] as? String {
                handleExportShortcut(documentName: documentName)
            }
            return true

        case "com.myapp.share":
            if let documentName = userActivity.userInfo?["documentName"] as? String {
                handleShareShortcut(documentName: documentName)
            }
            return true

        default:
            return false
        }
    }

    // MARK: - Shortcut Handlers

    private func handleScanShortcut() {
        NotificationCenter.default.post(name: .openScannerFromShortcut, object: nil)
        Analytics.track(event: "shortcuts_scan_invoked")
    }

    private func handleExportShortcut(documentName: String) {
        NotificationCenter.default.post(
            name: .exportDocumentFromShortcut,
            object: nil,
            userInfo: ["documentName": documentName]
        )
        Analytics.track(event: "shortcuts_export_invoked", parameters: ["document": documentName])
    }

    private func handleShareShortcut(documentName: String) {
        NotificationCenter.default.post(
            name: .shareDocumentFromShortcut,
            object: nil,
            userInfo: ["documentName": documentName]
        )
        Analytics.track(event: "shortcuts_share_invoked", parameters: ["document": documentName])
    }

    // MARK: - Delete Shortcuts

    /// Delete all donated shortcuts
    func deleteAllShortcuts() {
        NSUserActivity.deleteAllSavedUserActivities {
            Analytics.track(event: "shortcuts_all_deleted")
        }
    }

    /// Delete specific shortcut
    func deleteShortcut(withIdentifier identifier: String) {
        NSUserActivity.deleteSavedUserActivities(withPersistentIdentifiers: [identifier]) {
            Analytics.track(event: "shortcuts_deleted", parameters: ["identifier": identifier])
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openScannerFromShortcut = Notification.Name("openScannerFromShortcut")
    static let exportDocumentFromShortcut = Notification.Name("exportDocumentFromShortcut")
    static let shareDocumentFromShortcut = Notification.Name("shareDocumentFromShortcut")
}
