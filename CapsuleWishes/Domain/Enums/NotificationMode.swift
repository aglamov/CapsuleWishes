//
//  NotificationMode.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import Foundation

enum NotificationMode: String, CaseIterable, Identifiable {
    case quiet
    case soft
    case engaged

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiet:
            String(localized: "Тишина")
        case .soft:
            String(localized: "Мягко")
        case .engaged:
            String(localized: "Вовлечение")
        }
    }

    var description: String {
        switch self {
        case .quiet:
            String(localized: "Только момент открытия капсул.")
        case .soft:
            String(localized: "Редкие возвращения и точные сигналы.")
        case .engaged:
            String(localized: "Больше касаний, но без давления.")
        }
    }
}
