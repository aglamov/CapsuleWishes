//
//  CapsuleWishesApp.swift
//  CapsuleWishes
//
//  Created by Рамиль Аглямов on 06.02.2025.
//

import SwiftUI

@main
struct CapsuleWishesApp: App {
    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self) private var notificationDelegate
    @StateObject private var notificationRouteCenter = NotificationRouteCenter.shared

    init() {
        UserDefaults.standard.register(defaults: [
            NotificationPreferences.modeKey: NotificationPreferences.defaultMode.rawValue,
            NotificationPreferences.morningDreamSignalsEnabledKey: NotificationPreferences.defaultMorningDreamSignalsEnabled,
            NotificationPreferences.morningDreamSignalHourKey: MorningSignalTime.defaultValue.hour,
            NotificationPreferences.morningDreamSignalMinuteKey: MorningSignalTime.defaultValue.minute,
            NotificationPreferences.lastMorningSignalAdjustmentDayKey: 0.0,
            AIUsagePreferences.enabledKey: AIUsagePreferences.defaultEnabled,
            AudioFeedbackPreferences.enabledKey: AudioFeedbackPreferences.defaultEnabled
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationRouteCenter)
        }
        .modelContainer(SwiftDataContainer.shared)
    }
}
