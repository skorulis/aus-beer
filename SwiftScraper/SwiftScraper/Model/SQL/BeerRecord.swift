//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import GRDB

struct BeerRecord: Codable, Identifiable, Sendable {

    var id: Int64 { rowId ?? -1 }

    private var rowId: Int64?
    let brewery: Int64
    let name: String
    var untappdID: String?

    init(
        rowId: Int64? = nil,
        brewery: Int64,
        name: String,
        untappdID: String? = nil
    ) {
        self.rowId = rowId
        self.brewery = brewery
        self.name = name
        self.untappdID = untappdID
    }
}

extension BeerRecord: TableRecord {
    static var databaseTableName: String { "beer" }
}

extension BeerRecord: FetchableRecord {

    enum Columns: String, ColumnExpression {
        case rowId, brewery, name, untappdID
    }
}
