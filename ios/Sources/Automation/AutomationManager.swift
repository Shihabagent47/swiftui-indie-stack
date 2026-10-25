//
//  AutomationManager.swift
//  MyApp
//
//  Manages workflow automation, scheduled tasks, and rule-based organization.
//

import Foundation
import Combine
import UIKit

@MainActor
final class AutomationManager: ObservableObject {
    static let shared = AutomationManager()

    // MARK: - Published Properties

    @Published var workflows: [Workflow] = []
    @Published var scheduledTasks: [ScheduledTask] = []
    @Published var organizationRules: [OrganizationRule] = []
    @Published var isProcessingWorkflow = false

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    private var taskTimer: Timer?

    // Storage keys
    private enum StorageKeys {
        static let workflows = "automation_workflows"
        static let scheduledTasks = "automation_scheduled_tasks"
        static let organizationRules = "automation_organization_rules"
    }

    // MARK: - Initialization

    private init() {
        loadWorkflows()
        loadScheduledTasks()
        loadOrganizationRules()
        setupTaskScheduler()
    }

    // MARK: - Workflows

    /// Create a new workflow
    func createWorkflow(name: String, actions: [WorkflowAction]) {
        let workflow = Workflow(
            id: UUID(),
            name: name,
            actions: actions,
            isEnabled: true,
            createdDate: Date()
        )

        workflows.append(workflow)
        saveWorkflows()

        Analytics.track(event: "workflow_created", parameters: ["name": name])
    }

    /// Execute a workflow
    func executeWorkflow(_ workflow: Workflow, on documents: [URL]) async throws {
        guard workflow.isEnabled else {
            throw AutomationError.workflowDisabled
        }

        isProcessingWorkflow = true

        for action in workflow.actions {
            try await performAction(action, on: documents)
        }

        isProcessingWorkflow = false

        Analytics.track(event: "workflow_executed", parameters: [
            "workflow": workflow.name,
            "actions": workflow.actions.count
        ])
    }

    private func performAction(_ action: WorkflowAction, on documents: [URL]) async throws {
        switch action {
        case .convert(let format, let quality):
            _ = try await BatchProcessingManager.shared.batchConvertToImages(
                urls: documents,
                format: format,
                quality: quality
            )

        case .compress(let level):
            _ = try await BatchProcessingManager.shared.batchCompress(
                urls: documents,
                compressionLevel: level
            )

        case .rename(let pattern):
            _ = try await BatchProcessingManager.shared.batchRename(
                urls: documents,
                pattern: pattern
            )

        case .organize(let strategy):
            try await BatchProcessingManager.shared.batchOrganize(
                urls: documents,
                strategy: strategy
            )

        case .ocr:
            _ = try await BatchProcessingManager.shared.batchOCR(urls: documents)

        case .export(let destination):
            // Export documents - destination would be used in a real implementation
            for url in documents {
                // Placeholder for export operation
                Analytics.track(event: "workflow_export", parameters: ["destination": destination])
            }
        }
    }

    /// Delete a workflow
    func deleteWorkflow(_ workflow: Workflow) {
        workflows.removeAll { $0.id == workflow.id }
        saveWorkflows()

        Analytics.track(event: "workflow_deleted", parameters: ["name": workflow.name])
    }

    /// Toggle workflow enabled state
    func toggleWorkflow(_ workflow: Workflow) {
        if let index = workflows.firstIndex(where: { $0.id == workflow.id }) {
            workflows[index].isEnabled.toggle()
            saveWorkflows()

            Analytics.track(event: "workflow_toggled", parameters: [
                "name": workflow.name,
                "enabled": workflows[index].isEnabled
            ])
        }
    }

    // MARK: - Scheduled Tasks

    /// Create a scheduled task
    func createScheduledTask(
        name: String,
        schedule: TaskSchedule,
        workflow: Workflow
    ) {
        let task = ScheduledTask(
            id: UUID(),
            name: name,
            schedule: schedule,
            workflow: workflow,
            isEnabled: true,
            lastRun: nil,
            nextRun: calculateNextRun(for: schedule)
        )

        scheduledTasks.append(task)
        saveScheduledTasks()

        Analytics.track(event: "scheduled_task_created", parameters: ["name": name])
    }

    private func calculateNextRun(for schedule: TaskSchedule) -> Date {
        let calendar = Calendar.current
        let now = Date()

        switch schedule {
        case .daily(let hour):
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = hour
            components.minute = 0

            if let nextRun = calendar.date(from: components), nextRun > now {
                return nextRun
            } else {
                return calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components)!)!
            }

        case .weekly(let weekday, let hour):
            var components = DateComponents()
            components.weekday = weekday
            components.hour = hour
            components.minute = 0

            return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)!

        case .monthly(let day, let hour):
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = day
            components.hour = hour
            components.minute = 0

            if let nextRun = calendar.date(from: components), nextRun > now {
                return nextRun
            } else {
                return calendar.date(byAdding: .month, value: 1, to: calendar.date(from: components)!)!
            }
        }
    }

    /// Delete a scheduled task
    func deleteScheduledTask(_ task: ScheduledTask) {
        scheduledTasks.removeAll { $0.id == task.id }
        saveScheduledTasks()

        Analytics.track(event: "scheduled_task_deleted", parameters: ["name": task.name])
    }

    private func setupTaskScheduler() {
        // Check for tasks to run every minute
        taskTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkScheduledTasks()
            }
        }
    }

    private func checkScheduledTasks() async {
        let now = Date()

        for task in scheduledTasks where task.isEnabled {
            if task.nextRun <= now {
                await runScheduledTask(task)
            }
        }
    }

    private func runScheduledTask(_ task: ScheduledTask) async {
        // Get documents to process (this would be customizable)
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let documents = try? fileManager.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: nil
        ).filter({ $0.pathExtension == "pdf" }) else {
            return
        }

        do {
            try await executeWorkflow(task.workflow, on: documents)

            // Update task
            if let index = scheduledTasks.firstIndex(where: { $0.id == task.id }) {
                scheduledTasks[index].lastRun = Date()
                scheduledTasks[index].nextRun = calculateNextRun(for: task.schedule)
                saveScheduledTasks()
            }

            Analytics.track(event: "scheduled_task_executed", parameters: ["name": task.name])

        } catch {
            Analytics.track(event: "scheduled_task_failed", parameters: [
                "name": task.name,
                "error": error.localizedDescription
            ])
        }
    }

    // MARK: - Organization Rules

    /// Create an organization rule
    func createOrganizationRule(
        name: String,
        condition: RuleCondition,
        action: RuleAction
    ) {
        let rule = OrganizationRule(
            id: UUID(),
            name: name,
            condition: condition,
            action: action,
            isEnabled: true
        )

        organizationRules.append(rule)
        saveOrganizationRules()

        Analytics.track(event: "organization_rule_created", parameters: ["name": name])
    }

    /// Apply organization rules to documents
    func applyOrganizationRules(to documents: [URL]) async throws {
        for rule in organizationRules where rule.isEnabled {
            let matchingDocuments = documents.filter { evaluateCondition(rule.condition, for: $0) }

            if !matchingDocuments.isEmpty {
                try await performRuleAction(rule.action, on: matchingDocuments)

                Analytics.track(event: "organization_rule_applied", parameters: [
                    "rule": rule.name,
                    "documents": matchingDocuments.count
                ])
            }
        }
    }

    private func evaluateCondition(_ condition: RuleCondition, for url: URL) -> Bool {
        switch condition {
        case .nameContains(let text):
            return url.lastPathComponent.lowercased().contains(text.lowercased())

        case .typeIs(let type):
            return url.pathExtension.lowercased() == type.lowercased()

        case .sizeGreaterThan(let bytes):
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                return size > bytes
            }
            return false

        case .createdAfter(let date):
            if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate {
                return creationDate > date
            }
            return false
        }
    }

    private func performRuleAction(_ action: RuleAction, on documents: [URL]) async throws {
        switch action {
        case .moveToFolder(let folderName):
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let folderURL = documentsURL.appendingPathComponent(folderName)

            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

            for document in documents {
                let destinationURL = folderURL.appendingPathComponent(document.lastPathComponent)
                try fileManager.moveItem(at: document, to: destinationURL)
            }

        case .rename(let pattern):
            _ = try await BatchProcessingManager.shared.batchRename(
                urls: documents,
                pattern: pattern
            )

        case .compress(let level):
            _ = try await BatchProcessingManager.shared.batchCompress(
                urls: documents,
                compressionLevel: level
            )

        case .delete:
            for document in documents {
                try fileManager.removeItem(at: document)
            }
        }
    }

    /// Delete an organization rule
    func deleteOrganizationRule(_ rule: OrganizationRule) {
        organizationRules.removeAll { $0.id == rule.id }
        saveOrganizationRules()

        Analytics.track(event: "organization_rule_deleted", parameters: ["name": rule.name])
    }

    // MARK: - Persistence

    private func loadWorkflows() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.workflows),
           let workflows = try? JSONDecoder().decode([Workflow].self, from: data) {
            self.workflows = workflows
        }
    }

    private func saveWorkflows() {
        if let data = try? JSONEncoder().encode(workflows) {
            UserDefaults.standard.set(data, forKey: StorageKeys.workflows)
        }
    }

    private func loadScheduledTasks() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.scheduledTasks),
           let tasks = try? JSONDecoder().decode([ScheduledTask].self, from: data) {
            self.scheduledTasks = tasks
        }
    }

    private func saveScheduledTasks() {
        if let data = try? JSONEncoder().encode(scheduledTasks) {
            UserDefaults.standard.set(data, forKey: StorageKeys.scheduledTasks)
        }
    }

    private func loadOrganizationRules() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.organizationRules),
           let rules = try? JSONDecoder().decode([OrganizationRule].self, from: data) {
            self.organizationRules = rules
        }
    }

    private func saveOrganizationRules() {
        if let data = try? JSONEncoder().encode(organizationRules) {
            UserDefaults.standard.set(data, forKey: StorageKeys.organizationRules)
        }
    }
}

// MARK: - Supporting Types

enum AutomationError: LocalizedError {
    case workflowDisabled
    case taskNotFound
    case invalidSchedule

    var errorDescription: String? {
        switch self {
        case .workflowDisabled:
            return "Workflow is disabled"
        case .taskNotFound:
            return "Scheduled task not found"
        case .invalidSchedule:
            return "Invalid task schedule"
        }
    }
}

// MARK: - Workflow

struct Workflow: Identifiable, Codable {
    let id: UUID
    let name: String
    let actions: [WorkflowAction]
    var isEnabled: Bool
    let createdDate: Date
}

enum WorkflowAction: Codable, Hashable {
    case convert(format: ExportFormat, quality: ExportQuality)
    case compress(level: BatchCompressionLevel)
    case rename(pattern: NamingPattern)
    case organize(strategy: OrganizationStrategy)
    case ocr
    case export(destination: String)

    var displayName: String {
        switch self {
        case .convert: return "Convert to Images"
        case .compress: return "Compress PDFs"
        case .rename: return "Rename Documents"
        case .organize: return "Organize Documents"
        case .ocr: return "Extract Text (OCR)"
        case .export: return "Export Documents"
        }
    }

    // Manual Codable implementation
    enum CodingKeys: String, CodingKey {
        case type, format, quality, level, pattern, strategy, destination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "convert":
            let format = try container.decode(ExportFormat.self, forKey: .format)
            let quality = try container.decode(ExportQuality.self, forKey: .quality)
            self = .convert(format: format, quality: quality)
        case "compress":
            let level = try container.decode(BatchCompressionLevel.self, forKey: .level)
            self = .compress(level: level)
        case "rename":
            let pattern = try container.decode(NamingPattern.self, forKey: .pattern)
            self = .rename(pattern: pattern)
        case "organize":
            let strategy = try container.decode(OrganizationStrategy.self, forKey: .strategy)
            self = .organize(strategy: strategy)
        case "ocr":
            self = .ocr
        case "export":
            let destination = try container.decode(String.self, forKey: .destination)
            self = .export(destination: destination)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .convert(let format, let quality):
            try container.encode("convert", forKey: .type)
            try container.encode(format, forKey: .format)
            try container.encode(quality, forKey: .quality)
        case .compress(let level):
            try container.encode("compress", forKey: .type)
            try container.encode(level, forKey: .level)
        case .rename(let pattern):
            try container.encode("rename", forKey: .type)
            try container.encode(pattern, forKey: .pattern)
        case .organize(let strategy):
            try container.encode("organize", forKey: .type)
            try container.encode(strategy, forKey: .strategy)
        case .ocr:
            try container.encode("ocr", forKey: .type)
        case .export(let destination):
            try container.encode("export", forKey: .type)
            try container.encode(destination, forKey: .destination)
        }
    }
}

// MARK: - Scheduled Task

struct ScheduledTask: Identifiable, Codable {
    let id: UUID
    let name: String
    let schedule: TaskSchedule
    let workflow: Workflow
    var isEnabled: Bool
    var lastRun: Date?
    var nextRun: Date
}

enum TaskSchedule: Codable {
    case daily(hour: Int)
    case weekly(weekday: Int, hour: Int)
    case monthly(day: Int, hour: Int)

    var displayName: String {
        switch self {
        case .daily(let hour):
            return "Daily at \(hour):00"
        case .weekly(let weekday, let hour):
            let weekdayName = Calendar.current.weekdaySymbols[weekday - 1]
            return "Weekly on \(weekdayName) at \(hour):00"
        case .monthly(let day, let hour):
            return "Monthly on day \(day) at \(hour):00"
        }
    }
}

// MARK: - Organization Rule

struct OrganizationRule: Identifiable, Codable {
    let id: UUID
    let name: String
    let condition: RuleCondition
    let action: RuleAction
    var isEnabled: Bool
}

enum RuleCondition: Codable {
    case nameContains(String)
    case typeIs(String)
    case sizeGreaterThan(Int)
    case createdAfter(Date)

    var displayName: String {
        switch self {
        case .nameContains(let text):
            return "Name contains '\(text)'"
        case .typeIs(let type):
            return "Type is \(type)"
        case .sizeGreaterThan(let bytes):
            return "Size greater than \(bytes / 1_000_000)MB"
        case .createdAfter(let date):
            return "Created after \(date.formatted(date: .abbreviated, time: .omitted))"
        }
    }
}

enum RuleAction: Codable {
    case moveToFolder(String)
    case rename(NamingPattern)
    case compress(BatchCompressionLevel)
    case delete

    var displayName: String {
        switch self {
        case .moveToFolder(let folder):
            return "Move to '\(folder)'"
        case .rename:
            return "Rename"
        case .compress:
            return "Compress"
        case .delete:
            return "Delete"
        }
    }

    // Manual Codable implementation
    enum CodingKeys: String, CodingKey {
        case type, folder, pattern, level
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "moveToFolder":
            let folder = try container.decode(String.self, forKey: .folder)
            self = .moveToFolder(folder)
        case "rename":
            let pattern = try container.decode(NamingPattern.self, forKey: .pattern)
            self = .rename(pattern)
        case "compress":
            let level = try container.decode(BatchCompressionLevel.self, forKey: .level)
            self = .compress(level)
        case "delete":
            self = .delete
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .moveToFolder(let folder):
            try container.encode("moveToFolder", forKey: .type)
            try container.encode(folder, forKey: .folder)
        case .rename(let pattern):
            try container.encode("rename", forKey: .type)
            try container.encode(pattern, forKey: .pattern)
        case .compress(let level):
            try container.encode("compress", forKey: .type)
            try container.encode(level, forKey: .level)
        case .delete:
            try container.encode("delete", forKey: .type)
        }
    }
}
