//
//  CapsuleStatus.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import Foundation

enum CapsuleStatus: String, Codable, CaseIterable {
    case sealed
    case opened
    case fulfilled
    case unfolding
    case changed
    case released

    var title: String {
        switch self {
        case .sealed: String(localized: "Запечатана")
        case .opened: String(localized: "Открыта")
        case .fulfilled: String(localized: "Сбылось")
        case .unfolding: String(localized: "Еще сбывается")
        case .changed: String(localized: "Сбылось иначе")
        case .released: String(localized: "Не сбылось")
        }
    }
}
