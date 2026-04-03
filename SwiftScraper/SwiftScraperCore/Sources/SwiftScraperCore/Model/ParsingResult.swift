//  Created by Alexander Skorulis on 3/4/2026.

import Foundation

public struct ParsingResult: Codable, Sendable {
    public let source: BeerSite
    public let scrapedAt: Date
    public let products: [ParsedBeer]

    public init(source: BeerSite, scrapedAt: Date, products: [ParsedBeer]) {
        self.source = source
        self.scrapedAt = scrapedAt
        self.products = products
    }
}
