//  Created by Alexander Skorulis on 3/4/2026.

import Foundation

protocol SiteParser {
    func parse(html: String) -> [BeerRecord]
}
