import AppKit
import CoreGraphics

final class OverlayCanvasView: NSView {
    var blocks: [OverlayTextBlock] = [] {
        didSet { needsDisplay = true }
    }

    var showDebugBounds: Bool = false {
        didSet { needsDisplay = true }
    }

    var overlayOpacity: CGFloat = 0.75
    var fontSizeScale: Double = 1.0

    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        for block in blocks {
            if showDebugBounds {
                drawDebugBounds(for: block)
            }
            drawTranslationBlock(block)
        }
    }

    private func drawTranslationBlock(_ block: OverlayTextBlock) {
        let frame = block.overlayFrame

        // Background
        let bgColor = NSColor.black.withAlphaComponent(overlayOpacity)
        let bgPath = NSBezierPath(roundedRect: frame, xRadius: 6, yRadius: 6)
        bgColor.setFill()
        bgPath.fill()

        // Border shadow effect (subtle)
        let borderPath = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        NSColor.white.withAlphaComponent(0.15).setStroke()
        borderPath.lineWidth = 1
        borderPath.stroke()

        // Text
        let textRect = frame.insetBy(dx: 8, dy: 6)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping

        let fontSize: CGFloat = 13 * fontSizeScale
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let text = block.translatedText as NSString
        text.draw(in: textRect, withAttributes: attrs)
    }

    private func drawDebugBounds(for block: OverlayTextBlock) {
        // Source text bounding box (in red)
        let sourcePath = NSBezierPath(rect: block.sourceFrame)
        NSColor.red.withAlphaComponent(0.4).setStroke()
        sourcePath.lineWidth = 1
        sourcePath.stroke()

        // Overlay frame (in green)
        let overlayPath = NSBezierPath(rect: block.overlayFrame)
        NSColor.green.withAlphaComponent(0.4).setStroke()
        overlayPath.lineWidth = 1
        overlayPath.stroke()
    }
}
