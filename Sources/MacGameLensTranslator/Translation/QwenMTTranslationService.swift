import Foundation
import os

final class QwenMTTranslationService: TranslationService {
    private let batcher: TranslationBatcher
    private let cache: TranslationCache
    private let settingsStore: SettingsStore
    private let logger = Logger(subsystem: "com.macgamelens.translator", category: "translation")

    private let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"

    init(
        batcher: TranslationBatcher,
        cache: TranslationCache,
        settingsStore: SettingsStore
    ) {
        self.batcher = batcher
        self.cache = cache
        self.settingsStore = settingsStore
    }

    func translate(_ blocks: [TextBlock], targetLanguage: String) async throws -> [TextBlock] {
        guard !blocks.isEmpty else { return [] }

        let settings = settingsStore.settings
        let apiKey = settings.qwenAPIKey
        guard !apiKey.isEmpty else {
            throw TranslationError.noAPIKey
        }

        var results = blocks.map { TextBlock(
            id: $0.id,
            sourceText: $0.sourceText,
            boundingBox: $0.boundingBox,
            confidence: $0.confidence,
            lines: $0.lines
        ) }

        let sourceLanguage = "qwen-mt:\(settings.sourceLanguage)"
        var uncached: [TextBlock] = []
        for block in results {
            if let cached = cache.get(sourceText: block.sourceText, targetLanguage: targetLanguage, sourceLanguage: sourceLanguage) {
                if let idx = results.firstIndex(where: { $0.id == block.id }) {
                    results[idx].translatedText = cached
                }
            } else {
                uncached.append(block)
            }
        }

        guard !uncached.isEmpty else {
            logger.debug("All Qwen MT blocks cached, skipping API call")
            return results
        }

        print("[MGLT] Qwen MT model: \(modelName(for: settings))")

        let batches = batcher.batch(uncached)
        var translatedBatches: [(id: Int, translation: String)] = []

        for batch in batches {
            do {
                let batchResults = try await translateBatch(batch.blocks, apiKey: apiKey, targetLanguage: targetLanguage)
                translatedBatches.append(contentsOf: batchResults)
            } catch {
                logger.error("Qwen MT batch translation failed: \(error.localizedDescription)")
                print("[MGLT] Qwen MT batch translation failed: \(error.localizedDescription)")

                let fallbackBatches = batcher.fallbackBatch(batch.blocks)
                for fb in fallbackBatches {
                    do {
                        let fbResults = try await translateBatch(fb.blocks, apiKey: apiKey, targetLanguage: targetLanguage)
                        translatedBatches.append(contentsOf: fbResults)
                    } catch {
                        logger.error("Qwen MT fallback batch failed: \(error.localizedDescription)")
                        print("[MGLT] Qwen MT fallback batch failed: \(error.localizedDescription)")

                        for sb in batcher.singleBlockBatches(fb.blocks) {
                            do {
                                let sbResults = try await translateBatch(sb.blocks, apiKey: apiKey, targetLanguage: targetLanguage)
                                translatedBatches.append(contentsOf: sbResults)
                            } catch {
                                logger.error("Qwen MT single block failed: \(error.localizedDescription)")
                                print("[MGLT] Qwen MT single block failed: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }

        for t in translatedBatches {
            if let idx = results.firstIndex(where: { $0.id == t.id }) {
                results[idx].translatedText = t.translation
                cache.set(sourceText: results[idx].sourceText, targetLanguage: targetLanguage, sourceLanguage: sourceLanguage, translation: t.translation)
            }
        }

        return results
    }

    private func translateBatch(_ blocks: [TextBlock], apiKey: String, targetLanguage: String) async throws -> [(id: Int, translation: String)] {
        let settings = settingsStore.settings
        let sourceLines = blocks.map { sanitizeForLineTranslation($0.sourceText) }
        let sourceText = sourceLines.joined(separator: "\n")

        print("[MGLT] Qwen MT request lines (\(blocks.count)):")
        for (block, line) in zip(blocks, sourceLines) {
            print("[MGLT]   send id=\(block.id), text=\(debugQuoted(line)), frame=\(block.boundingBox)")
        }

        let requestBody: [String: Any] = [
            "model": modelName(for: settings),
            "messages": [
                ["role": "user", "content": sourceText]
            ],
            "translation_options": [
                "source_lang": sourceLangCode(for: settings.sourceLanguage),
                "target_lang": targetLangCode(for: targetLanguage)
            ],
            "stream": false
        ]

        guard let url = URL(string: baseURL) else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("Qwen MT API error \(httpResponse.statusCode): \(body)")
            throw TranslationError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = extractContent(from: message["content"]) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[MGLT] Invalid Qwen MT response format. Body preview: \(body.prefix(1200))")
            throw TranslationError.invalidResponseFormat
        }

        if let finishReason = firstChoice["finish_reason"] as? String {
            print("[MGLT] Qwen MT finish_reason: \(finishReason), content chars=\(content.count)")
        }
        print("[MGLT] Qwen MT content preview: \(content.prefix(1200))")

        return try mapLineTranslations(content, to: blocks)
    }

    private func mapLineTranslations(_ content: String, to blocks: [TextBlock]) throws -> [(id: Int, translation: String)] {
        if blocks.count == 1 {
            let translation = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !translation.isEmpty else {
                throw TranslationError.parseError(preview: "Qwen MT returned an empty translation")
            }
            return [(id: blocks[0].id, translation: translation)]
        }

        let translatedLines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        print("[MGLT] Qwen MT response lines (\(translatedLines.count)):")
        for (index, line) in translatedLines.enumerated() {
            print("[MGLT]   recv line\(index + 1)=\(debugQuoted(line))")
        }

        guard translatedLines.count == blocks.count else {
            throw TranslationError.parseError(
                preview: "Qwen MT line count mismatch. expected=\(blocks.count) received=\(translatedLines.count) content=\(String(content.prefix(600)))"
            )
        }

        return zip(blocks, translatedLines).map { block, translation in
            print("[MGLT]   map id=\(block.id) <= \(debugQuoted(translation))")
            return (id: block.id, translation: translation)
        }
    }

    private func sanitizeForLineTranslation(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func modelName(for settings: AppSettings) -> String {
        settings.qwenModelName.isEmpty ? "qwen-mt-lite" : settings.qwenModelName
    }

    private func extractContent(from rawContent: Any?) -> String? {
        if let content = rawContent as? String {
            return content
        }

        if let parts = rawContent as? [[String: Any]] {
            let text = parts.compactMap { part -> String? in
                if let direct = part["text"] as? String { return direct }
                return nil
            }.joined(separator: "\n")
            return text.isEmpty ? nil : text
        }

        return nil
    }

    private func sourceLangCode(for value: String) -> String {
        let lower = value.lowercased()
        if lower == "auto" { return "auto" }
        if lower.hasPrefix("en") || lower == "english" { return "English" }
        if lower.hasPrefix("ja") || lower.contains("japanese") { return "Japanese" }
        if lower.hasPrefix("ko") || lower.contains("korean") { return "Korean" }
        if lower.hasPrefix("fr") || lower.contains("french") { return "French" }
        if lower.hasPrefix("de") || lower.contains("german") { return "German" }
        if lower.contains("chinese") && lower.contains("traditional") { return "Traditional Chinese" }
        if lower.contains("chinese") { return "Simplified Chinese" }
        return "auto"
    }

    private func targetLangCode(for value: String) -> String {
        let lower = value.lowercased()
        if lower.hasPrefix("en") || lower == "english" { return "English" }
        if lower.hasPrefix("ja") || lower.contains("japanese") { return "Japanese" }
        if lower.hasPrefix("ko") || lower.contains("korean") { return "Korean" }
        if lower.contains("traditional") { return "Traditional Chinese" }
        return "Simplified Chinese"
    }

    private func debugQuoted(_ text: String) -> String {
        "\"\(text.replacingOccurrences(of: "\n", with: "\\n"))\""
    }
}
