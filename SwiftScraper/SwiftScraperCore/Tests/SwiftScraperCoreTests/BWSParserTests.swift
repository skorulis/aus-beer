//
//  BWSParserTests.swift
//  SwiftScraperCoreTests
//

import Foundation
import SwiftScraperCore
import Testing

struct BWSParserTests {

    @Test func parseFixtureMatchesExpectedJSON() throws {
        let htmlURL = TestHelpers.fixturesDirectory.appendingPathComponent("bwsCraftBeer.html")
        let expectedURL = TestHelpers.fixturesDirectory.appendingPathComponent("bwsCraftBeer.expected.json")

        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let expectedData = try Data(contentsOf: expectedURL)
        let decoder = JSONDecoder()
        let expected = try decoder.decode([ParsedBeer].self, from: expectedData)

        let parser = BWSParser()
        let actual = parser.parse(html: html)

        #expect(TestHelpers.sortForCompare(actual) == TestHelpers.sortForCompare(expected))
    }
}
