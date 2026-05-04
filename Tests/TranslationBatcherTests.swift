import XCTest
import CoreGraphics
@testable import MacGameLensTranslator

final class TranslationBatcherTests: XCTestCase {

    func testSmallBatchSingleBatch() {
        let batcher = TranslationBatcher(maxBlocks: 50, maxCharacters: 10000)

        var blocks: [TextBlock] = []
        for i in 1...10 {
            blocks.append(TextBlock(id: i, sourceText: "Test text \(i)", boundingBox: .zero, confidence: 1.0))
        }

        let batches = batcher.batch(blocks)
        // 10 blocks <= 20, should be 1 batch
        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches[0].blocks.count, 10)
    }

    func testLargeBatchSplitIntoMultiple() {
        let batcher = TranslationBatcher(maxBlocks: 50, maxCharacters: 10000)

        var blocks: [TextBlock] = []
        for i in 1...30 {
            blocks.append(TextBlock(id: i, sourceText: "Test text number \(i)", boundingBox: .zero, confidence: 1.0))
        }

        let batches = batcher.batch(blocks)
        // 30 blocks > 20, should be split (20 per batch by default)
        XCTAssertGreaterThan(batches.count, 1)
        XCTAssertLessThanOrEqual(batches[0].blocks.count, 20)
    }

    func testExceedsMaxBlocksTrimmed() {
        let batcher = TranslationBatcher(maxBlocks: 50, maxCharacters: 10000)

        var blocks: [TextBlock] = []
        for i in 1...60 {
            blocks.append(TextBlock(id: i, sourceText: "Block \(i)", boundingBox: .zero, confidence: 1.0))
        }

        let batches = batcher.batch(blocks)
        let totalBlockCount = batches.reduce(0) { $0 + $1.blocks.count }
        XCTAssertLessThanOrEqual(totalBlockCount, 50)
    }

    func testFallbackBatchSmallerChunks() {
        let batcher = TranslationBatcher()

        var blocks: [TextBlock] = []
        for i in 1...12 {
            blocks.append(TextBlock(id: i, sourceText: "Fallback block \(i)", boundingBox: .zero, confidence: 1.0))
        }

        let batches = batcher.fallbackBatch(blocks)
        // Should create chunks of 5
        XCTAssertEqual(batches.count, 3) // 5 + 5 + 2
        XCTAssertEqual(batches[0].blocks.count, 5)
        XCTAssertEqual(batches[1].blocks.count, 5)
        XCTAssertEqual(batches[2].blocks.count, 2)
    }

    func testSingleBlockBatches() {
        let batcher = TranslationBatcher()

        var blocks: [TextBlock] = []
        for i in 1...3 {
            blocks.append(TextBlock(id: i, sourceText: "Single \(i)", boundingBox: .zero, confidence: 1.0))
        }

        let batches = batcher.singleBlockBatches(blocks)
        XCTAssertEqual(batches.count, 3)
        for batch in batches {
            XCTAssertEqual(batch.blocks.count, 1)
        }
    }

    func testEmptyBlocks() {
        let batcher = TranslationBatcher()
        let batches = batcher.batch([])
        XCTAssertTrue(batches.isEmpty)
    }

    func testCharacterLimitSplitting() {
        let batcher = TranslationBatcher(maxBlocks: 50, maxCharacters: 200)

        var blocks: [TextBlock] = []
        // Create 3 blocks of ~100 chars each
        for i in 1...3 {
            let longText = String(repeating: "A", count: 100)
            blocks.append(TextBlock(id: i, sourceText: longText, boundingBox: .zero, confidence: 1.0))
        }

        let batches = batcher.batch(blocks)
        // Should split into multiple batches due to character limit
        XCTAssertGreaterThan(batches.count, 1)
    }
}
