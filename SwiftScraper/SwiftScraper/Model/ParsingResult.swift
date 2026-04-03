//  Created by Alexander Skorulis on 3/4/2026.

import Foundation

struct ParsingResult: Codable {
    let source: BeerSite
    let scrapedAt: Date
    let products: [BeerRecord]
}
