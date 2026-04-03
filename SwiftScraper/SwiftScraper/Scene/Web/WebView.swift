//  Created by Alexander Skorulis on 3/4/2026.

import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    let store: WebViewStore

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        store.webView = webView
        context.coordinator.lastLoadedURL = url
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedURL != url else { return }
        context.coordinator.lastLoadedURL = url
        webView.load(URLRequest(url: url))
    }

    final class Coordinator {
        var lastLoadedURL: URL?
    }
}
