import XCTest
@testable import MacGameLensTranslator

final class TextBlockMergerTests: XCTestCase {

    func testMergeMultipleLinesSameParagraph() {
        let merger = TextBlockMerger()
        let pixelSize = CGSize(width: 1920, height: 1080)
        let scaleFactor: CGFloat = 1.0

        // Two lines of the same paragraph, close together
        let line1 = OCRTextObservation(
            id: UUID(), text: "This door is locked.",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.2, y: 0.6, width: 0.15, height: 0.03)
        )
        let line2 = OCRTextObservation(
            id: UUID(), text: "I need to find another way.",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.2, y: 0.57, width: 0.2, height: 0.03)
        )

        let blocks = merger.merge([line1, line2], pixelSize: pixelSize, scaleFactor: scaleFactor)
        // Should merge into one block
        XCTAssertEqual(blocks.count, 1)
        XCTAssertTrue(blocks[0].sourceText.contains("This door"))
        XCTAssertTrue(blocks[0].sourceText.contains("I need"))
    }

    func testDoNotMergeSeparateUIElements() {
        let merger = TextBlockMerger()
        let pixelSize = CGSize(width: 1920, height: 1080)
        let scaleFactor: CGFloat = 1.0

        // Two separate UI elements
        let ui1 = OCRTextObservation(
            id: UUID(), text: "Start Game",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.1, height: 0.03)
        )
        let ui2 = OCRTextObservation(
            id: UUID(), text: "Load Game",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.1, height: 0.03)
        )

        let blocks = merger.merge([ui1, ui2], pixelSize: pixelSize, scaleFactor: scaleFactor)
        // These are vertically far apart, should NOT merge
        XCTAssertEqual(blocks.count, 2)
    }

    func testMergeHorizontallyOverlappingLines() {
        let merger = TextBlockMerger()
        let pixelSize = CGSize(width: 1920, height: 1080)
        let scaleFactor: CGFloat = 1.0

        // Two lines that overlap horizontally
        let line1 = OCRTextObservation(
            id: UUID(), text: "Quest: Find the ancient artifact in the",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.3, y: 0.5, width: 0.3, height: 0.03)
        )
        let line2 = OCRTextObservation(
            id: UUID(), text: "ruins of the forgotten temple.",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.3, y: 0.47, width: 0.25, height: 0.03)
        )

        let blocks = merger.merge([line1, line2], pixelSize: pixelSize, scaleFactor: scaleFactor)
        XCTAssertEqual(blocks.count, 1)
    }

    func testMergeSameLineAdjacentText() {
        let merger = TextBlockMerger()
        let pixelSize = CGSize(width: 1000, height: 1000)
        let scaleFactor: CGFloat = 1.0

        let marker = OCRTextObservation(
            id: UUID(),
            text: "3.",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.10, y: 0.50, width: 0.03, height: 0.03)
        )
        let option = OCRTextObservation(
            id: UUID(),
            text: "Leave",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.15, y: 0.50, width: 0.08, height: 0.03)
        )

        let blocks = merger.merge([marker, option], pixelSize: pixelSize, scaleFactor: scaleFactor)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].sourceText, "3. Leave")
    }

    func testDoNotMergeSameLineFarApartText() {
        let merger = TextBlockMerger()
        let pixelSize = CGSize(width: 1000, height: 1000)
        let scaleFactor: CGFloat = 1.0

        let leftButton = OCRTextObservation(
            id: UUID(),
            text: "Accept",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.10, y: 0.50, width: 0.08, height: 0.03)
        )
        let rightButton = OCRTextObservation(
            id: UUID(),
            text: "Cancel",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.70, y: 0.50, width: 0.08, height: 0.03)
        )

        let blocks = merger.merge([leftButton, rightButton], pixelSize: pixelSize, scaleFactor: scaleFactor)

        XCTAssertEqual(blocks.count, 2)
    }

    func testLowConfidenceFilteredBeforeMerge() {
        let filter = TextBlockFilter(minimumConfidence: 0.5)
        let merger = TextBlockMerger()
        let pixelSize = CGSize(width: 1920, height: 1080)
        let scaleFactor: CGFloat = 1.0

        let goodText = OCRTextObservation(
            id: UUID(), text: "Hello World",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.2, y: 0.5, width: 0.1, height: 0.03)
        )
        let badText = OCRTextObservation(
            id: UUID(), text: "??!@#",
            confidence: 0.2,
            boundingBox: CGRect(x: 0.2, y: 0.4, width: 0.05, height: 0.03)
        )

        let filtered = filter.filter([goodText, badText])
        XCTAssertEqual(filtered.count, 1)

        let blocks = merger.merge(filtered, pixelSize: pixelSize, scaleFactor: scaleFactor)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].sourceText, "Hello World")
    }
}
