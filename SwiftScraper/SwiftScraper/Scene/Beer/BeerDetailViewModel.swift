//  Created by Alex Skorulis on 19/4/2026.

import ASKCoordinator
import Foundation
import GRDB
import Knit
import KnitMacros
import UntappdAPI

@Observable final class BeerDetailViewModel: CoordinatorViewModel {
    weak var coordinator: ASKCoordinator.Coordinator?
    
    var row: BeerInstanceListRow
    
    private let sqlStore: SQLStore
    private let untappdService: UntappdService
    
    @Resolvable<Resolver>
    init(@Argument row: BeerInstanceListRow, sqlStore: SQLStore, untappdService: UntappdService) {
        self.row = row
        self.sqlStore = sqlStore
        self.untappdService = untappdService
    }
}

// MARK: - Actions

extension BeerDetailViewModel {
    func findUntappdBeer() {
        Task {
            let breweryName = BreweryUtils.simplifiedName(row.brewery.name)
            let searchTerm = "\(breweryName) \(row.beer.name)"
            do {
                let results = try await untappdService.search(text: searchTerm)
                let items = results.response.beers.items
                guard !items.isEmpty else { return }
                let path = UntappdSearchPath(items: items, onSelect: { [weak self] item in
                    self?.setUntappdID(String(item.beer.bid))
                })
                await MainActor.run {
                    coordinator?.custom(overlay: .basicDialog, MainPath.untappdSearch(path))
                }
            } catch {
                print("Failure: \(error)")
            }
        }
    }
    
    func clearUntappdID() {
        setUntappdID(nil)
    }
    
    private func setUntappdID(_ id: String?) {
        do {
            var beer = row.beer
            beer.untappdID = id
            try sqlStore.dbQueue.write { db in
                try beer.update(db)
            }
            row = .init(instance: row.instance, beer: beer, brewery: row.brewery)
        } catch {
            print("Failed to save untappd id: \(error)")
        }
    }
}

