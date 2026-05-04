import CoreGraphics
import Foundation

struct OCRTextObservation: Identifiable {
    let id: UUID
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}
