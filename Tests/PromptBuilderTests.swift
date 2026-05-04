import XCTest
@testable import MacGameLensTranslator

final class PromptBuilderTests: XCTestCase {

    let builder = TranslationPromptBuilder()

    func testBuildSystemPrompt() {
        let prompt = builder.buildSystemPrompt(targetLanguage: "Simplified Chinese")
        XCTAssertTrue(prompt.contains("Simplified Chinese"))
        XCTAssertTrue(prompt.contains("game localization translator"))
        XCTAssertTrue(prompt.contains("OCR text blocks"))
        XCTAssertTrue(prompt.contains("JSON"))
    }

    func testBuildUserPayload() {
        let blocks = [
            TextBlock(id: 1, sourceText: "Hello World", boundingBox: .zero, confidence: 1.0),
            TextBlock(id: 2, sourceText: "Test", boundingBox: .zero, confidence: 1.0)
        ]

        let payload = builder.buildUserPayload(blocks: blocks, targetLanguage: "Simplified Chinese")

        XCTAssertTrue(payload.contains("targetLanguage"))
        XCTAssertTrue(payload.contains("Simplified Chinese"))
        XCTAssertTrue(payload.contains("\"id\" : 1") || payload.contains("\"id\":1") || payload.contains("\"id\": 1") || payload.contains("\"id\" :1"))
        XCTAssertTrue(payload.contains("Hello World"))
        XCTAssertTrue(payload.contains("items"))
    }

    func testBuildMessages() {
        let blocks = [
            TextBlock(id: 1, sourceText: "Save", boundingBox: .zero, confidence: 1.0)
        ]

        let messages = builder.buildMessages(blocks: blocks, targetLanguage: "Japanese")

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"], "system")
        XCTAssertEqual(messages[1]["role"], "user")
        XCTAssertTrue(messages[1]["content"]?.contains("Save") ?? false)
    }

    func testEmptyBlocksPayload() {
        let payload = builder.buildUserPayload(blocks: [], targetLanguage: "English")
        XCTAssertTrue(payload.contains("items"))
    }
}
