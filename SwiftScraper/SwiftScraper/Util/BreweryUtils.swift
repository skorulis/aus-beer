//  Created by Alex Skorulis on 19/4/2026.

import Foundation

enum BreweryUtils {
    static func simplifiedName(_ name: String) -> String {
        return name.replacingOccurrences(of: " Brewing Company", with: "")
    }
}
