//
//  FolderManagementView.swift
//  MyApp
//
//  Interface for managing folders, collections, and hierarchical organization.
//

import SwiftUI
import SwiftData

struct FolderManagementView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DocumentFolder.name) private var folders: [DocumentFolder]
    
    @StateObject private var viewModel = FolderManagementViewModel()
    
    @State private var showCreateFolder = false
    @State private var showCreateSmartFolder = false
    @State private var selectedFolder: DocumentFolder?
    @State private var expandedFolders: Set<UUID> = []
    
    var body: some View {
        NavigationStack {
            List {
                // All Documents
                NavigationLink {
                    DocumentBrowserView()
                } label: {
                    Label("All Documents", systemImage: "doc.on.doc.fill")
                        .foregroundStyle(.blue)
                }
                
                // Favorites
                NavigationLink {
                    DocumentBrowserView()
                        // TODO: Pass favorites filter
                } label: {
                    Label("Favorites", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
                
                // Recent
                NavigationLink {
                    DocumentBrowserView()
                        // TODO: Pass recent filter
                } label: {
                    Label("Recent", systemImage: "clock.fill")
                        .foregroundStyle(.purple)
                }
                
                Divider()
                
                // Regular Folders
                Section("Folders") {
                    ForEach(rootFolders) { folder in
                        FolderRow(
                            folder: folder,
                            level: 0,
                            expandedFolders: $expandedFolders,
                            onSelect: { selectedFolder = folder }
                        )
                    }
                    
                    if rootFolders.isEmpty {
                        Text("No folders yet")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
                
                // Smart Folders
                Section("Smart Folders") {
                    ForEach(smartFolders) { folder in
                        NavigationLink {
                            DocumentBrowserView(folder: folder)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.name)
                                    
                                    Text("\(folder.documentCount) documents")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: folder.icon ?? "folder.badge.gearshape")
                                    .foregroundStyle(folder.colorLabel?.color ?? .purple)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteFolder(folder)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                selectedFolder = folder
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    
                    if smartFolders.isEmpty {
                        Text("No smart folders yet")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Folders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showCreateFolder = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                        
                        Button {
                            showCreateSmartFolder = true
                        } label: {
                            Label("New Smart Folder", systemImage: "folder.badge.gearshape")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateFolder) {
                CreateFolderView(parentFolder: nil) { folder in
                    modelContext.insert(folder)
                    try? modelContext.save()
                }
            }
            .sheet(isPresented: $showCreateSmartFolder) {
                CreateSmartFolderView { folder in
                    modelContext.insert(folder)
                    try? modelContext.save()
                }
            }
            .sheet(item: $selectedFolder) { folder in
                EditFolderView(folder: folder)
            }
        }
        .onAppear {
            viewModel.loadFolders(folders)
        }
    }
    
    // MARK: - Computed Properties
    
    private var rootFolders: [DocumentFolder] {
        folders.filter { $0.parentFolder == nil && !$0.isSmartFolder }
    }
    
    private var smartFolders: [DocumentFolder] {
        folders.filter { $0.isSmartFolder }
    }
    
    // MARK: - Actions
    
    private func deleteFolder(_ folder: DocumentFolder) {
        modelContext.delete(folder)
        try? modelContext.save()
        
        Analytics.track(event: "folder_deleted", properties: [
            "is_smart": folder.isSmartFolder,
            "had_documents": folder.documentCount > 0
        ])
    }
}

// MARK: - Folder Row

struct FolderRow: View {
    let folder: DocumentFolder
    let level: Int
    
    @Binding var expandedFolders: Set<UUID>
    let onSelect: () -> Void
    
    @State private var showSubfolders = false
    
    private var isExpanded: Bool {
        expandedFolders.contains(folder.id)
    }
    
    private var hasSubfolders: Bool {
        !folder.subfolders.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationLink {
                DocumentBrowserView(folder: folder)
            } label: {
                HStack(spacing: 8) {
                    // Expand/collapse button
                    if hasSubfolders {
                        Button {
                            withAnimation {
                                if isExpanded {
                                    expandedFolders.remove(folder.id)
                                } else {
                                    expandedFolders.insert(folder.id)
                                }
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer()
                            .frame(width: 16)
                    }
                    
                    // Folder icon
                    Image(systemName: folder.icon ?? "folder.fill")
                        .foregroundStyle(folder.colorLabel?.color ?? .blue)
                    
                    // Folder name and count
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.name)
                        
                        Text("\(folder.documentCount) documents • \(formatFileSize(folder.totalSize))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.leading, CGFloat(level * 20))
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    // Delete
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                
                Button {
                    onSelect()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
            
            // Subfolders
            if isExpanded && hasSubfolders {
                ForEach(folder.subfolders) { subfolder in
                    FolderRow(
                        folder: subfolder,
                        level: level + 1,
                        expandedFolders: $expandedFolders,
                        onSelect: onSelect
                    )
                }
            }
        }
    }
}

// MARK: - Create Folder View

struct CreateFolderView: View {
    @Environment(\.dismiss) private var dismiss
    
    let parentFolder: DocumentFolder?
    let onCreate: (DocumentFolder) -> Void
    
    @State private var name = ""
    @State private var selectedIcon: String?
    @State private var selectedColor: ColorLabel?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Folder Details") {
                    TextField("Name", text: $name)
                    
                    if let parent = parentFolder {
                        HStack {
                            Text("Parent Folder")
                            Spacer()
                            Text(parent.name)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Appearance") {
                    Picker("Icon", selection: $selectedIcon) {
                        Text("Default").tag(nil as String?)
                        ForEach(folderIcons, id: \.self) { icon in
                            Label(icon, systemImage: icon)
                                .tag(icon as String?)
                        }
                    }
                    
                    Picker("Color Label", selection: $selectedColor) {
                        Text("None").tag(nil as ColorLabel?)
                        ForEach(ColorLabel.allCases, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 20, height: 20)
                                Text(color.displayName)
                            }
                            .tag(color as ColorLabel?)
                        }
                    }
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createFolder()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createFolder() {
        let folder = DocumentFolder(
            name: name,
            icon: selectedIcon,
            colorLabel: selectedColor
        )
        
        folder.parentFolder = parentFolder
        
        onCreate(folder)
        
        Analytics.track(event: "folder_created", properties: [
            "has_parent": parentFolder != nil,
            "has_icon": selectedIcon != nil,
            "has_color": selectedColor != nil
        ])
        
        dismiss()
    }
}

// MARK: - Create Smart Folder View

struct CreateSmartFolderView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onCreate: (DocumentFolder) -> Void
    
    @State private var name = ""
    @State private var selectedIcon: String?
    @State private var selectedColor: ColorLabel?
    @State private var rules: [SmartFolderRule] = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Folder Details") {
                    TextField("Name", text: $name)
                }
                
                Section("Appearance") {
                    Picker("Icon", selection: $selectedIcon) {
                        Text("Default").tag(nil as String?)
                        ForEach(folderIcons, id: \.self) { icon in
                            Label(icon, systemImage: icon)
                                .tag(icon as String?)
                        }
                    }
                    
                    Picker("Color Label", selection: $selectedColor) {
                        Text("None").tag(nil as ColorLabel?)
                        ForEach(ColorLabel.allCases, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 20, height: 20)
                                Text(color.displayName)
                            }
                            .tag(color as ColorLabel?)
                        }
                    }
                }
                
                Section("Rules") {
                    ForEach(rules) { rule in
                        SmartFolderRuleRow(rule: rule)
                    }
                    
                    Button("Add Rule") {
                        rules.append(SmartFolderRule())
                    }
                }
            }
            .navigationTitle("New Smart Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSmartFolder()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createSmartFolder() {
        let folder = DocumentFolder(
            name: name,
            icon: selectedIcon,
            colorLabel: selectedColor,
            isSmartFolder: true
        )
        
        // Encode rules
        // TODO: Implement rule encoding
        
        onCreate(folder)
        
        Analytics.track(event: "smart_folder_created", properties: [
            "rule_count": rules.count
        ])
        
        dismiss()
    }
}

// MARK: - Edit Folder View

struct EditFolderView: View {
    @Environment(\.dismiss) private var dismiss
    
    let folder: DocumentFolder
    
    @State private var name: String
    @State private var selectedIcon: String?
    @State private var selectedColor: ColorLabel?
    
    init(folder: DocumentFolder) {
        self.folder = folder
        _name = State(initialValue: folder.name)
        _selectedIcon = State(initialValue: folder.icon)
        _selectedColor = State(initialValue: folder.colorLabel)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Folder Details") {
                    TextField("Name", text: $name)
                }
                
                Section("Appearance") {
                    Picker("Icon", selection: $selectedIcon) {
                        Text("Default").tag(nil as String?)
                        ForEach(folderIcons, id: \.self) { icon in
                            Label(icon, systemImage: icon)
                                .tag(icon as String?)
                        }
                    }
                    
                    Picker("Color Label", selection: $selectedColor) {
                        Text("None").tag(nil as ColorLabel?)
                        ForEach(ColorLabel.allCases, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 20, height: 20)
                                Text(color.displayName)
                            }
                            .tag(color as ColorLabel?)
                        }
                    }
                }
                
                Section("Information") {
                    HStack {
                        Text("Documents")
                        Spacer()
                        Text("\(folder.documentCount)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Total Size")
                        Spacer()
                        Text(formatFileSize(folder.totalSize))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(folder.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        folder.name = name
        folder.icon = selectedIcon
        folder.colorLabel = selectedColor
        folder.modifiedAt = Date()
        
        Analytics.track(event: "folder_edited")
        
        dismiss()
    }
}

// MARK: - Smart Folder Rule

struct SmartFolderRule: Identifiable {
    let id = UUID()
    var field: RuleField = .fileFormat
    var condition: RuleCondition = .equals
    var value: String = ""
    
    enum RuleField: String, CaseIterable {
        case fileFormat = "File Format"
        case tag = "Tag"
        case createdDate = "Created Date"
        case modifiedDate = "Modified Date"
        case fileSize = "File Size"
        case pageCount = "Page Count"
        
        var displayName: String { rawValue }
    }
    
    enum RuleCondition: String, CaseIterable {
        case equals = "equals"
        case contains = "contains"
        case greaterThan = "greater than"
        case lessThan = "less than"
        
        var displayName: String { rawValue }
    }
}

struct SmartFolderRuleRow: View {
    let rule: SmartFolderRule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Field:")
                    .foregroundStyle(.secondary)
                Text(rule.field.displayName)
            }
            
            HStack {
                Text("Condition:")
                    .foregroundStyle(.secondary)
                Text(rule.condition.displayName)
            }
            
            HStack {
                Text("Value:")
                    .foregroundStyle(.secondary)
                Text(rule.value.isEmpty ? "Not set" : rule.value)
            }
        }
        .font(.subheadline)
    }
}

// MARK: - Supporting Types

private let folderIcons = [
    "folder.fill",
    "folder.badge.person.crop",
    "folder.badge.gear",
    "briefcase.fill",
    "archivebox.fill",
    "tray.fill",
    "doc.on.doc.fill",
    "book.fill",
    "newspaper.fill"
]

extension ColorLabel {
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .gray: return .gray
        }
    }
}

private func formatFileSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

#Preview {
    FolderManagementView()
        .modelContainer(for: DocumentFolder.self, inMemory: true)
}
