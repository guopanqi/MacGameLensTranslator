import Foundation

final class ProviderTranslationService: TranslationService {
    private let settingsStore: SettingsStore
    private let deepSeekService: TranslationService
    private let qwenMTService: TranslationService

    init(
        settingsStore: SettingsStore,
        deepSeekService: TranslationService,
        qwenMTService: TranslationService
    ) {
        self.settingsStore = settingsStore
        self.deepSeekService = deepSeekService
        self.qwenMTService = qwenMTService
    }

    func translate(_ blocks: [TextBlock], targetLanguage: String) async throws -> [TextBlock] {
        switch settingsStore.settings.selectedTranslationProvider {
        case .deepSeek:
            return try await deepSeekService.translate(blocks, targetLanguage: targetLanguage)
        case .qwenMtLite:
            return try await qwenMTService.translate(blocks, targetLanguage: targetLanguage)
        }
    }
}
