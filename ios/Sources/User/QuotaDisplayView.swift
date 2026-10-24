//
//  QuotaDisplayView.swift
//  MyApp
//
//  Displays quota usage and limits for free tier users.
//

import SwiftUI

struct QuotaDisplayView: View {
    @ObservedObject var quotaManager = QuotaManager.shared
    @State private var showUpgradeSheet = false

    var body: some View {
        VStack(spacing: 16) {
            if !quotaManager.isPro {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Free Plan")
                            .font(.headline)
                        Text("Upgrade to unlock unlimited access")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        showUpgradeSheet = true
                        Haptics.light()
                    } label: {
                        Text("Upgrade")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                }

                Divider()

                // Scans quota
                QuotaRow(
                    icon: "doc.text.viewfinder",
                    title: "Daily Scans",
                    used: quotaManager.dailyScansUsed,
                    limit: QuotaManager.Limits.dailyScans,
                    color: .blue
                )

                // Conversions quota
                QuotaRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Weekly Conversions",
                    used: quotaManager.weeklyConversionsUsed,
                    limit: QuotaManager.Limits.weeklyConversions,
                    color: .purple
                )

                // Reset info
                Text("Resets daily at midnight")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Pro badge
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Pro Member")
                        .font(.headline)
                    Spacer()
                    Text("Unlimited")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    LinearGradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showUpgradeSheet) {
            PaywallView()
        }
    }
}

struct QuotaRow: View {
    let icon: String
    let title: String
    let used: Int
    let limit: Int
    let color: Color

    var percentage: Double {
        Double(used) / Double(limit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(used) / \(limit)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(used >= limit ? .red : .primary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: used >= limit ? [.red, .orange] : [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(percentage, 1.0), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    ScrollView {
        QuotaDisplayView()
            .padding()
    }
}
