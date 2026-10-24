//
//  QuickActionsManager.swift
//  MyApp
//
//  Manages 3D Touch/Haptic Touch quick actions for quick document scanning.
//

import UIKit
import SwiftUI
import Combine

// MARK: - Quick Actions Manager

@MainActor
final class QuickActionsManager {
    static let shared = QuickActionsManager()

    // Quick action types
    enum QuickActionType: String {
        case scanDocument = "com.myapp.scan"
        case importDocument = "com.myapp.import"
        case searchDocuments = "com.myapp.search"
        case recentDocuments = "com.myapp.recent"

        var title: String {
            switch self {
            case .scanDocument: return "Scan Document"
            case .importDocument: return "Import Document"
            case .searchDocuments: return "Search"
            case .recentDocuments: return "Recent"
            }
        }

        var subtitle: String {
            switch self {
            case .scanDocument: return "Capture with camera"
            case .importDocument: return "From photos or files"
            case .searchDocuments: return "Find documents"
            case .recentDocuments: return "View recent documents"
            }
        }

        var icon: UIApplicationShortcutIcon {
            switch self {
            case .scanDocument:
                return UIApplicationShortcutIcon(systemImageName: "doc.text.viewfinder")
            case .importDocument:
                return UIApplicationShortcutIcon(systemImageName: "square.and.arrow.down")
            case .searchDocuments:
                return UIApplicationShortcutIcon(systemImageName: "magnifyingglass")
            case .recentDocuments:
                return UIApplicationShortcutIcon(systemImageName: "clock")
            }
        }
    }

    private init() {}

    // MARK: - Setup Quick Actions

    func setupQuickActions() {
        let actions = [
            createQuickAction(type: .scanDocument),
            createQuickAction(type: .importDocument),
            createQuickAction(type: .searchDocuments),
            createQuickAction(type: .recentDocuments)
        ]

        UIApplication.shared.shortcutItems = actions
        Analytics.track(event: "quick_actions_setup", parameters: ["count": actions.count])
    }

    private func createQuickAction(type: QuickActionType) -> UIApplicationShortcutItem {
        return UIApplicationShortcutItem(
            type: type.rawValue,
            localizedTitle: type.title,
            localizedSubtitle: type.subtitle,
            icon: type.icon,
            userInfo: nil
        )
    }

    // MARK: - Handle Quick Action

    func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> QuickActionType? {
        guard let actionType = QuickActionType(rawValue: shortcutItem.type) else {
            return nil
        }

        Analytics.track(event: "quick_action_used", parameters: ["action": actionType.rawValue])
        return actionType
    }

    // MARK: - Update Dynamic Actions

    /// Updates quick actions based on app state (e.g., add recent document if available)
    func updateDynamicActions(recentDocumentName: String? = nil) {
        var actions = [
            createQuickAction(type: .scanDocument),
            createQuickAction(type: .importDocument)
        ]

        // Add dynamic action for recent document if available
        if let documentName = recentDocumentName {
            let recentAction = UIApplicationShortcutItem(
                type: "com.myapp.open-recent",
                localizedTitle: "Open '\(documentName)'",
                localizedSubtitle: "Recently viewed",
                icon: UIApplicationShortcutIcon(systemImageName: "doc.text"),
                userInfo: ["documentName": documentName as NSSecureCoding]
            )
            actions.insert(recentAction, at: 0)
        }

        actions.append(createQuickAction(type: .searchDocuments))

        UIApplication.shared.shortcutItems = actions
    }
}

// MARK: - App Delegate Integration

extension QuickActionsManager {
    /// Call this from SceneDelegate to handle quick action
    func performQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let actionType = handleQuickAction(shortcutItem) else {
            return false
        }

        // Post notification that will be handled by the coordinator/root view
        NotificationCenter.default.post(
            name: .quickActionTriggered,
            object: nil,
            userInfo: ["actionType": actionType]
        )

        return true
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let quickActionTriggered = Notification.Name("quickActionTriggered")
}

// MARK: - Quick Action Coordinator

/// Coordinates handling quick actions in SwiftUI
@MainActor
class QuickActionCoordinator: ObservableObject {
    @Published var presentedAction: QuickActionsManager.QuickActionType?
    @Published var showScanner = false
    @Published var showImporter = false
    @Published var showSearch = false
    @Published var showRecents = false

    private var cancellable: Any?

    init() {
        // Listen for quick action notifications
        cancellable = NotificationCenter.default.addObserver(
            forName: .quickActionTriggered,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let actionType = notification.userInfo?["actionType"] as? QuickActionsManager.QuickActionType else {
                return
            }

            self?.handleAction(actionType)
        }
    }

    func handleAction(_ action: QuickActionsManager.QuickActionType) {
        presentedAction = action
        Haptics.medium()

        switch action {
        case .scanDocument:
            showScanner = true
        case .importDocument:
            showImporter = true
        case .searchDocuments:
            showSearch = true
        case .recentDocuments:
            showRecents = true
        }
    }

    func clearAction() {
        presentedAction = nil
        showScanner = false
        showImporter = false
        showSearch = false
        showRecents = false
    }
}

// MARK: - Usage in MyApp.swift

/*
 Add this to your main App struct:

 @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
 @StateObject private var quickActionCoordinator = QuickActionCoordinator()

 And modify MyApp.swift to include:

 .onAppear {
     QuickActionsManager.shared.setupQuickActions()
 }
 .sheet(isPresented: $quickActionCoordinator.showScanner) {
     ScanningInterfaceView()
 }
 .sheet(isPresented: $quickActionCoordinator.showImporter) {
     DocumentImportView()
 }
 // etc for other actions

 Add AppDelegate:

 class AppDelegate: NSObject, UIApplicationDelegate {
     func application(
         _ application: UIApplication,
         configurationForConnecting connectingSceneSession: UISceneSession,
         options: UIScene.ConnectionOptions
     ) -> UISceneConfiguration {
         let configuration = UISceneConfiguration(
             name: connectingSceneSession.configuration.name,
             sessionRole: connectingSceneSession.role
         )
         configuration.delegateClass = SceneDelegate.self
         return configuration
     }
 }

 class SceneDelegate: UIResponder, UIWindowSceneDelegate {
     func windowScene(
         _ windowScene: UIWindowScene,
         performActionFor shortcutItem: UIApplicationShortcutItem,
         completionHandler: @escaping (Bool) -> Void
     ) {
         let handled = QuickActionsManager.shared.performQuickAction(shortcutItem)
         completionHandler(handled)
     }
 }
*/
