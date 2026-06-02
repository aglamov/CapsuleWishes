//
//  CapsuleNotificationScheduler.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import Foundation
import SwiftData
import UserNotifications

final class CapsuleNotificationScheduler {
    static let shared = CapsuleNotificationScheduler()

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    private init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current
    ) {
        self.center = center
        self.calendar = calendar
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                AppLog.notifications.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        @unknown default:
            return false
        }
    }

    @MainActor
    func sync(
        capsules: [WishCapsule],
        mode: NotificationMode,
        morningDreamsEnabled: Bool,
        morningDreamSignalTime: MorningSignalTime = .defaultValue,
        customSignals: [NotificationSignal] = [],
        modelContext: ModelContext? = nil
    ) async {
        let sealedCapsules = capsules.filter { $0.status == .sealed }
        let capsuleIDs = Set(capsules.map(\.id))
        let customSignalIdentifiers = customSignals.map(\.identifier)

        center.removePendingNotificationRequests(withIdentifiers: managedIdentifiers(for: capsules) + customSignalIdentifiers)

        let specs = deconflictedSignalSpecs(signalSpecs(
            capsules: sealedCapsules,
            allCapsules: capsules,
            mode: mode,
            morningDreamsEnabled: morningDreamsEnabled,
            morningDreamSignalTime: morningDreamSignalTime
        ) + customSignalSpecs(customSignals, existingCapsuleIDs: capsuleIDs))

        updateLedger(with: specs, existingCapsuleIDs: capsuleIDs, modelContext: modelContext)

        guard !specs.isEmpty, await requestAuthorizationIfNeeded() else { return }

        for spec in specs {
            addNotification(for: spec)
        }
    }

    @MainActor
    func scheduleOpeningSignal(for capsule: WishCapsule, modelContext: ModelContext? = nil) {
        let morningSignalTime = storedMorningSignalTime()
        guard let date = openingSignalDate(for: capsule, morningSignalTime: morningSignalTime) else { return }

        let rawSpec = NotificationSignalSpec(
            id: Self.openIdentifier(for: capsule.id),
            kind: .capsuleOpen,
            title: String(localized: "Пора проверить желание"),
            body: String(localized: "Капсула открылась. Посмотри, сбылось ли то, что ты загадал."),
            date: date,
            capsuleID: capsule.id,
            userInfo: ["capsuleID": capsule.id.uuidString, "signal": "capsule_open"]
        )

        let spec = deconflictedSignalSpecs(
            [rawSpec],
            existingSignals: existingSignals(from: modelContext)
        )[0]

        updateLedger(with: [spec], modelContext: modelContext)
        addNotification(for: spec)
    }

    @MainActor
    func scheduleFutureLetter(
        _ draft: FutureLetterDraft,
        for capsule: WishCapsule,
        modelContext: ModelContext
    ) {
        guard draft.shouldCreate, capsule.status == .sealed else {
            AppLog.notifications.debug("Future letter schedule skipped: shouldCreate=\(draft.shouldCreate, privacy: .public), capsuleStatus=\(capsule.statusRawValue, privacy: .public)")
            return
        }

        let rawSpec = NotificationSignalSpec(
            id: Self.futureLetterIdentifier(for: capsule.id),
            kind: .futureLetter,
            title: String(localized: "Письмо из будущего"),
            body: draft.letter,
            date: draft.scheduledAt,
            capsuleID: capsule.id,
            userInfo: ["capsuleID": capsule.id.uuidString, "signal": "future_letter", "reason": draft.reason]
        )
        let spec = deconflictedSignalSpecs(
            [rawSpec],
            existingSignals: existingSignals(from: modelContext)
        )[0]

        updateLedger(with: [spec], modelContext: modelContext)
        addNotification(for: spec)

        AppLog.notifications.debug("Future letter scheduled: identifier=\(spec.id, privacy: .public), capsuleID=\(capsule.id.uuidString, privacy: .public), date=\(spec.date.formatted(date: .abbreviated, time: .shortened), privacy: .public)")
    }

    @MainActor
    func schedulePlanCheckpoints(
        _ checkpoints: [WishPlanCheckpoint],
        for capsule: WishCapsule,
        modelContext: ModelContext
    ) {
        guard capsule.status == .sealed, !checkpoints.isEmpty else { return }

        let rawSpecs = checkpoints.prefix(3).enumerated().compactMap { index, checkpoint in
            planCheckpointSpec(checkpoint, index: index, for: capsule)
        }
        let specs = deconflictedSignalSpecs(
            rawSpecs,
            existingSignals: existingSignals(from: modelContext)
        )

        guard !specs.isEmpty else { return }

        updateLedger(with: specs, modelContext: modelContext)

        for spec in specs {
            addNotification(for: spec)
        }

        AppLog.notifications.debug("Plan checkpoints scheduled: count=\(specs.count, privacy: .public), capsuleID=\(capsule.id.uuidString, privacy: .public)")
    }

    func cancelSignals(for capsule: WishCapsule) {
        center.removePendingNotificationRequests(withIdentifiers: Self.identifiers(for: capsule.id))
    }

    private func signalSpecs(
        capsules sealedCapsules: [WishCapsule],
        allCapsules: [WishCapsule],
        mode: NotificationMode,
        morningDreamsEnabled: Bool,
        morningDreamSignalTime: MorningSignalTime
    ) -> [NotificationSignalSpec] {
        var specs = sealedCapsules.compactMap {
            openingSignalSpec(for: $0, morningSignalTime: morningDreamSignalTime)
        }

        guard mode != .quiet else { return specs }

        if !allCapsules.isEmpty {
            specs += reactivationSignalSpecs()
        }

        if morningDreamsEnabled {
            specs.append(morningDreamSignalSpec(time: morningDreamSignalTime))
        }

        for capsule in sealedCapsules {
            specs += contextSignalSpecs(for: capsule, mode: mode)
        }

        return specs
    }

    private func openingSignalSpec(
        for capsule: WishCapsule,
        morningSignalTime: MorningSignalTime
    ) -> NotificationSignalSpec? {
        guard let date = openingSignalDate(for: capsule, morningSignalTime: morningSignalTime) else { return nil }

        return NotificationSignalSpec(
            id: Self.openIdentifier(for: capsule.id),
            kind: .capsuleOpen,
            title: String(localized: "Пора проверить желание"),
            body: String(localized: "Капсула открылась. Посмотри, сбылось ли то, что ты загадал."),
            date: date,
            capsuleID: capsule.id,
            userInfo: ["capsuleID": capsule.id.uuidString, "signal": "capsule_open"]
        )
    }

    private func openingSignalDate(
        for capsule: WishCapsule,
        morningSignalTime: MorningSignalTime
    ) -> Date? {
        guard capsule.status == .sealed else { return nil }

        let openingDay = calendar.startOfDay(for: capsule.openAt)
        let startMinute = morningSignalTime.totalMinutes
        let endMinute = 21 * 60
        let clampedStartMinute = min(startMinute, endMinute)
        let minuteOffset = stableMinuteOffset(
            for: capsule,
            on: openingDay,
            availableMinutes: endMinute - clampedStartMinute
        )
        let signalMinute = clampedStartMinute + minuteOffset

        guard let date = calendar.date(
            bySettingHour: signalMinute / 60,
            minute: signalMinute % 60,
            second: 0,
            of: openingDay
        ), date > Date() else {
            return nil
        }

        return date
    }

    private func stableMinuteOffset(
        for capsule: WishCapsule,
        on openingDay: Date,
        availableMinutes: Int
    ) -> Int {
        guard availableMinutes > 0 else { return 0 }

        var seed: UInt64 = 1469598103934665603
        let uuid = capsule.id.uuid
        withUnsafeBytes(of: uuid) { bytes in
            for byte in bytes {
                seed ^= UInt64(byte)
                seed &*= 1099511628211
            }
        }

        let components = calendar.dateComponents([.year, .month, .day], from: openingDay)
        for value in [components.year, components.month, components.day].compactMap(\.self) {
            seed ^= UInt64(value)
            seed &*= 1099511628211
        }

        return Int(seed % UInt64(availableMinutes + 1))
    }

    private func reactivationSignalSpecs() -> [NotificationSignalSpec] {
        let now = Date()
        let messages: [(Int, String, String)] = [
            (3, String(localized: "Ты оставил здесь что-то важное"), String(localized: "Иногда достаточно просто вернуться и посмотреть.")),
            (7, String(localized: "Интересно, что изменилось с того момента?"), String(localized: "Одна мысль может прозвучать иначе спустя неделю.")),
            (14, String(localized: "Твоё будущее не торопит тебя"), String(localized: "Но оно всё ещё здесь.")),
        ]

        return messages.compactMap { day, title, body in
            guard let date = calendar.date(byAdding: .day, value: day, to: now) else { return nil }

            return NotificationSignalSpec(
                id: "signal.reactivation.\(day)",
                kind: .reactivation,
                title: title,
                body: body,
                date: resonantDate(
                    on: date,
                    salt: "reactivation-\(day)",
                    startMinute: 12 * 60,
                    endMinute: 20 * 60 + 30
                ),
                capsuleID: nil,
                userInfo: ["signal": "reactivation", "day": day]
            )
        }
    }

    private func morningDreamSignalSpec(time: MorningSignalTime) -> NotificationSignalSpec {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = time.hour
        components.minute = time.minute

        let today = calendar.date(from: components) ?? Date()
        let nextDate = today > Date() ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today

        return NotificationSignalSpec(
            id: "signal.morningDream",
            kind: .morningDream,
            title: String(localized: "Сон ещё рядом"),
            body: String(localized: "Поймай его, пока он не исчез."),
            date: nextDate,
            capsuleID: nil,
            userInfo: ["signal": "morning_dream"],
            repeatsDaily: true
        )
    }

    private func storedMorningSignalTime() -> MorningSignalTime {
        let defaults = UserDefaults.standard
        let hour = defaults.object(forKey: NotificationPreferences.morningDreamSignalHourKey) as? Int
        let minute = defaults.object(forKey: NotificationPreferences.morningDreamSignalMinuteKey) as? Int

        return MorningSignalTime(
            hour: hour ?? MorningSignalTime.defaultValue.hour,
            minute: minute ?? MorningSignalTime.defaultValue.minute
        )
    }

    private func contextSignalSpecs(for capsule: WishCapsule, mode: NotificationMode) -> [NotificationSignalSpec] {
        var specs: [NotificationSignalSpec] = []

        if let soonDate = calendar.date(byAdding: .day, value: -1, to: capsule.openAt),
           soonDate > Date() {
            specs.append(NotificationSignalSpec(
                id: Self.soonIdentifier(for: capsule.id),
                kind: .capsuleSoon,
                title: String(localized: "Одна из твоих капсул скоро станет ближе"),
                body: String(localized: "Время уже почти донесло её до тебя."),
                date: resonantDate(
                    on: soonDate,
                    capsule: capsule,
                    salt: "capsule-soon",
                    startMinute: 12 * 60,
                    endMinute: 20 * 60
                ),
                capsuleID: capsule.id,
                userInfo: ["capsuleID": capsule.id.uuidString, "signal": "capsule_soon"]
            ))
        }

        guard mode == .engaged,
              let revisitDate = calendar.date(byAdding: .day, value: 10, to: capsule.createdAt),
              revisitDate < capsule.openAt,
              revisitDate > Date()
        else { return specs }

        specs.append(NotificationSignalSpec(
            id: Self.revisitIdentifier(for: capsule.id),
            kind: .capsuleRevisit,
            title: String(localized: "Иногда полезно перечитать себя"),
            body: String(localized: "Что в этом желании сегодня звучит иначе?"),
            date: resonantDate(
                on: revisitDate,
                capsule: capsule,
                salt: "capsule-revisit",
                startMinute: 10 * 60 + 30,
                endMinute: 20 * 60 + 30
            ),
            capsuleID: capsule.id,
            userInfo: ["capsuleID": capsule.id.uuidString, "signal": "capsule_revisit"]
        ))

        return specs
    }

    private func planCheckpointSpec(
        _ checkpoint: WishPlanCheckpoint,
        index: Int,
        for capsule: WishCapsule
    ) -> NotificationSignalSpec? {
        guard let rawDate = calendar.date(byAdding: .day, value: checkpoint.afterDays, to: capsule.sealedAt) else {
            return nil
        }

        let latestAllowedDate = calendar.date(byAdding: .hour, value: -2, to: capsule.openAt) ?? capsule.openAt
        let scheduledDate = min(rawDate, latestAllowedDate)
        let preferredDate = resonantDate(
            on: scheduledDate,
            capsule: capsule,
            salt: "plan-checkpoint-\(index)",
            startMinute: 11 * 60,
            endMinute: 20 * 60 + 45
        )
        let finalDate = preferredDate < latestAllowedDate ? preferredDate : scheduledDate
        guard finalDate > Date(), finalDate < capsule.openAt else { return nil }

        return NotificationSignalSpec(
            id: Self.planCheckpointIdentifier(for: capsule.id, index: index),
            kind: .wishPlanCheckpoint,
            title: checkpoint.title,
            body: checkpoint.message,
            date: finalDate,
            capsuleID: capsule.id,
            userInfo: [
                "capsuleID": capsule.id.uuidString,
                "signal": "wish_plan_checkpoint",
                "checkpointIndex": index,
            ]
        )
    }

    private func customSignalSpecs(_ signals: [NotificationSignal], existingCapsuleIDs: Set<UUID>) -> [NotificationSignalSpec] {
        signals.compactMap { signal in
            guard (!signal.isCancelled || signal.kind == .futureLetter), signal.scheduledAt > Date() else { return nil }
            if let capsuleID = signal.capsuleID, !existingCapsuleIDs.contains(capsuleID) { return nil }

            var userInfo: [AnyHashable: Any] = ["signal": signal.kind.rawValue]
            if let capsuleID = signal.capsuleID {
                userInfo["capsuleID"] = capsuleID.uuidString
            }

            return NotificationSignalSpec(
                id: signal.identifier,
                kind: signal.kind,
                title: signal.title,
                body: signal.message,
                date: signal.scheduledAt,
                capsuleID: signal.capsuleID,
                userInfo: userInfo
            )
        }
    }

    private func addNotification(for spec: NotificationSignalSpec) {
        guard spec.date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: spec)
        content.body = notificationBody(for: spec)
        content.sound = UNNotificationSound(named: UNNotificationSoundName("notification_soft.caf"))
        content.userInfo = spec.userInfo

        let trigger: UNNotificationTrigger
        if spec.repeatsDaily {
            let components = calendar.dateComponents([.hour, .minute], from: spec.date)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        } else {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: spec.date)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        center.add(UNNotificationRequest(identifier: spec.id, content: content, trigger: trigger))
    }

    private func deconflictedSignalSpecs(
        _ specs: [NotificationSignalSpec],
        existingSignals: [NotificationSignal] = []
    ) -> [NotificationSignalSpec] {
        let incomingIDs = Set(specs.map(\.id))
        var usedKeys = Set(existingSignals.compactMap { signal -> String? in
            guard !incomingIDs.contains(signal.identifier),
                  !signal.isCancelled,
                  signal.scheduledAt > Date()
            else { return nil }

            return minuteKey(for: signal.scheduledAt)
        })

        return specs.map { spec in
            guard !spec.repeatsDaily else { return spec }

            var adjustedSpec = spec
            var adjustedDate = spec.date
            var key = minuteKey(for: adjustedDate)

            while usedKeys.contains(key) {
                guard let nextDate = calendar.date(byAdding: .minute, value: 15, to: adjustedDate) else { break }
                adjustedDate = nextDate
                key = minuteKey(for: adjustedDate)
            }

            usedKeys.insert(key)
            adjustedSpec.date = adjustedDate
            return adjustedSpec
        }
    }

    private func minuteKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return [
            components.year,
            components.month,
            components.day,
            components.hour,
            components.minute,
        ]
            .map { String($0 ?? 0) }
            .joined(separator: ".")
    }

    @MainActor
    private func existingSignals(from modelContext: ModelContext?) -> [NotificationSignal] {
        guard let modelContext else { return [] }

        do {
            return try modelContext.fetch(FetchDescriptor<NotificationSignal>())
        } catch {
            AppLog.notifications.error("Notification deconflict fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func notificationBody(for spec: NotificationSignalSpec) -> String {
        if spec.kind == .futureLetter {
            return String(localized: "Кажется, будущий ты хочет кое-что сказать.")
        }

        return spec.body
    }

    private func notificationTitle(for spec: NotificationSignalSpec) -> String {
        if spec.kind == .futureLetter {
            return String(localized: "Письмо из будущего")
        }

        return spec.title
    }

    @MainActor
    private func updateLedger(
        with specs: [NotificationSignalSpec],
        existingCapsuleIDs: Set<UUID>? = nil,
        modelContext: ModelContext?
    ) {
        guard let modelContext else { return }

        do {
            let existing = try modelContext.fetch(FetchDescriptor<NotificationSignal>())
            let specIDs = Set(specs.map(\.id))
            var cancelledIdentifiers: [String] = []

            for signal in existing where shouldCancelMissingSignal(signal, specIDs: specIDs, existingCapsuleIDs: existingCapsuleIDs) {
                signal.cancelledAt = Date()
                cancelledIdentifiers.append(signal.identifier)
            }

            if !cancelledIdentifiers.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: cancelledIdentifiers)
            }

            for spec in specs {
                if let signal = existing.first(where: { $0.identifier == spec.id }) {
                    signal.kind = spec.kind
                    signal.title = spec.title
                    signal.message = spec.body
                    signal.scheduledAt = spec.date
                    signal.capsuleID = spec.capsuleID
                    signal.cancelledAt = nil
                    AppLog.notifications.debug("Notification ledger updated: identifier=\(spec.id, privacy: .public), kind=\(spec.kind.rawValue, privacy: .public)")
                } else {
                    modelContext.insert(NotificationSignal(
                        identifier: spec.id,
                        kind: spec.kind,
                        title: spec.title,
                        message: spec.body,
                        scheduledAt: spec.date,
                        capsuleID: spec.capsuleID
                    ))
                    AppLog.notifications.debug("Notification ledger inserted: identifier=\(spec.id, privacy: .public), kind=\(spec.kind.rawValue, privacy: .public)")
                }
            }
        } catch {
            AppLog.notifications.error("Notification ledger update failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resonantDate(
        on date: Date,
        capsule: WishCapsule? = nil,
        salt: String,
        startMinute: Int,
        endMinute: Int
    ) -> Date {
        let day = calendar.startOfDay(for: date)
        let safeStartMinute = min(startMinute, endMinute)
        let minute = safeStartMinute + stableMinuteOffset(
            capsuleID: capsule?.id,
            on: day,
            salt: salt,
            availableMinutes: endMinute - safeStartMinute
        )

        return calendar.date(
            bySettingHour: minute / 60,
            minute: minute % 60,
            second: 0,
            of: day
        ) ?? date
    }

    private func stableMinuteOffset(
        capsuleID: UUID?,
        on day: Date,
        salt: String,
        availableMinutes: Int
    ) -> Int {
        guard availableMinutes > 0 else { return 0 }

        var seed: UInt64 = 1469598103934665603
        if let capsuleID {
            var uuid = capsuleID.uuid
            withUnsafeBytes(of: &uuid) { bytes in
                for byte in bytes {
                    seed ^= UInt64(byte)
                    seed &*= 1099511628211
                }
            }
        }

        for byte in salt.utf8 {
            seed ^= UInt64(byte)
            seed &*= 1099511628211
        }

        let components = calendar.dateComponents([.year, .month, .day], from: day)
        for value in [components.year, components.month, components.day].compactMap(\.self) {
            seed ^= UInt64(value)
            seed &*= 1099511628211
        }

        return Int(seed % UInt64(availableMinutes + 1))
    }

    private func managedIdentifiers(for capsules: [WishCapsule]) -> [String] {
        var identifiers = capsules.flatMap { Self.identifiers(for: $0.id) }
        identifiers += [
            "signal.reactivation.3",
            "signal.reactivation.7",
            "signal.reactivation.14",
            "signal.morningDream",
        ]
        return identifiers
    }

    private static func identifiers(for capsuleID: UUID) -> [String] {
        [
            openIdentifier(for: capsuleID),
            soonIdentifier(for: capsuleID),
            revisitIdentifier(for: capsuleID),
            futureLetterIdentifier(for: capsuleID),
        ] + (0..<3).map { planCheckpointIdentifier(for: capsuleID, index: $0) }
    }

    private static func openIdentifier(for capsuleID: UUID) -> String {
        "capsule.\(capsuleID.uuidString).open"
    }

    private static func soonIdentifier(for capsuleID: UUID) -> String {
        "capsule.\(capsuleID.uuidString).soon"
    }

    private static func revisitIdentifier(for capsuleID: UUID) -> String {
        "capsule.\(capsuleID.uuidString).revisit"
    }

    private static func futureLetterIdentifier(for capsuleID: UUID) -> String {
        "capsule.\(capsuleID.uuidString).futureLetter"
    }

    private static func planCheckpointIdentifier(for capsuleID: UUID, index: Int) -> String {
        "capsule.\(capsuleID.uuidString).planCheckpoint.\(index)"
    }

    private func isManagedIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix("capsule.") || identifier.hasPrefix("signal.")
    }

    private func shouldCancelMissingSignal(
        _ signal: NotificationSignal,
        specIDs: Set<String>,
        existingCapsuleIDs: Set<UUID>?
    ) -> Bool {
        guard signal.cancelledAt == nil,
              isManagedIdentifier(signal.identifier),
              !specIDs.contains(signal.identifier)
        else { return false }

        if let capsuleID = signal.capsuleID,
           let existingCapsuleIDs,
           !existingCapsuleIDs.contains(capsuleID) {
            return true
        }

        return !signal.hasPassed
    }
}

private struct NotificationSignalSpec {
    let id: String
    let kind: NotificationSignalKind
    let title: String
    let body: String
    var date: Date
    let capsuleID: UUID?
    let userInfo: [AnyHashable: Any]
    var repeatsDaily = false
}
