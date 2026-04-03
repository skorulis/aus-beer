//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import GRDB
import SwiftScraperCore

struct BeerInstanceRecord: Codable, Identifiable, Sendable, MutablePersistableRecord {

    var id: Int64 { rowId ?? -1 }

    private var rowId: Int64?
    let beer: Int64
    let size: Int
    let vessel: VesselType

    init(
        rowId: Int64? = nil,
        beer: Int64,
        size: Int,
        vessel: VesselType
    ) {
        self.rowId = rowId
        self.beer = beer
        self.size = size
        self.vessel = vessel
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        rowId = inserted.rowID
    }
}

extension BeerInstanceRecord: TableRecord {
    static var databaseTableName: String { "beer_instance" }
}

extension BeerInstanceRecord: FetchableRecord {

    enum Columns: String, ColumnExpression {
        case rowId, beer, size, vessel
    }
}
