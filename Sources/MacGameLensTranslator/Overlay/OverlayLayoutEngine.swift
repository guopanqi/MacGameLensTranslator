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
        maxWidth: CGFloat = 420,
        verticalGap: CGFloat = 4,
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

        return blocks.compactMap { block in
            guard let translatedText = block.translatedText, !translatedText.isEmpty else {
                return nil
            }

            let sourceFrame = block.boundingBox

            // Calculate preferred overlay position (below source text)
            var overlayX = sourceFrame.minX
            var overlayY = sourceFrame.maxY + verticalGap

            let preferredWidth = max(sourceFrame.width * 1.5, minWidth)
            let overlayWidth = min(preferredWidth, maxWidth)

            // Estimate height based on text
            let overlayHeight = estimateHeight(for: translatedText, width: overlayWidth)

            // If the overlay goes below the screen, place it above
            if overlayY + overlayHeight > displayHeight - screenMargin {
                overlayY = sourceFrame.minY - overlayHeight - verticalGap
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

            let overlayFrame = CGRect(x: overlayX, y: overlayY, width: overlayWidth, height: overlayHeight)

            return OverlayTextBlock(
                id: block.id,
                sourceText: block.sourceText,
                translatedText: translatedText,
                sourceFrame: sourceFrame,
                overlayFrame: overlayFrame
            )
        }
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
}
