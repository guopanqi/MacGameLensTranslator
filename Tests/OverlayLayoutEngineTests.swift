import XCTest
import CoreGraphics
@testable import MacGameLensTranslator

final class OverlayLayoutEngineTests: XCTestCase {

    func testTranslationBelowSource() {
        let engine = OverlayLayoutEngine()

        let block = TextBlock(
            id: 1,
            sourceText: "Hello World",
            translatedText: "你好世界",
            boundingBox: CGRect(x: 100, y: 500, width: 150, height: 20),
            confidence: 1.0
        )

        let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = engine.layout([block], displayFrame: displayFrame)

        XCTAssertEqual(result.count, 1)
        let overlay = result[0]
        // Overlay should be positioned below the source text
        XCTAssertEqual(overlay.overlayFrame.origin.x, 100, accuracy: 0.1)
        // y = source.maxY + verticalGap = 520 + 4 = 524
        XCTAssertEqual(overlay.overlayFrame.origin.y, 524, accuracy: 1.0)
    }

    func testTranslationAboveWhenBelowOverflows() {
        let engine = OverlayLayoutEngine()

        // Source text near the bottom of the screen
        let block = TextBlock(
            id: 1,
            sourceText: "Bottom Text",
            translatedText: "底部文字",
            boundingBox: CGRect(x: 100, y: 1050, width: 150, height: 20),
            confidence: 1.0
        )

        let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = engine.layout([block], displayFrame: displayFrame)

        XCTAssertEqual(result.count, 1)
        let overlay = result[0]
        // Overlay should be positioned above (y < source.minY)
        XCTAssertLessThan(overlay.overlayFrame.maxY, block.boundingBox.minY)
    }

    func testRightEdgeClampedToScreen() {
        let engine = OverlayLayoutEngine()

        // Source text at the right edge
        let block = TextBlock(
            id: 1,
            sourceText: "Right Edge",
            translatedText: "右侧边缘文字需要换行显示",
            boundingBox: CGRect(x: 1800, y: 500, width: 120, height: 20),
            confidence: 1.0
        )

        let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = engine.layout([block], displayFrame: displayFrame)

        XCTAssertEqual(result.count, 1)
        let overlay = result[0]
        // Overlay should not exceed screen width
        XCTAssertLessThan(overlay.overlayFrame.maxX, displayFrame.width + 1)
    }

    func testMinWidthApplied() {
        let engine = OverlayLayoutEngine(minWidth: 160)

        // Very narrow source text
        let block = TextBlock(
            id: 1,
            sourceText: "OK",
            translatedText: "确定",
            boundingBox: CGRect(x: 500, y: 500, width: 20, height: 15),
            confidence: 1.0
        )

        let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = engine.layout([block], displayFrame: displayFrame)

        XCTAssertEqual(result.count, 1)
        // Width should be at least minWidth
        XCTAssertGreaterThanOrEqual(result[0].overlayFrame.width, 160)
    }

    func testMaxWidthApplied() {
        let engine = OverlayLayoutEngine(maxWidth: 420)

        // Very wide source text
        let block = TextBlock(
            id: 1,
            sourceText: "A very long text that spans across a large portion of the screen",
            translatedText: "一段跨越屏幕大部分区域的非常长的文本",
            boundingBox: CGRect(x: 100, y: 500, width: 800, height: 20),
            confidence: 1.0
        )

        let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = engine.layout([block], displayFrame: displayFrame)

        XCTAssertEqual(result.count, 1)
        // Width should not exceed maxWidth
        XCTAssertLessThanOrEqual(result[0].overlayFrame.width, 420 + 1)
    }

    func testBlocksWithoutTranslationSkipped() {
        let engine = OverlayLayoutEngine()

        let blockWithoutTranslation = TextBlock(
            id: 1,
            sourceText: "No Translation",
            boundingBox: CGRect(x: 100, y: 500, width: 150, height: 20),
            confidence: 1.0
        )

        let blockWithTranslation = TextBlock(
            id: 2,
            sourceText: "Has Translation",
            translatedText: "有翻译",
            boundingBox: CGRect(x: 100, y: 600, width: 150, height: 20),
            confidence: 1.0
        )

        let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = engine.layout([blockWithoutTranslation, blockWithTranslation], displayFrame: displayFrame)

        // Only blocks with translation should be included
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, 2)
    }

    func testMultipleBlocksLayoutNoCrash() {
        let engine = OverlayLayoutEngine()

        var blocks: [TextBlock] = []
        for i in 1...20 {
            let block = TextBlock(
                id: i,
                sourceText: "Block \(i)",
                translatedText: "块\(i)",
                boundingBox: CGRect(
                    x: CGFloat.random(in: 0...1500),
                    y: CGFloat.random(in: 0...1000),
                    width: CGFloat.random(in: 50...200),
                    height: CGFloat.random(in: 15...40)
                ),
                confidence: 1.0
            )
            blocks.append(block)
        }

        let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = engine.layout(blocks, displayFrame: displayFrame)

        XCTAssertEqual(result.count, 20)
        // All blocks should be within screen bounds
        for overlay in result {
            XCTAssertGreaterThanOrEqual(overlay.overlayFrame.minX, -1)
            XCTAssertGreaterThanOrEqual(overlay.overlayFrame.minY, -1)
            XCTAssertLessThanOrEqual(overlay.overlayFrame.maxX, displayFrame.width + 1)
            XCTAssertLessThanOrEqual(overlay.overlayFrame.maxY, displayFrame.height + 1)
        }
    }
}
