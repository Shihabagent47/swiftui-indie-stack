//
//  MemoryManager.swift
//  MyApp
//
//  Manages memory pressure monitoring and optimization.
//

import Foundation
import UIKit

/// Monitors and manages app memory usage
@MainActor
class MemoryManager: ObservableObject {
    
    static let shared = MemoryManager()
    
    @Published var memoryPressure: MemoryPressureLevel = .normal
    @Published var currentMemoryUsage: UInt64 = 0
    
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryPressureMonitoring()
        setupMemoryWarningObserver()
        updateMemoryUsage()
    }
    
    deinit {
        memoryPressureSource?.cancel()
    }
    
    // MARK: - Memory Pressure Monitoring
    
    private func setupMemoryPressureMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let event = source.data
            
            if event.contains(.critical) {
                self.handleMemoryPressure(.critical)
            } else if event.contains(.warning) {
                self.handleMemoryPressure(.warning)
            }
        }
        
        source.resume()
        memoryPressureSource = source
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryPressure(.critical)
        }
    }
    
    private func handleMemoryPressure(_ level: MemoryPressureLevel) {
        memoryPressure = level
        
        debugPrint("⚠️ Memory pressure: \(level.rawValue)")
        
        // Notify interested parties
        NotificationCenter.default.post(
            name: .memoryPressureChanged,
            object: nil,
            userInfo: ["level": level]
        )
        
        // Clear caches based on pressure level
        Task {
            await clearCachesForMemoryPressure(level)
        }
        
        Analytics.track(event: "memory_pressure", properties: [
            "level": level.rawValue,
            "usage_mb": Int(currentMemoryUsage / 1024 / 1024)
        ])
    }
    
    private func clearCachesForMemoryPressure(_ level: MemoryPressureLevel) async {
        switch level {
        case .normal:
            break
            
        case .warning:
            // Clear preview cache, keep thumbnails
            DocumentCacheManager.shared.previewCache.removeAllObjects()
            debugPrint("🧹 Cleared preview cache due to memory warning")
            
        case .critical:
            // Clear all memory caches
            DocumentCacheManager.shared.clearMemoryCaches()
            
            // Also cleanup temp files
            await DocumentFileManager.shared.cleanupTempFiles()
            
            debugPrint("🧹 Cleared all caches due to critical memory pressure")
        }
    }
    
    // MARK: - Memory Usage Tracking
    
    func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        if result == KERN_SUCCESS {
            currentMemoryUsage = info.resident_size
        }
    }
    
    /// Get formatted memory usage string
    func getFormattedMemoryUsage() -> String {
        updateMemoryUsage()
        let mb = Double(currentMemoryUsage) / 1024 / 1024
        return String(format: "%.1f MB", mb)
    }
    
    /// Get memory usage in MB
    func getMemoryUsageMB() -> Double {
        updateMemoryUsage()
        return Double(currentMemoryUsage) / 1024 / 1024
    }
    
    /// Check if memory usage is high
    func isMemoryUsageHigh() -> Bool {
        updateMemoryUsage()
        let usageMB = getMemoryUsageMB()
        
        // Consider high if over 500 MB (adjust based on device)
        return usageMB > 500
    }
}

// MARK: - Memory Pressure Level

enum MemoryPressureLevel: String {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
}

// MARK: - Notification Names

extension Notification.Name {
    static let memoryPressureChanged = Notification.Name("memoryPressureChanged")
}
