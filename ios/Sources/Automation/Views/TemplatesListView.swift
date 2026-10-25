//
//  TemplatesListView.swift
//  MyApp
//
//  List and manage document templates.
//

import SwiftUI

struct TemplatesListView: View {
    @ObservedObject var templateManager = TemplateManager.shared
    @State private var showCreateTemplate = false
    @State private var generatingTemplate: DocumentTemplate?
    @State private var generatedURL: URL?
    @State private var showSuccess = false

    var body: some View {
        List {
            if templateManager.templates.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text("No Templates")
                            .font(.headline)

                        Text("Create templates for quick document generation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                Section {
                    ForEach(templateManager.templates) { template in
                        TemplateRow(template: template) {
                            generateDocument(from: template)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                templateManager.deleteTemplate(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Templates")
                }
            }
        }
        .navigationTitle("Document Templates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateTemplate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateTemplate) {
            CreateTemplateView()
        }
        .alert("Document Generated", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            if let url = generatedURL {
                Text("Document created: \(url.lastPathComponent)")
            }
        }
    }

    private func generateDocument(from template: DocumentTemplate) {
        Task {
            do {
                generatedURL = try await templateManager.generateDocument(from: template)
                Haptics.success()
                showSuccess = true
            } catch {
                Haptics.error()
            }
        }
    }
}

struct TemplateRow: View {
    let template: DocumentTemplate
    let onGenerate: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(template.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(template.pageSize.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                onGenerate()
                Haptics.light()
            } label: {
                Image(systemName: "doc.badge.plus")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct CreateTemplateView: View {
    @ObservedObject var templateManager = TemplateManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var templateType: TemplateType = .blank
    @State private var pageSize: PageSize = .letter
    @State private var orientation: PageOrientation = .portrait

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Template Name", text: $name)

                    Picker("Type", selection: $templateType) {
                        ForEach(TemplateType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                } header: {
                    Text("Basic Info")
                }

                Section {
                    Picker("Page Size", selection: Binding(
                        get: { pageSizeType },
                        set: { updatePageSize($0) }
                    )) {
                        Text("Letter").tag("letter")
                        Text("A4").tag("a4")
                        Text("Legal").tag("legal")
                    }

                    Picker("Orientation", selection: $orientation) {
                        ForEach(PageOrientation.allCases, id: \.self) { orient in
                            Text(orient.rawValue).tag(orient)
                        }
                    }

                } header: {
                    Text("Page Settings")
                }
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createTemplate()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private var pageSizeType: String {
        switch pageSize {
        case .letter: return "letter"
        case .a4: return "a4"
        case .legal: return "legal"
        case .custom: return "custom"
        }
    }

    private func updatePageSize(_ type: String) {
        switch type {
        case "letter": pageSize = .letter
        case "a4": pageSize = .a4
        case "legal": pageSize = .legal
        default: break
        }
    }

    private func createTemplate() {
        let content: TemplateContent?
        switch templateType {
        case .blank:
            content = .blank
        case .lined:
            content = .lined(spacing: 25)
        case .grid:
            content = .grid(spacing: 20)
        default:
            content = nil
        }

        templateManager.createTemplate(
            name: name,
            type: templateType,
            pageSize: pageSize,
            orientation: orientation,
            content: content
        )

        Haptics.success()
        dismiss()
    }
}

#Preview {
    NavigationView {
        TemplatesListView()
    }
}
