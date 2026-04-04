//  Created by Alex Skorulis on 4/4/2026.

import SwiftScraperCore
import Foundation

enum TestHelpers {
    static let fixturesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("fixtures", isDirectory: true)

    static func compareKey(_ p: ParsedBeer) -> String {
        let priceKeys = p.prices
            .map { price in
                let member = price.memberOffer.map { String($0) } ?? "nil"
                return "\(price.price)|\(price.quantity)|\(member)"
            }
            .sorted()
            .joined(separator: ";")
        return [
            (p.brewery ?? "").lowercased(),
            p.name.lowercased(),
            String(p.sizeMl),
            p.vesselType?.rawValue ?? "",
            priceKeys,
        ]
        .joined(separator: "\0")
    }

    static func sortForCompare(_ products: [ParsedBeer]) -> [ParsedBeer] {
        products.sorted { compareKey($0).localizedStandardCompare(compareKey($1)) == .orderedAscending }
    }
}
