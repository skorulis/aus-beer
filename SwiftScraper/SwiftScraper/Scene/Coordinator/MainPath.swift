//  Created by Alexander Skorulis on 4/4/2026.

import ASKCoordinator
import Foundation
import Knit
import SwiftUI
import UntappdAPI

enum MainPath: CoordinatorPath {
    case beerList
    case beerDetails(BeerInstanceListRow)
    case untappdSearch(UntappdSearchPath)
    
    public var id: String {
        switch self {
        case .beerList:
            return String(describing: self)
        case let .beerDetails(row):
            return "beer-details-\(row.id)"
        case let .untappdSearch(path):
            return path.id
        }
    }
}

struct UntappdSearchPath: CoordinatorPath {
    let id = "untappd-search-\(UUID().uuidString)"
    let items: [UntappdSearchResponse.Item]
    let onSelect: (UntappdSearchResponse.Item) -> Void
}

struct MainPathRenderer: CoordinatorPathRenderer {
 
    let resolver: Resolver

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    @ViewBuilder func render(path: MainPath, in coordinator: Coordinator) -> some View {
        switch path {
        case .beerList:
            BeerListView(viewModel: resolver.beerListViewModel())
        case .beerDetails(let row):
            BeerDetailView(viewModel: coordinator.apply(resolver.beerDetailViewModel(row: row)))
        case .untappdSearch(let path):
            BeerUntappdSearchListView(
                items: path.items,
                onSelect: { item in
                    path.onSelect(item)
                    coordinator.dismissOverlay()
                }
            )
        }
    }
}
