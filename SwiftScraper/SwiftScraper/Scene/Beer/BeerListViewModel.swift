//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import GRDB
import Knit
import KnitMacros

@MainActor @Observable final class BeerListViewModel {

    private let sqlStore: SQLStore

    var beerInstances: [BeerInstanceListRow] = []
    var lastErrorMessage: String?

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
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

