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
    @AppStorage(NotificationPreferences.modeKey) private var notificationModeRawValue = NotificationMode.soft.rawValue
    @AppStorage(NotificationPreferences.morningDreamSignalsEnabledKey) private var morningDreamSignalsEnabled = false
    @Query(sort: \WishCapsule.openAt, order: .forward) private var capsules: [WishCapsule]
    @Query(sort: \NotificationSignal.scheduledAt, order: .forward) private var signals: [NotificationSignal]

    private var notificationMode: NotificationMode {
        NotificationMode(rawValue: notificationModeRawValue) ?? .soft
    }

    private var notificationSyncKey: String {
        [
            notificationModeRawValue,
            morningDreamSignalsEnabled.description,
            capsuleSyncFingerprint,
            signalSyncFingerprint,
        ].joined(separator: "#")
    }

    private var capsuleSyncFingerprint: String {
        capsules.map { "\($0.id.uuidString):\($0.statusRawValue):\($0.openAt.timeIntervalSince1970)" }.joined(separator: "|")
    }

    private var signalSyncFingerprint: String {
        signals.map { "\($0.identifier):\($0.scheduledAt.timeIntervalSince1970):\($0.cancelledAt?.timeIntervalSince1970 ?? 0)" }.joined(separator: "|")
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
            customSignals: signals.filter { $0.kind == .futureLetter || $0.kind == .wishPlanCheckpoint },
            modelContext: modelContext
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WishCapsule.self, JournalEntry.self, NotificationSignal.self], inMemory: true)
}
