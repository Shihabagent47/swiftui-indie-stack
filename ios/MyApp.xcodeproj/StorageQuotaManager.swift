//
//  StorageQuotaManager.swift
//  MyApp
//
//  Monitors storage usage and enforces storage limits.
//

import Foundation

/// Manages storage quota and monitoring
@MainActor
class StorageQuotaManager: ObservableObject {
    
    static let shared = StorageQuotaManager()
    
    @Published var currentUsage: Int64 = 0
    @Published var availableSpace: Int64 = 0
    @Published var isNearLimit: Bool = false
    
    private let fileManager = DocumentFileManager.shared
    
    // Storage limits (can be overridden by Pro subscription)
    private let freeStorageLimit: Int64 = 500 * 1024 * 1024 // 500 MB for free tier
    private let warningThreshold: Double = 0.8 // 80%
    
    private init() {
        Task {
            await updateStorageInfo()
        }
    }
    
    // MARK: - Storage Monitoring
    
    /// Update storage information
    func updateStorageInfo() async {
        do {
            currentUsage = try await fileManager.getTotalDocumentsSize()
            availableSpace = await fileManager.getAvailableStorage()
            
            // Check if near limit
            let usagePercentage = Double(currentUsage) / Double(storageLimit)
            isNearLimit = usagePercentage >= warningThreshold
            
            if isNearLimit {
                debugPrint("⚠️ Storage usage at \(Int(usagePercentage * 100))%")
            }
        } catch {
            debugPrint("❌ Failed to update storage info: \(error)")
        }
    }
    
    /// Check if there's enough space for a new file
    func canStoreFile(size: Int64) async -> Bool {
        await updateStorageInfo()
        
        let afterAddition = currentUsage + size
        return afterAddition <= storageLimit && await fileManager.hasAvailableStorage(requiredBytes: size)
    }
    
    /// Get storage limit based on subscription status
    var storageLimit: Int64 {
        // TODO: Check Pro subscription status from UserPreferences
        // For now, return free tier limit
        return freeStorageLimit
    }
    
    /// Get storage usage percentage
    var usagePercentage: Double {
        guard storageLimit > 0 else { return 0 }
        return Double(currentUsage) / Double(storageLimit)
    }
    
    /// Get remaining storage
    var remainingStorage: Int64 {
        max(0, storageLimit - currentUsage)
    }
    
    // MARK: - Storage Analytics
    
    /// Get formatted storage strings
    func getFormattedUsage() -> (used: String, total: String, percentage: String) {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        let used = formatter.string(fromByteCount: currentUsage)
        let total = formatter.string(fromByteCount: storageLimit)
        let percentage = String(format: "%.1f%%", usagePercentage * 100)
        
        return (used, total, percentage)
    }
    
    /// Track storage event
    func trackStorageEvent(_ event: StorageEvent) {
        Analytics.track(event: "storage_\(event.rawValue)", properties: [
            "current_usage": currentUsage,
            "storage_limit": storageLimit,
            "usage_percentage": usagePercentage
        ])
    }
}

// MARK: - Storage Events

enum StorageEvent: String {
    case nearLimit = "near_limit"
    case limitReached = "limit_reached"
    case cleanupPerformed = "cleanup_performed"
    case upgraded = "upgraded"
}
