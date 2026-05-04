import XCTest
@testable import MacGameLensTranslator

final class CoordinateTransformTests: XCTestCase {
    
    func testVisionBboxToOverlayPoint_StandardDisplay() {
        let pixelSize = CGSize(width: 1920, height: 1080)
        let scaleFactor: CGFloat = 1.0

        let merger = TextBlockMerger()
        let obs = OCRTextObservation(
            id: UUID(),
            text: "Test",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.05)
        )

        let blocks = merger.merge([obs], pixelSize: pixelSize, scaleFactor: scaleFactor)
        XCTAssertEqual(blocks.count, 1)

        let block = blocks[0]
        // At 1920x1080 @ 1x, with Vision origin at bottom-left:
        // pixelX = 0.1 * 1920 = 192
        // pixelYFromBottom = 0.1 * 1080 = 108
        // pixelW = 0.2 * 1920 = 384
        // pixelH = 0.05 * 1080 = 54
        // pointYFromTop = 1080 - 108 - 54 = 918
        XCTAssertEqual(block.boundingBox.origin.x, 192, accuracy: 0.1)
        XCTAssertEqual(block.boundingBox.origin.y, 918, accuracy: 0.1)
        XCTAssertEqual(block.boundingBox.width, 384, accuracy: 0.1)
        XCTAssertEqual(block.boundingBox.height, 54, accuracy: 0.1)
    }

    func testVisionBboxToOverlayPoint_RetinaDisplay() {
        let pixelSize = CGSize(width: 3840, height: 2160)
        let scaleFactor: CGFloat = 2.0

        let merger = TextBlockMerger()
        let obs = OCRTextObservation(
            id: UUID(),
            text: "Retina",
            confidence: 0.95,
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.05)
        )

        let blocks = merger.merge([obs], pixelSize: pixelSize, scaleFactor: scaleFactor)
        XCTAssertEqual(blocks.count, 1)

        let block = blocks[0]
        // pixelX = 0.1 * 3840 = 384, pointX = 384/2 = 192
        // pixelYFromBottom = 0.1 * 2160 = 216, pointYFromBottom = 216/2 = 108
        // pointYFromTop = (2160/2) - 108 - 54 = 1080 - 108 - 54 = 918
        XCTAssertEqual(block.boundingBox.origin.x, 192, accuracy: 0.1)
        XCTAssertEqual(block.boundingBox.origin.y, 918, accuracy: 0.1)
        XCTAssertEqual(block.boundingBox.width, 384, accuracy: 0.1)
        XCTAssertEqual(block.boundingBox.height, 54, accuracy: 0.1)
    }

    func testVisionBboxToOverlayPoint_TopLeftCorner() {
        let pixelSize = CGSize(width: 1920, height: 1080)
        let scaleFactor: CGFloat = 1.0

        let merger = TextBlockMerger()
        // Vision bbox near top-left of image (bottom-left origin, so high y = near top)
        let obs = OCRTextObservation(
            id: UUID(),
            text: "TopLeft",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.01, y: 0.95, width: 0.1, height: 0.04)
        )

        let blocks = merger.merge([obs], pixelSize: pixelSize, scaleFactor: scaleFactor)
        XCTAssertEqual(blocks.count, 1)

        let block = blocks[0]
        // pixelYFromBottom = 0.95 * 1080 = 1026
        // pointYFromBottom = 1026
        // pointYFromTop = 1080 - 1026 - 43.2 = 10.8 (near top!)
        XCTAssertEqual(block.boundingBox.origin.y, 10.8, accuracy: 1.0)
        XCTAssertLessThan(block.boundingBox.origin.y, 50)
    }

    func testVisionBboxToOverlayPoint_BottomRightCorner() {
        let pixelSize = CGSize(width: 1920, height: 1080)
        let scaleFactor: CGFloat = 1.0

        let merger = TextBlockMerger()
        let obs = OCRTextObservation(
            id: UUID(),
            text: "BottomRight",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.85, y: 0.01, width: 0.1, height: 0.04)
        )

        let blocks = merger.merge([obs], pixelSize: pixelSize, scaleFactor: scaleFactor)
        XCTAssertEqual(blocks.count, 1)

        let block = blocks[0]
        // pixelYFromBottom = 0.01 * 1080 = 10.8, pointYFromBottom = 10.8
        // pointYFromTop = 1080 - 10.8 - 43.2 = 1026 (near bottom)
        XCTAssertEqual(block.boundingBox.origin.y, 1026, accuracy: 1.0)
        XCTAssertGreaterThan(block.boundingBox.origin.y, 1000)
    }

    func testVisionBboxToOverlayPoint_CenterOfScreen() {
        let pixelSize = CGSize(width: 1920, height: 1080)
        let scaleFactor: CGFloat = 1.0

        let merger = TextBlockMerger()
        let obs = OCRTextObservation(
            id: UUID(),
            text: "Center",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.4, y: 0.45, width: 0.2, height: 0.1)
        )

        let blocks = merger.merge([obs], pixelSize: pixelSize, scaleFactor: scaleFactor)
        XCTAssertEqual(blocks.count, 1)

        let block = blocks[0]
        // pixelX = 0.4 * 1920 = 768, pixelYFromBottom = 0.45 * 1080 = 486
        // pointYFromTop = 1080 - 486 - 108 = 486
        XCTAssertEqual(block.boundingBox.origin.x, 768, accuracy: 0.1)
        XCTAssertEqual(block.boundingBox.origin.y, 486, accuracy: 0.1)
    }
}
