import CoreGraphics
import Foundation
import os

enum CoordinateDebugDumper {
    static func dumpConversion(
        _ observations: [OCRTextObservation],
        pixelSize: CGSize,
        scaleFactor: CGFloat,
        displayFrame: CGRect
    ) {
        let logger = Logger(subsystem: "com.macgamelens.translator", category: "coordinate")
        logger.debug("=== Coordinate Debug: image=\(Int(pixelSize.width))x\(Int(pixelSize.height)), scale=\(String(describing: scaleFactor)), displayFrame=\(String(describing: displayFrame)) ===")

        for (i, obs) in observations.enumerated() {
            let bbox = obs.boundingBox

            let pixelX = bbox.minX * pixelSize.width
            let pixelYFromBottom = bbox.minY * pixelSize.height
            let pixelW = bbox.width * pixelSize.width
            let pixelH = bbox.height * pixelSize.height

            let displayHeightPoints = pixelSize.height / scaleFactor

            let pointX = pixelX / scaleFactor
            let pointYFromBottom = pixelYFromBottom / scaleFactor
            let pointW = pixelW / scaleFactor
            let pointH = pixelH / scaleFactor
            let pointYFromTop = displayHeightPoints - pointYFromBottom - pointH

            logger.debug("""
            [\(i)] "\(obs.text)" (conf: \(String(format: "%.2f", obs.confidence)))
              Vision:  (\(String(format: "%.3f", bbox.minX)), \(String(format: "%.3f", bbox.minY)), \(String(format: "%.3f", bbox.width)), \(String(format: "%.3f", bbox.height)))
              Pixel:   (\(Int(pixelX)), \(Int(pixelYFromBottom)), \(Int(pixelW)), \(Int(pixelH)))
              Points:  (\(String(format: "%.1f", pointX)), bottom=\(String(format: "%.1f", pointYFromBottom)), \(String(format: "%.1f", pointW)), \(String(format: "%.1f", pointH)))
              Overlay: (\(String(format: "%.1f", pointX)), \(String(format: "%.1f", pointYFromTop)), \(String(format: "%.1f", pointW)), \(String(format: "%.1f", pointH)))
            """)
        }
    }
}
