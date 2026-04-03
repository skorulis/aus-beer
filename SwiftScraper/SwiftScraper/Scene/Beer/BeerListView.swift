//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import Knit
import SwiftUI

// MARK: - Memory footprint

@MainActor struct BeerListView {

    @State var viewModel: BeerListViewModel
}

// MARK: - Rendering

extension BeerListView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = viewModel.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding([.horizontal, .top])
            }

            List(viewModel.beers) { beer in
                Text(beer.name)
            }
        }
        .onAppear {
            viewModel.loadBeers()
        }
    }
}

// MARK: - Previews

#Preview {
    let assembler = SwiftScraperAssembly.testing()
    BeerListView(viewModel: assembler.resolver.beerListViewModel())
}

