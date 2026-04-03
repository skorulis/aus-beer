//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import Knit
import SwiftScraperCore
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

            List(viewModel.beerInstances) { row in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.beer.name)
                            .font(.subheadline)
                        Text(row.brewery.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text("\(row.instance.size) ml · \(row.instance.vessel.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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

