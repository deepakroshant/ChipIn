import Foundation

struct QuickTextParseResult {
    var cleanTitle: String
    var amount: String?
    var mentionedHandle: String?
}

enum QuickTextParser {
    /// Parse "pizza $20 @sarah" → title: "pizza", amount: "20", mention: "sarah"
    static func parse(_ input: String) -> QuickTextParseResult {
        var text = input
        var amount: String?
        var handle: String?

        if let r = text.range(of: #"\$[\d.]+"#, options: .regularExpression) {
            let raw = String(text[r])
            amount = String(raw.dropFirst())
            text.removeSubrange(r)
        }

        if let r = text.range(of: #"@[a-zA-Z0-9_]+"#, options: .regularExpression) {
            let raw = String(text[r])
            handle = String(raw.dropFirst())
            text.removeSubrange(r)
        }

        let cleanTitle = text.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return QuickTextParseResult(cleanTitle: cleanTitle, amount: amount, mentionedHandle: handle)
    }
}
