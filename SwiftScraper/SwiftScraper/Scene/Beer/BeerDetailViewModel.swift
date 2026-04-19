//  Created by Alex Skorulis on 19/4/2026.

import ASKCoordinator
import Foundation
import Knit
import KnitMacros
import UntappdAPI

@Observable final class BeerDetailViewModel: CoordinatorViewModel {
    weak var coordinator: ASKCoordinator.Coordinator?
    
    let row: BeerInstanceListRow
    private let untappdService: UntappdService
    
    @Resolvable<Resolver>
    init(@Argument row: BeerInstanceListRow, untappdService: UntappdService) {
        self.row = row
        self.untappdService = untappdService
    }
}

// MARK: - Actions

extension BeerDetailViewModel {
    func findUntappdBeer() {
        Task {
            let searchTerm = "\(row.brewery.name) \(row.beer.name)"
            do {
                let results = try await untappdService.search(text: searchTerm)
                print(results)
            } catch {
                print("Failure: \(error)")
            }
        }
    }
}

