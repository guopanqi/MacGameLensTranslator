import Foundation

struct TextBlockFilter {
    let minimumConfidence: Float

    init(minimumConfidence: Float = 0.5) {
        self.minimumConfidence = minimumConfidence
    }

    func filter(_ observations: [OCRTextObservation]) -> [OCRTextObservation] {
        var seen = Set<String>()
        let filtered = observations.filter { observation in
            guard observation.confidence >= minimumConfidence else { return false }
            let trimmed = observation.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            guard !isOnlySymbols(trimmed) else { return false }

            let normalized = trimmed.lowercased()
            guard !seen.contains(normalized) else { return false }
            seen.insert(normalized)

            return true
        }
        return filtered
    }

    private func isOnlySymbols(_ text: String) -> Bool {
        let lettersAndDigits = CharacterSet.letters.union(.decimalDigits)
        return text.unicodeScalars.allSatisfy { !lettersAndDigits.contains($0) }
    }
}
