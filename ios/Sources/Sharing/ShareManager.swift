//
//  ShareManager.swift
//  MyApp
//
//  Manages document sharing via native share sheet, email, AirDrop, and other apps.
//

import Foundation
import UIKit
import SwiftUI
import MessageUI
import Combine
import UniformTypeIdentifiers

@MainActor
final class ShareManager: NSObject, ObservableObject {
    static let shared = ShareManager()

    // MARK: - Published Properties

    @Published var isSharing = false
    @Published var shareError: String?
    @Published var shareHistory: [ShareHistoryEntry] = []

    // MARK: - Private Properties

    private var mailComposeDelegate: MailComposerDelegate?
    private let maxHistoryItems = 50

    // Storage keys
    private enum StorageKeys {
        static let shareHistory = "shareHistory"
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        loadShareHistory()
    }

    // MARK: - Native Share Sheet

    /// Present native share sheet for a document
    func shareDocument(at url: URL, from viewController: UIViewController? = nil) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            shareError = "File not found"
            Analytics.track(event: "share_error", parameters: ["error": "file_not_found"])
            return
        }

        isSharing = true

        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        // Exclude some activity types if needed
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList
        ]

        activityViewController.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
            self?.isSharing = false

            if let error = error {
                self?.shareError = error.localizedDescription
                Analytics.track(event: "share_error", parameters: ["error": error.localizedDescription])
                return
            }

            if completed, let activityType = activityType {
                self?.recordShare(url: url, method: activityType.rawValue)
                Analytics.track(event: "document_shared", parameters: [
                    "method": activityType.rawValue,
                    "filename": url.lastPathComponent
                ])
            }
        }

        // Present from view controller or root window
        if let viewController = viewController {
            viewController.present(activityViewController, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }

    /// Share multiple documents
    func shareMultipleDocuments(_ urls: [URL], from viewController: UIViewController? = nil) {
        guard !urls.isEmpty else { return }

        let existingURLs = urls.filter { FileManager.default.fileExists(atPath: $0.path) }

        guard !existingURLs.isEmpty else {
            shareError = "No valid files to share"
            return
        }

        isSharing = true

        let activityViewController = UIActivityViewController(
            activityItems: existingURLs,
            applicationActivities: nil
        )

        activityViewController.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
            self?.isSharing = false

            if completed, let activityType = activityType {
                for url in existingURLs {
                    self?.recordShare(url: url, method: activityType.rawValue)
                }
                Analytics.track(event: "batch_share", parameters: [
                    "method": activityType.rawValue,
                    "count": existingURLs.count
                ])
            }
        }

        if let viewController = viewController {
            viewController.present(activityViewController, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }

    // MARK: - Email Sharing

    /// Share document via email
    func shareViaEmail(url: URL, from viewController: UIViewController) {
        guard MFMailComposeViewController.canSendMail() else {
            shareError = "Email is not configured on this device"
            Analytics.track(event: "email_share_unavailable")
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            shareError = "File not found"
            return
        }

        let mailComposer = MFMailComposeViewController()
        mailComposer.setSubject("Shared Document: \(url.lastPathComponent)")
        mailComposer.setMessageBody("Please find the attached document.", isHTML: false)

        // Attach the document
        if let fileData = try? Data(contentsOf: url) {
            let mimeType = getMimeType(for: url.pathExtension)
            mailComposer.addAttachmentData(fileData, mimeType: mimeType, fileName: url.lastPathComponent)
        }

        mailComposeDelegate = MailComposerDelegate { [weak self] result in
            if result == .sent {
                self?.recordShare(url: url, method: "email")
                Analytics.track(event: "email_shared", parameters: ["filename": url.lastPathComponent])
            } else if result == .failed {
                Analytics.track(event: "email_share_failed")
            }
        }

        mailComposer.mailComposeDelegate = mailComposeDelegate

        viewController.present(mailComposer, animated: true)
    }

    // MARK: - AirDrop

    /// Share document via AirDrop (uses native share sheet with AirDrop pre-selected if available)
    func shareViaAirDrop(url: URL, from viewController: UIViewController) {
        // AirDrop is handled through the native share sheet
        shareDocument(at: url, from: viewController)
    }

    // MARK: - Print

    /// Print a document
    func printDocument(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            shareError = "File not found"
            return
        }

        let printController = UIPrintInteractionController.shared

        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = url.lastPathComponent
        printInfo.outputType = .general

        printController.printInfo = printInfo
        printController.printingItem = url

        printController.present(animated: true) { [weak self] _, completed, error in
            if let error = error {
                self?.shareError = error.localizedDescription
                Analytics.track(event: "print_error", parameters: ["error": error.localizedDescription])
            } else if completed {
                self?.recordShare(url: url, method: "print")
                Analytics.track(event: "document_printed", parameters: ["filename": url.lastPathComponent])
            }
        }
    }

    // MARK: - Open In Other Apps

    /// Open document in another app
    func openInApp(url: URL, from viewController: UIViewController) {
        let documentController = UIDocumentInteractionController(url: url)
        documentController.delegate = self

        if documentController.presentOpenInMenu(from: .zero, in: viewController.view, animated: true) {
            recordShare(url: url, method: "open_in")
            Analytics.track(event: "opened_in_app", parameters: ["filename": url.lastPathComponent])
        } else {
            shareError = "No apps available to open this document"
            Analytics.track(event: "open_in_failed")
        }
    }

    /// Present options menu for a document
    func presentOptionsMenu(url: URL, from viewController: UIViewController) {
        let documentController = UIDocumentInteractionController(url: url)
        documentController.delegate = self

        if documentController.presentOptionsMenu(from: .zero, in: viewController.view, animated: true) {
            Analytics.track(event: "options_menu_presented")
        }
    }

    // MARK: - Share History

    private func recordShare(url: URL, method: String) {
        let entry = ShareHistoryEntry(
            id: UUID(),
            documentName: url.lastPathComponent,
            documentURL: url,
            shareMethod: method,
            shareDate: Date()
        )

        shareHistory.insert(entry, at: 0)

        // Keep only recent items
        if shareHistory.count > maxHistoryItems {
            shareHistory = Array(shareHistory.prefix(maxHistoryItems))
        }

        saveShareHistory()
    }

    private func loadShareHistory() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.shareHistory),
           let history = try? JSONDecoder().decode([ShareHistoryEntry].self, from: data) {
            shareHistory = history
        }
    }

    private func saveShareHistory() {
        if let data = try? JSONEncoder().encode(shareHistory) {
            UserDefaults.standard.set(data, forKey: StorageKeys.shareHistory)
        }
    }

    func clearShareHistory() {
        shareHistory.removeAll()
        saveShareHistory()
        Analytics.track(event: "share_history_cleared")
    }

    // MARK: - Helper Methods

    private func getMimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "txt":
            return "text/plain"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default:
            return "application/octet-stream"
        }
    }
}

// MARK: - UIDocumentInteractionControllerDelegate

extension ShareManager: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            return rootViewController
        }
        return UIViewController()
    }
}

// MARK: - Mail Composer Delegate

class MailComposerDelegate: NSObject, MFMailComposeViewControllerDelegate {
    private let completion: (MFMailComposeResult) -> Void

    init(completion: @escaping (MFMailComposeResult) -> Void) {
        self.completion = completion
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        completion(result)
        controller.dismiss(animated: true)
    }
}

// MARK: - Supporting Types

struct ShareHistoryEntry: Identifiable, Codable {
    let id: UUID
    let documentName: String
    let documentURL: URL
    let shareMethod: String
    let shareDate: Date

    var methodIcon: String {
        switch shareMethod.lowercased() {
        case let method where method.contains("mail"):
            return "envelope.fill"
        case let method where method.contains("airdrop"):
            return "airplayvideo"
        case "print":
            return "printer.fill"
        case let method where method.contains("message"):
            return "message.fill"
        case "open_in":
            return "square.and.arrow.up.fill"
        default:
            return "square.and.arrow.up"
        }
    }

    var methodDisplayName: String {
        switch shareMethod.lowercased() {
        case "email":
            return "Email"
        case "print":
            return "Print"
        case "open_in":
            return "Open In App"
        case let method where method.contains("airdrop"):
            return "AirDrop"
        case let method where method.contains("message"):
            return "Messages"
        default:
            return shareMethod.capitalized
        }
    }
}
