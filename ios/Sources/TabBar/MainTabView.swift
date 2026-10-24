//
//  MainTabView.swift
//  MyApp
//
//  Custom tab bar with styled icons and content switching.
//

import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Content views - keep all views alive to preserve state
            ZStack {
                HomeView()
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)

                LibraryView()
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)

                SettingsView()
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)
            }

            // Tab bar separator
            Divider()

            // Custom Tab bar
            HStack {
                Spacer(minLength: 0)

                TabBarIcon(
                    selectedTab: $selectedTab,
                    assignedTab: 0,
                    systemIconName: "house.fill",
                    tabName: "Home",
                    color: AppColors.tabHome
                )

                Spacer(minLength: 0)

                TabBarIcon(
                    selectedTab: $selectedTab,
                    assignedTab: 1,
                    systemIconName: "doc.on.doc.fill",
                    tabName: "Documents",
                    color: AppColors.tabLibrary
                )

                Spacer(minLength: 0)

                TabBarIcon(
                    selectedTab: $selectedTab,
                    assignedTab: 2,
                    systemIconName: "gearshape.fill",
                    tabName: "Settings",
                    color: AppColors.tabSettings
                )

                Spacer(minLength: 0)
            }
            .background(AppColors.backgroundPrimary)
            .padding(.bottom, 5)
        }
        .task {
            Analytics.trackScreenView("MainTabView")

            // Mark app usage for streak tracking
            SettingsViewModel.shared.markAppUsage()
        }
        .withPaywall()
    }
}

// MARK: - Placeholder Views (Replace with your implementations)

struct HomeView: View {
    @State private var showScanner = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .padding(.top)

                        Text("Document Scanner")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Scan, organize, and manage your documents")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    // Quick Actions
                    VStack(spacing: 16) {
                        // Scan Document
                        Button {
                            showScanner = true
                            Haptics.medium()
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.title2)
                                    .frame(width: 32)
                                Text("Scan Document")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        // Show Onboarding
                        Button {
                            showOnboarding = true
                            Haptics.light()
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.title2)
                                    .frame(width: 32)
                                Text("App Tutorial")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                            .padding(.horizontal)

                        FeatureCard(icon: "camera.viewfinder", title: "Smart Scanning", description: "Auto edge detection and enhancement")
                        FeatureCard(icon: "wand.and.stars", title: "PDF Editing", description: "Annotate, merge, and organize PDFs")
                        FeatureCard(icon: "text.viewfinder", title: "OCR Text Recognition", description: "Extract text from any document")
                        FeatureCard(icon: "arrow.up.arrow.down", title: "Format Conversion", description: "Convert between PDF, images, and more")
                    }

                    Spacer(minLength: 20)
                }
                .padding(.bottom)
            }
            .navigationTitle("Home")
        }
        .sheet(isPresented: $showScanner) {
            ScanningInterfaceView()
        }
        .sheet(isPresented: $showOnboarding) {
            DocumentOnboardingView()
        }
        .task {
            Analytics.trackScreenView("DocumentHome")
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Feature Status Row

struct FeatureStatusRow: View {
    let name: String
    let enabled: Bool
    let icon: String
    var detail: String? = nil

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(enabled ? .green : .secondary)
                .frame(width: 24)

            Text(name)
                .foregroundColor(.primary)

            Spacer()

            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
            }

            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(enabled ? .green : .secondary)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @AppStorage("appearance") var appearance: Appearance = .system

    var body: some View {
        NavigationView {
            List {
                // Account Section
                Section("Account") {
                    if authManager.authState == .signedIn {
                        #if canImport(FirebaseAuth)
                        if let email = authManager.user?.email {
                            HStack {
                                Text("Email")
                                Spacer()
                                Text(email)
                                    .foregroundColor(.secondary)
                            }
                        }
                        #endif

                        Button("Sign Out", role: .destructive) {
                            authManager.signOut()
                        }
                    } else if authManager.canSignIn {
                        #if canImport(GoogleSignIn)
                        NavigationLink("Sign In") {
                            LoginView()
                        }
                        #endif
                    }
                }

                // Appearance Section
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }

                // Subscription Section
                Section("Subscription") {
                    Button("Manage Subscription") {
                        PaywallManager.shared.triggerPaywall()
                    }

                    Button("Restore Purchases") {
                        Task {
                            try? await PaywallManager.shared.restorePurchases()
                        }
                    }
                }

                // About Section
                Section("About") {
                    Link("Terms of Service", destination: URL(string: AppConfiguration.termsOfServiceURL)!)
                    Link("Privacy Policy", destination: URL(string: AppConfiguration.privacyPolicyURL)!)
                }

                // Template Credit (feel free to remove when customizing)
                Section {
                    Link(destination: URL(string: "https://github.com/cliffordh/swiftui-indie-stack")!) {
                        HStack {
                            Text("Built with SwiftUI Indie Stack")
                                .font(.footnote)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.footnote)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            Analytics.trackScreenView("SettingsView")
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
}
