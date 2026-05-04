import Foundation

enum TextNormalizer {
    static func normalize(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Collapse multiple spaces/newlines into single space
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    static func normalizeForCache(_ text: String, sourceLanguage: String) -> String {
        var result = normalize(text)
        if sourceLanguage.lowercased().hasPrefix("en") || sourceLanguage.lowercased() == "auto" {
            result = result.lowercased()
        }
        return result
    }
}
