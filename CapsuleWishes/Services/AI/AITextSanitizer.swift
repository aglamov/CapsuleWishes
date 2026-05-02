//
//  AITextSanitizer.swift
//  CapsuleWishes
//
//  Created by Codex on 02.05.2026.
//

import Foundation

enum AITextSanitizer {
    static func optional(_ text: String) -> String? {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))

        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static func value(_ text: String, fallback: String) -> String {
        optional(text) ?? fallback
    }
}
