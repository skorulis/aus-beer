//  Created by Alexander Skorulis on 3/4/2026.

import SwiftUI
import Knit

@main
struct SwiftScraperApp: App {
    
    private let assembler: ScopedModuleAssembler<Resolver> = {
        let assembler = ScopedModuleAssembler<Resolver>(
            [
                SwiftScraperAssembly()
            ]
        )
        return assembler
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: assembler.resolver.contentViewModel())
                .environment(\.resolver, assembler.resolver)
        }
    }
}
