import CoreGraphics
import Foundation

struct TextBlockMerger {
    struct Config {
        var verticalDistanceThreshold: CGFloat
        var horizontalOverlapRatio: CGFloat
        var heightSimilarityThreshold: CGFloat

        static let `default` = Config(
            verticalDistanceThreshold: 8,
            horizontalOverlapRatio: 0.3,
            heightSimilarityThreshold: 0.5
        )
    }

    let config: Config

    init(config: Config = .default) {
        self.config = config
    }

    func merge(
        _ observations: [OCRTextObservation],
        pixelSize: CGSize,
        scaleFactor: CGFloat
    ) -> [TextBlock] {
        guard !observations.isEmpty else { return [] }

        let imageW = pixelSize.width
        let imageH = pixelSize.height

        // Convert Vision normalized coords → overlay point coords (top-left origin in points)
        let converted: [(obs: OCRTextObservation, frame: CGRect)] = observations.map { obs in
            let pixelX = obs.boundingBox.minX * imageW
            let pixelYFromBottom = obs.boundingBox.minY * imageH
            let pixelW = obs.boundingBox.width * imageW
            let pixelH = obs.boundingBox.height * imageH

            let displayHeightPoints = imageH / scaleFactor

            let pointX = pixelX / scaleFactor
            let pointYFromBottom = pixelYFromBottom / scaleFactor
            let pointW = pixelW / scaleFactor
            let pointH = pixelH / scaleFactor

            let pointYFromTop = displayHeightPoints - pointYFromBottom - pointH

            let frame = CGRect(x: pointX, y: pointYFromTop, width: pointW, height: pointH)
            return (obs, frame)
        }

        // Sort by y (top to bottom), then x (left to right)
        let sorted = converted.sorted { a, b in
            if abs(a.frame.minY - b.frame.minY) < 5 {
                return a.frame.minX < b.frame.minX
            }
            return a.frame.minY < b.frame.minY
        }

        var blocks: [TextBlock] = []
        var nextId = 1

        for item in sorted {
            let obs = item.obs
            let frame = item.frame

            var merged = false
            for i in 0..<blocks.count {
                let existing = blocks[i]
                if shouldMerge(newFrame: frame, existingFrame: existing.boundingBox) {
                    let unionFrame = existing.boundingBox.union(frame)
                    var mergedLines = existing.lines
                    mergedLines.append(obs.text)
                    blocks[i] = TextBlock(
                        id: existing.id,
                        sourceText: mergedLines.joined(separator: " "),
                        boundingBox: unionFrame,
                        confidence: min(existing.confidence, obs.confidence),
                        lines: mergedLines
                    )
                    merged = true
                    break
                }
            }

            if !merged {
                blocks.append(TextBlock(
                    id: nextId,
                    sourceText: obs.text,
                    boundingBox: frame,
                    confidence: obs.confidence,
                    lines: [obs.text]
                ))
                nextId += 1
            }
        }

        return blocks
    }

    private func shouldMerge(newFrame: CGRect, existingFrame: CGRect) -> Bool {
        // Vertical distance: gap between upper block bottom and lower block top
        let (upper, lower) = existingFrame.minY < newFrame.minY
            ? (existingFrame, newFrame)
            : (newFrame, existingFrame)
        let verticalDistance = max(0, lower.minY - upper.maxY)

        if verticalDistance > config.verticalDistanceThreshold {
            return false
        }

        // Horizontal overlap
        let overlapMinX = max(newFrame.minX, existingFrame.minX)
        let overlapMaxX = min(newFrame.maxX, existingFrame.maxX)
        let overlapWidth = max(0, overlapMaxX - overlapMinX)
        let minWidth = min(newFrame.width, existingFrame.width)

        guard minWidth > 0 else { return false }
        let overlapRatio = overlapWidth / minWidth

        if overlapRatio < config.horizontalOverlapRatio {
            return false
        }

        // Height similarity
        let maxHeight = max(newFrame.height, existingFrame.height)
        guard maxHeight > 0 else { return false }
        let heightDiff = abs(newFrame.height - existingFrame.height)
        let heightSimilarity = heightDiff / maxHeight

        if heightSimilarity > config.heightSimilarityThreshold {
            return false
        }

        return true
    }
}
