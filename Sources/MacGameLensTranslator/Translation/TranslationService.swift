import Foundation

protocol TranslationService {
    func translate(_ blocks: [TextBlock], targetLanguage: String) async throws -> [TextBlock]
}
