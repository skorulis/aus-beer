//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import SwiftUI
import SwiftScraperCore

// MARK: - Memory footprint

@MainActor struct BeerCell {
    let beer: ParsedBeer
}

// MARK: - Rendering

extension BeerCell: View {
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(beer.name)
                    .font(.subheadline)
                if let brewery = beer.brewery {
                    Text(brewery)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text("\(beer.sizeMl) ml")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Previews

#Preview {
    BeerCell(beer: .init(brewery: "Asahi", name: "Super Dry", vesselType: .can, sizeMl: 375, prices: []))
}

