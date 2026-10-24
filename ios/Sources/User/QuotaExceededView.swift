//
//  QuotaExceededView.swift
//  MyApp
//
//  Alert shown when user exceeds their free tier quota.
//

import SwiftUI

struct QuotaExceededView: View {
    let quotaType: QuotaType
    @Environment(\.dismiss) private var dismiss

    enum QuotaType {
        case scans
        case conversions

        var title: String {
            switch self {
            case .scans: return "Daily Scan Limit Reached"
            case .conversions: return "Weekly Conversion Limit Reached"
            }
        }

        var message: String {
            switch self {
            case .scans: return "You've used all 5 scans for today. Upgrade to Pro for unlimited scanning!"
            case .conversions: return "You've used all 3 conversions this week. Upgrade to Pro for unlimited conversions!"
            }
        }

        var icon: String {
            switch self {
            case .scans: return "doc.text.viewfinder"
            case .conversions: return "arrow.triangle.2.circlepath"
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: quotaType.icon)
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }

            // Message
            VStack(spacing: 12) {
                Text(quotaType.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(quotaType.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Reset info
            if quotaType == .scans {
                Text("Resets tomorrow at midnight")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Resets next Monday")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // CTA buttons
            VStack(spacing: 12) {
                Button {
                    upgradeNow()
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Upgrade to Pro")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .task {
            Analytics.track(event: "quota_exceeded_shown", parameters: ["type": quotaType == .scans ? "scans" : "conversions"])
        }
    }

    private func upgradeNow() {
        Haptics.medium()
        PaywallManager.shared.triggerPaywall()
        dismiss()
    }
}

#Preview("Scans") {
    QuotaExceededView(quotaType: .scans)
}

#Preview("Conversions") {
    QuotaExceededView(quotaType: .conversions)
}
