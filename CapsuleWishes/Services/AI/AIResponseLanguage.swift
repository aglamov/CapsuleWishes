//
//  AIResponseLanguage.swift
//  CapsuleWishes
//
//  Created by Codex on 02.05.2026.
//

import Foundation

enum AIResponseLanguage {
    static var isRussian: Bool {
        Bundle.main.preferredLocalizations.first == "ru"
    }

    static var name: String {
        isRussian ? "Russian" : "English"
    }

    static var instruction: String {
        "Write every user-facing response in \(name)."
    }

    static var jsonInstruction: String {
        "All user-facing JSON string values must be in \(name). Keep JSON keys exactly as requested."
    }

    static func text(ru: String, en: String) -> String {
        isRussian ? ru : en
    }
}
