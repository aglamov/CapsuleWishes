//
//  NotificationSettingsView.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import SwiftData
import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(NotificationPreferences.modeKey) private var notificationModeRawValue = NotificationMode.soft.rawValue
    @AppStorage(NotificationPreferences.morningDreamSignalsEnabledKey) private var morningDreamSignalsEnabled = false
    @Query(sort: \NotificationSignal.scheduledAt, order: .reverse) private var signals: [NotificationSignal]
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var selectedSignal: NotificationSignal?

    private var notificationMode: Binding<NotificationMode> {
        Binding {
            NotificationMode(rawValue: notificationModeRawValue) ?? .soft
        } set: { mode in
            notificationModeRawValue = mode.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NightSkyBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        authorizationPanel
                        modePicker
                        morningDreamsToggle
                        signalHistory
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Сигналы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .task {
                await refreshAuthorizationStatus()
            }
            .sheet(item: $selectedSignal) { signal in
                NotificationSignalDetailView(signal: signal)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Пусть время говорит тихо")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Здесь нет ежедневных пинков. Только события, редкие возвращения и моменты, которые действительно имеют смысл.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    private var authorizationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(authorizationTitle, systemImage: authorizationIcon)
                .font(.headline)
                .foregroundStyle(.white)

            Text(authorizationDescription)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            if authorizationStatus == .notDetermined {
                Button {
                    Task {
                        _ = await CapsuleNotificationScheduler.shared.requestAuthorizationIfNeeded()
                        await refreshAuthorizationStatus()
                    }
                } label: {
                    Label("Разрешить сигналы", systemImage: "bell.badge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryCapsuleButtonStyle())
            }
        }
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Режим")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(NotificationMode.allCases) { mode in
                Button {
                    notificationMode.wrappedValue = mode
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: notificationMode.wrappedValue == mode ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(mode.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(mode.description)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.62))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(
                        notificationMode.wrappedValue == mode ? .white.opacity(0.14) : .white.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var morningDreamsToggle: some View {
        Toggle(isOn: $morningDreamSignalsEnabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Утренние сны")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Один мягкий утренний сигнал, если хочется сделать это личным ритуалом.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(.white)
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var signalHistory: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Следы сигналов")
                .font(.headline)
                .foregroundStyle(.white)

            if pastSignals.isEmpty {
                Text("Здесь появятся сигналы, которые уже приходили: открытие капсул, мягкие возвращения и утренние сны.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                signalSection(title: "Уже приходило", signals: pastSignals)
            }

            if !upcomingSignals.isEmpty {
                signalSection(title: "Ожидают", signals: upcomingSignals)
            }
        }
    }

    private func signalSection(title: String, signals: [NotificationSignal]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))

            ForEach(signals) { signal in
                Button {
                    selectedSignal = signal
                } label: {
                    signalRow(signal)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func signalRow(_ signal: NotificationSignal) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: signal.kind.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(signal.kind.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.52))

                    Spacer(minLength: 0)

                    Text(signal.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.46))
                        .lineLimit(1)
                }

                Text(signal.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(signal.message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var pastSignals: [NotificationSignal] {
        Array(signals
            .filter(isVisibleSignal)
            .filter(\.hasPassed)
            .sorted { $0.scheduledAt > $1.scheduledAt }
            .prefix(12))
    }

    private var upcomingSignals: [NotificationSignal] {
        Array(signals
            .filter(isVisibleSignal)
            .filter { !$0.hasPassed }
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .prefix(16))
    }

    private func isVisibleSignal(_ signal: NotificationSignal) -> Bool {
        !signal.isCancelled || signal.kind == .futureLetter
    }

    private var authorizationTitle: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            "Сигналы включены"
        case .denied:
            "Сигналы выключены в настройках iOS"
        case .notDetermined:
            "Сигналы ещё не включены"
        @unknown default:
            "Статус сигналов неизвестен"
        }
    }

    private var authorizationDescription: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            "Капсулы смогут вернуться в нужный момент."
        case .denied:
            "Открытие капсул останется внутри приложения, пока уведомления запрещены в системных настройках."
        case .notDetermined:
            "Разрешение понадобится, чтобы письмо из прошлого действительно дошло."
        @unknown default:
            "Можно продолжать пользоваться приложением без внешних сигналов."
        }
    }

    private var authorizationIcon: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            "bell.fill"
        case .denied:
            "bell.slash.fill"
        case .notDetermined:
            "bell"
        @unknown default:
            "bell"
        }
    }

    @MainActor
    private func refreshAuthorizationStatus() async {
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}

private struct NotificationSignalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let signal: NotificationSignal

    var body: some View {
        NavigationStack {
            ZStack {
                NightSkyBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Image(systemName: signal.kind.symbolName)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(.white.opacity(0.12), in: Circle())
                            .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(signal.kind.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.56))

                            Text(signal.title)
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(signal.message)
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.74))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(signal.scheduledAt.formatted(date: .complete, time: .shortened))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.50))

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
            }
            .navigationTitle("Сигнал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}
