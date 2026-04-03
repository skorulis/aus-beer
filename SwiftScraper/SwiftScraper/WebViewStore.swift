//  Created by Alexander Skorulis on 3/4/2026.

import Combine
import Foundation
import WebKit

enum WebViewStoreError: Error, LocalizedError {
    case noWebView
    case javaScriptFailed(Error?)
    case invalidResult

    var errorDescription: String? {
        switch self {
        case .noWebView:
            "Web view is not ready."
        case .javaScriptFailed(let underlying):
            if let underlying {
                underlying.localizedDescription
            } else {
                "JavaScript evaluation failed."
            }
        case .invalidResult:
            "Could not read HTML from the page."
        }
    }
}

final class WebViewStore: ObservableObject {
    weak var webView: WKWebView?

    /// Writes `document.documentElement.outerHTML` to a new file in the system temporary directory.
    func saveCurrentHTMLToTemporaryFile() async throws -> URL {
        let html = try await captureOuterHTML()
        let name = "danmurphys-\(Int(Date().timeIntervalSince1970)).html"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try html.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func captureOuterHTML() async throws -> String {
        guard let webView else { throw WebViewStoreError.noWebView }
        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript("document.documentElement.outerHTML") { result, error in
                if let error {
                    continuation.resume(throwing: WebViewStoreError.javaScriptFailed(error))
                    return
                }
                guard let html = result as? String else {
                    continuation.resume(throwing: WebViewStoreError.invalidResult)
                    return
                }
                continuation.resume(returning: html)
            }
        }
    }
}
