//
//  DanMurphysParserTests.swift
//  SwiftScraperCoreTests
//

import Foundation
import SwiftScraperCore
import Testing

struct DanMurphysParserTests {

    @Test func parseFixtureMatchesExpectedJSON() throws {
        let htmlURL = TestHelpers.fixturesDirectory.appendingPathComponent("danmurphys-beer-all.html")
        let expectedURL = TestHelpers.fixturesDirectory.appendingPathComponent("danmurphys-beer-all.expected.json")

        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let expectedData = try Data(contentsOf: expectedURL)
        let decoder = JSONDecoder()
        let expected = try decoder.decode([ParsedBeer].self, from: expectedData)

        let parser = DanMurphysParser()
        let actual = parser.parse(html: html)

        #expect(TestHelpers.sortForCompare(actual) == TestHelpers.sortForCompare(expected))
    }
}
