//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import GRDB

struct BreweryRecord: Codable, Identifiable, Sendable, MutablePersistableRecord {
    
    var id: Int64 { return rowId ?? -1 }
    
    private var rowId: Int64?
    let name: String
    var untappdID: String?
    
    init(
        rowId: Int64? = nil,
        name: String,
        untappdID: String? = nil
    ) {
        self.rowId = rowId
        self.name = name
        self.untappdID = untappdID
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        rowId = inserted.rowID
    }
}

extension BreweryRecord: TableRecord {
    static var databaseTableName: String { "brewery" }
}

extension BreweryRecord: FetchableRecord {
    
    enum Columns: String, ColumnExpression {
        case rowId, name, untappdID
    }
    
}
