//
//  NotificationSignal.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import Foundation
import SwiftData

@Model
final class NotificationSignal {
    var id: UUID
    var identifier: String
    var kindRawValue: String
    var title: String
    var message: String
    var scheduledAt: Date
    var createdAt: Date
    var cancelledAt: Date?
    var capsuleID: UUID?

    init(
        id: UUID = UUID(),
        identifier: String,
        kind: NotificationSignalKind,
        title: String,
        message: String,
        scheduledAt: Date,
        createdAt: Date = Date(),
        cancelledAt: Date? = nil,
        capsuleID: UUID? = nil
    ) {
        self.id = id
        self.identifier = identifier
        self.kindRawValue = kind.rawValue
        self.title = title
        self.message = message
        self.scheduledAt = scheduledAt
        self.createdAt = createdAt
        self.cancelledAt = cancelledAt
        self.capsuleID = capsuleID
    }

    var kind: NotificationSignalKind {
        get { NotificationSignalKind(rawValue: kindRawValue) ?? .capsuleOpen }
        set { kindRawValue = newValue.rawValue }
    }

    var isCancelled: Bool {
        cancelledAt != nil
    }

    var hasPassed: Bool {
        scheduledAt <= Date()
    }
}

enum NotificationSignalKind: String, CaseIterable {
    case capsuleOpen
    case capsuleSoon
    case capsuleRevisit
    case reactivation
    case morningDream

    var title: String {
        switch self {
        case .capsuleOpen:
            "Открытие капсулы"
        case .capsuleSoon:
            "Капсула близко"
        case .capsuleRevisit:
            "Перечитать себя"
        case .reactivation:
            "Мягкое возвращение"
        case .morningDream:
            "Утренний сон"
        }
    }

    var symbolName: String {
        switch self {
        case .capsuleOpen:
            "lock.open.fill"
        case .capsuleSoon:
            "hourglass"
        case .capsuleRevisit:
            "text.magnifyingglass"
        case .reactivation:
            "sparkles"
        case .morningDream:
            "moon.stars.fill"
        }
    }
}
