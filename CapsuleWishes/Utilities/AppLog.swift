//
//  AppLog.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import Foundation
import OSLog

enum AppLog {
    static let ai = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CapsuleWishes", category: "AI")
    static let notifications = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CapsuleWishes", category: "Notifications")
}
