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
        case .sign: "Странность"
        case .thought: "Мысль"
        case .dream: "Сон"
        case .step: "Шаг"
        }
    }

    var prompt: String {
        switch self {
        case .sign: "Что сегодня показалось случайным, но почему-то задержалось внутри?"
        case .thought: "Какая мысль вернулась к тебе рядом с этим желанием?"
        case .dream: "Что запомнилось из сна, образа или полусна?"
        case .step: "Какой маленький жест ты сделал в сторону желания?"
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
