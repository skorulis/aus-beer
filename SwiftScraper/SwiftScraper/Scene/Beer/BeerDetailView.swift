//  Created by Alexander Skorulis on 4/4/2026.

import Knit
import SwiftScraperCore
import SwiftUI

// MARK: - Memory footprint

@MainActor struct BeerDetailView {

    @State var viewModel: BeerDetailViewModel
    var row: BeerInstanceListRow { viewModel.row }
}

// MARK: - Rendering

extension BeerDetailView: View {

    var body: some View {
        Form {
            Section("Beer") {
                LabeledContent("Name", value: row.beer.name)
                if let id = row.beer.untappdID, !id.isEmpty {
                    LabeledContent("Untappd", value: id)
                }
            }
            Section("Brewery") {
                LabeledContent("Name", value: row.brewery.name)
                if let id = row.brewery.untappdID, !id.isEmpty {
                    LabeledContent("Untappd", value: id)
                }
            }
            Section("Packaging") {
                LabeledContent("Size", value: "\(row.instance.size) ml")
                LabeledContent("Vessel", value: row.instance.vessel.rawValue.capitalized)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(row.beer.name)
    }
}

// MARK: - Previews

#Preview {
    let assembler = SwiftScraperAssembly.testing()
    let row = BeerInstanceListRow(
        instance: BeerInstanceRecord(rowId: 1, beer: 1, size: 375, vessel: .can),
        beer: BeerRecord(rowId: 1, brewery: 1, name: "Super Dry"),
        brewery: BreweryRecord(rowId: 1, name: "Asahi")
    )
    let viewModel = assembler.resolver.beerDetailViewModel(row: row)
    return NavigationStack {
        BeerDetailView(
            viewModel: viewModel
        )
    }
    .frame(minWidth: 360, minHeight: 280)
}
