//
//  CapsuleDetailView.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftData
import SwiftUI

struct CapsuleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AIUsagePreferences.enabledKey) private var aiFeaturesEnabled = false
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry]
    @Query(sort: \NotificationSignal.scheduledAt, order: .reverse) private var allSignals: [NotificationSignal]
    @Bindable var capsule: WishCapsule
    @State private var selectedEntryType: JournalEntryType = .sign
    @State private var entryText = ""
    @State private var didEnter = false
    @State private var isShowingDeleteConfirmation = false
    @State private var openingStage: CapsuleOpeningStage = .idle
    @State private var openingTask: Task<Void, Never>?
    @State private var entryPromptText: String?
    @State private var entryPromptPresentationID = UUID()
    @State private var isLoadingAIEntryPrompt = false
    @State private var aiEntryPromptGlowAmount = 0.0
    @State private var aiEntryPromptGlowTask: Task<Void, Never>?
    @State private var isBeautifyingEntry = false
    @State private var isLoadingOpeningReflection = false
    @State private var isShowingOpeningReflectionOverlay = false
    @State private var selectedFutureLetterSignal: NotificationSignal?
    @State private var isShowingSealingFortune = false
    @State private var didAutoScrollToEntryPanel = false
    @State private var readinessRefreshDate = Date()
    @FocusState private var isEntryFieldFocused: Bool

    private let aiWishPromptService = AIWishPromptService()
    private let openingReflectionService = OpeningReflectionService()
    private let creationAssistantService = WishCreationAssistantService()
    private let readinessTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var entries: [JournalEntry] {
        allEntries.filter { $0.capsuleID == capsule.id }
    }

    private var futureLetterSignal: NotificationSignal? {
        allSignals
            .filter { $0.capsuleID == capsule.id && $0.kind == .futureLetter && $0.hasPassed }
            .sorted { $0.scheduledAt > $1.scheduledAt }
            .first
    }

    private var fallbackEntryPrompt: String {
        WishPromptLibrary.prompt(
            for: selectedEntryType,
            capsule: capsule,
            recentEntries: entries
        )
    }

    private var currentEntryPrompt: String {
        entryPromptText ?? fallbackEntryPrompt
    }

    private var promptRequestKey: String {
        [
            capsule.id.uuidString,
            selectedEntryType.rawValue,
            aiFeaturesEnabled.description,
            entries.first?.id.uuidString ?? "empty",
        ].joined(separator: "-")
    }

    private var openingReflectionRequestKey: String {
        [
            capsule.id.uuidString,
            capsule.statusRawValue,
            aiFeaturesEnabled.description,
            capsule.openingReflectionText?.isEmpty == false ? "saved" : "empty",
            entries.first?.id.uuidString ?? "empty",
        ].joined(separator: "-")
    }

    private var isOpeningPending: Bool {
        openingStage != .idle
    }

    private var freezesCapsuleMotion: Bool {
        openingStage == .returning
    }

    private var focusOpacity: Double {
        switch openingStage {
        case .idle:
            1
        case .centering:
            0.45
        case .awakening, .tension, .release, .afterglow, .returning:
            0
        }
    }

    private var orbOpeningPhase: CapsuleOrbOpeningPhase {
        switch openingStage {
        case .idle, .centering:
            .idle
        case .awakening:
            .awakening
        case .tension:
            .tension
        case .release:
            .release
        case .afterglow:
            .afterglow
        case .returning:
            .returning
        }
    }

    private var showsSealedControls: Bool {
        capsule.status == .sealed || isOpeningPending
    }

    private var showsOpeningPanel: Bool {
        _ = readinessRefreshDate
        return showsSealedControls && capsule.isReadyToOpen
    }

    var body: some View {
        let _ = readinessRefreshDate

        ZStack {
            NightSkyBackground()

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 22) {
                        CapsuleOrbView(
                            capsule: capsule,
                            size: 168,
                            isInteractive: true,
                            freezesMotion: freezesCapsuleMotion,
                            openingPhase: orbOpeningPhase,
                            refreshDate: readinessRefreshDate
                        )
                        .id("capsule-orb")
                        .padding(.top, 28)

                        VStack(spacing: 8) {
                            Text(capsule.title)
                                .font(.title.bold())
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Text(statusText)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        .opacity(focusOpacity)

                        WishTextPanel(
                            capsule: capsule,
                            showsSealingFortuneButton: sealingFortuneText != nil
                        ) {
                            AudioFeedbackService.shared.play(.letterOpen)
                            isShowingSealingFortune = true
                        }
                        .opacity(focusOpacity)

                        if showsOpeningPanel {
                            OpeningPanel(isOpening: isOpeningPending) { status in
                                openCapsule(as: status, scrollProxy: scrollProxy)
                            }
                            .opacity(focusOpacity)
                        }

                        Group {
                            if showsSealedControls {
                                addEntryPanel
                                    .id("add-entry-panel")
                            } else {
                                openedReflectionPanel
                            }
                        }
                        .opacity(focusOpacity)

                        entriesPanel
                            .opacity(focusOpacity)
                    }
                    .padding(20)
                    .padding(.bottom, isEntryFieldFocused ? 170 : 32)
                    .opacity(didEnter ? 1 : 0)
                    .scaleEffect(didEnter ? 1 : 0.985)
                    .blur(radius: isShowingOpeningReflectionOverlay ? 8 : 0)
                    .opacity(isShowingOpeningReflectionOverlay ? 0.16 : 1)
                }
                .onAppear {
                    scrollToEntryPanelIfNeeded(scrollProxy)
                }
                .onChange(of: isEntryFieldFocused) { _, isFocused in
                    guard isFocused else { return }
                    scrollEntryFieldIntoView(scrollProxy)
                }
                .onChange(of: entryText) { _, _ in
                    guard isEntryFieldFocused else { return }
                    scrollEntryFieldIntoView(scrollProxy)
                }
            }

            if isShowingOpeningReflectionOverlay {
                CapsuleOpeningReflectionOverlay(
                    reflection: openedReflection,
                    isLoading: isLoadingOpeningReflection && capsule.openingReflectionText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
                    capsuleTitle: capsule.title,
                    colorHex: capsule.colorHex,
                    symbol: capsule.symbol
                ) {
                    withAnimation(.smooth(duration: 0.36)) {
                        isShowingOpeningReflectionOverlay = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.48)) {
                didEnter = true
            }
        }
        .onDisappear {
            openingTask?.cancel()
            aiEntryPromptGlowTask?.cancel()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isEntryFieldFocused = false
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isEntryFieldFocused = false
                    isShowingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.42))
                }
                .accessibilityLabel("Удалить капсулу")
            }
        }
        .alert("Удалить капсулу?", isPresented: $isShowingDeleteConfirmation) {
            Button("Оставить", role: .cancel) { }

            Button("Удалить", role: .destructive) {
                deleteCapsule()
            }
        } message: {
            Text("Капсула уже хранит твой запрос к миру. Иногда именно такие внезапные желания оказываются заветными. Удалить ее навсегда?")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingKeyboardDoneBar(isVisible: isEntryFieldFocused) {
                isEntryFieldFocused = false
            }
        }
        .task(id: promptRequestKey) {
            await refreshAIEntryPrompt()
        }
        .task(id: openingReflectionRequestKey) {
            await generateOpeningReflectionIfNeeded()
        }
        .onReceive(readinessTimer) { date in
            readinessRefreshDate = date
        }
        .sheet(item: $selectedFutureLetterSignal) { signal in
            FutureLetterReadingView(signal: signal)
        }
        .sheet(isPresented: $isShowingSealingFortune) {
            if let sealingFortuneText {
                SealingFortuneReadingView(text: sealingFortuneText, sealedAt: capsule.sealedAt)
            }
        }
    }

    private var statusText: String {
        _ = readinessRefreshDate

        if capsule.status == .sealed && capsule.isReadyToOpen {
            return "Капсула готова открыться"
        }

        if capsule.status == .sealed {
            return "Откроется \(capsule.openAt.formatted(date: .abbreviated, time: .omitted))"
        }

        return capsule.status.title
    }

    private var sealingFortuneText: String? {
        let text = capsule.sealingFortuneText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    private var openedReflection: OpenedReflection {
        let savedText = capsule.openingReflectionText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return OpenedReflection(status: capsule.status, generatedMessage: savedText?.isEmpty == false ? savedText : nil)
    }

    private var addEntryPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Добавить наблюдение")
                .font(.headline)
                .foregroundStyle(.white)

            Picker("Тип записи", selection: $selectedEntryType) {
                ForEach(JournalEntryType.allCases) { type in
                    Label(type.title, systemImage: type.symbolName)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            promptView

            HStack(alignment: .top, spacing: 10) {
                TextField("Запиши коротко, как есть", text: $entryText, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .focused($isEntryFieldFocused)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("capsule-entry-field")

                Button {
                    AudioFeedbackService.shared.play(.softSelect)
                    beautifyEntry()
                } label: {
                    Image(systemName: isBeautifyingEntry ? "wand.and.rays" : "wand.and.stars")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .disabled(entryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBeautifyingEntry)
                .opacity(entryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                .accessibilityLabel("Переписать наблюдение красивее")
            }
            .padding(14)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))

            Button {
                addEntry()
            } label: {
                Label("Сохранить", systemImage: "sparkle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryCapsuleButtonStyle())
            .disabled(entryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var openedReflectionPanel: some View {
        let reflection = openedReflection

        return VStack(alignment: .leading, spacing: 12) {
            Label(reflection.title, systemImage: reflection.symbolName)
                .font(.headline)
                .foregroundStyle(.white)

            if isLoadingOpeningReflection && capsule.openingReflectionText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.regular)

                    Text("Собираю итог этого желания...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.vertical, 2)
                .transition(.opacity)
            } else {
                Text(reflection.message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var entriesPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Следы вокруг желания")
                .font(.headline)
                .foregroundStyle(.white)

            if entries.isEmpty && futureLetterSignal == nil {
                Text("Здесь появятся странности, маленькие радости и шаги, которые будут собираться вокруг капсулы.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if let futureLetterSignal {
                    futureLetterTimelineRow(futureLetterSignal)
                }

                ForEach(entries) { entry in
                    JournalEntryRow(entry: entry)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func futureLetterTimelineRow(_ signal: NotificationSignal) -> some View {
        Button {
            AudioFeedbackService.shared.play(.letterOpen)
            selectedFutureLetterSignal = signal
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "envelope.open.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Color(hex: capsule.colorHex).opacity(0.38), radius: 10)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Письмо из будущего")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        Spacer(minLength: 8)

                        Text(signal.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    Text("Открыть послание, которое пришло по пути к желанию")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.38))
                    .padding(.top, 8)
            }
            .padding(14)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: capsule.colorHex).opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Открыть письмо из будущего")
    }

    private func addEntry() {
        let trimmed = entryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        AudioFeedbackService.shared.play(.journalSave)
        withAnimation {
            let entry = JournalEntry(capsuleID: capsule.id, type: selectedEntryType, text: trimmed)
            modelContext.insert(entry)
            entryText = ""
            isEntryFieldFocused = false
        }
    }

    private func scrollToEntryPanelIfNeeded(_ scrollProxy: ScrollViewProxy) {
        guard showsSealedControls, !didAutoScrollToEntryPanel else { return }
        didAutoScrollToEntryPanel = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard openingStage == .idle else { return }

            withAnimation(.easeInOut(duration: 0.62)) {
                scrollProxy.scrollTo("add-entry-panel", anchor: .top)
            }
        }
    }

    private func scrollEntryFieldIntoView(_ scrollProxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.24)) {
                scrollProxy.scrollTo("capsule-entry-field", anchor: .bottom)
            }
        }
    }

    private var promptView: some View {
        HStack(alignment: .top, spacing: 8) {
            if isLoadingAIEntryPrompt {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white.opacity(0.70))
                    .padding(.top, 1)
            }

            Text(isLoadingAIEntryPrompt ? String(localized: "Ищу подсказку вокруг этого желания...") : currentEntryPrompt)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.76 + aiEntryPromptGlowAmount * 0.24))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(isLoadingAIEntryPrompt ? "loading" : entryPromptPresentationID.uuidString)
                .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .leading)))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: Color(hex: "F2C46D").opacity(0.14 + aiEntryPromptGlowAmount * 0.64), radius: 3 + aiEntryPromptGlowAmount * 17)
        .shadow(color: .white.opacity(aiEntryPromptGlowAmount * 0.28), radius: aiEntryPromptGlowAmount * 7)
    }

    @MainActor
    private func refreshAIEntryPrompt() async {
        let libraryPrompt = fallbackEntryPrompt
        entryPromptText = nil

        guard aiWishPromptService.isAvailable else {
            isLoadingAIEntryPrompt = false
            presentEntryPrompt(libraryPrompt)
            return
        }

        isLoadingAIEntryPrompt = true
        var resolvedPrompt = libraryPrompt
        do {
            let prompt = try await aiWishPromptService.prompt(
                for: selectedEntryType,
                capsule: capsule,
                recentEntries: entries
            )
            try Task.checkCancellation()
            if let prompt {
                resolvedPrompt = prompt
            }
        } catch is CancellationError {
            isLoadingAIEntryPrompt = false
            return
        } catch {
            AppLog.ai.error("AI backend capsule prompt fallback: \(error.localizedDescription, privacy: .public)")
            resolvedPrompt = libraryPrompt
        }

        presentEntryPrompt(resolvedPrompt)
    }

    @MainActor
    private func presentEntryPrompt(_ prompt: String) {
        withAnimation(.easeInOut(duration: 0.28)) {
            isLoadingAIEntryPrompt = false
            entryPromptText = prompt
            entryPromptPresentationID = UUID()
        }

        glowEntryPrompt()
    }

    @MainActor
    private func glowEntryPrompt() {
        aiEntryPromptGlowTask?.cancel()

        withAnimation(.easeOut(duration: 0.36)) {
            aiEntryPromptGlowAmount = 1
        }

        aiEntryPromptGlowTask = Task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 2.4)) {
                    aiEntryPromptGlowAmount = 0
                }
            }
        }
    }

    @MainActor
    private func generateOpeningReflectionIfNeeded() async {
        guard capsule.status != .sealed else { return }
        guard capsule.openingReflectionText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else { return }

        isLoadingOpeningReflection = true
        var resolvedText: String?
        do {
            if openingReflectionService.isAvailable {
                resolvedText = try await openingReflectionService.reflection(
                    for: capsule,
                    status: capsule.status,
                    entries: entries
                )
                try Task.checkCancellation()
            }
        } catch is CancellationError {
            return
        } catch {
            AppLog.ai.error("AI backend opening reflection fallback: \(error.localizedDescription, privacy: .public)")
        }

        let fallbackText = OpenedReflection(status: capsule.status).message
        withAnimation(.easeInOut(duration: 0.36)) {
            capsule.openingReflectionText = resolvedText ?? fallbackText
            isLoadingOpeningReflection = false
        }
    }

    private func beautifyEntry() {
        let clean = entryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isBeautifyingEntry else { return }

        isEntryFieldFocused = false
        isBeautifyingEntry = true

        Task {
            let polished = await creationAssistantService.polishedObservation(clean, entryType: selectedEntryType)
            await MainActor.run {
                if let polished { entryText = polished }
                isBeautifyingEntry = false
            }
        }
    }

    private func openCapsule(as status: CapsuleStatus, scrollProxy: ScrollViewProxy) {
        guard !isOpeningPending else { return }
        isEntryFieldFocused = false

        if reduceMotion {
            AudioFeedbackService.shared.play(.capsuleRelease)
            isLoadingOpeningReflection = true
            capsule.status = status
            capsule.openedAt = Date()
            CapsuleNotificationScheduler.shared.cancelSignals(for: capsule)
            isShowingOpeningReflectionOverlay = true
            AudioFeedbackService.shared.play(.afterglow)
            return
        }

        openingStage = .centering
        openingTask?.cancel()

        withAnimation(.easeInOut(duration: 0.34)) {
            scrollProxy.scrollTo("capsule-orb", anchor: .center)
        }

        openingTask = Task {
            try? await Task.sleep(for: .milliseconds(360))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                AudioFeedbackService.shared.play(.capsuleAwaken)
                withAnimation(.smooth(duration: 0.82)) {
                    openingStage = .awakening
                }
            }

            try? await Task.sleep(for: .milliseconds(820))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                AudioFeedbackService.shared.play(.capsuleRelease)
                withAnimation(.smooth(duration: 0.62)) {
                    openingStage = .release
                }
            }

            try? await Task.sleep(for: .milliseconds(620))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                var transaction = Transaction()
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    isLoadingOpeningReflection = true
                    capsule.status = status
                    capsule.openedAt = Date()
                    CapsuleNotificationScheduler.shared.cancelSignals(for: capsule)
                }

                isShowingOpeningReflectionOverlay = true
                AudioFeedbackService.shared.play(.afterglow)
            }

            await MainActor.run {
                openingStage = .returning
            }

            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.smooth(duration: 0.62)) {
                    openingStage = .idle
                }
            }

            try? await Task.sleep(for: .milliseconds(620))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                openingTask = nil
            }
        }
    }

    private func deleteCapsule() {
        openingTask?.cancel()
        openingTask = nil
        isEntryFieldFocused = false

        let capsuleID = capsule.id
        CapsuleNotificationScheduler.shared.cancelSignals(for: capsule)
        allEntries
            .filter { $0.capsuleID == capsuleID }
            .forEach(modelContext.delete)
        allSignals
            .filter { $0.capsuleID == capsuleID }
            .forEach(modelContext.delete)

        modelContext.delete(capsule)
        dismiss()
    }
}

private struct OpenedReflection {
    let title: String
    let message: String
    let symbolName: String

    init(status: CapsuleStatus, generatedMessage: String? = nil) {
        switch status {
        case .fulfilled:
            title = String(localized: "Желание сбылось")
            message = generatedMessage ?? String(localized: "Это желание дошло до берега. Отметь не только факт, но и путь: что помогло ему случиться, что внутри стало спокойнее, и какой маленький след ты хочешь взять с собой дальше.")
            symbolName = "sparkles"
        case .unfolding:
            title = String(localized: "Желание еще сбывается")
            message = generatedMessage ?? String(localized: "Похоже, история не закрыта, а продолжает собираться. Капсула уже показала направление: можно вернуться к следам, заметить живые признаки и выбрать один следующий шаг без спешки.")
            symbolName = "leaf.fill"
        case .changed:
            title = String(localized: "Желание сбылось иначе")
            message = generatedMessage ?? String(localized: "Иногда желание отвечает не тем предметом, а смыслом под ним. Посмотри, что изменилось в тебе, в обстоятельствах или в самом запросе: возможно, итог оказался точнее первоначальной формулировки.")
            symbolName = "wand.and.stars"
        case .released:
            title = String(localized: "Желание не сбылось")
            message = generatedMessage ?? String(localized: "Это тоже честный итог. Желание было важным, даже если мир не сложился в его сторону. Можно поблагодарить его за то, что оно показало, и отпустить без долга продолжать хотеть.")
            symbolName = "hand.raised.fill"
        case .opened:
            title = String(localized: "Капсула открыта")
            message = generatedMessage ?? String(localized: "Ты уже сделал важную часть: сохранил желание, дал ему время и вернулся к нему внимательнее. Пусть то, что открылось сейчас, станет не точкой, а мягкой подсказкой для следующего шага.")
            symbolName = "sparkles"
        case .sealed:
            title = String(localized: "Капсула ждет открытия")
            message = String(localized: "Когда придет время, здесь появится итог желания.")
            symbolName = "lock.fill"
        }
    }
}

private struct CapsuleOpeningReflectionOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let reflection: OpenedReflection
    let isLoading: Bool
    let capsuleTitle: String
    let colorHex: String
    let symbol: String
    let onDone: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()

                if reduceMotion {
                    staticStars(in: proxy.size)
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                        openingField(in: proxy.size, time: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }

                ScrollView(showsIndicators: !isLoading) {
                    VStack(spacing: 22) {
                        Spacer(minLength: 30)

                        openingOrb

                        VStack(spacing: 8) {
                            Text(isLoading ? String(localized: "Капсула слушает итог") : reflection.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Text(capsuleTitle)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.62))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 28)

                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.regular)
                                .padding(.top, 6)

                            Text("Собираю итог этого желания...")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.68))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                                .transition(.opacity)
                        } else {
                            Text(reflection.message)
                                .font(.title3.weight(.medium))
                                .lineSpacing(5)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.86)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 26)
                                .transition(.opacity.combined(with: .offset(y: 12)))

                            Button {
                                onDone()
                            } label: {
                                Label("Вернуться к капсуле", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryCapsuleButtonStyle())
                            .padding(.horizontal, 26)
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .offset(y: 10)))
                        }

                        Spacer(minLength: 34)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
    }

    private var openingOrb: some View {
        let color = Color(hex: colorHex)

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(isLoading ? 0.38 : 0.86),
                            color.opacity(isLoading ? 0.48 : 0.58),
                            .clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 168
                    )
                )
                .frame(width: 260, height: 260)
                .scaleEffect(isLoading ? 1.05 : 1.42)
                .blur(radius: isLoading ? 10 : 18)
                .blendMode(.screen)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.90),
                            color.opacity(0.72),
                            color.opacity(isLoading ? 0.18 : 0.08)
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 96
                    )
                )
                .frame(width: isLoading ? 132 : 154, height: isLoading ? 132 : 154)
                .shadow(color: color.opacity(isLoading ? 0.62 : 0.82), radius: isLoading ? 26 : 34)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.42), lineWidth: 1)
                }

            Image(systemName: symbol)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white.opacity(isLoading ? 0.78 : 1))
                .scaleEffect(isLoading ? 0.96 : 1.08)
        }
        .frame(width: 280, height: 280)
        .scaleEffect(isLoading ? 1 : 1.05)
    }

    @ViewBuilder
    private func openingField(in size: CGSize, time: TimeInterval) -> some View {
        ForEach(0..<64, id: \.self) { index in
            let particle = particle(index: index, time: time, in: size)

            Circle()
                .fill(.white.opacity(particle.opacity))
                .frame(width: particle.size, height: particle.size)
                .shadow(color: Color(hex: colorHex).opacity(particle.opacity), radius: particle.size * 2.4)
                .position(particle.position)
        }
    }

    @ViewBuilder
    private func staticStars(in size: CGSize) -> some View {
        ForEach(0..<40, id: \.self) { index in
            Circle()
                .fill(.white.opacity(0.18 + random(index, salt: 40) * 0.32))
                .frame(width: 1.8 + random(index, salt: 41) * 3.2)
                .position(
                    x: size.width * random(index, salt: 42),
                    y: size.height * random(index, salt: 43)
                )
        }
    }

    private func particle(index: Int, time: TimeInterval, in size: CGSize) -> OpeningParticle {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.34)
        let baseAngle = random(index, salt: 1) * .pi * 2
        let speed = 0.10 + random(index, salt: 2) * 0.24
        let phase = time * speed + random(index, salt: 3) * .pi * 2
        let orbit = CGFloat(48 + random(index, salt: 4) * 174)
        let pulse = CGFloat((sin(phase * 2.0) + 1) * 0.5)
        let bloom = isLoading ? CGFloat(0.82 + pulse * 0.16) : CGFloat(1.08 + pulse * 0.38)
        let listeningDrift = isLoading ? CGFloat(sin(phase * 1.7)) * 18 : CGFloat(sin(phase * 1.2)) * 8

        let position = CGPoint(
            x: center.x + cos(baseAngle + phase) * orbit * bloom,
            y: center.y + sin(baseAngle * 0.72 + phase) * orbit * 0.64 + listeningDrift
        )
        let opacity = (isLoading ? 0.14 : 0.20) + Double(pulse) * (isLoading ? 0.42 : 0.58)
        let starSize = CGFloat(1.8 + random(index, salt: 5) * 4.8) * (isLoading ? 0.94 : 1.18)

        return OpeningParticle(position: position, size: starSize, opacity: opacity)
    }

    private func random(_ index: Int, salt: Int) -> Double {
        var value = UInt64(index &+ 1) &* 0x9E37_79B9_7F4A_7C15
        value ^= UInt64(salt &+ 211) &* 0xBF58_476D_1CE4_E5B9
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31

        return Double(value & 0x00FF_FFFF) / Double(0x0100_0000)
    }
}

private struct OpeningParticle {
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
}

private struct SealingFortuneReadingView: View {
    @Environment(\.dismiss) private var dismiss
    let text: String
    let sealedAt: Date

    private var reading: SealingFortuneReading {
        SealingFortuneReading(text: text)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NightSkyBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Image(systemName: "bookmark.circle")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(.white.opacity(0.12), in: Circle())
                            .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Послание при запечатывании")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(reading.message)
                                .font(.title3)
                                .lineSpacing(6)
                                .foregroundStyle(.white.opacity(0.76))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !reading.signs.isEmpty {
                            planSignsView(reading.signs)
                        }

                        Text(sealedAt.formatted(date: .complete, time: .shortened))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.50))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
            }
            .navigationTitle("Послание")
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

    private func planSignsView(_ signs: [SealingFortunePlanSign]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Капсула оставила знаки на пути", systemImage: "bell.badge")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(signs) { sign in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(.white.opacity(0.72))
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(sign.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)

                            if !sign.message.isEmpty {
                                Text(sign.message)
                                    .font(.footnote)
                                    .lineSpacing(3)
                                    .foregroundStyle(.white.opacity(0.68))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct SealingFortuneReading {
    let message: String
    let signs: [SealingFortunePlanSign]

    init(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let markerRange = Self.signsMarkers
            .compactMap({ trimmedText.range(of: $0) })
            .first
        else {
            message = trimmedText
            signs = []
            return
        }

        message = String(trimmedText[..<markerRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let signsText = String(trimmedText[markerRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        signs = signsText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(SealingFortunePlanSign.init)
    }

    private static let signsMarkers = [
        "Капсула оставила знаки на пути:",
        "The capsule left signs along the way:",
    ]
}

private struct SealingFortunePlanSign: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(text: String) {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        title = lines.first ?? text
        message = lines.dropFirst().joined(separator: "\n")
    }
}

private struct FutureLetterReadingView: View {
    @Environment(\.dismiss) private var dismiss
    let signal: NotificationSignal

    var body: some View {
        NavigationStack {
            ZStack {
                NightSkyBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Image(systemName: "envelope.open.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(.white.opacity(0.12), in: Circle())
                            .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Письмо из будущего")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(signal.message)
                                .font(.title3)
                                .lineSpacing(6)
                                .foregroundStyle(.white.opacity(0.76))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(signal.scheduledAt.formatted(date: .complete, time: .shortened))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.50))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
            }
            .navigationTitle("Письмо")
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

private enum CapsuleOpeningStage {
    case idle
    case centering
    case awakening
    case tension
    case release
    case afterglow
    case returning
}
