//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import GRDB

extension SQLStore {
    static let migrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_schema") { db in
            try db.create(table: "brewery", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("rowId")
                t.column("name", .text).notNull().unique()
                t.column("untappdID", .text)
            }
            try db.create(table: "beer", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("rowId")
                t.column("brewery", .integer)
                    .notNull()
                    .references("brewery", column: "rowId", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("untappdID", .text)
                t.uniqueKey(["brewery", "name"])
            }
            try db.create(table: "beer_instance", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("rowId")
                t.column("beer", .integer)
                    .notNull()
                    .references("beer", column: "rowId", onDelete: .cascade)
                t.column("size", .integer).notNull()
                t.column("vessel", .text).notNull()
            }
            try db.create(table: "price_points", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("rowId")
                t.column("beerInstance", .integer)
                    .notNull()
                    .references("beer_instance", column: "rowId", onDelete: .cascade)
                t.column("price", .double).notNull()
                t.column("quantity", .integer).notNull()
                t.column("date", .datetime).notNull()
            }
        }
        return migrator
    }()
}
