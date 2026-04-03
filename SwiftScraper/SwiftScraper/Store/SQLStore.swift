//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import GRDB

final class SQLStore {
    
    static var docDir: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private static let dbURL: URL = docDir.appending(path: "db.sqlite")
    private static var dbPath: String {
        return dbURL.pathComponents.joined(separator: "/")
    }
    
    let dbQueue: DatabaseQueue
    
    init(inMemory: Bool = false) {
        print("SQL STARTED: \(Self.dbPath)")
        if inMemory {
            self.dbQueue = try! DatabaseQueue(path: "file::memory")
        } else {
            self.dbQueue = try! DatabaseQueue(path: Self.dbPath)
        }
        try! Self.migrator.migrate(self.dbQueue)
    }

    /// Removes every row from app data tables (order respects foreign keys). Does not touch `grdb_migrations`.
    func clearAllUserData() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM price_points")
            try db.execute(sql: "DELETE FROM beer_instance")
            try db.execute(sql: "DELETE FROM beer")
            try db.execute(sql: "DELETE FROM brewery")
            try db.execute(sql: "DELETE FROM supplier")
        }
    }

    static func `default`() -> SQLStore {
        return .init(inMemory: false)
    }
    
    static func inMemory() -> SQLStore {
        return .init(inMemory: true)
    }
    
}

