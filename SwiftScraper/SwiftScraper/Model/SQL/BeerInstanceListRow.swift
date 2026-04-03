//  Created by Alexander Skorulis on 4/4/2026.

import Foundation
import GRDB
import SwiftScraperCore

private enum BeerInstanceListRowDecodingError: Error {
    case invalidVessel(String)
}

/// A `beer_instance` row with joined `beer` and `brewery` for display.
struct BeerInstanceListRow: Identifiable, Sendable {

    let instance: BeerInstanceRecord
    let beer: BeerRecord
    let brewery: BreweryRecord

    var id: Int64 { instance.id }
}

extension BeerInstanceListRow: FetchableRecord {

    static let selectSQL = """
        SELECT
          bi.rowId AS instance_rowId,
          bi.beer AS instance_beer,
          bi.size AS instance_size,
          bi.vessel AS instance_vessel,
          b.rowId AS beer_rowId,
          b.brewery AS beer_brewery,
          b.name AS beer_name,
          b.untappdID AS beer_untappdID,
          br.rowId AS brewery_rowId,
          br.name AS brewery_name,
          br.untappdID AS brewery_untappdID
        FROM beer_instance bi
        INNER JOIN beer b ON b.rowId = bi.beer
        INNER JOIN brewery br ON br.rowId = b.brewery
        ORDER BY brewery_name COLLATE NOCASE, beer_name COLLATE NOCASE, instance_size
        """

    init(row: Row) throws {
        let vesselRaw: String = row["instance_vessel"]
        guard let vessel = VesselType(rawValue: vesselRaw) else {
            throw BeerInstanceListRowDecodingError.invalidVessel(vesselRaw)
        }
        instance = BeerInstanceRecord(
            rowId: row["instance_rowId"],
            beer: row["instance_beer"],
            size: row["instance_size"],
            vessel: vessel
        )
        beer = BeerRecord(
            rowId: row["beer_rowId"],
            brewery: row["beer_brewery"],
            name: row["beer_name"],
            untappdID: row["beer_untappdID"]
        )
        brewery = BreweryRecord(
            rowId: row["brewery_rowId"],
            name: row["brewery_name"],
            untappdID: row["brewery_untappdID"]
        )
    }
}
