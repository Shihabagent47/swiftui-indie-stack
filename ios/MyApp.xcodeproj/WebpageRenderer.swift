//
//  WebpageRenderer.swift
//  MyApp
//
//  Renders webpages to PDF using WKWebView.
//

import Foundation
import WebKit
import UIKit

/// Renders webpages to PDF format
actor WebpageRenderer {
    
    static let shared = WebpageRenderer()
    
    private init() {}
    
    // MARK: - Webpage to PDF
    
    /// Render a webpage to PDF
    @MainActor
    func renderWebpageToPDF(url: URL, title: String) async throws -> URL {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 612, height: 792))
        
        // Configure web view for PDF rendering
        webView.isOpaque = false
        webView.backgroundColor = .white
        
        // Load the webpage
        let request = URLRequest(url: url)
        webView.load(request)
        
        // Wait for page to load
        try await waitForPageLoad(webView)
        
        // Create PDF data
        let pdfData = try await createPDFData(from: webView)
        
        // Save to file
        let filename = "\(title).pdf"
        let pdfURL = try await DocumentFileManager.shared.saveDocument(
            data: pdfData,
            filename: filename,
            format: .pdf
        )
        
        Analytics.track(event: "webpage_imported", properties: [
            "url": url.absoluteString
        ])
        
        return pdfURL
    }
    
    /// Render HTML string to PDF
    @MainActor
    func renderHTMLToPDF(html: String, baseURL: URL? = nil, title: String) async throws -> URL {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 612, height: 792))
        
        webView.isOpaque = false
        webView.backgroundColor = .white
        
        // Load HTML
        webView.loadHTMLString(html, baseURL: baseURL)
        
        // Wait for page to load
        try await waitForPageLoad(webView)
        
        // Create PDF data
        let pdfData = try await createPDFData(from: webView)
        
        // Save to file
        let filename = "\(title).pdf"
        return try await DocumentFileManager.shared.saveDocument(
            data: pdfData,
            filename: filename,
            format: .pdf
        )
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func waitForPageLoad(_ webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var observer: NSKeyValueObservation?
            var hasResumed = false
            
            observer = webView.observe(\.isLoading, options: [.new]) { webView, change in
                guard let isLoading = change.newValue, !isLoading else { return }
                
                // Page finished loading
                if !hasResumed {
                    hasResumed = true
                    observer?.invalidate()
                    continuation.resume()
                }
            }
            
            // Timeout after 30 seconds
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if !hasResumed {
                    hasResumed = true
                    observer?.invalidate()
                    continuation.resume(throwing: DocumentError.processingFailed(reason: "Webpage load timeout"))
                }
            }
        }
    }
    
    @MainActor
    private func createPDFData(from webView: WKWebView) async throws -> Data {
        // Calculate proper page height based on content
        let contentHeight = await webView.evaluateJavaScript("document.body.scrollHeight") as? CGFloat ?? 792
        
        // Configure PDF renderer
        let pageWidth: CGFloat = 612 // US Letter width
        let pageHeight: CGFloat = 792 // US Letter height
        
        let printFormatter = webView.viewPrintFormatter()
        
        let printRenderer = UIPrintPageRenderer()
        printRenderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)
        
        // Set up page frame
        let pageFrame = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let printableRect = pageFrame.insetBy(dx: 36, dy: 36) // 0.5 inch margins
        
        printRenderer.setValue(pageFrame, forKey: "paperRect")
        printRenderer.setValue(printableRect, forKey: "printableRect")
        
        // Create PDF data
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)
        
        for pageIndex in 0..<printRenderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            
            let bounds = UIGraphicsGetPDFContextBounds()
            printRenderer.drawPage(at: pageIndex, in: bounds)
        }
        
        UIGraphicsEndPDFContext()
        
        guard pdfData.length > 0 else {
            throw DocumentError.processingFailed(reason: "Failed to create PDF from webpage")
        }
        
        return pdfData as Data
    }
    
    // MARK: - Batch Webpage Rendering
    
    /// Render multiple webpages to PDFs
    @MainActor
    func batchRenderWebpages(_ urls: [URL]) async throws -> [WebpageRenderResult] {
        var results: [WebpageRenderResult] = []
        
        for url in urls {
            do {
                let title = url.host ?? "webpage"
                let pdfURL = try await renderWebpageToPDF(url: url, title: title)
                
                results.append(WebpageRenderResult(
                    sourceURL: url,
                    outputURL: pdfURL,
                    success: true,
                    error: nil
                ))
            } catch {
                results.append(WebpageRenderResult(
                    sourceURL: url,
                    outputURL: nil,
                    success: false,
                    error: error
                ))
            }
        }
        
        Analytics.track(event: "batch_webpage_render_completed", properties: [
            "total": urls.count,
            "successful": results.filter { $0.success }.count
        ])
        
        return results
    }
}

// MARK: - Supporting Types

struct WebpageRenderResult {
    let sourceURL: URL
    let outputURL: URL?
    let success: Bool
    let error: Error?
}

// MARK: - WKWebView Extension

extension WKWebView {
    /// Convenience method to get page title
    var pageTitle: String? {
        get async {
            try? await evaluateJavaScript("document.title") as? String
        }
    }
}
