//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import Knit
import KnitMacros

@MainActor @Observable final class ContentViewModel {
    
    let webViewStore: WebViewStore
    
    var toolbarStatus: String?
    
    @Resolvable<Resolver>
    init(webViewStore: WebViewStore) {
        self.webViewStore = webViewStore
    }
}


extension ContentViewModel {
    func saveHTMLToTmp() async {
        do {
            let url = try await webViewStore.saveCurrentHTMLToTemporaryFile()
            toolbarStatus = url.path
        } catch {
            toolbarStatus = "Error: \(error.localizedDescription)"
        }
    }

    func clickShowMore() async {
        do {
            let clicked = try await webViewStore.clickDanMurphysLoadMoreIfPresent()
            toolbarStatus = clicked ? "Tapped Show more." : "No Show more button on the page."
        } catch {
            toolbarStatus = "Error: \(error.localizedDescription)"
        }
    }
}
