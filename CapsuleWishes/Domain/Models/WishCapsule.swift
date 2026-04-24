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

    var hasBeenOpened: Bool {
        status != .sealed
    }
}
