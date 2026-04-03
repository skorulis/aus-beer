//  Created by Alexander Skorulis on 3/4/2026.

import Foundation

public struct ParsingResult: Codable, Sendable {
    public let source: BeerSite
    public let scrapedAt: Date
    public let products: [BeerRecord]

    public init(source: BeerSite, scrapedAt: Date, products: [BeerRecord]) {
        self.source = source
        self.scrapedAt = scrapedAt
        self.products = products
    }
}
