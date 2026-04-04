//  Created by Alexander Skorulis on 3/4/2026.

import Foundation

public enum BeerSite: String, Codable, Sendable, CaseIterable, Identifiable {

    public var id: String { rawValue }
    
    case danMurphys
    case bwsCraftBeer

    public var rootPage: String {
        switch self {
        case .danMurphys:
            "https://www.danmurphys.com.au/beer/all"
        case .bwsCraftBeer:
            "https://bws.com.au/beer/craft-beer"
        }
    }

    public var rootURL: URL {
        URL(string: rootPage)!
    }

    public var parser: SiteParser {
        switch self {
        case .danMurphys:
            return DanMurphysParser()
        case .bwsCraftBeer:
            return BWSParser()
        }
    }

    /// Retailer name stored on `SupplierRecord` / `price_points.supplier`.
    public var supplierName: String {
        switch self {
        case .danMurphys:
            "Dan Murphy's"
        case .bwsCraftBeer:
            "BWS"
        }
    }
}
