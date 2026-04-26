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
    @EnvironmentObject private var notificationRouteCenter: NotificationRouteCenter
    @AppStorage(NotificationPreferences.modeKey) private var notificationModeRawValue = NotificationMode.soft.rawValue
    @AppStorage(NotificationPreferences.morningDreamSignalsEnabledKey) private var morningDreamSignalsEnabled = false
    @AppStorage(NotificationPreferences.morningDreamSignalHourKey) private var morningDreamSignalHour = MorningSignalTime.defaultValue.hour
    @AppStorage(NotificationPreferences.morningDreamSignalMinuteKey) private var morningDreamSignalMinute = MorningSignalTime.defaultValue.minute
    @AppStorage(NotificationPreferences.lastMorningSignalAdjustmentDayKey) private var lastMorningSignalAdjustmentDay = 0.0
    @Query(sort: \WishCapsule.openAt, order: .forward) private var capsules: [WishCapsule]
    @Query(sort: \NotificationSignal.scheduledAt, order: .forward) private var signals: [NotificationSignal]
    @State private var selectedTab: AppTab = .capsules

    private var notificationMode: NotificationMode {
        NotificationMode(rawValue: notificationModeRawValue) ?? .soft
    }

    private var notificationSyncKey: String {
        [
            notificationModeRawValue,
            morningDreamSignalsEnabled.description,
            "\(morningDreamSignalHour):\(morningDreamSignalMinute)",
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
        TabView(selection: $selectedTab) {
            CapsuleListView()
                .tabItem {
                    Label("Капсулы", systemImage: "sparkles")
                }
                .tag(AppTab.capsules)

            JournalView()
                .tabItem {
                    Label("Дневник", systemImage: "book.closed")
                }
                .tag(AppTab.journal)
        }
        .tint(.white)
        .onChange(of: notificationRouteCenter.requestedCapsuleID) { _, capsuleID in
            if capsuleID != nil {
                selectedTab = .capsules
            }
        }
        .task(id: notificationSyncKey) {
            adaptMorningSignalTimeIfNeeded()
            await syncNotifications()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }

            Task {
                adaptMorningSignalTimeIfNeeded()
                await syncNotifications()
            }
        }
    }

    private func syncNotifications() async {
        await CapsuleNotificationScheduler.shared.sync(
            capsules: capsules,
            mode: notificationMode,
            morningDreamsEnabled: morningDreamSignalsEnabled,
            morningDreamSignalTime: currentMorningSignalTime,
            customSignals: customSignals,
            modelContext: modelContext
        )
    }

    private var currentMorningSignalTime: MorningSignalTime {
        MorningSignalTime(hour: morningDreamSignalHour, minute: morningDreamSignalMinute)
    }

    private func adaptMorningSignalTimeIfNeeded(now: Date = Date(), calendar: Calendar = .current) {
        guard morningDreamSignalsEnabled else { return }

        let hour = calendar.component(.hour, from: now)
        guard (5..<12).contains(hour) else { return }

        let startOfToday = calendar.startOfDay(for: now)
        guard lastMorningSignalAdjustmentDay < startOfToday.timeIntervalSinceReferenceDate else { return }

        let minute = calendar.component(.minute, from: now)
        let openedAt = MorningSignalTime(hour: hour, minute: minute)
        let adjustedTime = currentMorningSignalTime.adjustedToward(openedAt)

        morningDreamSignalHour = adjustedTime.hour
        morningDreamSignalMinute = adjustedTime.minute
        lastMorningSignalAdjustmentDay = startOfToday.timeIntervalSinceReferenceDate
    }

    private var customSignals: [NotificationSignal] {
        signals.filter { $0.kind == .futureLetter || $0.kind == .wishPlanCheckpoint }
    }
}

private enum AppTab {
    case capsules
    case journal
}

#Preview {
    ContentView()
        .environmentObject(NotificationRouteCenter.shared)
        .modelContainer(for: [WishCapsule.self, JournalEntry.self, NotificationSignal.self], inMemory: true)
}
