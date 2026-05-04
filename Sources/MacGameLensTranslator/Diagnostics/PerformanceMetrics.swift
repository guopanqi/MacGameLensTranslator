import Foundation
import os

final class PerformanceMetrics {
    private let logger = Logger(subsystem: "com.macgamelens.translator", category: "performance")

    struct SnapshotMetrics {
        var captureDuration: TimeInterval = 0
        var ocrDuration: TimeInterval = 0
        var rawOCRObservationCount: Int = 0
        var filteredBlockCount: Int = 0
        var mergedBlockCount: Int = 0
        var translationBatchCount: Int = 0
        var translationDuration: TimeInterval = 0
        var jsonParseStatus: String = ""
        var overlayLayoutDuration: TimeInterval = 0
        var overlayRenderDuration: TimeInterval = 0
        var totalDuration: TimeInterval = 0
        var timestamp: Date = Date()
    }

    private(set) var lastMetrics: SnapshotMetrics?

    func record(_ metrics: SnapshotMetrics) {
        lastMetrics = metrics
        logger.info("""
        Performance Summary:
          Capture: \(String(format: "%.0f", metrics.captureDuration * 1000))ms
          OCR: \(String(format: "%.0f", metrics.ocrDuration * 1000))ms (\(metrics.rawOCRObservationCount) raw)
          Filtered: \(metrics.filteredBlockCount) blocks
          Merged: \(metrics.mergedBlockCount) blocks
          Translation: \(String(format: "%.0f", metrics.translationDuration * 1000))ms (\(metrics.translationBatchCount) batches)
          Parse: \(metrics.jsonParseStatus)
          Layout: \(String(format: "%.0f", metrics.overlayLayoutDuration * 1000))ms
          Total: \(String(format: "%.0f", metrics.totalDuration * 1000))ms
        """)
    }
}
