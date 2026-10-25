//
//  ScheduledTasksListView.swift
//  MyApp
//
//  List and manage scheduled automation tasks.
//

import SwiftUI

struct ScheduledTasksListView: View {
    @ObservedObject var automationManager = AutomationManager.shared

    var body: some View {
        List {
            if automationManager.scheduledTasks.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text("No Scheduled Tasks")
                            .font(.headline)

                        Text("Schedule workflows to run automatically")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                Section {
                    ForEach(automationManager.scheduledTasks) { task in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(task.name)
                                    .font(.headline)

                                Spacer()

                                if task.isEnabled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }

                            Text(task.schedule.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                if let lastRun = task.lastRun {
                                    Text("Last: \(lastRun, style: .relative)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Text("Next: \(task.nextRun, style: .relative)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Text("Workflow: \(task.workflow.name)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                automationManager.deleteScheduledTask(task)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Scheduled Tasks")
                }
            }
        }
        .navigationTitle("Scheduled Tasks")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        ScheduledTasksListView()
    }
}
