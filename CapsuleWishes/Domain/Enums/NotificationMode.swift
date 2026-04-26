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
            "Тишина"
        case .soft:
            "Мягко"
        case .engaged:
            "Вовлечение"
        }
    }

    var description: String {
        switch self {
        case .quiet:
            "Только момент открытия капсул."
        case .soft:
            "Редкие возвращения и точные сигналы."
        case .engaged:
            "Больше касаний, но без давления."
        }
    }
}
