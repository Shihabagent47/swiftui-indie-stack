//
//  WorkflowsListView.swift
//  MyApp
//
//  List and manage automation workflows.
//

import SwiftUI

struct WorkflowsListView: View {
    @ObservedObject var automationManager = AutomationManager.shared

    var body: some View {
        List {
            if automationManager.workflows.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text("No Workflows")
                            .font(.headline)

                        Text("Create workflows to automate document processing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                Section {
                    ForEach(automationManager.workflows) { workflow in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(workflow.name)
                                    .font(.headline)

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { workflow.isEnabled },
                                    set: { _ in
                                        automationManager.toggleWorkflow(workflow)
                                        Haptics.light()
                                    }
                                ))
                                .labelsHidden()
                            }

                            Text("\(workflow.actions.count) action\(workflow.actions.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(workflow.actions.indices, id: \.self) { index in
                                Text("• \(workflow.actions[index].displayName)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                automationManager.deleteWorkflow(workflow)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Workflows")
                }
            }
        }
        .navigationTitle("Workflows")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        WorkflowsListView()
    }
}
