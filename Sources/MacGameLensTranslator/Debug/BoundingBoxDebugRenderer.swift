import CoreGraphics
import AppKit

struct BoundingBoxDebugRenderer {
    let color: NSColor
    let lineWidth: CGFloat

    init(color: NSColor = .systemRed, lineWidth: CGFloat = 1.5) {
        self.color = color
        self.lineWidth = lineWidth
    }

    func renderBoundingBoxes(
        _ observations: [OCRTextObservation],
        pixelSize: CGSize,
        scaleFactor: CGFloat,
        in context: CGContext,
        viewHeight: CGFloat
    ) {
        for obs in observations {
            let bbox = obs.boundingBox

            // Convert Vision normalized (bottom-left) to overlay flipped (top-left) in points
            let pixelX = bbox.minX * pixelSize.width
            let pixelYFromBottom = bbox.minY * pixelSize.height
            let pixelW = bbox.width * pixelSize.width
            let pixelH = bbox.height * pixelSize.height

            let displayHeightPoints = pixelSize.height / scaleFactor

            let pointX = pixelX / scaleFactor
            let pointYFromTop = displayHeightPoints - (pixelYFromBottom / scaleFactor) - (pixelH / scaleFactor)
            let pointW = pixelW / scaleFactor
            let pointH = pixelH / scaleFactor

            let rect = CGRect(x: pointX, y: pointYFromTop, width: pointW, height: pointH)

            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.stroke(rect)
        }
    }
}
