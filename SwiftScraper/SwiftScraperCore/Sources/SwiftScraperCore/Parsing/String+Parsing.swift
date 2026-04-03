//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import SwiftSoup

extension String {
    func decodeBasicHtmlEntities() -> String {
        var r = self
        let pairs: [(String, String)] = [
            ("&amp;", "&"),
            ("&nbsp;", " "),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&#39;", "'"),
            ("&quot;", "\""),
            ("&#x27;", "'"),
        ]
        for (enc, dec) in pairs {
            r = r.replacingOccurrences(of: enc, with: dec)
        }
        return r
    }
    
    func htmlFragmentToInnerTextLike() -> String {
        var s = self
        s.replace(#"<script\b[^<]*(?:(?!</script>)<[^<]*)*</script>"#, "")
        s.replace(#"<style\b[^<]*(?:(?!</style>)<[^<]*)*</style>"#, "")
        s.replace(#"<br\s*/?>"#, "\n", caseInsensitive: true)
        s.replace(
            #"</(div|p|h[1-6]|li|tr|section|article|dd|dt|header|footer|ul|ol|table|tbody|thead|dl)\s*>"#,
            "\n",
            caseInsensitive: true
        )
        s.replace(#"<[^>]+>"#, "")
        s = s.decodeBasicHtmlEntities()
        s.replace(#"[ \t]+\n"#, "\n")
        s.replace(#"\n{3,}"#, "\n\n")
        return s
    }
    
    mutating func replace(_ pattern: String, _ replacement: String, caseInsensitive: Bool = false) {
        self = replacingOccurrences(
            of: pattern,
            with: replacement,
            options: caseInsensitive ? [.regularExpression, .caseInsensitive] : .regularExpression
        )
    }
    
    func normalizeWhitespace() -> String {
        self.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func capitalizeWords() -> String {
        self.split(whereSeparator: { $0.isWhitespace || $0 == "-" })
            .map { w in
                let str = String(w)
                guard let f = str.first else { return "" }
                return String(f).uppercased() + str.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}
