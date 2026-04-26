//
//  String+JSONExtraction.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import Foundation

extension String {
    func extractedJSONObject() -> String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }

        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end
        else { return nil }

        return String(trimmed[start...end])
    }
}
