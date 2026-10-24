//
//  PDFSecurityView.swift
//  MyApp
//
//  SwiftUI views for PDF security features.
//

import SwiftUI

// MARK: - PDF Security View

struct PDFSecurityView: View {
    
    let document: Document
    let onComplete: (URL) -> Void
    
    @State private var selectedOption: SecurityOption = .password
    @State private var showingPasswordSheet = false
    @State private var showingWatermarkSheet = false
    @State private var showingPermissionsSheet = false
    @State private var showingRedactionSheet = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(SecurityOption.allCases, id: \.self) { option in
                        Button {
                            selectOption(option)
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(option.color)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.rawValue)
                                        .foregroundColor(.primary)
                                    
                                    Text(option.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("PDF Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPasswordSheet) {
            PasswordProtectionView(document: document) { secureURL in
                onComplete(secureURL)
                dismiss()
            }
        }
        .sheet(isPresented: $showingWatermarkSheet) {
            WatermarkView(document: document) { watermarkedURL in
                onComplete(watermarkedURL)
                dismiss()
            }
        }
        .sheet(isPresented: $showingPermissionsSheet) {
            PermissionsView(document: document) { permissionedURL in
                onComplete(permissionedURL)
                dismiss()
            }
        }
        .sheet(isPresented: $showingRedactionSheet) {
            RedactionView(document: document) { redactedURL in
                onComplete(redactedURL)
                dismiss()
            }
        }
    }
    
    private func selectOption(_ option: SecurityOption) {
        selectedOption = option
        
        switch option {
        case .password:
            showingPasswordSheet = true
        case .watermark:
            showingWatermarkSheet = true
        case .permissions:
            showingPermissionsSheet = true
        case .redaction:
            showingRedactionSheet = true
        }
    }
}

// MARK: - Password Protection View

struct PasswordProtectionView: View {
    
    let document: Document
    let onComplete: (URL) -> Void
    
    @State private var userPassword = ""
    @State private var ownerPassword = ""
    @State private var confirmPassword = ""
    @State private var useOwnerPassword = false
    @State private var isProcessing = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("User Password", text: $userPassword)
                    SecureField("Confirm Password", text: $confirmPassword)
                } header: {
                    Text("User Password")
                } footer: {
                    Text("Required to open the PDF")
                }
                
                Section {
                    Toggle("Set Owner Password", isOn: $useOwnerPassword)
                    
                    if useOwnerPassword {
                        SecureField("Owner Password", text: $ownerPassword)
                    }
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Owner password allows full permissions and can remove restrictions")
                }
                
                Section {
                    Button {
                        applyPassword()
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                            } else {
                                Text("Protect PDF")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!isValid || isProcessing)
                }
            }
            .navigationTitle("Password Protection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isValid: Bool {
        !userPassword.isEmpty && userPassword == confirmPassword
    }
    
    private func applyPassword() {
        isProcessing = true
        
        Task {
            do {
                let secureURL = try await PDFSecurityManager.shared.addPassword(
                    to: document.fileURL,
                    userPassword: userPassword,
                    ownerPassword: useOwnerPassword ? ownerPassword : nil
                )
                
                await MainActor.run {
                    onComplete(secureURL)
                    isProcessing = false
                }
            } catch {
                debugPrint("❌ Failed to protect PDF: \(error)")
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Watermark View

struct WatermarkView: View {
    
    let document: Document
    let onComplete: (URL) -> Void
    
    @State private var watermarkText = ""
    @State private var selectedPosition: WatermarkPosition = .center
    @State private var opacity: Double = 0.3
    @State private var isProcessing = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Watermark Text", text: $watermarkText)
                } header: {
                    Text("Watermark")
                }
                
                Section {
                    Picker("Position", selection: $selectedPosition) {
                        Text("Center").tag(WatermarkPosition.center)
                        Text("Top").tag(WatermarkPosition.topCenter)
                        Text("Bottom").tag(WatermarkPosition.bottomCenter)
                        Text("Diagonal").tag(WatermarkPosition.diagonal)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Opacity")
                        Slider(value: $opacity, in: 0.1...1.0)
                        Text(String(format: "%.0f%%", opacity * 100))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Appearance")
                }
                
                Section {
                    Button {
                        applyWatermark()
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                            } else {
                                Text("Add Watermark")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(watermarkText.isEmpty || isProcessing)
                }
            }
            .navigationTitle("Add Watermark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func applyWatermark() {
        isProcessing = true
        
        Task {
            do {
                let options = WatermarkOptions(
                    position: selectedPosition,
                    opacity: opacity,
                    color: .gray,
                    font: UIFont.systemFont(ofSize: 48, weight: .bold)
                )
                
                let watermarkedURL = try await PDFSecurityManager.shared.addWatermark(
                    to: document.fileURL,
                    text: watermarkText,
                    options: options
                )
                
                await MainActor.run {
                    onComplete(watermarkedURL)
                    isProcessing = false
                }
            } catch {
                debugPrint("❌ Failed to add watermark: \(error)")
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Permissions View

struct PermissionsView: View {
    
    let document: Document
    let onComplete: (URL) -> Void
    
    @State private var allowPrinting = true
    @State private var allowCopying = true
    @State private var allowChanges = true
    @State private var allowComments = true
    @State private var ownerPassword = ""
    @State private var isProcessing = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Allow Printing", isOn: $allowPrinting)
                    Toggle("Allow Copying", isOn: $allowCopying)
                    Toggle("Allow Changes", isOn: $allowChanges)
                    Toggle("Allow Comments", isOn: $allowComments)
                } header: {
                    Text("Permissions")
                }
                
                Section {
                    SecureField("Owner Password", text: $ownerPassword)
                } header: {
                    Text("Protection")
                } footer: {
                    Text("Owner password is required to modify these permissions")
                }
                
                Section {
                    Button {
                        applyPermissions()
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                            } else {
                                Text("Set Permissions")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(ownerPassword.isEmpty || isProcessing)
                }
            }
            .navigationTitle("Set Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func applyPermissions() {
        isProcessing = true
        
        Task {
            do {
                let permissions = PDFPermissions(
                    allowsPrinting: allowPrinting,
                    allowsCopying: allowCopying,
                    allowsDocumentChanges: allowChanges,
                    allowsDocumentAssembly: allowChanges,
                    allowsContentAccessibility: true,
                    allowsCommenting: allowComments,
                    allowsFormFieldEntry: allowComments
                )
                
                let permissionedURL = try await PDFSecurityManager.shared.setPermissions(
                    on: document.fileURL,
                    permissions: permissions,
                    ownerPassword: ownerPassword
                )
                
                await MainActor.run {
                    onComplete(permissionedURL)
                    isProcessing = false
                }
            } catch {
                debugPrint("❌ Failed to set permissions: \(error)")
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Redaction View

struct RedactionView: View {
    
    let document: Document
    let onComplete: (URL) -> Void
    
    @State private var enableEmailRedaction = true
    @State private var enablePhoneRedaction = true
    @State private var enableSSNRedaction = true
    @State private var enableCreditCardRedaction = true
    @State private var isProcessing = false
    @State private var foundRedactions: [RedactionArea] = []
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Email Addresses", isOn: $enableEmailRedaction)
                    Toggle("Phone Numbers", isOn: $enablePhoneRedaction)
                    Toggle("SSN", isOn: $enableSSNRedaction)
                    Toggle("Credit Cards", isOn: $enableCreditCardRedaction)
                } header: {
                    Text("Auto-Detect & Redact")
                } footer: {
                    Text("Automatically find and redact sensitive information")
                }
                
                if !foundRedactions.isEmpty {
                    Section {
                        Text("\(foundRedactions.count) items found")
                            .foregroundColor(.orange)
                    }
                }
                
                Section {
                    Button {
                        findAndRedact()
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                            } else {
                                Text("Redact Sensitive Data")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isProcessing || !hasAnyEnabled)
                }
            }
            .navigationTitle("Redact Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var hasAnyEnabled: Bool {
        enableEmailRedaction || enablePhoneRedaction || enableSSNRedaction || enableCreditCardRedaction
    }
    
    private var selectedPatterns: [SensitiveDataPattern] {
        var patterns: [SensitiveDataPattern] = []
        if enableEmailRedaction { patterns.append(.email) }
        if enablePhoneRedaction { patterns.append(.phoneNumber) }
        if enableSSNRedaction { patterns.append(.ssn) }
        if enableCreditCardRedaction { patterns.append(.creditCard) }
        return patterns
    }
    
    private func findAndRedact() {
        isProcessing = true
        
        Task {
            do {
                let (redactedURL, redactions) = try await PDFSecurityManager.shared.findAndRedactSensitiveData(
                    in: document.fileURL,
                    patterns: selectedPatterns
                )
                
                await MainActor.run {
                    foundRedactions = redactions
                    onComplete(redactedURL)
                    isProcessing = false
                }
            } catch {
                debugPrint("❌ Failed to redact: \(error)")
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Security Option

enum SecurityOption: String, CaseIterable {
    case password = "Password Protection"
    case watermark = "Add Watermark"
    case permissions = "Set Permissions"
    case redaction = "Redact Information"
    
    var icon: String {
        switch self {
        case .password: return "lock.fill"
        case .watermark: return "signature"
        case .permissions: return "checkmark.shield.fill"
        case .redaction: return "eye.slash.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .password: return .blue
        case .watermark: return .purple
        case .permissions: return .green
        case .redaction: return .red
        }
    }
    
    var description: String {
        switch self {
        case .password:
            return "Require a password to open the PDF"
        case .watermark:
            return "Add visible text watermark to all pages"
        case .permissions:
            return "Control printing, copying, and editing"
        case .redaction:
            return "Remove sensitive information permanently"
        }
    }
}

#Preview {
    PDFSecurityView(document: Document(
        title: "Sample",
        filename: "sample.pdf",
        fileURL: URL(fileURLWithPath: "/tmp/sample.pdf"),
        fileSize: 1000,
        pageCount: 3,
        fileFormat: .pdf
    )) { _ in }
}
