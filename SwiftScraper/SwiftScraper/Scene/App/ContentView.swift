//  Created by Alexander Skorulis on 3/4/2026.

import ASKCoordinator
import SwiftUI
import Knit
import SwiftScraperCore

private let danMurphysBeerListURL = BeerSite.danMurphys.rootURL

struct ContentView: View {
    
    @State var viewModel: ContentViewModel
    @Environment(\.resolver) var resolver

    var body: some View {
        TabView {
            SiteParsingView(viewModel: resolver!.siteParsingViewModel(site: .danMurphys))
                .tabItem {
                    Label("Parsing", systemImage: "globe")
                }
            
            BeerListView(viewModel: resolver!.beerListViewModel())
                .tabItem {
                    Label("Beers", systemImage: "list.bullet")
                }
            
            SettingsView(viewModel: resolver!.settingsViewModel())
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }

}

#Preview {
    let assembler = SwiftScraperAssembly.testing()
    ContentView(viewModel: assembler.resolver.contentViewModel())
        .environment(\.resolver, assembler.resolver)
}
