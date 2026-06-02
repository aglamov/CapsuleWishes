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
    @AppStorage(NotificationPreferences.modeKey) private var notificationModeRawValue = NotificationPreferences.defaultMode.rawValue
    @AppStorage(NotificationPreferences.morningDreamSignalsEnabledKey) private var morningDreamSignalsEnabled = NotificationPreferences.defaultMorningDreamSignalsEnabled
    @AppStorage(NotificationPreferences.morningDreamSignalHourKey) private var morningDreamSignalHour = MorningSignalTime.defaultValue.hour
    @AppStorage(NotificationPreferences.morningDreamSignalMinuteKey) private var morningDreamSignalMinute = MorningSignalTime.defaultValue.minute
    @AppStorage(NotificationPreferences.lastMorningSignalAdjustmentDayKey) private var lastMorningSignalAdjustmentDay = 0.0
    @Query(sort: \WishCapsule.openAt, order: .forward) private var capsules: [WishCapsule]
    @Query(sort: \NotificationSignal.scheduledAt, order: .forward) private var signals: [NotificationSignal]
    @State private var selectedTab: AppTab = .capsules

    private var notificationMode: NotificationMode {
        NotificationMode(rawValue: notificationModeRawValue) ?? NotificationPreferences.defaultMode
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

            if showsMeaningTab {
                PersonalMeaningView { question in
                    notificationRouteCenter.requestJournalEntry(.thought, prompt: question)
                    selectedTab = .journal
                }
                    .tabItem {
                        Label("Смысл", systemImage: "sparkle.magnifyingglass")
                    }
                    .tag(AppTab.meaning)
            }
        }
        .tint(.white)
        .onChange(of: showsMeaningTab) { _, isVisible in
            if !isVisible, selectedTab == .meaning {
                selectedTab = .capsules
            }
        }
        .onChange(of: notificationRouteCenter.requestedCapsuleID) { _, capsuleID in
            if capsuleID != nil {
                selectedTab = .capsules
            }
        }
        .onChange(of: notificationRouteCenter.requestedJournalEntryType) { _, entryType in
            if entryType != nil {
                selectedTab = .journal
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

    private var showsMeaningTab: Bool {
        capsules.count >= 5
    }
}

private enum AppTab {
    case capsules
    case journal
    case meaning
}

struct PersonalMeaningView: View {
    @AppStorage(AIUsagePreferences.enabledKey) private var aiFeaturesEnabled = AIUsagePreferences.defaultEnabled
    @Query(sort: \WishCapsule.createdAt, order: .reverse) private var capsules: [WishCapsule]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \PersonalSymbol.createdAt, order: .reverse) private var symbols: [PersonalSymbol]
    @State private var insight: PersonalMeaningInsight?
    @State private var isLoadingInsight = false

    let onAnswerQuestion: (String) -> Void

    private let personalMeaningService = PersonalMeaningService()

    var body: some View {
        NavigationStack {
            ZStack {
                NightSkyBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        insightPanel
                        selfPortraitPanel
                        themeCloud
                        symbolShelf
                        recentEchoes
                    }
                    .padding(20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Слой смысла")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Что возвращается")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Здесь капсулы собираются в более честную картину: что ты часто хочешь, от чего уходишь, к чему возвращаешься и какая потребность звучит под разными желаниями.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    private var insightPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Отражение пути", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Кнопка обновляет этот блок и «О себе». Темы, символы и последние капсулы ниже меняются автоматически.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.56))
                .fixedSize(horizontal: false, vertical: true)

            if isLoadingInsight {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)

                    Text("Собираю слой личного смысла...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
            } else if let insight {
                Text(insight.themes.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "FFD89A").opacity(0.88))
                    .textCase(.uppercase)

                if !insight.portrait.isEmpty {
                    Text(insight.portrait)
                        .font(.title3.weight(.medium))
                        .lineSpacing(4)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(insight.observation)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)

                meaningQuestion(insight.question)
            } else {
                Text("Можно собрать более откровенное отражение по капсулам, дневнику и личным символам. Оно не будет ставить диагнозы, но попробует прямо назвать паттерны, напряжения и желания под желаниями.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                generateInsight()
            } label: {
                Label(insight == nil ? "Собрать отражение" : "Обновить отражение", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryCapsuleButtonStyle())
            .disabled(isLoadingInsight)
        }
        .padding(18)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }

    private func meaningQuestion(_ question: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Вопрос для дневника")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.58))
                .textCase(.uppercase)

            Text(question)
                .font(.callout.weight(.medium))
                .lineSpacing(3)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onAnswerQuestion(question)
            } label: {
                Label("Ответить в дневник", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryCapsuleButtonStyle())
        }
        .padding(.top, 2)
    }

    private var selfPortraitPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("О себе")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Этот блок обновляется вместе с отражением пути.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.52))
                .fixedSize(horizontal: false, vertical: true)

            if let insight {
                meaningRow(
                    title: "Что повторяется",
                    systemImage: "arrow.triangle.2.circlepath",
                    text: insight.recurringPattern.isEmpty ? fallbackRecurringPattern : insight.recurringPattern
                )

                meaningRow(
                    title: "Внутреннее напряжение",
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                    text: insight.innerTension.isEmpty ? fallbackInnerTension : insight.innerTension
                )

                meaningRow(
                    title: "Потребность под желаниями",
                    systemImage: "heart.text.square.fill",
                    text: insight.hiddenNeed.isEmpty ? fallbackHiddenNeed : insight.hiddenNeed
                )
            } else {
                meaningRow(title: "Что повторяется", systemImage: "arrow.triangle.2.circlepath", text: fallbackRecurringPattern)
                meaningRow(title: "Внутреннее напряжение", systemImage: "point.topleft.down.curvedto.point.bottomright.up", text: fallbackInnerTension)
                meaningRow(title: "Потребность под желаниями", systemImage: "heart.text.square.fill", text: fallbackHiddenNeed)
            }
        }
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func meaningRow(title: String, systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: "FFD89A").opacity(0.92))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.58))
                    .textCase(.uppercase)

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var themeCloud: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Частые темы")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Считаются автоматически по словам в капсулах и дневнике.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.52))
                .fixedSize(horizontal: false, vertical: true)

            if localThemes.isEmpty {
                Text("Темы появятся, когда в капсулах и дневнике накопится больше повторяющихся слов.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(localThemes, id: \.self) { theme in
                        Text(theme)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(.white.opacity(0.10), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.12), lineWidth: 1)
                            }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var symbolShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Личные символы")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Появляются здесь, когда ты создаешь или сохраняешь символ.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.52))
                .fixedSize(horizontal: false, vertical: true)

            if symbols.isEmpty {
                Text("Созданные тобой пиктограммы появятся здесь и начнут складываться в личный словарь желаний.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(symbols.prefix(6)) { symbol in
                        HStack(spacing: 12) {
                            Image(systemName: symbol.systemName)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(symbol.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)

                                Text(symbol.meaning)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.66))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    private var recentEchoes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Последние отголоски")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Берутся из последних созданных капсул.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.52))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(capsules.prefix(4)) { capsule in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: capsule.symbol)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color(hex: capsule.colorHex).opacity(0.24), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(capsule.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(capsule.desiredFeeling.isEmpty ? capsule.status.title : capsule.desiredFeeling)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.64))
                            .lineLimit(2)
                    }
                }
                .padding(12)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var localThemes: [String] {
        let text = (capsules.flatMap { [$0.title, $0.intentionText, $0.desiredFeeling] } + entries.map(\.text))
            .joined(separator: " ")
            .lowercased()

        let candidates: [(String, [String])] = [
            ("спокойствие", ["спокой", "тишин", "отдых"]),
            ("дом", ["дом", "уют", "мест"]),
            ("свобода", ["свобод", "дыша", "простор"]),
            ("смелость", ["смел", "страх", "реш"]),
            ("близость", ["любов", "близ", "отнош"]),
            ("творчество", ["твор", "проект", "иде"]),
            ("движение", ["шаг", "движ", "дорог"])
        ]

        return candidates.compactMap { title, fragments in
            fragments.contains(where: text.contains) ? title : nil
        }
    }

    private func generateInsight() {
        guard !isLoadingInsight else { return }
        isLoadingInsight = true

        Task {
            var generatedInsight: PersonalMeaningInsight?
            do {
                if aiFeaturesEnabled, personalMeaningService.isAvailable {
                    generatedInsight = try await personalMeaningService.insight(capsules: capsules, entries: entries, symbols: symbols)
                }
            } catch {
                AppLog.ai.error("AI backend personal meaning fallback: \(error.localizedDescription, privacy: .public)")
            }

            let resolvedInsight = generatedInsight ?? fallbackInsight
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.32)) {
                    insight = resolvedInsight
                    isLoadingInsight = false
                }
            }
        }
    }

    private var fallbackInsight: PersonalMeaningInsight {
        let themes = localThemes.isEmpty ? ["ясность", "внимание", "движение"] : Array(localThemes.prefix(3))
        let firstTheme = themes.first ?? "ясность"

        return PersonalMeaningInsight(
            themes: themes,
            portrait: "По этим капсулам ты выглядишь человеком, который не просто хочет результата, а ищет состояние, в котором можно наконец выдохнуть и действовать честнее.",
            recurringPattern: fallbackRecurringPattern,
            innerTension: fallbackInnerTension,
            hiddenNeed: fallbackHiddenNeed,
            observation: "В твоих капсулах уже начал появляться собственный ритм: \(firstTheme) возвращается не как случайное слово, а как место, куда желания снова и снова пытаются привести внимание. Видно, что тебе важен не только внешний итог. Тебе важно понять, каким человеком ты становишься по дороге к нему, где ты продолжаешь сжиматься, а где наконец позволяешь себе больше правды.",
            question: "Какое желание ты называешь целью, хотя внутри оно больше похоже на просьбу жить иначе?"
        )
    }

    private var fallbackRecurringPattern: String {
        let primary = localThemes.first ?? "ясность"
        return "Ты часто возвращаешься к теме \(primary), но формулируешь ее через разные желания, будто проверяешь один и тот же внутренний вопрос с разных сторон."
    }

    private var fallbackInnerTension: String {
        "Видно напряжение между желанием двигаться вперед и потребностью не потерять ощущение безопасности по дороге."
    }

    private var fallbackHiddenNeed: String {
        "Под разными желаниями звучит потребность в более спокойном праве быть собой, выбирать свое и не доказывать важность этого выбора."
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > width {
                totalHeight += rowHeight + spacing
                maxWidth = max(maxWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += rowWidth == 0 ? size.width : spacing + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        totalHeight += rowHeight
        maxWidth = max(maxWidth, rowWidth)
        return CGSize(width: width == 0 ? maxWidth : width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + spacing + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NotificationRouteCenter.shared)
        .modelContainer(for: [WishCapsule.self, JournalEntry.self, NotificationSignal.self, PersonalSymbol.self], inMemory: true)
}
