import Foundation

struct TranslationCacheKey: Hashable {
    let normalizedSourceText: String
    let targetLanguage: String
}

final class TranslationCache {
    private var store: [TranslationCacheKey: String] = [:]

    func get(sourceText: String, targetLanguage: String, sourceLanguage: String) -> String? {
        let normalized = TextNormalizer.normalizeForCache(sourceText, sourceLanguage: sourceLanguage)
        let key = TranslationCacheKey(normalizedSourceText: normalized, targetLanguage: targetLanguage)
        return store[key]
    }

    func set(sourceText: String, targetLanguage: String, sourceLanguage: String, translation: String) {
        let normalized = TextNormalizer.normalizeForCache(sourceText, sourceLanguage: sourceLanguage)
        let key = TranslationCacheKey(normalizedSourceText: normalized, targetLanguage: targetLanguage)
        store[key] = translation
    }

    func clear() {
        store.removeAll()
    }

    var count: Int { store.count }
}
