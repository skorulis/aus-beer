//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import GRDB

struct SupplierRecord: Codable, Identifiable, Sendable, MutablePersistableRecord {

    var id: Int64 { rowId ?? -1 }

    private var rowId: Int64?
    let name: String

    init(rowId: Int64? = nil, name: String) {
        self.rowId = rowId
        self.name = name
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        rowId = inserted.rowID
    }
}

extension SupplierRecord: TableRecord {
    static var databaseTableName: String { "supplier" }
}

extension SupplierRecord: FetchableRecord {

    enum Columns: String, ColumnExpression {
        case rowId, name
    }
}
