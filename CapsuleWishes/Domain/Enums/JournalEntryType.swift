//
//  JournalEntryType.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import Foundation

enum JournalEntryType: String, Codable, CaseIterable, Identifiable {
    case sign
    case smallJoy
    case thought
    case dream
    case gratitude
    case step

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sign: "Странность"
        case .smallJoy: "Радость"
        case .thought: "Мысль"
        case .dream: "Сон"
        case .gratitude: "Благодарность"
        case .step: "Шаг"
        }
    }

    var prompt: String {
        switch self {
        case .sign: "Что сегодня было чуть-чуть необычным?"
        case .smallJoy: "Что сделало день хотя бы на 1% легче?"
        case .thought: "Какая мысль возвращалась к тебе?"
        case .dream: "Что запомнилось из сна или полусна?"
        case .gratitude: "За что сегодня можно тихо поблагодарить?"
        case .step: "Какой маленький шаг ты сделал?"
        }
    }

    var symbolName: String {
        switch self {
        case .sign: "sparkles"
        case .smallJoy: "sun.max"
        case .thought: "text.bubble"
        case .dream: "moon.stars"
        case .gratitude: "heart"
        case .step: "figure.walk"
        }
    }
}
