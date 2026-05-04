import XCTest
@testable import MacGameLensTranslator

final class TranslationResultParserTests: XCTestCase {

    let parser = TranslationResultParser()

    func testParseValidJSON() {
        let response = """
        {
            "items": [
                {"id": 1, "translation": "这扇门锁住了。"},
                {"id": 2, "translation": "我得找另一条路。"}
            ]
        }
        """

        let result = parser.parse(response)
        XCTAssertTrue(result.parseSuccessful)
        XCTAssertEqual(result.translations.count, 2)
        XCTAssertEqual(result.translations[0].id, 1)
        XCTAssertEqual(result.translations[0].translation, "这扇门锁住了。")
    }

    func testParseMarkdownCodeBlock() {
        let response = """
        ```json
        {
            "items": [
                {"id": 1, "translation": "你好"}
            ]
        }
        ```
        """

        let result = parser.parse(response)
        XCTAssertTrue(result.parseSuccessful)
        XCTAssertEqual(result.translations.count, 1)
        XCTAssertEqual(result.translations[0].translation, "你好")
    }

    func testParseWithExtraTextSurrounding() {
        let response = """
        Here is the translation you requested:

        {
            "items": [
                {"id": 1, "translation": "保存"}
            ]
        }

        Hope this helps!
        """

        let result = parser.parse(response)
        XCTAssertTrue(result.parseSuccessful)
        XCTAssertEqual(result.translations.count, 1)
        XCTAssertEqual(result.translations[0].translation, "保存")
    }

    func testParseWithTrailingComma() {
        let response = """
        {
            "items": [
                {"id": 1, "translation": "开始游戏",},
            ],
        }
        """

        let result = parser.parse(response)
        // May or may not parse, but should not crash
        XCTAssertNotNil(result)
    }

    func testParseMissingTranslation() {
        let response = """
        {
            "items": [
                {"id": 1},
                {"id": 2, "translation": "好的"}
            ]
        }
        """

        let result = parser.parse(response)
        // Partial success: id 2 should be parsed
        XCTAssertTrue(result.parseSuccessful)
        XCTAssertEqual(result.translations.count, 1)
        XCTAssertEqual(result.translations[0].id, 2)
    }

    func testParseCompletelyInvalidResponse() {
        let response = "I'm sorry, I cannot translate this text."

        let result = parser.parse(response)
        XCTAssertFalse(result.parseSuccessful)
        XCTAssertTrue(result.translations.isEmpty)
    }

    func testParseEmptyResponse() {
        let response = ""

        let result = parser.parse(response)
        XCTAssertFalse(result.parseSuccessful)
    }

    func testParseSingleItem() {
        let response = """
        {
            "items": [
                {"id": 42, "translation": "选项"}
            ]
        }
        """

        let result = parser.parse(response)
        XCTAssertTrue(result.parseSuccessful)
        XCTAssertEqual(result.translations.count, 1)
        XCTAssertEqual(result.translations[0].id, 42)
    }
}
