//
//  JournalEntry.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import Foundation
import SwiftData

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
        get {
            if let type = JournalEntryType(rawValue: typeRawValue) {
                return type
            }

            switch typeRawValue {
            case "smallJoy":
                return .sign
            case "gratitude":
                return .thought
            default:
                return .thought
            }
        }
        set { typeRawValue = newValue.rawValue }
    }
}
