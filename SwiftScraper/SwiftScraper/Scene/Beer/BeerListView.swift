//  Created by Alexander Skorulis on 3/4/2026.

import ASKCoordinator
import Foundation
import Knit
import SwiftScraperCore
import SwiftUI

// MARK: - Memory footprint

@MainActor struct BeerListView {

    @State var viewModel: BeerListViewModel
    @Environment(\.resolver) var resolver
}

// MARK: - Rendering

extension BeerListView: View {

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                if let message = viewModel.lastErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding([.horizontal, .top])
                }

                List(viewModel.beerInstances, selection: $viewModel.selectedBeerInstanceID) { row in
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
            .navigationTitle("Beers")
        } detail: {
            Group {
                if let row = viewModel.selectedBeerInstance {
                    CoordinatorView(
                        coordinator: Coordinator(root: MainPath.beerDetails(row))
                    )
                    .withRenderers(resolver: resolver!)
                    .id(row.id)
                } else {
                    ContentUnavailableView(
                        "No Selection",
                        systemImage: "mug.fill",
                        description: Text("Select a beer in the list to see its details.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

