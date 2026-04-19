//  Created by Alexander Skorulis on 3/4/2026.

import ASKCore
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
        ASKCoreAssembly(purpose: .normal).assemble(container: container)
        
        registerViewModels(container: container)
        registerStores(container: container)
        registerService(container: container)
        
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
        
        container.register(MainStore.self) { MainStore.make(resolver: $0) }
            .inObjectScope(.container)
    }
    
    @MainActor
    private func registerService(container: Container<TargetResolver>) {
        container.register(ParsedBeerPersistenceService.self) { ParsedBeerPersistenceService.make(resolver: $0) }
            .inObjectScope(.container)
        
        container.register(UntappdService.self) { resolver in
            let store = resolver.mainStore()
            return UntappdService(clientID: store.settings.untappdClientID ?? "", clientSecret: store.settings.untappdSecretID ?? "")
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
