//  Created by Alexander Skorulis on 4/4/2026.

import Foundation
import SwiftSoup

/// Parses BWS product listing HTML (PLP tiles: `productTile_*` classes on `bws.com.au`).
public final class BWSParser: SiteParser, @unchecked Sendable {
    private static let maxPriceLinesPerProduct = 12
    private static let siteOrigin = "https://bws.com.au"

    public init() {}

    public func parse(html: String) -> [ParsedBeer] {
        guard let doc = try? SwiftSoup.parse(html) else { return [] }

        // `productTile_background` only wraps the image/rating strip; brand, name, and price live in sibling nodes under `div.productTile`.
        let tiles = (try? doc.select("div.productTile")) ?? Elements()
        var rows: [RetailBeerListingProductRow] = []

        for tile in tiles {
            let breweryLine = ((try? tile.select("h2.productTile_brand").first()?.text()) ?? "").normalizeWhitespace()
            guard
                !breweryLine.isEmpty,
                let link = try? tile.select("a[href*='/product/']").first(),
                let href = try? link.attr("href")
            else { continue }
            let subtitle = ((try? tile.select(".productTile_name").first()?.text()) ?? "").normalizeWhitespace()
            // Full-tile inner text also includes savings badges (“save $3”), ratings “(32)”, etc., which add bogus `$` lines — keep PLP price + pack hint only.
            let pricePlain = ((try? tile.select(".productTile_price").first()?.text()) ?? "").normalizeWhitespace()
            let imgAlt = ((try? tile.select("img.productTile_image").first()?.attr("alt")) ?? "").normalizeWhitespace()
            let cardText = [breweryLine, subtitle, pricePlain, imgAlt].filter { !$0.isEmpty }.joined(separator: "\n")
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

extension BWSParser {
    /// Clicks the PLP “Load more” control (`progressive-paging-control` → `ctrl.loadMore()`).
    private static let bwsLoadMoreButtonSelector = "progressive-paging-control a.btn.btn-secondary"

    public func pressNextPageScript() -> String {
        let script = """
        (function() {
          var el = document.querySelector('\(Self.bwsLoadMoreButtonSelector)');
          if (!el) { return false; }
          el.click();
          return true;
        })()
        """
        return script
    }
}
