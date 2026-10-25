//
//  AutomationDashboardView.swift
//  MyApp
//
//  Main dashboard for automation features.
//

import SwiftUI

struct AutomationDashboardView: View {
    @ObservedObject var automationManager = AutomationManager.shared
    @ObservedObject var templateManager = TemplateManager.shared
    @ObservedObject var quotaManager = QuotaManager.shared

    @State private var showProUpgrade = false

    var body: some View {
        NavigationView {
            List {
                // Pro Status
                if !quotaManager.isPro {
                    Section {
                        ProUpgradePrompt()
                            .onTapGesture {
                                showProUpgrade = true
                            }
                    }
                }

                // Templates
                Section {
                    NavigationLink {
                        TemplatesListView()
                    } label: {
                        Label("Document Templates", systemImage: "doc.text")
                        if !templateManager.templates.isEmpty {
                            Text("\(templateManager.templates.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }

                    NavigationLink {
                        PresetsListView()
                    } label: {
                        Label("Preset Configurations", systemImage: "slider.horizontal.3")
                        if !templateManager.presetConfigurations.isEmpty {
                            Text("\(templateManager.presetConfigurations.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }

                } header: {
                    Text("Templates & Presets")
                }

                // Workflows
                if quotaManager.isPro {
                    Section {
                        NavigationLink {
                            WorkflowsListView()
                        } label: {
                            Label("Workflows", systemImage: "arrow.triangle.branch")
                            if !automationManager.workflows.isEmpty {
                                Text("\(automationManager.workflows.count)")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }

                        NavigationLink {
                            ScheduledTasksListView()
                        } label: {
                            Label("Scheduled Tasks", systemImage: "clock.arrow.circlepath")
                            if !automationManager.scheduledTasks.isEmpty {
                                Text("\(automationManager.scheduledTasks.count)")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }

                        NavigationLink {
                            OrganizationRulesListView()
                        } label: {
                            Label("Organization Rules", systemImage: "square.grid.2x2")
                            if !automationManager.organizationRules.isEmpty {
                                Text("\(automationManager.organizationRules.count)")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }

                    } header: {
                        Text("Automation")
                    } footer: {
                        Text("Automate repetitive tasks with workflows and rules")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Automation")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showProUpgrade) {
            PaywallView()
        }
        .task {
            Analytics.trackScreenView("AutomationDashboard")
        }
    }
}

#Preview {
    AutomationDashboardView()
}
