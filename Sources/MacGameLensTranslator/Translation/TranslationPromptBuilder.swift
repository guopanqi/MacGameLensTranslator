import Foundation

struct TranslationPromptBuilder {
    struct TranslationItem: Codable {
        let id: Int
        let text: String
    }

    struct RequestPayload: Codable {
        let targetLanguage: String
        let items: [TranslationItem]
    }

    struct ResponsePayload: Codable {
        let items: [TranslationResponseItem]
    }

    struct TranslationResponseItem: Codable {
        let id: Int
        let translation: String
    }

    func buildSystemPrompt(targetLanguage: String) -> String {
        """
        You are a game localization translator. Translate the provided OCR text blocks into \(targetLanguage). Preserve meaning, tone, UI brevity, and game context.

        Return only valid JSON in exactly this shape:
        {"items":[{"id":1,"translation":"translated text"}]}

        Every input item must have one output item with the same id. Do not add explanations, markdown, comments, or fields outside this JSON object.
        """
    }

    func buildUserPayload(blocks: [TextBlock], targetLanguage: String) -> String {
        let items = blocks.map { TranslationItem(id: $0.id, text: $0.sourceText) }
        let payload = RequestPayload(targetLanguage: targetLanguage, items: items)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(payload),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{\"target_language\": \"\(targetLanguage)\", \"items\": []}"
        }
        return jsonString
    }

    func buildMessages(blocks: [TextBlock], targetLanguage: String) -> [[String: String]] {
        let systemPrompt = buildSystemPrompt(targetLanguage: targetLanguage)
        let userPayload = buildUserPayload(blocks: blocks, targetLanguage: targetLanguage)

        return [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPayload]
        ]
    }
}
