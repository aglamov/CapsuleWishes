//
//  NotificationSettingsView.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(NotificationPreferences.modeKey) private var notificationModeRawValue = NotificationMode.soft.rawValue
    @AppStorage(NotificationPreferences.morningDreamSignalsEnabledKey) private var morningDreamSignalsEnabled = false
    @AppStorage(NotificationPreferences.morningDreamSignalHourKey) private var morningDreamSignalHour = MorningSignalTime.defaultValue.hour
    @AppStorage(NotificationPreferences.morningDreamSignalMinuteKey) private var morningDreamSignalMinute = MorningSignalTime.defaultValue.minute
    @AppStorage(AIUsagePreferences.enabledKey) private var aiFeaturesEnabled = false
    @AppStorage(AudioFeedbackPreferences.enabledKey) private var audioFeedbackEnabled = true
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private var notificationMode: Binding<NotificationMode> {
        Binding {
            NotificationMode(rawValue: notificationModeRawValue) ?? .soft
        } set: { mode in
            notificationModeRawValue = mode.rawValue
        }
    }

    private var morningSignalTime: MorningSignalTime {
        get {
            MorningSignalTime(hour: morningDreamSignalHour, minute: morningDreamSignalMinute)
        }
        nonmutating set {
            morningDreamSignalHour = newValue.hour
            morningDreamSignalMinute = newValue.minute
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
                        audioFeedbackToggle
                        aiUsageToggle
                        morningDreamsToggle
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Настройки")
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
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Сигналы без суеты")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Здесь можно выбрать ритм напоминаний: от полной тишины до более внимательного сопровождения.")
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
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $morningDreamSignalsEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Утренние сны")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Один утренний сигнал для снов и образов, которые лучше записать сразу после пробуждения.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Color(hex: "7EE0B3"))

            if morningDreamSignalsEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Примерное утро")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))

                    HStack(spacing: 8) {
                        ForEach(MorningSignalTime.presets, id: \.self) { time in
                            Button {
                                morningSignalTime = time
                            } label: {
                                Text(time.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(morningSignalTime == time ? .black.opacity(0.78) : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        morningSignalTime == time ? Color(hex: "7EE0B3") : .white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.caption.weight(.semibold))

                        Text(
                            String(
                                format: String(localized: "Сейчас: %@. Время сигнала будет уточняться по твоему утреннему ритму."),
                                morningSignalTime.title
                            )
                        )
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(.white.opacity(0.58))
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var audioFeedbackToggle: some View {
        Toggle(isOn: $audioFeedbackEnabled) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Звуки капсулы")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Короткие звуковые отклики для запечатывания, открытия и сохранения записей.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Color(hex: "7EE0B3"))
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var aiUsageToggle: some View {
        Toggle(isOn: $aiFeaturesEnabled) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Умные подсказки")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Когда включено, приложение может точнее формулировать подсказки, письма и итоги через защищенный сервер. Передаются только данные, нужные для выбранного действия.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Когда выключено, капсула использует встроенные локальные тексты.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.54))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Color(hex: "7EE0B3"))
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var authorizationTitle: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            String(localized: "Сигналы включены")
        case .denied:
            String(localized: "Сигналы выключены в настройках iOS")
        case .notDetermined:
            String(localized: "Сигналы ещё не включены")
        @unknown default:
            String(localized: "Статус сигналов неизвестен")
        }
    }

    private var authorizationDescription: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            String(localized: "Капсулы смогут вернуться в нужный момент.")
        case .denied:
            String(localized: "Открытие капсул останется внутри приложения, пока уведомления запрещены в системных настройках.")
        case .notDetermined:
            String(localized: "Разрешение понадобится, чтобы капсула вернулась в нужный момент.")
        @unknown default:
            String(localized: "Можно продолжать пользоваться приложением без внешних сигналов.")
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
