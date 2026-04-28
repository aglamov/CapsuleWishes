import Foundation

final class ObservationAssistantService {
    // Toggle to simulate availability of AI features; in real app this would check configuration
    var isAvailable: Bool {
        // Assume availability is governed elsewhere; return true to enable button behavior.
        true
    }

    /// Returns a polished version of the observation text, or nil if polishing failed.
    /// - Parameters:
    ///   - text: Original user-entered observation text
    ///   - type: Entry type context to help polishing
    ///   - capsuleTitle: Optional capsule title for extra context
    func polishedObservation(_ text: String, type: JournalEntryType, capsuleTitle: String?) async -> String? {
        // If not available or text is empty, return the original as a no-op.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }

        // Here you'd call your AI backend. For now, simulate a light rewrite.
        // Keep it deterministic and safe for offline/demo builds.
        let prefix: String
        switch type {
        case .sign: prefix = "Знак: "
        case .thought: prefix = "Мысль: "
        case .dream: prefix = "Сон: "
        case .step: prefix = "Шаг: "
        }

        // Add gentle polishing: capitalize first letter and ensure ending punctuation.
        let capitalized = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        let endsWithPunctuation = capitalized.last.map({ ".!?".contains($0) }) ?? false
        let withPunctuation = endsWithPunctuation ? capitalized : capitalized + "."

        if let title = capsuleTitle, !title.isEmpty {
            return "\(prefix)\(withPunctuation) (вокруг: \(title))"
        } else {
            return "\(prefix)\(withPunctuation)"
        }
    }
}
