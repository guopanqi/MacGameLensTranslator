import CoreGraphics
import Foundation

struct ScreenshotResult {
    let image: CGImage
    let displayFrame: CGRect
    let scaleFactor: CGFloat
    let pixelSize: CGSize
    let capturedAt: Date
}
