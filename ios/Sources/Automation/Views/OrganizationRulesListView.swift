//
//  OrganizationRulesListView.swift
//  MyApp
//
//  List and manage organization rules.
//

import SwiftUI

struct OrganizationRulesListView: View {
    @ObservedObject var automationManager = AutomationManager.shared

    var body: some View {
        List {
            if automationManager.organizationRules.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text("No Organization Rules")
                            .font(.headline)

                        Text("Create rules to automatically organize documents")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                Section {
                    ForEach(automationManager.organizationRules) { rule in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(rule.name)
                                    .font(.headline)

                                Spacer()

                                if rule.isEnabled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("If:")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)

                                    Text(rule.condition.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text("Then:")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)

                                    Text(rule.action.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                automationManager.deleteOrganizationRule(rule)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Organization Rules")
                } footer: {
                    Text("Rules are automatically applied to new documents")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Organization Rules")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        OrganizationRulesListView()
    }
}
