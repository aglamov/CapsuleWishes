//
//  AIResponseLanguage.swift
//  CapsuleWishes
//
//  Created by Codex on 02.05.2026.
//

import Foundation

enum AIResponseLanguage {
    static var isRussian: Bool {
        code == "ru"
    }

    private static var code: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    static var name: String {
        switch code {
        case "ru":
            "Russian"
        case "de":
            "German"
        case "fr":
            "French"
        case "es":
            "Spanish"
        default:
            "English"
        }
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
