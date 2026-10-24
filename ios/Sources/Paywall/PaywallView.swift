//
//  PaywallView.swift
//  MyApp
//
//  Compelling paywall UI with feature comparison for document scanner app.
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PricingPlan = .yearly
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.3), radius: 10)

                        Text("Upgrade to Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Unlock unlimited scanning and premium features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    // Feature comparison
                    FeatureComparisonView()

                    // Pricing plans
                    VStack(spacing: 12) {
                        PricingPlanCard(
                            plan: .yearly,
                            isSelected: selectedPlan == .yearly,
                            onSelect: {
                                selectedPlan = .yearly
                                Haptics.light()
                            }
                        )

                        PricingPlanCard(
                            plan: .monthly,
                            isSelected: selectedPlan == .monthly,
                            onSelect: {
                                selectedPlan = .monthly
                                Haptics.light()
                            }
                        )
                    }
                    .padding(.horizontal)

                    // Subscribe button
                    Button {
                        subscribe()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        } else {
                            Text("Start Free Trial")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        }
                    }
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                    .disabled(isLoading)
                    .padding(.horizontal)

                    // Fine print
                    VStack(spacing: 8) {
                        Text("7-day free trial, then \(selectedPlan.price)/\(selectedPlan.period)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Cancel anytime • No commitment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Restore purchases
                    Button {
                        restorePurchases()
                    } label: {
                        Text("Restore Purchases")
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task {
            Analytics.trackScreenView("Paywall")
        }
    }

    private func subscribe() {
        isLoading = true
        Haptics.medium()

        // Integrate with PaywallManager/RevenueCat
        Task {
            do {
                try await PaywallManager.shared.purchase()
                Analytics.track(event: "subscription_purchased", parameters: ["plan": selectedPlan.rawValue])
                dismiss()
            } catch {
                Analytics.track(event: "subscription_failed", parameters: ["error": error.localizedDescription])
                isLoading = false
            }
        }
    }

    private func restorePurchases() {
        Task {
            try? await PaywallManager.shared.restorePurchases()
            Analytics.track(event: "purchases_restored")
        }
    }
}

// MARK: - Feature Comparison

struct FeatureComparisonView: View {
    let proFeatures: [(icon: String, title: String, description: String)] = [
        ("infinity", "Unlimited Scans", "Scan as many documents as you need"),
        ("arrow.triangle.2.circlepath", "Unlimited Conversions", "Convert between any formats"),
        ("square.stack.3d.up", "Batch Processing", "Process multiple files at once"),
        ("photo.badge.arrow.down", "High-Res Exports", "Export in highest quality"),
        ("icloud", "Cloud Backup", "Sync across all your devices"),
        ("wand.and.stars.inverse", "Advanced Editing", "Professional annotation tools"),
        ("text.viewfinder", "Full OCR", "All languages supported"),
        ("bolt.fill", "Priority Processing", "Skip the queue")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pro Features")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(proFeatures, id: \.title) { feature in
                    PaywallFeatureCard(
                        icon: feature.icon,
                        title: feature.title,
                        description: feature.description
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct PaywallFeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Pricing Plan Card

enum PricingPlan: String {
    case monthly = "Monthly"
    case yearly = "Yearly"

    var price: String {
        switch self {
        case .monthly: return "$9.99"
        case .yearly: return "$59.99"
        }
    }

    var period: String {
        switch self {
        case .monthly: return "month"
        case .yearly: return "year"
        }
    }

    var savings: String? {
        switch self {
        case .monthly: return nil
        case .yearly: return "Save 50%"
        }
    }

    var perMonth: String? {
        switch self {
        case .monthly: return nil
        case .yearly: return "$4.99/month"
        }
    }
}

struct PricingPlanCard: View {
    let plan: PricingPlan
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.rawValue)
                            .font(.headline)

                        if let savings = plan.savings {
                            Text(savings)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    if let perMonth = plan.perMonth {
                        Text(perMonth)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("per \(plan.period)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
}
