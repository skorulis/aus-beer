//  Created by Alexander Skorulis on 4/4/2026.

import Foundation
import SwiftSoup

// Shared between retailer-specific `SiteParser` implementations (Dan Murphy's, BWS, …).

struct RetailBeerListingProductRow {
    var breweryLine: String
    var subtitle: String
    var href: String
    var cardText: String
}

/// SwiftSoup's `text()` joins nodes with spaces; Playwright's `innerText` breaks on block elements. We approximate that so price parsing sees the same logical lines as the TS scrapers.
func retailListingInnerTextApproximation(from element: Element) throws -> String {
    try element.html().htmlFragmentToInnerTextLike()
}

/// Matches `new URL(href)` then `` `${u.origin}${u.pathname}` `` for deduping product links.
func retailListingCanonicalProductURL(_ href: String, siteOrigin: String) -> String? {
    let absolute = href.hasPrefix("http") ? href : "\(siteOrigin)\(href)"
    guard let url = URL(string: absolute), let scheme = url.scheme, let host = url.host else { return nil }
    var origin = "\(scheme)://\(host)"
    if let port = url.port {
        let defaultPort = (scheme == "https") ? 443 : 80
        if port != defaultPort { origin += ":\(port)" }
    }
    return origin + url.path
}

// MARK: - Brewery / name

func resolveRetailBeerBreweryAndName(_ row: RetailBeerListingProductRow, siteOrigin: String) -> (brewery: String, name: String)? {
    var brewery = row.breweryLine.trimmingCharacters(in: .whitespacesAndNewlines)
    var name = cleanRetailBeerName(row.subtitle)
    guard !brewery.isEmpty else { return nil }
    if name.isEmpty {
        if let slug = parseRetailBeerBreweryAndNameFromProductHref(row.href, siteOrigin: siteOrigin) {
            brewery = slug.brewery
            name = slug.name
        }
    }
    if !name.isEmpty, !isPlausibleRetailProductName(name) { return nil }
    return (brewery, name)
}

private func cleanRetailBeerName(_ raw: String) -> String {
    var s = raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let patterns: [(String, String)] = [
        (#"\s+\d+\s+Block(?:\s+and\s+Bottles)?(?:\s+\d+\s*x\s*\d+\s*m[lL]?)?"#, ""),
        (#"\s+(bottles?|cans?|stubbies?)\s*\d+\s*x\s*\d+\s*m[lL]?\b"#, ""),
        (#"\s+\d+\s*x\s*\d+\s*m[lL]?\b"#, ""),
        (#",?\s*(bottles?|cans?|stubbies?)\s*,?\s*\d+\s*m[lL]?\b"#, ""),
        (#"\s+\d+\s*m[lL]\b"#, ""),
        (#",?\s*(bottles?|cans?|stubbies?)\s*$"#, ""),
        (#"^[,–—-]\s*"#, ""),
        (#"\s*[,–—-]\s*$"#, ""),
    ]
    for (pat, rep) in patterns {
        s = s.replacingOccurrences(of: pat, with: rep, options: [.regularExpression, .caseInsensitive])
    }
    return s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func parseRetailBeerBreweryAndNameFromProductHref(_ href: String, siteOrigin: String) -> (brewery: String, name: String)? {
    let urlString = href.hasPrefix("http") ? href : "\(siteOrigin)\(href)"
    guard let url = URL(string: urlString) else { return nil }
    let slug = url.path.split(separator: "/").last.map(String.init) ?? ""
    guard slug.contains("-") else { return nil }
    let tokens = slug.split(separator: "-").map(String.init).filter { !$0.isEmpty }
    let vesselIdx = tokens.firstIndex { t in
        t.range(of: #"^(cans?|bottles?|stubbies?)$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
    guard let vesselIdx, vesselIdx >= 1, tokens.count >= 2 else { return nil }
    let before = Array(tokens[..<vesselIdx])
    guard before.count >= 2 else { return nil }
    let brewery = before[0].capitalizeWords()
    let name = cleanRetailBeerName(before.dropFirst().joined(separator: " ").capitalizeWords())
    guard !brewery.isEmpty, !name.isEmpty else { return nil }
    return (brewery, name)
}

private func isPlausibleRetailProductName(_ name: String) -> Bool {
    let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.count < 2 || t.count > 180 { return false }
    if isReviewCountLine(t) { return false }
    if isUiChromeLine(t) { return false }
    let lower = t.lowercased()
    if lower.range(
        of: #"reminder|our stores are closed|good friday|order now|weekend|subscribe|newsletter|cookie|privacy policy|click here|sign up|terms and conditions|would you like to change your store|change your store|default store|delivery"#,
        options: .regularExpression
    ) != nil {
        return false
    }
    return true
}

private func isUiChromeLine(_ line: String) -> Bool {
    let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.isEmpty || t.count > 140 { return true }
    if t.hasPrefix("$") { return true }
    let patterns = [
        #"^sponsored$"#,
        #"^offer$"#,
        #"^special\s+offer$"#,
        #"^member\s*offer$"#,
        #"^limits?\s*apply$"#,
        #"^save\s+"#,
        #"^was\s+"#,
        #"^each$"#,
        #"^per\s+"#,
        #"^add\s+to\s+cart"#,
        #"^view\s+"#,
        #"^compare$"#,
        #"^online\s+only$"#,
        #"^only\s+at\s+"#,
        #"^\(?\s*\d+\s+reviews?\s*\)?$"#,
        #"^\(\s*\d+\s+reviews?\s*\)$"#,
        #"^\(\s*\d+\s+review\s*\)$"#,
        #"^\d+\s+reviews?$"#,
        #"^\(\s*\d+\s+reviews?\s*\)"#,
    ]
    for p in patterns {
        if t.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil { return true }
    }
    return false
}

private func isReviewCountLine(_ line: String) -> Bool {
    let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
    let patterns = [
        #"^\d+\s+reviews?$"#,
        #"^\(\s*\d+\s+reviews?\s*\)$"#,
        #"^\(\s*\d+\s+review\s*\)$"#,
        #"^\(\s*\d+\s+reviews?\s*\)"#,
    ]
    for p in patterns {
        if t.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil { return true }
    }
    return false
}

// MARK: - Vessel / size

func inferRetailBeerVessel(_ text: String) -> VesselType? {
    let t = text.lowercased()
    if t.range(of: #"\bcan(s)?\b"#, options: .regularExpression) != nil
        || t.range(of: #"\bstubbie?s?\b"#, options: .regularExpression) != nil
    {
        return .can
    }
    if t.range(of: #"\bbottle(s)?\b"#, options: .regularExpression) != nil { return .bottle }
    return nil
}

func extractRetailBeerSizeMl(_ text: String) -> Int? {
    guard let m = text.range(of: #"(\d+)\s*m[lL]\b"#, options: .regularExpression) else { return nil }
    let matched = String(text[m])
    guard let num = matched.range(of: #"\d+"#, options: .regularExpression) else { return nil }
    return Int(String(matched[num]))
}

// MARK: - Prices

struct RetailBeerMutablePrice {
    var price: Double
    var quantity: Int
    var memberOffer: Bool
}

func parseRetailBeerPricesFromCardText(_ text: String) -> [RetailBeerMutablePrice] {
    let lines = retailCardTextLines(text)
    var entries: [RetailBeerMutablePrice] = []
    for i in lines.indices {
        let line = lines[i]
        guard line.contains("$") else { continue }
        let lo = max(0, i - 4)
        let hi = min(lines.count, i + 3)
        let wideBlock = lines[lo..<hi].joined(separator: " ").replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let narrowBlock = narrowQuantityContext(lines: lines, i: i)
        let memberOffer = memberOfferForPriceLine(line: line, wideBlock: wideBlock)
        for price in dollarAmounts(in: line) {
            guard price > 0 else { continue }
            let quantity = parseQuantityFromPriceBlock(price: price, block: narrowBlock)
            entries.append(RetailBeerMutablePrice(price: price, quantity: max(1, quantity), memberOffer: memberOffer))
        }
    }
    let hasExplicitNonMember = text.range(of: #"non[-\s]?member"#, options: [.regularExpression, .caseInsensitive]) != nil
    let hasMemberOffer = text.range(of: #"member\s+offer"#, options: [.regularExpression, .caseInsensitive]) != nil
    if !hasExplicitNonMember {
        reconcileMemberOffersForSameQuantity(&entries)
        if hasMemberOffer {
            reconcileMemberOffersMixedQuantity(&entries, fullCardText: text)
        }
    }
    return dedupePriceEntries(entries)
}

private func retailCardTextLines(_ text: String) -> [String] {
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    return normalized.split(separator: "\n", omittingEmptySubsequences: false)
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

private func dollarAmounts(in line: String) -> [Double] {
    let pattern = #"\$\s*(\d+(?:\.\d{2})?)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(line.startIndex..., in: line)
    var out: [Double] = []
    regex.enumerateMatches(in: line, range: range) { match, _, _ in
        guard let match, match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: line)
        else { return }
        if let v = Double(String(line[r])), v > 0 { out.append(v) }
    }
    return out
}

private func narrowQuantityContext(lines: [String], i: Int) -> String {
    let line = lines[i]
    let next = i + 1 < lines.count ? lines[i + 1] : ""
    let lineHasPackaging =
        line.range(of: #"\$[\s\S]*\b(pack|case|each|block)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
        || line.range(of: #"\$[\s\S]*\bfor\s+\d+\s+(bottles?|cases?)"#, options: [.regularExpression, .caseInsensitive]) != nil
        || line.range(of: #"\$[\s\S]*\bper\s+(pack|case)\s+of\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    if lineHasPackaging { return line }
    if !next.isEmpty, !next.hasPrefix("$") {
        return "\(line) \(next)".replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }
    return line
}

private func memberOfferForPriceLine(line: String, wideBlock: String) -> Bool {
    if line.range(of: #"non[-\s]?member"#, options: [.regularExpression, .caseInsensitive]) != nil { return false }
    if wideBlock.range(of: #"member\s+offer"#, options: [.regularExpression, .caseInsensitive]) != nil,
       line.contains("$"),
       line.range(of: #"non[-\s]?member"#, options: [.regularExpression, .caseInsensitive]) == nil
    {
        return true
    }
    return inferMemberOfferFromText(wideBlock)
}

private func inferMemberOfferFromText(_ text: String) -> Bool {
    let t = text.lowercased()
    if t.range(of: #"non[-\s]?member|nonmember"#, options: .regularExpression) != nil { return false }
    if t.range(
        of: #"\bmember\s+price|\bmembers?\s+price|my\s+dan|rewards?\s+card|member\s+offer|dans\s+member"#,
        options: .regularExpression
    ) != nil {
        return true
    }
    if t.range(of: #"\bmembers?\b"#, options: .regularExpression) != nil { return true }
    return false
}

private func cardSuggestsMemberPricing(_ fullCardText: String) -> Bool {
    let stripped = fullCardText.replacingOccurrences(of: #"non[-\s]?member"#, with: " ", options: [.regularExpression, .caseInsensitive])
    return inferMemberOfferFromText(stripped)
}

private func reconcileMemberOffersForSameQuantity(_ entries: inout [RetailBeerMutablePrice]) {
    var byQty: [Int: [Int]] = [:]
    for (idx, e) in entries.enumerated() {
        byQty[e.quantity, default: []].append(idx)
    }
    for indices in byQty.values where indices.count == 2 {
        let i0 = indices[0]
        let i1 = indices[1]
        let a = entries[i0]
        let b = entries[i1]
        if a.memberOffer != b.memberOffer { continue }
        if a.memberOffer, b.memberOffer { continue }
        if a.price == b.price { continue }
        var left = entries[i0]
        var right = entries[i1]
        if a.price < b.price {
            left.memberOffer = true
            right.memberOffer = false
        } else {
            left.memberOffer = false
            right.memberOffer = true
        }
        entries[i0] = left
        entries[i1] = right
    }
}

private func reconcileMemberOffersMixedQuantity(_ entries: inout [RetailBeerMutablePrice], fullCardText: String) {
    guard entries.count == 2 else { return }
    var a = entries[0]
    var b = entries[1]
    if a.quantity == b.quantity { return }
    if a.memberOffer != b.memberOffer { return }
    if a.memberOffer, b.memberOffer { return }
    if !cardSuggestsMemberPricing(fullCardText) { return }
    func perUnit(_ e: RetailBeerMutablePrice) -> Double { e.price / Double(e.quantity) }
    let aPu = perUnit(a)
    let bPu = perUnit(b)
    if abs(aPu - bPu) < 1e-9 { return }
    if aPu < bPu {
        a.memberOffer = true
        b.memberOffer = false
    } else {
        b.memberOffer = true
        a.memberOffer = false
    }
    entries[0] = a
    entries[1] = b
}

private func dedupePriceEntries(_ entries: [RetailBeerMutablePrice]) -> [RetailBeerMutablePrice] {
    var seen = Set<String>()
    var out: [RetailBeerMutablePrice] = []
    for p in entries {
        let key = "\(p.price)|\(p.quantity)|\(p.memberOffer)"
        if seen.insert(key).inserted {
            out.append(p)
        }
    }
    return out
}

private func parseQuantityFromPriceBlock(price: Double, block: String) -> Int {
    let b = block.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    func match2(_ pattern: String) -> (Int, Int)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(b.startIndex..., in: b)
        guard let m = regex.firstMatch(in: b, range: range), m.numberOfRanges >= 3,
              let r1 = Range(m.range(at: 1), in: b),
              let r2 = Range(m.range(at: 2), in: b),
              let n1 = Int(b[r1]),
              let n2 = Int(b[r2])
        else { return nil }
        return (n1, n2)
    }
    func match1(_ pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(b.startIndex..., in: b)
        guard let m = regex.firstMatch(in: b, range: range), m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: b),
              let n = Int(b[r])
        else { return nil }
        return n
    }
    if let pair = match2(#"for\s+(\d+)\s+cases?\s*\((\d+)\)"#) { return pair.0 * pair.1 }
    if let n = match1(#"for\s+(\d+)\s+cases?\b"#) { return n * 24 }
    if let n = match1(#"per\s+case\s+of\s+(\d+)"#) { return n }
    if let n = match1(#"per\s+pack\s+of\s+(\d+)"#) { return n }
    if let n = match1(#"for\s+(\d+)\s+bottles?"#) { return n }
    if let n = match1(#"block\s*\((\d+)\)"#) { return n }
    if let n = match1(#"case\s*\((\d+)\)"#) { return n }
    if let n = match1(#"pack\s*\((\d+)\)"#) { return n }
    if let n = match1(#"(?:case|pack)\s*\(?\s*(\d+)\s*\)?"#) { return n }
    if let n = match1(#"(\d+)\s*pk\b"#) { return n }
    if let n = match1(#"\b(\d+)\s+x\s+\$"#) { return n }
    if b.range(of: #"\beach\b"#, options: .regularExpression) != nil {
        return price < 15 ? 1 : 24
    }
    return 1
}
