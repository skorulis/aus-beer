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
    }
    
    static func `default`() -> SQLStore {
        return .init(inMemory: false)
    }
    
    static func inMemory() -> SQLStore {
        return .init(inMemory: true)
    }
    
}

