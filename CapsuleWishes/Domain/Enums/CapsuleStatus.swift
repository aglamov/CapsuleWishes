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
        case .sealed: "Запечатана"
        case .opened: "Открыта"
        case .fulfilled: "Сбылось"
        case .unfolding: "Еще сбывается"
        case .changed: "Сбылось иначе"
        case .released: "Не сбылось"
        }
    }
}
