//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import SwiftSoup

// Logic mirrors `scraper/src/sites/danmurphys.ts` (`extractProductsFromDom`, price parsing helpers).

public final class DanMurphysParser: SiteParser, @unchecked Sendable {
    private static let maxPriceLinesPerProduct = 12
    private static let siteOrigin = "https://www.danmurphys.com.au"

    public init() {}

    public func parse(html: String) -> [ParsedBeer] {
        guard let doc = try? SwiftSoup.parse(html) else { return [] }

        var rows: [RetailBeerListingProductRow] = []

        if let carousel = try? doc.select("dd-product-carousel").first() {
            let dmTiles = (try? carousel.select(".product--dm")) ?? Elements()
            for root in dmTiles {
                let breweryLine = ((try? root.select(".product__title--primary").first()?.text()) ?? "").normalizeWhitespace()
                guard
                    !breweryLine.isEmpty,
                    let link = try? root.select("a[href*='/product/']").first(),
                    let href = try? link.attr("href")
                else { continue }
                let subtitle = ((try? root.select(".product__title--secondary").first()?.text()) ?? "").normalizeWhitespace()
                let cardText = (try? retailListingInnerTextApproximation(from: root)) ?? ""
                rows.append(RetailBeerListingProductRow(breweryLine: breweryLine, subtitle: subtitle, href: href, cardText: cardText))
            }
        }

        let gridCards = (try? doc.select("#results shop-product-card")) ?? Elements()
        for card in gridCards {
            guard
                let link = try? card.select("h2.not-offers a[href*='/product/']").first(),
                let href = try? link.attr("href")
            else { continue }
            let breweryLine = ((try? card.select("h2.not-offers span.title").first()?.text()) ?? "").normalizeWhitespace()
            guard !breweryLine.isEmpty else { continue }
            let subtitle = ((try? card.select("h2.not-offers span.subtitle").first()?.text()) ?? "").normalizeWhitespace()
            let cardText = (try? retailListingInnerTextApproximation(from: card)) ?? ""
            rows.append(RetailBeerListingProductRow(breweryLine: breweryLine, subtitle: subtitle, href: href, cardText: cardText))
        }

        var seenCanonical = Set<String>()
        var out: [ParsedBeer] = []

        for row in rows {
            guard row.href.contains("/product/") else { continue }
            let lower = row.href.lowercased()
            if lower.contains("gift") || lower.contains("egift") { continue }

            guard let canonical = retailListingCanonicalProductURL(row.href, siteOrigin: Self.siteOrigin) else { continue }
            if seenCanonical.contains(canonical) { continue }
            seenCanonical.insert(canonical)

            guard row.cardText.contains("$") else { continue }
            guard let parsed = resolveRetailBeerBreweryAndName(row, siteOrigin: Self.siteOrigin) else { continue }

            let prices = parseRetailBeerPricesFromCardText(row.cardText)
            if prices.isEmpty { continue }
            if prices.count > Self.maxPriceLinesPerProduct { continue }

            let textForMeta = "\(parsed.brewery) \(row.subtitle) \(row.cardText)"
            let vessel = inferRetailBeerVessel(textForMeta)
            let size = extractRetailBeerSizeMl(textForMeta) ?? 0

            out.append(
                ParsedBeer(
                    brewery: parsed.brewery,
                    name: parsed.name,
                    vesselType: vessel,
                    sizeMl: size,
                    prices: prices.map { BeerPrice(price: $0.price, quantity: $0.quantity, memberOffer: $0.memberOffer) }
                )
            )
        }

        return out
    }
    
    
}

// MARK: - Next page

extension DanMurphysParser {
    /// Same selector as `DANMURPHYS_LOAD_MORE_BUTTON_SELECTOR` in `scraper/src/sites/danmurphys.ts`.
    private static let danMurphysLoadMoreButtonSelector = ".infinite-loader__load-more-button"
    
    public func pressNextPageScript() -> String {
        let script = """
        (function() {
          var el = document.querySelector('\(Self.danMurphysLoadMoreButtonSelector)');
          if (!el) { return false; }
          el.click();
          return true;
        })()
        """
        return script
    }
}
