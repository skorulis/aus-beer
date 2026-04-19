//  Created by Alex Skorulis on 19/4/2026.

import Foundation
import Knit
import KnitMacros
import UntappdAPI

@Observable final class BeerDetailViewModel {
    
    let row: BeerInstanceListRow
    private let untappdService: UntappdService
    
    @Resolvable<Resolver>
    init(@Argument row: BeerInstanceListRow, untappdService: UntappdService) {
        self.row = row
        self.untappdService = untappdService
    }
}
