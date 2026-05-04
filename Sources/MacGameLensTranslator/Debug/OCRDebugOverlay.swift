import CoreGraphics
import Foundation
import os

enum OCRDebugOverlay {
    static func logObservations(_ observations: [OCRTextObservation], pixelSize: CGSize, scaleFactor: CGFloat) {
        let logger = Logger(subsystem: "com.macgamelens.translator", category: "debug")
        logger.debug("=== OCR Debug: \(observations.count) observations ===")

        for obs in observations {
            let bbox = obs.boundingBox
            _ = bbox.minX * pixelSize.width
            let py = bbox.minY * pixelSize.height
            _ = bbox.width * pixelSize.width
            let ph = bbox.height * pixelSize.height

            let displayH = pixelSize.height / scaleFactor
            let topY = displayH - (py / scaleFactor) - (ph / scaleFactor)

            let confidencePercent = Int(obs.confidence * 100)
            logger.debug("[\(confidencePercent)%] \"\(obs.text)\" → pt(y=\(String(format: "%.1f", topY)))")
        }
    }
}
