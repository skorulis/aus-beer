//  Created by Alexander Skorulis on 3/4/2026.

import Foundation

public struct BeerRecord: Codable, Equatable, Sendable {
    public let brewery: String?
    public let name: String
    public let vesselType: VesselType?
    public let sizeMl: Int
    public let prices: [BeerPrice]

    public init(brewery: String?, name: String, vesselType: VesselType?, sizeMl: Int, prices: [BeerPrice]) {
        self.brewery = brewery
        self.name = name
        self.vesselType = vesselType
        self.sizeMl = sizeMl
        self.prices = prices
    }
}

public struct BeerPrice: Codable, Equatable, Sendable {
    public let price: Double
    public let quantity: Int
    public let memberOffer: Bool?

    public init(price: Double, quantity: Int, memberOffer: Bool?) {
        self.price = price
        self.quantity = quantity
        self.memberOffer = memberOffer
    }
}

public enum VesselType: String, Codable, Sendable {
    case can, bottle
}
