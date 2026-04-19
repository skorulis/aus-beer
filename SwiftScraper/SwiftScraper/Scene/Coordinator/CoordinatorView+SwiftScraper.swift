//  Created by Alexander Skorulis on 4/4/2026.

import ASKCoordinator
import Knit
import SwiftUI

extension CoordinatorView {
    func withRenderers(resolver: Resolver) -> Self {
        self
            .with(renderer: resolver.mainPathRenderer())
            .with(overlay: .basicDialog) { content, _ in
                AnyView(BasicOverlayDialog {
                    content
                })
            }
    }
}
