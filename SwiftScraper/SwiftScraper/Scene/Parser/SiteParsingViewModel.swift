//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import Knit
import KnitMacros
import SwiftScraperCore

@MainActor @Observable final class SiteParsingViewModel {
    
    let webViewStore: WebViewStore
    let site: BeerSite
    private let parsedBeerPersistence: ParsedBeerPersistenceService
    private let htmlExportDirectory: HTMLExportDirectoryStore
    
    var toolbarStatus: String?
    var autoLoadAllBeers = false
    
    @Resolvable<Resolver>
    init(
        @Argument site: BeerSite,
        webViewStore: WebViewStore,
        parsedBeerPersistence: ParsedBeerPersistenceService,
        htmlExportDirectory: HTMLExportDirectoryStore,
    ) {
        self.site = site
        self.webViewStore = webViewStore
        self.parsedBeerPersistence = parsedBeerPersistence
        self.htmlExportDirectory = htmlExportDirectory
    }
}

extension SiteParsingViewModel {
    func saveHTMLToTmp() async {
        do {
            let html = try await webViewStore.captureOuterHTML()
            let name = "\(site.rawValue)-\(Int(Date().timeIntervalSince1970)).html"
            let url = try htmlExportDirectory.performWithAccess { exportDir in
                try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
                let fileURL = exportDir.appendingPathComponent(name)
                try html.write(to: fileURL, atomically: true, encoding: .utf8)
                return fileURL
            }
            toolbarStatus = url.path
        } catch {
            toolbarStatus = "Error: \(error.localizedDescription)"
        }
    }

    func clickShowMore() async {
        do {
            let script = site.parser.pressNextPageScript()
            let clicked = try await webViewStore.executeClick(script)
            toolbarStatus = clicked ? "Tapped Show more." : "No Show more button on the page."
        } catch {
            toolbarStatus = "Error: \(error.localizedDescription)"
        }
    }

    func loadAllBeers() async {
        autoLoadAllBeers = true
        while autoLoadAllBeers {
            do {
                let script = site.parser.pressNextPageScript()
                let clicked = try await webViewStore.executeClick(script)
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
            let beers = site.parser.parse(html: html)
            let noun = beers.count == 1 ? "beer" : "beers"
            let persistenceSummary: String
            do {
                let r = try parsedBeerPersistence.persistParsedBeers(beers, supplier: site)
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
