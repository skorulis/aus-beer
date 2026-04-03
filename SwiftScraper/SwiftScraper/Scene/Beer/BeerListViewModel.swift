//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import GRDB
import Knit
import KnitMacros

@MainActor @Observable final class BeerListViewModel {

    private let sqlStore: SQLStore

    var beers: [BeerRecord] = []
    var lastErrorMessage: String?

    @Resolvable<Resolver>
    init(sqlStore: SQLStore) {
        self.sqlStore = sqlStore
    }
}

extension BeerListViewModel {

    func loadBeers() {
        do {
            beers = try sqlStore.dbQueue.read { db in
                try BeerRecord.fetchAll(db)
            }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

