import CoreGraphics
import Foundation

struct OverlayLayoutEngine {
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let verticalGap: CGFloat
    let screenMargin: CGFloat
    let fontSizeScale: Double

    init(
        minWidth: CGFloat = 160,
        maxWidth: CGFloat = 560,
        verticalGap: CGFloat = 8,
        screenMargin: CGFloat = 8,
        fontSizeScale: Double = 1.0
    ) {
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.verticalGap = verticalGap
        self.screenMargin = screenMargin
        self.fontSizeScale = fontSizeScale
    }

    func layout(_ blocks: [TextBlock], displayFrame: CGRect) -> [OverlayTextBlock] {
        let displayHeight = displayFrame.height

        var laidOutBlocks: [OverlayTextBlock] = []

        for block in blocks {
            guard let translatedText = block.translatedText, !translatedText.isEmpty else {
                continue
            }

            let sourceFrame = block.boundingBox

            // Prefer covering the source text area instead of adding another
            // row below it. This keeps dense game manuals readable and avoids
            // cascading translations over the next paragraph.
            var overlayX = sourceFrame.minX
            var overlayY = sourceFrame.minY

            let preferredWidth = max(sourceFrame.width + 24, minWidth)
            let overlayWidth = min(preferredWidth, maxWidth)

            // Estimate height based on text
            let overlayHeight = max(estimateHeight(for: translatedText, width: overlayWidth), sourceFrame.height + 8)

            // If the overlay goes below the screen, place it above
            if overlayY + overlayHeight > displayHeight - screenMargin {
                overlayY = sourceFrame.maxY - overlayHeight
            }

            // Clamp left/right within screen
            if overlayX < screenMargin {
                overlayX = screenMargin
            }
            if overlayX + overlayWidth > displayFrame.width - screenMargin {
                overlayX = displayFrame.width - overlayWidth - screenMargin
            }

            // Clamp top
            if overlayY < screenMargin {
                overlayY = screenMargin
            }

            var overlayFrame = CGRect(x: overlayX, y: overlayY, width: overlayWidth, height: overlayHeight)
            overlayFrame = avoidOverlaps(for: overlayFrame, existing: laidOutBlocks.map(\.overlayFrame), displayHeight: displayHeight)

            laidOutBlocks.append(OverlayTextBlock(
                id: block.id,
                sourceText: block.sourceText,
                translatedText: translatedText,
                sourceFrame: sourceFrame,
                overlayFrame: overlayFrame
            ))
        }

        return laidOutBlocks
    }

    private func estimateHeight(for text: String, width: CGFloat) -> CGFloat {
        let maxCharsPerLine = Int(width / 10)
        let charCount = text.count + text.unicodeScalars.filter { $0.value > 127 }.count
        let lines = max(1, ceil(Double(charCount) / Double(max(16, maxCharsPerLine))))
        let baseLineHeight: CGFloat = 18
        let scaledLineHeight = baseLineHeight * fontSizeScale
        let padding: CGFloat = 12
        return CGFloat(lines) * scaledLineHeight + padding
    }

    private func avoidOverlaps(for frame: CGRect, existing: [CGRect], displayHeight: CGFloat) -> CGRect {
        var adjusted = frame
        let maxPasses = 24

        for _ in 0..<maxPasses {
            guard let overlap = existing.first(where: { $0.intersects(adjusted.insetBy(dx: -2, dy: -verticalGap)) }) else {
                return adjusted
            }

            adjusted.origin.y = overlap.maxY + verticalGap
            if adjusted.maxY > displayHeight - screenMargin {
                adjusted.origin.y = max(screenMargin, frame.minY - adjusted.height - verticalGap)
                return adjusted
            }
        }

        return adjusted
    }
}
