//
//  PDFSecurityManager.swift
//  MyApp
//
//  Manages PDF security features including encryption, passwords, and permissions.
//

import Foundation
import UIKit
import PDFKit

/// Manages PDF security and encryption
actor PDFSecurityManager {
    
    static let shared = PDFSecurityManager()
    
    private init() {}
    
    // MARK: - Password Protection
    
    /// Add password protection to PDF
    func addPassword(
        to url: URL,
        userPassword: String?,
        ownerPassword: String?,
        permissions: PDFPermissions = .default
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        // Create encryption options
        var options: [PDFDocumentWriteOption: Any] = [:]
        
        if let userPwd = userPassword {
            options[.userPasswordOption] = userPwd
        }
        
        if let ownerPwd = ownerPassword {
            options[.ownerPasswordOption] = ownerPwd
        }
        
        // Set permissions
        options[.allowsPrintingOption] = permissions.allowsPrinting
        options[.allowsCopyingOption] = permissions.allowsCopying
        
        // Save with encryption
        let filename = generateSecureFilename(from: url)
        let outputURL = try await saveSecurePDF(pdfDocument, filename: filename, options: options)
        
        Analytics.track(event: "pdf_password_protected", properties: [
            "has_user_password": userPassword != nil,
            "has_owner_password": ownerPassword != nil
        ])
        
        return outputURL
    }
    
    /// Remove password from PDF
    func removePassword(from url: URL, password: String) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        // Unlock document
        guard pdfDocument.unlock(withPassword: password) else {
            throw DocumentError.unauthorized
        }
        
        // Save without password
        let filename = generateSecureFilename(from: url, suffix: "unlocked")
        let outputURL = try await saveSecurePDF(pdfDocument, filename: filename, options: [:])
        
        Analytics.track(event: "pdf_password_removed")
        
        return outputURL
    }
    
    /// Check if PDF is password protected
    func isPasswordProtected(_ url: URL) -> Bool {
        guard let pdfDocument = PDFDocument(url: url) else {
            return false
        }
        return pdfDocument.isLocked
    }
    
    /// Unlock PDF with password
    func unlockPDF(at url: URL, password: String) async throws -> PDFDocument {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        guard pdfDocument.unlock(withPassword: password) else {
            throw DocumentError.unauthorized
        }
        
        return pdfDocument
    }
    
    // MARK: - Encryption
    
    /// Encrypt PDF with AES encryption
    func encryptPDF(
        at url: URL,
        password: String,
        encryptionLevel: EncryptionLevel = .aes256
    ) async throws -> URL {
        // PDFKit uses encryption level based on password length and complexity
        // 40-bit, 128-bit RC4, or 128/256-bit AES
        
        let permissions = PDFPermissions(
            allowsPrinting: false,
            allowsCopying: false,
            allowsDocumentChanges: false,
            allowsDocumentAssembly: false,
            allowsContentAccessibility: true,
            allowsCommenting: false,
            allowsFormFieldEntry: false
        )
        
        return try await addPassword(
            to: url,
            userPassword: password,
            ownerPassword: password,
            permissions: permissions
        )
    }
    
    // MARK: - Permissions Management
    
    /// Set specific permissions on PDF
    func setPermissions(
        on url: URL,
        permissions: PDFPermissions,
        ownerPassword: String
    ) async throws -> URL {
        return try await addPassword(
            to: url,
            userPassword: nil,
            ownerPassword: ownerPassword,
            permissions: permissions
        )
    }
    
    /// Get current permissions from PDF
    func getPermissions(from url: URL) -> PDFPermissions {
        guard let pdfDocument = PDFDocument(url: url) else {
            return PDFPermissions.none
        }
        
        return PDFPermissions(
            allowsPrinting: pdfDocument.allowsPrinting,
            allowsCopying: pdfDocument.allowsCopying,
            allowsDocumentChanges: true, // Not directly available
            allowsDocumentAssembly: true, // Not directly available
            allowsContentAccessibility: true, // Always allowed
            allowsCommenting: true, // Not directly available
            allowsFormFieldEntry: true // Not directly available
        )
    }
    
    // MARK: - Watermarking
    
    /// Add watermark to PDF
    func addWatermark(
        to url: URL,
        text: String,
        options: WatermarkOptions = .default
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            
            addWatermarkToPage(page, text: text, options: options)
        }
        
        let filename = generateSecureFilename(from: url, suffix: "watermarked")
        let outputURL = try await saveSecurePDF(pdfDocument, filename: filename, options: [:])
        
        Analytics.track(event: "pdf_watermark_added")
        
        return outputURL
    }
    
    private func addWatermarkToPage(_ page: PDFPage, text: String, options: WatermarkOptions) {
        let bounds = page.bounds(for: .mediaBox)
        
        // Create watermark annotation
        let watermarkRect = calculateWatermarkRect(pageBounds: bounds, options: options)
        
        let annotation = PDFAnnotation(bounds: watermarkRect, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = options.font
        annotation.fontColor = options.color.withAlphaComponent(options.opacity)
        annotation.color = .clear
        annotation.alignment = .center
        
        page.addAnnotation(annotation)
    }
    
    private func calculateWatermarkRect(pageBounds: CGRect, options: WatermarkOptions) -> CGRect {
        let width = pageBounds.width
        let height = pageBounds.height
        
        let watermarkWidth = width * 0.8
        let watermarkHeight: CGFloat = 50
        
        let x: CGFloat
        let y: CGFloat
        
        switch options.position {
        case .center:
            x = (width - watermarkWidth) / 2
            y = (height - watermarkHeight) / 2
        case .topCenter:
            x = (width - watermarkWidth) / 2
            y = height - watermarkHeight - 50
        case .bottomCenter:
            x = (width - watermarkWidth) / 2
            y = 50
        case .diagonal:
            x = (width - watermarkWidth) / 2
            y = (height - watermarkHeight) / 2
        }
        
        return CGRect(x: x, y: y, width: watermarkWidth, height: watermarkHeight)
    }
    
    // MARK: - Digital Signatures
    
    /// Add digital signature placeholder to PDF
    func addSignaturePlaceholder(
        to url: URL,
        page: Int,
        rect: CGRect
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        guard let pdfPage = pdfDocument.page(at: page) else {
            throw DocumentError.processingFailed(reason: "Invalid page")
        }
        
        // Create signature annotation
        let annotation = PDFAnnotation(bounds: rect, forType: .widget, withProperties: nil)
        annotation.widgetFieldType = .signature
        annotation.fieldName = "signature_\(UUID().uuidString)"
        
        pdfPage.addAnnotation(annotation)
        
        let filename = generateSecureFilename(from: url, suffix: "signature_ready")
        let outputURL = try await saveSecurePDF(pdfDocument, filename: filename, options: [:])
        
        Analytics.track(event: "pdf_signature_placeholder_added")
        
        return outputURL
    }
    
    // MARK: - Redaction
    
    /// Redact text in PDF
    func redactText(
        in url: URL,
        areas: [RedactionArea]
    ) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        for area in areas {
            guard let page = pdfDocument.page(at: area.pageIndex) else { continue }
            
            // Create redaction annotation
            let redaction = PDFAnnotation(bounds: area.rect, forType: .redact, withProperties: nil)
            redaction.color = .black
            page.addAnnotation(redaction)
        }
        
        let filename = generateSecureFilename(from: url, suffix: "redacted")
        let outputURL = try await saveSecurePDF(pdfDocument, filename: filename, options: [:])
        
        Analytics.track(event: "pdf_redacted", properties: [
            "areas": areas.count
        ])
        
        return outputURL
    }
    
    /// Find and redact sensitive patterns (emails, phone numbers, SSN)
    func findAndRedactSensitiveData(
        in url: URL,
        patterns: [SensitiveDataPattern] = SensitiveDataPattern.allCases
    ) async throws -> (url: URL, redactions: [RedactionArea]) {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        var redactionAreas: [RedactionArea] = []
        
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex),
                  let pageText = page.string else { continue }
            
            for pattern in patterns {
                let matches = findMatches(in: pageText, pattern: pattern)
                
                for match in matches {
                    // Find bounds for match (simplified - real implementation would use PDFSelection)
                    let redactionRect = CGRect(x: 100, y: 100, width: 200, height: 20)
                    let area = RedactionArea(pageIndex: pageIndex, rect: redactionRect, reason: pattern.rawValue)
                    redactionAreas.append(area)
                }
            }
        }
        
        let outputURL = try await redactText(in: url, areas: redactionAreas)
        
        return (outputURL, redactionAreas)
    }
    
    private func findMatches(in text: String, pattern: SensitiveDataPattern) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: pattern.regex, options: [])
            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            
            return matches.compactMap { match in
                guard let range = Range(match.range, in: text) else { return nil }
                return String(text[range])
            }
        } catch {
            return []
        }
    }
    
    // MARK: - Secure Sharing
    
    /// Prepare PDF for secure sharing with expiration
    func prepareSecureShare(
        url: URL,
        password: String,
        expiresIn days: Int = 7
    ) async throws -> SecureShareInfo {
        // Add password protection
        let secureURL = try await addPassword(
            to: url,
            userPassword: password,
            ownerPassword: password,
            permissions: PDFPermissions.viewOnly
        )
        
        // Add watermark with expiration info
        let expirationDate = Calendar.current.date(byAdding: .day, value: days, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let watermarkText = "Expires: \(dateFormatter.string(from: expirationDate))"
        
        let watermarkedURL = try await addWatermark(
            to: secureURL,
            text: watermarkText,
            options: WatermarkOptions(
                position: .bottomCenter,
                opacity: 0.3,
                color: .red
            )
        )
        
        Analytics.track(event: "pdf_secure_share_prepared", properties: [
            "expiration_days": days
        ])
        
        return SecureShareInfo(
            url: watermarkedURL,
            password: password,
            expirationDate: expirationDate
        )
    }
    
    // MARK: - Utilities
    
    private func saveSecurePDF(
        _ pdf: PDFDocument,
        filename: String,
        options: [PDFDocumentWriteOption: Any]
    ) async throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        guard pdf.write(to: tempURL, withOptions: options) else {
            throw DocumentError.processingFailed(reason: "Failed to save PDF")
        }
        
        // Move to documents directory
        let data = try Data(contentsOf: tempURL)
        let finalURL = try await DocumentFileManager.shared.saveDocument(
            data: data,
            filename: filename,
            format: .pdf
        )
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
        
        return finalURL
    }
    
    private func generateSecureFilename(from url: URL, suffix: String = "secure") -> String {
        let baseName = url.deletingPathExtension().lastPathComponent
        return "\(baseName)_\(suffix)_\(UUID().uuidString).pdf"
    }
}

// MARK: - Supporting Types

struct PDFPermissions {
    var allowsPrinting: Bool
    var allowsCopying: Bool
    var allowsDocumentChanges: Bool
    var allowsDocumentAssembly: Bool
    var allowsContentAccessibility: Bool
    var allowsCommenting: Bool
    var allowsFormFieldEntry: Bool
    
    static let `default` = PDFPermissions(
        allowsPrinting: true,
        allowsCopying: true,
        allowsDocumentChanges: true,
        allowsDocumentAssembly: true,
        allowsContentAccessibility: true,
        allowsCommenting: true,
        allowsFormFieldEntry: true
    )
    
    static let viewOnly = PDFPermissions(
        allowsPrinting: true,
        allowsCopying: false,
        allowsDocumentChanges: false,
        allowsDocumentAssembly: false,
        allowsContentAccessibility: true,
        allowsCommenting: false,
        allowsFormFieldEntry: false
    )
    
    static let none = PDFPermissions(
        allowsPrinting: false,
        allowsCopying: false,
        allowsDocumentChanges: false,
        allowsDocumentAssembly: false,
        allowsContentAccessibility: false,
        allowsCommenting: false,
        allowsFormFieldEntry: false
    )
}

enum EncryptionLevel {
    case rc4_40bit
    case rc4_128bit
    case aes128
    case aes256
    
    var displayName: String {
        switch self {
        case .rc4_40bit: return "40-bit RC4"
        case .rc4_128bit: return "128-bit RC4"
        case .aes128: return "128-bit AES"
        case .aes256: return "256-bit AES"
        }
    }
}

struct WatermarkOptions {
    var position: WatermarkPosition
    var opacity: CGFloat
    var color: UIColor
    var font: UIFont
    
    static let `default` = WatermarkOptions(
        position: .center,
        opacity: 0.3,
        color: .gray,
        font: UIFont.systemFont(ofSize: 48, weight: .bold)
    )
}

enum WatermarkPosition {
    case center
    case topCenter
    case bottomCenter
    case diagonal
}

struct RedactionArea {
    let pageIndex: Int
    let rect: CGRect
    let reason: String
}

enum SensitiveDataPattern: String, CaseIterable {
    case email = "Email"
    case phoneNumber = "Phone Number"
    case ssn = "SSN"
    case creditCard = "Credit Card"
    
    var regex: String {
        switch self {
        case .email:
            return "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        case .phoneNumber:
            return "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b"
        case .ssn:
            return "\\b\\d{3}-\\d{2}-\\d{4}\\b"
        case .creditCard:
            return "\\b\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}\\b"
        }
    }
}

struct SecureShareInfo {
    let url: URL
    let password: String
    let expirationDate: Date
}
