//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import Knit
import SwiftUI

final class SwiftScraperAssembly: AutoInitModuleAssembly {
    typealias TargetResolver = Resolver
    static var dependencies: [any Knit.ModuleAssembly.Type] { [] }

    init() {}
    
    @MainActor
    func assemble(container: Container<Resolver>) {
        registerViewModels(container: container)
        registerStores(container: container)
    }
    
    @MainActor
    private func registerViewModels(container: Container<TargetResolver>) {
        container.register(ContentViewModel.self) { ContentViewModel.make(resolver: $0) }
        container.register(SiteParsingViewModel.self) { SiteParsingViewModel.make(resolver: $0) }
        container.register(SettingsViewModel.self) { SettingsViewModel.make(resolver: $0) }
    }
    
    @MainActor
    private func registerStores(container: Container<TargetResolver>) {
        container.register(HTMLExportDirectoryStore.self) { _ in HTMLExportDirectoryStore() }
            .inObjectScope(.container)
        container.register(WebViewStore.self) { WebViewStore.make(resolver: $0) }
            .inObjectScope(.container)
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
