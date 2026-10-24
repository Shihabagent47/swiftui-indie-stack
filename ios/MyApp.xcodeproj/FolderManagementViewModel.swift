//
//  FolderManagementViewModel.swift
//  MyApp
//
//  View model for folder management operations.
//

import Foundation
import SwiftUI

@MainActor
class FolderManagementViewModel: ObservableObject {
    
    @Published var folders: [DocumentFolder] = []
    @Published var isLoading = false
    @Published var error: DocumentError?
    
    // MARK: - Loading
    
    func loadFolders(_ allFolders: [DocumentFolder]) {
        folders = allFolders
    }
    
    // MARK: - Hierarchy Operations
    
    func getRootFolders() -> [DocumentFolder] {
        folders.filter { $0.parentFolder == nil && !$0.isSmartFolder }
    }
    
    func getSmartFolders() -> [DocumentFolder] {
        folders.filter { $0.isSmartFolder }
    }
    
    func getSubfolders(of folder: DocumentFolder) -> [DocumentFolder] {
        folder.subfolders
    }
    
    func getPath(to folder: DocumentFolder) -> [DocumentFolder] {
        var path: [DocumentFolder] = [folder]
        var current = folder
        
        while let parent = current.parentFolder {
            path.insert(parent, at: 0)
            current = parent
        }
        
        return path
    }
    
    // MARK: - Folder Operations
    
    func createFolder(
        name: String,
        parent: DocumentFolder? = nil,
        icon: String? = nil,
        colorLabel: ColorLabel? = nil
    ) -> DocumentFolder {
        let folder = DocumentFolder(
            name: name,
            icon: icon,
            colorLabel: colorLabel
        )
        
        folder.parentFolder = parent
        
        Analytics.track(event: "folder_created", properties: [
            "has_parent": parent != nil,
            "has_icon": icon != nil,
            "has_color": colorLabel != nil
        ])
        
        return folder
    }
    
    func createSmartFolder(
        name: String,
        icon: String? = nil,
        colorLabel: ColorLabel? = nil,
        rules: [String: String]
    ) -> DocumentFolder {
        let folder = DocumentFolder(
            name: name,
            icon: icon,
            colorLabel: colorLabel,
            isSmartFolder: true
        )
        
        folder.smartFolderRules = rules
        
        Analytics.track(event: "smart_folder_created", properties: [
            "rule_count": rules.count
        ])
        
        return folder
    }
    
    func moveFolder(_ folder: DocumentFolder, to newParent: DocumentFolder?) {
        // Prevent circular references
        if let newParent = newParent {
            var current: DocumentFolder? = newParent
            while current != nil {
                if current?.id == folder.id {
                    error = .processingFailed(reason: "Cannot move folder into itself or its subfolder")
                    return
                }
                current = current?.parentFolder
            }
        }
        
        folder.parentFolder = newParent
        folder.modifiedAt = Date()
        
        Analytics.track(event: "folder_moved", properties: [
            "has_new_parent": newParent != nil
        ])
    }
    
    func renameFolder(_ folder: DocumentFolder, to newName: String) {
        folder.name = newName
        folder.modifiedAt = Date()
        
        Analytics.track(event: "folder_renamed")
    }
    
    func deleteFolder(_ folder: DocumentFolder, moveDocumentsTo: DocumentFolder? = nil) {
        // Move documents if needed
        if let destination = moveDocumentsTo {
            for document in folder.documents {
                document.folder = destination
            }
        }
        
        // Move subfolders to parent
        if let parent = folder.parentFolder {
            for subfolder in folder.subfolders {
                subfolder.parentFolder = parent
            }
        }
        
        Analytics.track(event: "folder_deleted", properties: [
            "is_smart": folder.isSmartFolder,
            "had_documents": folder.documentCount > 0,
            "had_subfolders": !folder.subfolders.isEmpty
        ])
    }
    
    // MARK: - Smart Folder Evaluation
    
    func evaluateSmartFolder(_ folder: DocumentFolder, allDocuments: [Document]) -> [Document] {
        guard folder.isSmartFolder,
              let rules = folder.smartFolderRules else {
            return []
        }
        
        // TODO: Implement rule evaluation
        // For now, return empty array
        return []
    }
    
    // MARK: - Statistics
    
    func getTotalDocumentCount() -> Int {
        folders.reduce(0) { $0 + $1.documentCount }
    }
    
    func getTotalSize() -> Int64 {
        folders.reduce(0) { $0 + $1.totalSize }
    }
    
    func getFolderStatistics(_ folder: DocumentFolder) -> FolderStatistics {
        FolderStatistics(
            documentCount: folder.documentCount,
            totalSize: folder.totalSize,
            subfolderCount: folder.subfolders.count,
            averageFileSize: folder.documentCount > 0 ? folder.totalSize / Int64(folder.documentCount) : 0
        )
    }
}

// MARK: - Statistics

struct FolderStatistics {
    let documentCount: Int
    let totalSize: Int64
    let subfolderCount: Int
    let averageFileSize: Int64
}
