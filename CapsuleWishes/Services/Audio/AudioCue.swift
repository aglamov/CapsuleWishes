//
//  AudioCue.swift
//  CapsuleWishes
//
//  Created by Codex on 02.05.2026.
//

enum AudioCue: String, CaseIterable {
    case capsuleSeal
    case capsuleRelease
    case journalSave
    case letterOpen
    case sealingFortuneOpen
    case softSelect

    var fileName: String {
        switch self {
        case .capsuleSeal:
            return "capsule_seal"
        case .capsuleRelease:
            return "capsule_release"
        case .journalSave:
            return "journal_save"
        case .letterOpen:
            return "letter_open"
        case .sealingFortuneOpen:
            return "sealing_fortune_open"
        case .softSelect:
            return "soft_select"
        }
    }

    var volume: Float {
        switch self {
        case .capsuleRelease:
            return 0.42
        case .capsuleSeal:
            return 0.34
        case .journalSave, .letterOpen, .sealingFortuneOpen:
            return 0.30
        case .softSelect:
            return 0.18
        }
    }
}
