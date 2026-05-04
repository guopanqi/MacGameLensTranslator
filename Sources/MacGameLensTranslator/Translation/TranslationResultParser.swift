import Foundation
import os

struct TranslationResultParser {
    private let logger = Logger(subsystem: "com.macgamelens.translator", category: "parser")

    struct ParsedResult {
        let translations: [(id: Int, translation: String)]
        let parseSuccessful: Bool
        let partialSuccess: Bool
    }

    func parse(_ rawResponse: String) -> ParsedResult {
        var content = rawResponse

        // Strategy 1: Try direct JSON parse
        if let result = tryParseJSON(content) {
            return result
        }

        // Strategy 2: Strip markdown code blocks
        content = stripMarkdownCodeBlocks(content)
        if let result = tryParseJSON(content) {
            return result
        }

        // Strategy 3: Extract first JSON object
        content = extractFirstJSONObject(content)
        if let result = tryParseJSON(content) {
            return result
        }

        // Strategy 4: Try fixing trailing commas
        content = fixTrailingCommas(content)
        if let result = tryParseJSON(content) {
            return result
        }

        logger.error("Failed to parse translation response")
        return ParsedResult(translations: [], parseSuccessful: false, partialSuccess: false)
    }

    private func tryParseJSON(_ content: String) -> ParsedResult? {
        guard let data = content.data(using: .utf8) else { return nil }

        do {
            let decoder = JSONDecoder()
            let payload = try decoder.decode(TranslationPromptBuilder.ResponsePayload.self, from: data)
            let translations = payload.items.map {
                (id: $0.id, translation: $0.translation)
            }
            let fullSuccess = !translations.isEmpty
            return ParsedResult(translations: translations, parseSuccessful: fullSuccess, partialSuccess: fullSuccess)
        } catch {
            logger.debug("JSON parse attempt failed: \(error.localizedDescription)")
        }

        // Try parsing with partial success (allow missing items)
        return tryParsePartialJSON(content)
    }

    private func tryParsePartialJSON(_ content: String) -> ParsedResult? {
        guard let data = content.data(using: .utf8) else { return nil }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [[String: Any]] {
                var translations: [(id: Int, translation: String)] = []
                for item in items {
                    if let id = item["id"] as? Int,
                       let translation = item["translation"] as? String {
                        translations.append((id: id, translation: translation))
                    }
                }
                if !translations.isEmpty {
                    return ParsedResult(translations: translations, parseSuccessful: true, partialSuccess: true)
                }
            }
        } catch {
            logger.debug("Partial JSON parse attempt failed: \(error.localizedDescription)")
        }

        return nil
    }

    private func stripMarkdownCodeBlocks(_ content: String) -> String {
        var result = content
        // Remove ```json ... ``` or ``` ... ```
        if let startRange = result.range(of: "```") {
            result = String(result[startRange.upperBound...])
            if let endRange = result.range(of: "```") {
                result = String(result[..<endRange.lowerBound])
            }
        }
        if result.hasPrefix("json\n") {
            result = String(result.dropFirst(5))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractFirstJSONObject(_ content: String) -> String {
        // Find first { and last }
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}") else {
            return content
        }
        return String(content[start...end])
    }

    private func fixTrailingCommas(_ content: String) -> String {
        // Remove trailing commas before } or ]
        var result = content
        result = result.replacingOccurrences(of: ",(\\s*[}\\]])", with: "$1", options: .regularExpression)
        return result
    }
}
