import CoreGraphics
import Foundation

struct TextBlock: Identifiable {
    let id: Int
    var sourceText: String
    var translatedText: String?
    var boundingBox: CGRect
    var confidence: Float
    var lines: [String] = []
}
