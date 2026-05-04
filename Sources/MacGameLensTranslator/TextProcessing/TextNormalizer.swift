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
        let language = sourceLanguage.lowercased().split(separator: ":").last.map(String.init) ?? sourceLanguage.lowercased()
        if language.hasPrefix("en") || language == "auto" {
            result = result.lowercased()
        }
        return result
    }
}
