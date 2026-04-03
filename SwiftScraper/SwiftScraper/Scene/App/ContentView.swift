//  Created by Alexander Skorulis on 3/4/2026.

import SwiftUI
import Knit
import SwiftScraperCore

private let danMurphysBeerListURL = BeerSite.danMurphys.rootURL

struct ContentView: View {
    
    @State var viewModel: ContentViewModel

    var body: some View {
        VStack(spacing: 0) {
            WebView(url: danMurphysBeerListURL, store: viewModel.webViewStore)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                actions
                if let toolbarStatus = viewModel.toolbarStatus {
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
    
    private var actions: some View {
        HStack(spacing: 12) {
            Button("Save HTML to tmp") {
                Task { await viewModel.saveHTMLToTmp() }
            }
            Button("Show more") {
                Task { await viewModel.clickShowMore() }
            }
            Spacer(minLength: 0)
        }
    }

}

#Preview {
    let assembler = SwiftScraperAssembly.testing()
    ContentView(viewModel: assembler.resolver.contentViewModel())
}
