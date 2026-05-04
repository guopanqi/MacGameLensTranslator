import CoreGraphics

protocol OCRService {
    func recognizeText(in image: CGImage) async throws -> [OCRTextObservation]
}
