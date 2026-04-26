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

    func sync(
        capsules: [WishCapsule],
        mode: NotificationMode,
        morningDreamsEnabled: Bool,
        modelContext: ModelContext? = nil
    ) async {
        center.removePendingNotificationRequests(withIdentifiers: managedIdentifiers(for: capsules))

        let sealedCapsules = capsules.filter { $0.status == .sealed }
        let needsSignals = !sealedCapsules.isEmpty || (mode != .quiet && morningDreamsEnabled)
        let specs = signalSpecs(
            capsules: sealedCapsules,
            allCapsules: capsules,
            mode: mode,
            morningDreamsEnabled: morningDreamsEnabled
        )

        await MainActor.run {
            updateLedger(with: specs, modelContext: modelContext)
        }

        guard needsSignals, await requestAuthorizationIfNeeded() else { return }

        for spec in specs {
            addNotification(for: spec)
        }
    }

    func scheduleOpeningSignal(for capsule: WishCapsule) {
        guard capsule.status == .sealed, capsule.openAt > Date() else { return }

        let spec = NotificationSignalSpec(
            id: Self.openIdentifier(for: capsule.id),
            kind: .capsuleOpen,
            title: "Тебе пришло письмо из прошлого",
            body: "Ты писал это себе. Пришло время прочитать.",
            date: capsule.openAt,
            capsuleID: capsule.id,
            userInfo: ["capsuleID": capsule.id.uuidString, "signal": "capsule_open"]
        )
        addNotification(for: spec)
    }

    func cancelSignals(for capsule: WishCapsule) {
        center.removePendingNotificationRequests(withIdentifiers: Self.identifiers(for: capsule.id))
    }

    private func signalSpecs(
        capsules sealedCapsules: [WishCapsule],
        allCapsules: [WishCapsule],
        mode: NotificationMode,
        morningDreamsEnabled: Bool
    ) -> [NotificationSignalSpec] {
        var specs = sealedCapsules.compactMap(openingSignalSpec)

        guard mode != .quiet else { return specs }

        if !allCapsules.isEmpty {
            specs += reactivationSignalSpecs()
        }

        if morningDreamsEnabled {
            specs.append(morningDreamSignalSpec())
        }

        for capsule in sealedCapsules {
            specs += contextSignalSpecs(for: capsule, mode: mode)
        }

        return specs
    }

    private func openingSignalSpec(for capsule: WishCapsule) -> NotificationSignalSpec? {
        guard capsule.status == .sealed, capsule.openAt > Date() else { return nil }

        return NotificationSignalSpec(
            id: Self.openIdentifier(for: capsule.id),
            kind: .capsuleOpen,
            title: "Тебе пришло письмо из прошлого",
            body: "Ты писал это себе. Пришло время прочитать.",
            date: capsule.openAt,
            capsuleID: capsule.id,
            userInfo: ["capsuleID": capsule.id.uuidString, "signal": "capsule_open"]
        )
    }

    private func reactivationSignalSpecs() -> [NotificationSignalSpec] {
        let now = Date()
        let messages: [(Int, String, String)] = [
            (3, "Ты оставил здесь что-то важное", "Иногда достаточно просто вернуться и посмотреть."),
            (7, "Интересно, что изменилось с того момента?", "Одна мысль может прозвучать иначе спустя неделю."),
            (14, "Твоё будущее не торопит тебя", "Но оно всё ещё здесь."),
        ]

        return messages.compactMap { day, title, body in
            guard let date = calendar.date(byAdding: .day, value: day, to: now) else { return nil }

            return NotificationSignalSpec(
                id: "signal.reactivation.\(day)",
                kind: .reactivation,
                title: title,
                body: body,
                date: signalDate(on: date, hour: 19),
                capsuleID: nil,
                userInfo: ["signal": "reactivation", "day": day]
            )
        }
    }

    private func morningDreamSignalSpec() -> NotificationSignalSpec {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 30

        let today = calendar.date(from: components) ?? Date()
        let nextDate = today > Date() ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today

        return NotificationSignalSpec(
            id: "signal.morningDream",
            kind: .morningDream,
            title: "Сон ещё рядом",
            body: "Поймай его, пока он не исчез.",
            date: nextDate,
            capsuleID: nil,
            userInfo: ["signal": "morning_dream"],
            repeatsDaily: true
        )
    }

    private func contextSignalSpecs(for capsule: WishCapsule, mode: NotificationMode) -> [NotificationSignalSpec] {
        var specs: [NotificationSignalSpec] = []

        if let soonDate = calendar.date(byAdding: .day, value: -1, to: capsule.openAt),
           soonDate > Date() {
            specs.append(NotificationSignalSpec(
                id: Self.soonIdentifier(for: capsule.id),
                kind: .capsuleSoon,
                title: "Одна из твоих капсул скоро станет ближе",
                body: "Время уже почти донесло её до тебя.",
                date: signalDate(on: soonDate, hour: 18),
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
            title: "Иногда полезно перечитать себя",
            body: "Что в этом желании сегодня звучит иначе?",
            date: signalDate(on: revisitDate, hour: 19),
            capsuleID: capsule.id,
            userInfo: ["capsuleID": capsule.id.uuidString, "signal": "capsule_revisit"]
        ))

        return specs
    }

    private func addNotification(for spec: NotificationSignalSpec) {
        guard spec.date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = spec.title
        content.body = spec.body
        content.sound = .default
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

    @MainActor
    private func updateLedger(with specs: [NotificationSignalSpec], modelContext: ModelContext?) {
        guard let modelContext else { return }

        do {
            let existing = try modelContext.fetch(FetchDescriptor<NotificationSignal>())
            let specIDs = Set(specs.map(\.id))

            for signal in existing where signal.cancelledAt == nil && isManagedIdentifier(signal.identifier) && !specIDs.contains(signal.identifier) && !signal.hasPassed {
                signal.cancelledAt = Date()
            }

            for spec in specs {
                if let signal = existing.first(where: { $0.identifier == spec.id }) {
                    signal.kind = spec.kind
                    signal.title = spec.title
                    signal.message = spec.body
                    signal.scheduledAt = spec.date
                    signal.capsuleID = spec.capsuleID
                    signal.cancelledAt = nil
                } else {
                    modelContext.insert(NotificationSignal(
                        identifier: spec.id,
                        kind: spec.kind,
                        title: spec.title,
                        message: spec.body,
                        scheduledAt: spec.date,
                        capsuleID: spec.capsuleID
                    ))
                }
            }
        } catch {
            AppLog.notifications.error("Notification ledger update failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func signalDate(on date: Date, hour: Int) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components) ?? date
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
        ]
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

    private func isManagedIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix("capsule.") || identifier.hasPrefix("signal.")
    }
}

private struct NotificationSignalSpec {
    let id: String
    let kind: NotificationSignalKind
    let title: String
    let body: String
    let date: Date
    let capsuleID: UUID?
    let userInfo: [AnyHashable: Any]
    var repeatsDaily = false
}
