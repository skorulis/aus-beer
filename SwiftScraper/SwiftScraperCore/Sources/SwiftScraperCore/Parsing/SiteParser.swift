//  Created by Alexander Skorulis on 3/4/2026.

import Foundation

public protocol SiteParser: Sendable {
    func parse(html: String) -> [BeerRecord]
}
