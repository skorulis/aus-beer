//  Created by Alexander Skorulis on 3/4/2026.

import Foundation

struct BeerRecord: Codable {
    let brewery: String?
    let name: String
    let vesselType: VesselType?
    let sizeMl: Int
    let prices: [BeerPrice]
}

struct BeerPrice: Codable {
    let price: Double
    let quantity: Int
    let memberOffer: Bool?
}

enum VesselType: String, Codable {
    case can, bottle
}
