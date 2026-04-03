//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import Knit
import KnitMacros
import SwiftScraperCore

@MainActor @Observable final class SiteParsingViewModel {
    
    let webViewStore: WebViewStore
    private let parsedBeerPersistence: ParsedBeerPersistenceService
    
    var toolbarStatus: String?
    var autoLoadAllBeers = false
    
    @Resolvable<Resolver>
    init(webViewStore: WebViewStore, parsedBeerPersistence: ParsedBeerPersistenceService) {
        self.webViewStore = webViewStore
        self.parsedBeerPersistence = parsedBeerPersistence
    }
}

extension SiteParsingViewModel {
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

    func loadAllBeers() async {
        autoLoadAllBeers = true
        while autoLoadAllBeers {
            do {
                let clicked = try await webViewStore.clickDanMurphysLoadMoreIfPresent()
                if !clicked {
                    toolbarStatus = "No Show more button on the page."
                    break
                }
                toolbarStatus = "Tapped Show more. Waiting 5s before next load..."
            } catch {
                toolbarStatus = "Error: \(error.localizedDescription)"
                break
            }
            try? await Task.sleep(for: .seconds(5))
        }
    }

    func parseBeersFromCurrentPage() async {
        do {
            let html = try await webViewStore.currentOuterHTML()
            let beers = BeerSite.danMurphys.parser.parse(html: html)
            let noun = beers.count == 1 ? "beer" : "beers"
            let persistenceSummary: String
            do {
                let r = try parsedBeerPersistence.persistParsedBeers(beers, supplier: BeerSite.danMurphys)
                if r.newBeersInserted == 0 && r.breweriesInserted == 0 {
                    persistenceSummary = " DB: no new beers (\(r.existingBeersSkipped) already saved)."
                } else {
                    persistenceSummary =
                        " DB: +\(r.newBeersInserted) new beer(s), +\(r.breweriesInserted) new brewery/breweries, skipped \(r.existingBeersSkipped) existing."
                }
            } catch {
                persistenceSummary = " DB save failed: \(error.localizedDescription)"
            }
            toolbarStatus = "Parsed \(beers.count) \(noun).\(persistenceSummary)"
        } catch {
            toolbarStatus = "Error: \(error.localizedDescription)"
        }
    }
}
