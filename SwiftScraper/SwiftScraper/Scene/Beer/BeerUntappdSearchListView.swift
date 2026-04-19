//  Created by Alex Skorulis on 19/4/2026.

import SwiftUI
import UntappdAPI

@MainActor struct BeerUntappdSearchListView {
    let items: [UntappdSearchResponse.Item]
    let onSelect: (UntappdSearchResponse.Item) -> Void
}

extension BeerUntappdSearchListView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Select Untappd Beer")
                .font(.headline)
                .padding()
            
            Divider()
            
            List(items, id: \.id) { item in
                Button {
                    onSelect(item)
                } label: {
                    content(item: item)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
        .frame(width: 420, height: 500)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    private func content(item: UntappdSearchResponse.Item) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.beer.beer_name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(item.brewery.brewery_name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let style = item.beer.beer_style, !style.isEmpty {
                    Text(style)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text("\(item.beer.beer_abv)% ABV")
        }
        
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(Rectangle())
    }
}
