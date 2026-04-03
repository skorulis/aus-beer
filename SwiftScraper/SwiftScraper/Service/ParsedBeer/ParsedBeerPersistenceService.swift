//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import GRDB
import Knit
import KnitMacros
import SwiftScraperCore

/// Persists scraped `ParsedBeer` rows into SQLite via `SQLStore`.
///
/// - **Breweries**: Ensured for each parsed row (inserted when missing, matched by exact `name`).
/// - **Beers**: Inserted only when no row exists for the same `(brewery id, beer name)`.
///   Subsequent parses skip beers that already exist so only **new** beers are inserted.
/// - **Instances & price points**: Written only for newly inserted beers.
struct ParsedBeerPersistenceResult: Sendable, Equatable {
    var breweriesInserted: Int
    var newBeersInserted: Int
    var existingBeersSkipped: Int
}

final class ParsedBeerPersistenceService: Sendable {

    private let sqlStore: SQLStore

    @Resolvable<Resolver>
    init(sqlStore: SQLStore) {
        self.sqlStore = sqlStore
    }

    func persistParsedBeers(_ beers: [ParsedBeer]) throws -> ParsedBeerPersistenceResult {
        let now = Date()
        return try sqlStore.dbQueue.write { db in
            var breweriesInserted = 0
            var newBeersInserted = 0
            var existingBeersSkipped = 0

            for parsed in beers {
                let trimmedName = parsed.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else { continue }

                let breweryName = parsed.brewery?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? Self.unknownBreweryPlaceholder

                let (breweryId, insertedBrewery) = try breweryIdEnsuringExists(db: db, name: breweryName)
                if insertedBrewery {
                    breweriesInserted += 1
                }

                if try beerExists(db: db, breweryId: breweryId, name: trimmedName) {
                    existingBeersSkipped += 1
                    continue
                }

                var beerRow = BeerRecord(brewery: breweryId, name: trimmedName)
                try beerRow.insert(db)
                let beerId = beerRow.id

                let vessel = parsed.vesselType ?? .can
                var instanceRow = BeerInstanceRecord(beer: beerId, size: parsed.sizeMl, vessel: vessel)
                try instanceRow.insert(db)
                let instanceId = instanceRow.id

                for price in parsed.prices {
                    var priceRow = PricePointRecord(
                        beerInstance: instanceId,
                        price: price.price,
                        quantity: price.quantity,
                        date: now
                    )
                    try priceRow.insert(db)
                }

                newBeersInserted += 1
            }

            return ParsedBeerPersistenceResult(
                breweriesInserted: breweriesInserted,
                newBeersInserted: newBeersInserted,
                existingBeersSkipped: existingBeersSkipped
            )
        }
    }

    private static let unknownBreweryPlaceholder = "Unknown brewery"

    /// Returns `(rowId, didInsert)`.
    private func breweryIdEnsuringExists(db: Database, name: String) throws -> (Int64, Bool) {
        let sql = "SELECT rowId FROM brewery WHERE name = ?"
        if let id = try Int64.fetchOne(db, sql: sql, arguments: [name]) {
            return (id, false)
        }
        var row = BreweryRecord(name: name)
        try row.insert(db)
        return (row.id, true)
    }

    private func beerExists(db: Database, breweryId: Int64, name: String) throws -> Bool {
        let sql = "SELECT rowId FROM beer WHERE brewery = ? AND name = ? LIMIT 1"
        return try Int64.fetchOne(db, sql: sql, arguments: [breweryId, name]) != nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
