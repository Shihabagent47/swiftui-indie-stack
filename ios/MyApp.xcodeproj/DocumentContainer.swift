//
//  DocumentContainer.swift
//  MyApp
//
//  SwiftData container setup for document management.
//

import Foundation
import SwiftData

/// Manages the SwiftData model container for documents
@MainActor
class DocumentContainer {
    
    static let shared = DocumentContainer()
    
    let container: ModelContainer
    
    private init() {
        let schema = Schema([
            Document.self,
            ScanPage.self,
            DocumentFolder.self,
            ScanSession.self,
            ConversionJob.self,
            UserPreferences.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            
            // Create default folders and preferences on first launch
            createDefaultDataIfNeeded()
            
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    /// Creates default folders and preferences if they don't exist
    private func createDefaultDataIfNeeded() {
        let context = container.mainContext
        
        // Check if preferences exist
        let preferencesFetch = FetchDescriptor<UserPreferences>()
        let existingPreferences = (try? context.fetch(preferencesFetch)) ?? []
        
        if existingPreferences.isEmpty {
            let preferences = UserPreferences()
            context.insert(preferences)
            
            do {
                try context.save()
                debugPrint("✅ Created default user preferences")
            } catch {
                debugPrint("❌ Failed to create default preferences: \(error)")
            }
        }
        
        // Check if default folders exist
        let foldersFetch = FetchDescriptor<DocumentFolder>()
        let existingFolders = (try? context.fetch(foldersFetch)) ?? []
        
        if existingFolders.isEmpty {
            // Create default folder structure
            let folders = [
                DocumentFolder(name: "All Documents", icon: "folder.fill"),
                DocumentFolder(name: "Scans", icon: "doc.text.viewfinder"),
                DocumentFolder(name: "Favorites", icon: "star.fill", colorLabel: .yellow, isSmartFolder: true),
                DocumentFolder(name: "Recent", icon: "clock.fill", isSmartFolder: true)
            ]
            
            for folder in folders {
                context.insert(folder)
            }
            
            do {
                try context.save()
                debugPrint("✅ Created default folder structure")
            } catch {
                debugPrint("❌ Failed to create default folders: \(error)")
            }
        }
    }
    
    /// Get the main context for UI operations
    var mainContext: ModelContext {
        container.mainContext
    }
    
    /// Create a background context for heavy operations
    func backgroundContext() -> ModelContext {
        ModelContext(container)
    }
}
