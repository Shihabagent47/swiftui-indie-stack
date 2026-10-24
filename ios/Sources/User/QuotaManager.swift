//
//  QuotaManager.swift
//  MyApp
//
//  Manages usage quotas for free tier users and Pro subscription checks.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class QuotaManager: ObservableObject {
    static let shared = QuotaManager()

    // MARK: - Published Properties

    @Published var dailyScansUsed: Int = 0
    @Published var weeklyConversionsUsed: Int = 0
    @Published var lastResetDate: Date = Date()
    @Published var lastConversionResetDate: Date = Date()

    // MARK: - Free Tier Limits

    struct Limits {
        static let dailyScans = 5
        static let weeklyConversions = 3
    }

    // MARK: - Storage Keys

    private enum StorageKeys {
        static let dailyScansUsed = "quotaDailyScansUsed"
        static let weeklyConversionsUsed = "quotaWeeklyConversionsUsed"
        static let lastResetDate = "quotaLastResetDate"
        static let lastConversionResetDate = "quotaLastConversionResetDate"
    }

    private init() {
        loadQuotaData()
        checkAndResetQuotas()
    }

    // MARK: - Pro Status Check

    var isPro: Bool {
        // Check RevenueCat subscription status
        #if canImport(RevenueCat)
        return PaywallManager.shared.isSubscribed
        #else
        return false
        #endif
    }

    // MARK: - Quota Checks

    var canScan: Bool {
        if isPro { return true }
        return dailyScansUsed < Limits.dailyScans
    }

    var canConvert: Bool {
        if isPro { return true }
        return weeklyConversionsUsed < Limits.weeklyConversions
    }

    var scansRemaining: Int {
        if isPro { return -1 } // Unlimited
        return max(0, Limits.dailyScans - dailyScansUsed)
    }

    var conversionsRemaining: Int {
        if isPro { return -1 } // Unlimited
        return max(0, Limits.weeklyConversions - weeklyConversionsUsed)
    }

    var scanLimitReached: Bool {
        !isPro && dailyScansUsed >= Limits.dailyScans
    }

    var conversionLimitReached: Bool {
        !isPro && weeklyConversionsUsed >= Limits.weeklyConversions
    }

    // MARK: - Usage Tracking

    func recordScan() {
        guard !isPro else { return }

        checkAndResetQuotas()
        dailyScansUsed += 1
        saveQuotaData()

        Analytics.track(event: "quota_scan_used", parameters: [
            "scans_used": dailyScansUsed,
            "scans_remaining": scansRemaining,
            "is_pro": isPro
        ])

        if scanLimitReached {
            Analytics.track(event: "quota_scan_limit_reached")
        }
    }

    func recordConversion() {
        guard !isPro else { return }

        checkAndResetQuotas()
        weeklyConversionsUsed += 1
        saveQuotaData()

        Analytics.track(event: "quota_conversion_used", parameters: [
            "conversions_used": weeklyConversionsUsed,
            "conversions_remaining": conversionsRemaining,
            "is_pro": isPro
        ])

        if conversionLimitReached {
            Analytics.track(event: "quota_conversion_limit_reached")
        }
    }

    // MARK: - Reset Logic

    func checkAndResetQuotas() {
        let calendar = Calendar.current

        // Reset daily scans if it's a new day
        if !calendar.isDateInToday(lastResetDate) {
            dailyScansUsed = 0
            lastResetDate = Date()
            saveQuotaData()
            Analytics.track(event: "quota_daily_reset")
        }

        // Reset weekly conversions if it's a new week
        let lastWeek = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: lastConversionResetDate)
        let currentWeek = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: Date())

        if lastWeek.weekOfYear != currentWeek.weekOfYear || lastWeek.yearForWeekOfYear != currentWeek.yearForWeekOfYear {
            weeklyConversionsUsed = 0
            lastConversionResetDate = Date()
            saveQuotaData()
            Analytics.track(event: "quota_weekly_reset")
        }
    }

    // MARK: - Persistence

    private func loadQuotaData() {
        dailyScansUsed = UserDefaults.standard.integer(forKey: StorageKeys.dailyScansUsed)
        weeklyConversionsUsed = UserDefaults.standard.integer(forKey: StorageKeys.weeklyConversionsUsed)

        if let lastReset = UserDefaults.standard.object(forKey: StorageKeys.lastResetDate) as? Date {
            lastResetDate = lastReset
        }

        if let lastConversionReset = UserDefaults.standard.object(forKey: StorageKeys.lastConversionResetDate) as? Date {
            lastConversionResetDate = lastConversionReset
        }
    }

    private func saveQuotaData() {
        UserDefaults.standard.set(dailyScansUsed, forKey: StorageKeys.dailyScansUsed)
        UserDefaults.standard.set(weeklyConversionsUsed, forKey: StorageKeys.weeklyConversionsUsed)
        UserDefaults.standard.set(lastResetDate, forKey: StorageKeys.lastResetDate)
        UserDefaults.standard.set(lastConversionResetDate, forKey: StorageKeys.lastConversionResetDate)
    }

    // MARK: - Usage Statistics

    func getUsageStats() -> UsageStats {
        UsageStats(
            dailyScansUsed: dailyScansUsed,
            dailyScansLimit: Limits.dailyScans,
            weeklyConversionsUsed: weeklyConversionsUsed,
            weeklyConversionsLimit: Limits.weeklyConversions,
            isPro: isPro,
            lastResetDate: lastResetDate,
            nextResetDate: nextDailyResetDate()
        )
    }

    private func nextDailyResetDate() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        return calendar.startOfDay(for: tomorrow)
    }
}

// MARK: - Usage Stats Model

struct UsageStats {
    let dailyScansUsed: Int
    let dailyScansLimit: Int
    let weeklyConversionsUsed: Int
    let weeklyConversionsLimit: Int
    let isPro: Bool
    let lastResetDate: Date
    let nextResetDate: Date

    var scansRemainingText: String {
        if isPro {
            return "Unlimited"
        }
        let remaining = max(0, dailyScansLimit - dailyScansUsed)
        return "\(remaining) of \(dailyScansLimit)"
    }

    var conversionsRemainingText: String {
        if isPro {
            return "Unlimited"
        }
        let remaining = max(0, weeklyConversionsLimit - weeklyConversionsUsed)
        return "\(remaining) of \(weeklyConversionsLimit)"
    }

    var scanPercentageUsed: Double {
        if isPro { return 0 }
        return Double(dailyScansUsed) / Double(dailyScansLimit)
    }

    var conversionPercentageUsed: Double {
        if isPro { return 0 }
        return Double(weeklyConversionsUsed) / Double(weeklyConversionsLimit)
    }
}
