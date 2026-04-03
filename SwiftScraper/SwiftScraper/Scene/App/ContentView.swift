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
                if !viewModel.parsedBeers.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(viewModel.parsedBeers.enumerated()), id: \.offset) { _, beer in
                                BeerCell(beer: beer)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
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
            Button("Parse beers") {
                Task { await viewModel.parseBeersFromCurrentPage() }
            }
            Spacer(minLength: 0)
        }
    }

}

#Preview {
    let assembler = SwiftScraperAssembly.testing()
    ContentView(viewModel: assembler.resolver.contentViewModel())
}
