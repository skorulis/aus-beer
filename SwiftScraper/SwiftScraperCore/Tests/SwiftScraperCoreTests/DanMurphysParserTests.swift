//
//  DanMurphysParserTests.swift
//  SwiftScraperCoreTests
//

import Foundation
import SwiftScraperCore
import Testing

private let fixturesDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("fixtures", isDirectory: true)

/// Mirrors `compareKey` / `sortForCompare` in `scraper/src/danmurphys.fixture.test.ts`.
private func compareKey(_ p: BeerRecord) -> String {
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

private func sortForCompare(_ products: [BeerRecord]) -> [BeerRecord] {
    products.sorted { compareKey($0).localizedStandardCompare(compareKey($1)) == .orderedAscending }
}

struct DanMurphysParserTests {

    @Test func parseFixtureMatchesExpectedJSON() throws {
        let htmlURL = fixturesDirectory.appendingPathComponent("danmurphys-beer-all.html")
        let expectedURL = fixturesDirectory.appendingPathComponent("danmurphys-beer-all.expected.json")

        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let expectedData = try Data(contentsOf: expectedURL)
        let decoder = JSONDecoder()
        let expected = try decoder.decode([BeerRecord].self, from: expectedData)

        let parser = DanMurphysParser()
        let actual = parser.parse(html: html)

        #expect(sortForCompare(actual) == sortForCompare(expected))
    }
}
