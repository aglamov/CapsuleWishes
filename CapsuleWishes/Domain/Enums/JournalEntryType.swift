//
//  JournalEntryType.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import Foundation

enum JournalEntryType: String, Codable, CaseIterable, Identifiable {
    case sign
    case thought
    case dream
    case step

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sign: String(localized: "Странность")
        case .thought: String(localized: "Мысль")
        case .dream: String(localized: "Сон")
        case .step: String(localized: "Шаг")
        }
    }

    var prompt: String {
        switch self {
        case .sign: String(localized: "Что сегодня показалось случайным, но почему-то задержалось внутри?")
        case .thought: String(localized: "Какая мысль вернулась к тебе рядом с этим желанием?")
        case .dream: String(localized: "Что запомнилось из сна, образа или полусна?")
        case .step: String(localized: "Какой маленький жест ты сделал в сторону желания?")
        }
    }

    var symbolName: String {
        switch self {
        case .sign: "sparkles"
        case .thought: "text.bubble"
        case .dream: "moon.stars"
        case .step: "figure.walk"
        }
    }
}
