//
//  AudioCue.swift
//  CapsuleWishes
//
//  Created by Codex on 02.05.2026.
//

enum AudioCue: String, CaseIterable {
    case capsuleGather
    case capsuleLaunch
    case capsuleSeal
    case capsuleAwaken
    case capsuleRelease
    case afterglow
    case journalSave
    case letterOpen
    case softSelect

    var fileName: String {
        switch self {
        case .capsuleGather:
            return "capsule_gather"
        case .capsuleLaunch:
            return "capsule_launch"
        case .capsuleSeal:
            return "capsule_seal"
        case .capsuleAwaken:
            return "capsule_awaken"
        case .capsuleRelease:
            return "capsule_release"
        case .afterglow:
            return "afterglow"
        case .journalSave:
            return "journal_save"
        case .letterOpen:
            return "letter_open"
        case .softSelect:
            return "soft_select"
        }
    }

    var volume: Float {
        switch self {
        case .capsuleRelease:
            return 0.42
        case .capsuleGather, .capsuleLaunch, .capsuleSeal, .capsuleAwaken, .afterglow:
            return 0.34
        case .journalSave, .letterOpen:
            return 0.30
        case .softSelect:
            return 0.18
        }
    }
}
