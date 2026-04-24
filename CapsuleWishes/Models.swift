//
//  Models.swift
//  CapsuleWishes
//
//  Created by Codex on 22.04.2026.
//

import Foundation
import SwiftData
import SwiftUI

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
        case .unfolding: "Сбывается"
        case .changed: "Изменилось"
        case .released: "Отпущено"
        }
    }
}

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

@Model
final class WishCapsule {
    var id: UUID
    var title: String
    var intentionText: String
    var desiredFeeling: String
    var createdAt: Date
    var sealedAt: Date
    var openAt: Date
    var openedAt: Date?
    var statusRawValue: String
    var colorHex: String
    var symbol: String

    init(
        id: UUID = UUID(),
        title: String,
        intentionText: String,
        desiredFeeling: String,
        createdAt: Date = Date(),
        sealedAt: Date = Date(),
        openAt: Date,
        status: CapsuleStatus = .sealed,
        colorHex: String,
        symbol: String
    ) {
        self.id = id
        self.title = title
        self.intentionText = intentionText
        self.desiredFeeling = desiredFeeling
        self.createdAt = createdAt
        self.sealedAt = sealedAt
        self.openAt = openAt
        self.statusRawValue = status.rawValue
        self.colorHex = colorHex
        self.symbol = symbol
    }

    var status: CapsuleStatus {
        get { CapsuleStatus(rawValue: statusRawValue) ?? .sealed }
        set { statusRawValue = newValue.rawValue }
    }

    var isReadyToOpen: Bool {
        status == .sealed && openAt <= Date()
    }
}

@Model
final class JournalEntry {
    var id: UUID
    var capsuleID: UUID?
    var typeRawValue: String
    var text: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        capsuleID: UUID?,
        type: JournalEntryType,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.capsuleID = capsuleID
        self.typeRawValue = type.rawValue
        self.text = text
        self.createdAt = createdAt
    }

    var type: JournalEntryType {
        get { JournalEntryType(rawValue: typeRawValue) ?? .thought }
        set { typeRawValue = newValue.rawValue }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch hex.count {
        case 6:
            (red, green, blue) = ((int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:
            (red, green, blue) = (118, 214, 255)
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}
