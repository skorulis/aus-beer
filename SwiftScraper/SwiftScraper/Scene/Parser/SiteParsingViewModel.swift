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
            let beers = site.parser.parse(html: html)
            let timestamp = Int(Date().timeIntervalSince1970)
            let baseName = "\(site.rawValue)-\(timestamp)"
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(beers)
            let saved = try htmlExportDirectory.performWithAccess { exportDir in
                try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
                let htmlURL = exportDir.appendingPathComponent("\(baseName).html")
                try html.write(to: htmlURL, atomically: true, encoding: .utf8)
                let jsonURL = exportDir.appendingPathComponent("\(baseName).json")
                try jsonData.write(to: jsonURL, options: .atomic)
                return (htmlURL: htmlURL, jsonURL: jsonURL, beerCount: beers.count)
            }
            let noun = saved.beerCount == 1 ? "beer" : "beers"
            toolbarStatus = "\(saved.htmlURL.path) · \(saved.jsonURL.path) (\(saved.beerCount) \(noun))"
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
