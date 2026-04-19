//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import Knit
import SwiftUI
import SwiftScraperCore
import UntappdAPI

final class SwiftScraperAssembly: AutoInitModuleAssembly {
    typealias TargetResolver = Resolver
    static var dependencies: [any Knit.ModuleAssembly.Type] { [] }

    init() {}
    
    @MainActor
    func assemble(container: Container<Resolver>) {
        registerViewModels(container: container)
        registerStores(container: container)
        
        container.register(MainPathRenderer.self) { MainPathRenderer(resolver: $0) }
    }
    
    @MainActor
    private func registerViewModels(container: Container<TargetResolver>) {
        container.register(ContentViewModel.self) { ContentViewModel.make(resolver: $0) }
        container.register(SiteParsingViewModel.self) { (resolver: Resolver, site: BeerSite) in
            SiteParsingViewModel.make(resolver: resolver, site: site)
        }
        container.register(SettingsViewModel.self) { SettingsViewModel.make(resolver: $0) }
        container.register(BeerListViewModel.self) { BeerListViewModel.make(resolver: $0) }
        
        container.register(BeerDetailViewModel.self) { (resolver: Resolver, row: BeerInstanceListRow) in
            BeerDetailViewModel.make(resolver: resolver, row: row)
        }
    }
    
    @MainActor
    private func registerStores(container: Container<TargetResolver>) {
        container.register(HTMLExportDirectoryStore.self) { _ in HTMLExportDirectoryStore() }
            .inObjectScope(.container)
        container.register(WebViewStore.self) { WebViewStore.make(resolver: $0) }
            .inObjectScope(.container)

        container.register(SQLStore.self) { _ in
            SQLStore.default()
        }
        .inObjectScope(.container)
    }
    
    @MainActor
    private func registerService(container: Container<TargetResolver>) {
        container.register(ParsedBeerPersistenceService.self) { ParsedBeerPersistenceService.make(resolver: $0) }
            .inObjectScope(.container)
        
        container.register(UntappdService.self) { _ in
            UntappdService(clientID: "-", clientSecret: "-")
        }
    }
    
    
    
}

extension SwiftScraperAssembly {
    @MainActor static func testing() -> ScopedModuleAssembler<Resolver> {
        ScopedModuleAssembler<Resolver>([SwiftScraperAssembly()])
    }
}

public extension EnvironmentValues {
    @Entry var resolver: Resolver?
}
