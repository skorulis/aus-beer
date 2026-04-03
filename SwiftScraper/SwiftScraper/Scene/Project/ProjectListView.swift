//  Created by Alexander Skorulis on 4/4/2026.

import Knit
import SwiftScraperCore
import SwiftUI

struct ProjectListView: View {

    @Environment(\.resolver) private var resolver
    @State private var selection: BeerSite?

    var body: some View {
        NavigationSplitView {
            list
            .navigationTitle("Sites")
        } detail: {
            if let site = selection {
                SiteParsingView(viewModel: resolver!.siteParsingViewModel(site: site))
                    .id(site.id)
            } else {
                ContentUnavailableView(
                    "Select a site",
                    systemImage: "globe",
                    description: Text("Choose a retailer from the list to open its parser.")
                )
            }
        }
    }
    
    private var list: some View {
        List(BeerSite.allCases, selection: $selection) { site in
            cell(for: site)
                .tag(site)
        }
    }
    
    private func cell(for site: BeerSite) -> some View {
        HStack {
            Text(site.supplierName)
            Spacer()
            Image(systemName: "chevron.right")
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    let assembler = SwiftScraperAssembly.testing()
    ProjectListView()
        .environment(\.resolver, assembler.resolver)
}
