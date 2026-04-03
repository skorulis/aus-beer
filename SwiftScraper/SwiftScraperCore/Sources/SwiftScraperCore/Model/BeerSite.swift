//  Created by Alexander Skorulis on 3/4/2026.

import Foundation

public enum BeerSite: String, Codable, Sendable {

    case danMurphys

    public var rootPage: String {
        switch self {
        case .danMurphys:
            "https://www.danmurphys.com.au/beer/all"
        }
    }

    public var rootURL: URL {
        URL(string: rootPage)!
    }

    public var parser: SiteParser {
        switch self {
        case .danMurphys:
            return DanMurphysParser()
        }
    }
}
