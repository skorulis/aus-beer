//  Created by Alexander Skorulis on 3/4/2026.

import SwiftUI

private let danMurphysBeerListURL = URL(string: "https://www.danmurphys.com.au/beer/all")!

struct ContentView: View {
    
    // @State var viewModel: ContentViewModel
    
    @StateObject private var webViewStore = WebViewStore()
    @State private var toolbarStatus: String?

    var body: some View {
        VStack(spacing: 0) {
            WebView(url: danMurphysBeerListURL, store: webViewStore)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Button("Save HTML to tmp") {
                        Task { await saveHTMLToTmp() }
                    }
                    Spacer(minLength: 0)
                }
                if let toolbarStatus {
                    Text(toolbarStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }

    private func saveHTMLToTmp() async {
        do {
            let url = try await webViewStore.saveCurrentHTMLToTemporaryFile()
            toolbarStatus = url.path
        } catch {
            toolbarStatus = "Error: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
