import Vision
import CoreGraphics
import os

final class VisionOCRService: OCRService {
    private let logger = Logger(subsystem: "com.macgamelens.translator", category: "ocr")

    func recognizeText(in image: CGImage) async throws -> [OCRTextObservation] {
        logger.debug("Starting OCR recognition")

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { [logger] request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = self.processResults(request.results as? [VNRecognizedTextObservation])
                logger.debug("OCR complete: \(observations.count) observations")
                continuation.resume(returning: observations)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func processResults(_ results: [VNRecognizedTextObservation]?) -> [OCRTextObservation] {
        guard let results = results else { return [] }

        return results.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            return OCRTextObservation(
                id: UUID(),
                text: text,
                confidence: observation.confidence,
                boundingBox: observation.boundingBox
            )
        }
    }
}
