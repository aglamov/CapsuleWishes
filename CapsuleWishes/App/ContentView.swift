//
//  ContentView.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("notificationMode") private var notificationModeRawValue = NotificationMode.soft.rawValue
    @AppStorage("morningDreamSignalsEnabled") private var morningDreamSignalsEnabled = false
    @Query(sort: \WishCapsule.openAt, order: .forward) private var capsules: [WishCapsule]

    private var notificationMode: NotificationMode {
        NotificationMode(rawValue: notificationModeRawValue) ?? .soft
    }

    private var notificationSyncKey: String {
        [
            notificationModeRawValue,
            morningDreamSignalsEnabled.description,
            capsules.map { "\($0.id.uuidString):\($0.statusRawValue):\($0.openAt.timeIntervalSince1970)" }.joined(separator: "|"),
        ].joined(separator: "#")
    }

    var body: some View {
        TabView {
            CapsuleListView()
                .tabItem {
                    Label("Капсулы", systemImage: "sparkles")
                }

            JournalView()
                .tabItem {
                    Label("Дневник", systemImage: "book.closed")
                }
        }
        .tint(.white)
        .task(id: notificationSyncKey) {
            await syncNotifications()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }

            Task {
                await syncNotifications()
            }
        }
    }

    private func syncNotifications() async {
        await CapsuleNotificationScheduler.shared.sync(
            capsules: capsules,
            mode: notificationMode,
            morningDreamsEnabled: morningDreamSignalsEnabled,
            modelContext: modelContext
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WishCapsule.self, JournalEntry.self, NotificationSignal.self], inMemory: true)
}
