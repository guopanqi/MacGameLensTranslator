import Foundation
import os

final class DeepSeekTranslationService: TranslationService {
    private let promptBuilder: TranslationPromptBuilder
    private let resultParser: TranslationResultParser
    private let batcher: TranslationBatcher
    private let cache: TranslationCache
    private let settingsStore: SettingsStore
    private let logger = Logger(subsystem: "com.macgamelens.translator", category: "translation")

    private let baseURL = "https://api.deepseek.com/v1/chat/completions"
    private let model = "deepseek-v4-flash"

    init(
        promptBuilder: TranslationPromptBuilder,
        resultParser: TranslationResultParser,
        batcher: TranslationBatcher,
        cache: TranslationCache,
        settingsStore: SettingsStore
    ) {
        self.promptBuilder = promptBuilder
        self.resultParser = resultParser
        self.batcher = batcher
        self.cache = cache
        self.settingsStore = settingsStore
    }

    func translate(_ blocks: [TextBlock], targetLanguage: String) async throws -> [TextBlock] {
        guard !blocks.isEmpty else { return [] }

        let apiKey = settingsStore.settings.deepSeekAPIKey
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

        // Check cache
        let sourceLanguage = settingsStore.settings.sourceLanguage
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
            logger.debug("All blocks cached, skipping API call")
            return results
        }

        logger.debug("Translating \(uncached.count) uncached blocks")
        print("[MGLT] DeepSeek model: \(model)")

        // Batch and translate
        let batches = batcher.batch(uncached)
        var translatedBatches: [(id: Int, translation: String)] = []

        for batch in batches {
            do {
                let batchResults = try await translateBatch(batch.blocks, apiKey: apiKey, targetLanguage: targetLanguage)
                translatedBatches.append(contentsOf: batchResults)
            } catch {
                logger.error("Batch translation failed: \(error.localizedDescription)")
                print("[MGLT] Batch translation failed: \(error.localizedDescription)")

                // Fallback: smaller batches
                let fallbackBatches = batcher.fallbackBatch(batch.blocks)
                for fb in fallbackBatches {
                    do {
                        let fbResults = try await translateBatch(fb.blocks, apiKey: apiKey, targetLanguage: targetLanguage)
                        translatedBatches.append(contentsOf: fbResults)
                    } catch {
                        logger.error("Fallback batch failed: \(error.localizedDescription)")
                        print("[MGLT] Fallback batch failed: \(error.localizedDescription)")

                        // Last resort: single block
                        let singleBatches = batcher.singleBlockBatches(fb.blocks)
                        for sb in singleBatches {
                            do {
                                let sbResults = try await translateBatch(sb.blocks, apiKey: apiKey, targetLanguage: targetLanguage)
                                translatedBatches.append(contentsOf: sbResults)
                            } catch {
                                logger.error("Single block translation failed: \(error.localizedDescription)")
                                print("[MGLT] Single block translation failed: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }

        // Map translated results back
        for t in translatedBatches {
            if let idx = results.firstIndex(where: { $0.id == t.id }) {
                results[idx].translatedText = t.translation
                cache.set(sourceText: results[idx].sourceText, targetLanguage: targetLanguage, sourceLanguage: sourceLanguage, translation: t.translation)
            }
        }

        return results
    }

    private func translateBatch(_ blocks: [TextBlock], apiKey: String, targetLanguage: String) async throws -> [(id: Int, translation: String)] {
        let messages = promptBuilder.buildMessages(blocks: blocks, targetLanguage: targetLanguage)

        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "response_format": ["type": "json_object"],
            "thinking": ["type": "disabled"],
            "temperature": 0.3,
            "max_tokens": 8192,
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
            logger.error("API error \(httpResponse.statusCode): \(body)")
            throw TranslationError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[MGLT] Invalid API response format. Body preview: \(body.prefix(1200))")
            throw TranslationError.invalidResponseFormat
        }

        if let finishReason = firstChoice["finish_reason"] as? String {
            print("[MGLT] DeepSeek finish_reason: \(finishReason), content chars=\(content.count)")
        }
        print("[MGLT] DeepSeek content preview: \(content.prefix(1200))")

        let parsed = resultParser.parse(content)

        if !parsed.parseSuccessful {
            throw TranslationError.parseError(preview: String(content.prefix(1200)))
        }

        return parsed.translations
    }
}

enum TranslationError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case invalidResponseFormat
    case parseError(preview: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key configured. Please set your DeepSeek API key in Settings."
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid response from translation API"
        case .httpError(let code, _): return "API returned HTTP \(code)"
        case .invalidResponseFormat: return "Unexpected response format from API"
        case .parseError(let preview): return "Failed to parse translation result. Response preview: \(preview)"
        }
    }
}
