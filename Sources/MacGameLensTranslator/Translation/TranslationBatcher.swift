import Foundation

struct TranslationBatcher {
    let maxBlocks: Int
    let maxCharacters: Int

    init(maxBlocks: Int = 50, maxCharacters: Int = 10000) {
        self.maxBlocks = maxBlocks
        self.maxCharacters = maxCharacters
    }

    struct Batch {
        let blocks: [TextBlock]
        let isTrimmed: Bool
    }

    /// Split blocks into batches respecting size limits.
    func batch(_ blocks: [TextBlock]) -> [Batch] {
        var trimmed = blocks

        // Trim to max blocks
        if trimmed.count > maxBlocks {
            trimmed = Array(trimmed.prefix(maxBlocks))
        }

        // Filter blocks that exceed individual limits
        trimmed = trimmed.filter { $0.sourceText.count <= 500 }

        // Split into batches
        var batches: [Batch] = []
        var currentBatch: [TextBlock] = []
        var currentCharCount = 0

        for block in trimmed {
            let blockChars = block.sourceText.count

            if currentBatch.count >= 20 || (currentCharCount + blockChars > maxCharacters && !currentBatch.isEmpty) {
                batches.append(Batch(blocks: currentBatch, isTrimmed: false))
                currentBatch = []
                currentCharCount = 0
            }

            currentBatch.append(block)
            currentCharCount += blockChars
        }

        if !currentBatch.isEmpty {
            batches.append(Batch(blocks: currentBatch, isTrimmed: currentBatch.count < trimmed.count))
        }

        return batches
    }

    /// Fallback: split into smaller batches of 5 blocks each
    func fallbackBatch(_ blocks: [TextBlock]) -> [Batch] {
        let chunkSize = 5
        var batches: [Batch] = []
        for i in stride(from: 0, to: blocks.count, by: chunkSize) {
            let chunk = Array(blocks[i..<min(i + chunkSize, blocks.count)])
            batches.append(Batch(blocks: chunk, isTrimmed: false))
        }
        return batches
    }

    /// Single-block batches for last-resort fallback
    func singleBlockBatches(_ blocks: [TextBlock]) -> [Batch] {
        return blocks.map { Batch(blocks: [$0], isTrimmed: false) }
    }
}
