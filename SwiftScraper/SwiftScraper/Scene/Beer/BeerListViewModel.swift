//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import GRDB
import Knit
import KnitMacros

@MainActor @Observable final class BeerListViewModel {

    private let sqlStore: SQLStore

    var beerInstances: [BeerInstanceListRow] = []
    var selectedBeerInstanceID: Int64?
    var lastErrorMessage: String?

    var selectedBeerInstance: BeerInstanceListRow? {
        guard let id = selectedBeerInstanceID else { return nil }
        return beerInstances.first { $0.id == id }
    }

    @Resolvable<Resolver>
    init(sqlStore: SQLStore) {
        self.sqlStore = sqlStore
    }
}

extension BeerListViewModel {

    func loadBeers() {
        do {
            beerInstances = try sqlStore.dbQueue.read { db in
                try BeerInstanceListRow.fetchAll(db, sql: BeerInstanceListRow.selectSQL)
            }
            if let id = selectedBeerInstanceID, !beerInstances.contains(where: { $0.id == id }) {
                selectedBeerInstanceID = nil
            }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

