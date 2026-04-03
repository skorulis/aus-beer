//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import GRDB

struct PricePointRecord: Codable, Identifiable, Sendable, MutablePersistableRecord {

    var id: Int64 { rowId ?? -1 }

    private var rowId: Int64?
    let beerInstance: Int64
    let price: Double
    let quantity: Int
    let date: Date

    init(
        rowId: Int64? = nil,
        beerInstance: Int64,
        price: Double,
        quantity: Int,
        date: Date
    ) {
        self.rowId = rowId
        self.beerInstance = beerInstance
        self.price = price
        self.quantity = quantity
        self.date = date
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        rowId = inserted.rowID
    }
}

extension PricePointRecord: TableRecord {
    static var databaseTableName: String { "price_points" }
}

extension PricePointRecord: FetchableRecord {

    enum Columns: String, ColumnExpression {
        case rowId, beerInstance, price, quantity, date
    }
}
