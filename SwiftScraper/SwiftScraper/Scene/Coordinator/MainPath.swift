//
//  MainPath.swift
//  SwiftScraper
//
//  Created by Alexander Skorulis on 4/4/2026.
//

import ASKCoordinator
import Foundation
import Knit
import SwiftUI

enum MainPath: CoordinatorPath {
    case beerList
    
    public var id: String {
        switch self {
        case .beerList:
            return String(describing: self)
        }
    }
}

struct MainPathRenderer: CoordinatorPathRenderer {
 
    let resolver: Resolver

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    @ViewBuilder func render(path: MainPath, in coordinator: Coordinator) -> some View {
        switch path {
        case .beerList:
            BeerListView(viewModel: resolver.beerListViewModel())
        }
    }
}
