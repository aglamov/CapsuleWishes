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
            AIUsagePreferences.enabledKey: AIUsagePreferences.defaultEnabled
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
