//
//  DocumentOnboardingView.swift
//  MyApp
//
//  Onboarding flow specifically designed for the document scanning and management app.
//

import SwiftUI
import Combine

// MARK: - Document Onboarding View

struct DocumentOnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss

    let pages: [DocumentOnboardingPage] = [
        DocumentOnboardingPage(
            icon: "doc.text.viewfinder",
            iconColor: .blue,
            title: "Scan Documents",
            subtitle: "Instantly digitize receipts, contracts, notes, and more",
            features: [
                "Auto edge detection",
                "Multi-page scanning",
                "High-quality OCR"
            ]
        ),
        DocumentOnboardingPage(
            icon: "rectangle.stack",
            iconColor: .green,
            title: "Organize & Search",
            subtitle: "Keep all your documents organized and easily searchable",
            features: [
                "Smart folders",
                "Tags and labels",
                "Full-text search"
            ]
        ),
        DocumentOnboardingPage(
            icon: "wand.and.stars",
            iconColor: .purple,
            title: "Edit & Convert",
            subtitle: "Powerful tools to edit, annotate, and convert documents",
            features: [
                "PDF annotations",
                "Format conversion",
                "Compression & optimization"
            ]
        ),
        DocumentOnboardingPage(
            icon: "lock.shield",
            iconColor: .orange,
            title: "Secure & Private",
            subtitle: "Your documents stay private and secure on your device",
            features: [
                "Password protection",
                "Encryption",
                "Offline-first design"
            ]
        )
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    pages[currentPage].iconColor.opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .foregroundColor(.secondary)
                        .padding()
                    }
                }

                Spacer()

                // Onboarding pages
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        DocumentOnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                Spacer()

                // Page indicator and buttons
                VStack(spacing: 24) {
                    // Custom page indicator
                    HStack(spacing: 8) {
                        ForEach(pages.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? pages[currentPage].iconColor : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.spring(), value: currentPage)
                        }
                    }

                    // Action button
                    if currentPage < pages.count - 1 {
                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                            Haptics.light()
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(pages[currentPage].iconColor)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 32)
                    } else {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [pages[currentPage].iconColor, pages[currentPage].iconColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: pages[currentPage].iconColor.opacity(0.3), radius: 10, y: 5)
                        }
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .interactiveDismissDisabled()
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        Haptics.success()
        Analytics.track(event: "onboarding_completed", parameters: ["last_page_viewed": currentPage])
        dismiss()
    }
}

// MARK: - Onboarding Page Model

struct DocumentOnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let features: [String]
}

// MARK: - Onboarding Page View

struct DocumentOnboardingPageView: View {
    let page: DocumentOnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            // Icon
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.15))
                    .frame(width: 140, height: 140)

                Image(systemName: page.icon)
                    .font(.system(size: 64))
                    .foregroundColor(page.iconColor)
            }
            .padding(.top, 20)

            // Title and subtitle
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                ForEach(page.features, id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(page.iconColor)
                            .font(.title3)

                        Text(feature)
                            .font(.body)
                    }
                }
            }
            .padding(.horizontal, 48)
        }
        .padding(.vertical)
    }
}

// MARK: - Permissions Onboarding

struct PermissionsOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPermissionGranted = false
    @State private var notificationsPermissionGranted = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 140, height: 140)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
            }

            // Title
            VStack(spacing: 12) {
                Text("Enable Permissions")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("To get the most out of the app, we need a couple of permissions")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Permission cards
            VStack(spacing: 16) {
                PermissionCard(
                    icon: "camera.fill",
                    iconColor: .blue,
                    title: "Camera Access",
                    description: "Required to scan documents",
                    isGranted: $cameraPermissionGranted,
                    onRequest: {
                        requestCameraPermission()
                    }
                )

                PermissionCard(
                    icon: "bell.fill",
                    iconColor: .orange,
                    title: "Notifications",
                    description: "Get updates on processing and conversions",
                    isGranted: $notificationsPermissionGranted,
                    onRequest: {
                        requestNotificationPermission()
                    }
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Continue button
            Button {
                dismiss()
                Haptics.success()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private func requestCameraPermission() {
        // Request camera permission
        Haptics.light()
        // Implementation would use AVCaptureDevice.requestAccess
        cameraPermissionGranted = true
        Analytics.track(event: "camera_permission_requested")
    }

    private func requestNotificationPermission() {
        // Request notification permission
        Haptics.light()
        // Implementation would use UNUserNotificationCenter
        notificationsPermissionGranted = true
        Analytics.track(event: "notification_permission_requested")
    }
}

// MARK: - Permission Card

struct PermissionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    @Binding var isGranted: Bool
    let onRequest: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title2)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status/Action
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("Enable") {
                    onRequest()
                }
                .buttonStyle(.borderedProminent)
                .tint(iconColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Feature Walkthrough

struct FeatureWalkthroughView: View {
    let feature: WalkthroughFeature
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero image or animation
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(feature.color.opacity(0.15))
                            .frame(height: 250)

                        Image(systemName: feature.icon)
                            .font(.system(size: 80))
                            .foregroundColor(feature.color)
                    }
                    .padding()

                    // Title and description
                    VStack(spacing: 16) {
                        Text(feature.title)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(feature.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    // Steps
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(feature.steps.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(feature.color)
                                        .frame(width: 32, height: 32)

                                    Text("\(index + 1)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(feature.steps[index])
                                        .font(.body)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("How to Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WalkthroughFeature {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let steps: [String]
}

// MARK: - Preview

#Preview("Onboarding") {
    DocumentOnboardingView()
}

#Preview("Permissions") {
    PermissionsOnboardingView()
}

#Preview("Walkthrough") {
    FeatureWalkthroughView(
        feature: WalkthroughFeature(
            icon: "doc.text.viewfinder",
            color: .blue,
            title: "Scanning Documents",
            description: "Learn how to scan and digitize your documents",
            steps: [
                "Tap the scan button in the toolbar",
                "Position your document within the frame",
                "The app will auto-detect edges and capture",
                "Review and adjust if needed, then save"
            ]
        )
    )
}
