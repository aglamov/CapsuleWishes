//
//  WishCapsule.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import Foundation
import SwiftData

@Model
final class WishCapsule {
    var id: UUID = UUID()
    var title: String = ""
    var intentionText: String = ""
    var desiredFeeling: String = ""
    var createdAt: Date = Date()
    var sealedAt: Date = Date()
    var openAt: Date = Date()
    var openedAt: Date?
    var statusRawValue: String = CapsuleStatus.sealed.rawValue
    var colorHex: String = ""
    var symbol: String = "star"
    var sealingFortuneText: String?
    var openingReflectionText: String?

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
        symbol: String,
        sealingFortuneText: String? = nil,
        openingReflectionText: String? = nil
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
        self.sealingFortuneText = sealingFortuneText
        self.openingReflectionText = openingReflectionText
    }

    var status: CapsuleStatus {
        get { CapsuleStatus(rawValue: statusRawValue) ?? .sealed }
        set { statusRawValue = newValue.rawValue }
    }

    var isReadyToOpen: Bool {
        let calendar = Calendar.current
        return status == .sealed && calendar.startOfDay(for: openAt) <= calendar.startOfDay(for: Date())
    }

    var hasBeenOpened: Bool {
        status != .sealed
    }
}
