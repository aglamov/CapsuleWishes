//
//  NotificationRouteCenter.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationRouteCenter: ObservableObject {
    static let shared = NotificationRouteCenter()

    @Published var requestedCapsuleID: UUID?
    @Published var requestedJournalEntryType: JournalEntryType?
    @Published var requestedJournalPrompt: String?

    private init() { }

    func requestCapsuleOpen(_ capsuleID: UUID) {
        requestedCapsuleID = capsuleID
    }

    func requestJournalEntry(_ type: JournalEntryType, prompt: String? = nil) {
        requestedJournalEntryType = type
        requestedJournalPrompt = prompt
    }

    func consumeCapsuleOpenRequest() {
        requestedCapsuleID = nil
    }

    func consumeJournalEntryRequest() {
        requestedJournalEntryType = nil
        requestedJournalPrompt = nil
    }
}

final class AppNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if signal(from: userInfo) == "morning_dream" {
            Task { @MainActor in
                NotificationRouteCenter.shared.requestJournalEntry(.dream)
            }
        } else if let capsuleID = capsuleID(from: userInfo) {
            Task { @MainActor in
                NotificationRouteCenter.shared.requestCapsuleOpen(capsuleID)
            }
        }

        completionHandler()
    }

    private func capsuleID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let rawValue = userInfo["capsuleID"] as? String else { return nil }
        return UUID(uuidString: rawValue)
    }

    private func signal(from userInfo: [AnyHashable: Any]) -> String? {
        userInfo["signal"] as? String
    }
}
