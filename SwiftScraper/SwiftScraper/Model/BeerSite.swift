//  Created by Alexander Skorulis on 3/4/2026.

import Foundation

enum BeerSite: String, Codable {
    
    case danMurphys
    
    var rootPage: String {
        switch self {
        case .danMurphys:
            "https://www.danmurphys.com.au/beer/all"
        }
    }
    
    var rootURL: URL {
        URL(string: rootPage)!
    }
    
    var parser: SiteParser {
        switch self {
        case .danMurphys:
            return DanMurphysParser()
        }
    }
}
