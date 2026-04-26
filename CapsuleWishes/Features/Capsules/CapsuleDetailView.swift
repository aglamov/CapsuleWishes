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
    @State private var aiEntryPrompt: String?
    @State private var isLoadingAIEntryPrompt = false
    @State private var aiEntryPromptGlowAmount = 0.0
    @State private var aiEntryPromptGlowTask: Task<Void, Never>?
    @State private var selectedFutureLetterSignal: NotificationSignal?
    @FocusState private var isEntryFieldFocused: Bool

    private let aiWishPromptService = AIWishPromptService()

    private var entries: [JournalEntry] {
        allEntries.filter { $0.capsuleID == capsule.id }
    }

    private var futureLetterSignal: NotificationSignal? {
        allSignals
            .filter { $0.capsuleID == capsule.id && $0.kind == .futureLetter && $0.hasPassed }
            .sorted { $0.scheduledAt > $1.scheduledAt }
            .first
    }

    private var currentEntryPrompt: String {
        aiEntryPrompt ?? WishPromptLibrary.prompt(
            for: selectedEntryType,
            capsule: capsule,
            recentEntries: entries
        )
    }

    private var promptRequestKey: String {
        [
            capsule.id.uuidString,
            selectedEntryType.rawValue,
            aiFeaturesEnabled.description,
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
        showsSealedControls && capsule.openAt <= Date()
    }

    var body: some View {
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
                            openingPhase: orbOpeningPhase
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

                        WishTextPanel(capsule: capsule)
                            .opacity(focusOpacity)

                        if let futureLetterSignal {
                            futureLetterPanel(futureLetterSignal)
                                .opacity(focusOpacity)
                        }

                        if showsOpeningPanel {
                            OpeningPanel(isOpening: isOpeningPending) { status in
                                openCapsule(as: status, scrollProxy: scrollProxy)
                            }
                            .opacity(focusOpacity)
                        }

                        Group {
                            if showsSealedControls {
                                addEntryPanel
                            } else {
                                openedReflectionPanel
                            }
                        }
                        .opacity(focusOpacity)

                        entriesPanel
                            .opacity(focusOpacity)
                    }
                    .padding(20)
                    .padding(.bottom, 32)
                    .opacity(didEnter ? 1 : 0)
                    .scaleEffect(didEnter ? 1 : 0.985)
                }
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
        .sheet(item: $selectedFutureLetterSignal) { signal in
            FutureLetterReadingView(signal: signal)
        }
    }

    private var statusText: String {
        if capsule.status == .sealed && capsule.isReadyToOpen {
            return "Капсула готова открыться"
        }

        if capsule.status == .sealed {
            return "Откроется \(capsule.openAt.formatted(date: .abbreviated, time: .omitted))"
        }

        return capsule.status.title
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

            TextField("Запиши коротко, как есть", text: $entryText, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .padding(14)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
                .focused($isEntryFieldFocused)

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
        VStack(alignment: .leading, spacing: 12) {
            Label("Капсула открыта", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Ты уже сделал важную часть: сохранил желание, дал ему время и вернулся к нему внимательнее. Пусть то, что открылось сейчас, станет не итогом, а мягкой подсказкой для следующего шага.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func futureLetterPanel(_ signal: NotificationSignal) -> some View {
        Button {
            selectedFutureLetterSignal = signal
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "envelope.open.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Письмо из будущего")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Открыть")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.42))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var entriesPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Следы вокруг желания")
                .font(.headline)
                .foregroundStyle(.white)

            if entries.isEmpty {
                Text("Здесь появятся странности, маленькие радости и шаги, которые будут собираться вокруг капсулы.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(entries) { entry in
                    JournalEntryRow(entry: entry)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addEntry() {
        let trimmed = entryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation {
            let entry = JournalEntry(capsuleID: capsule.id, type: selectedEntryType, text: trimmed)
            modelContext.insert(entry)
            entryText = ""
            isEntryFieldFocused = false
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

            Text(isLoadingAIEntryPrompt ? "Ищу подсказку вокруг этого желания..." : currentEntryPrompt)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.76 + aiEntryPromptGlowAmount * 0.24))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: Color(hex: "F2C46D").opacity(0.14 + aiEntryPromptGlowAmount * 0.64), radius: 3 + aiEntryPromptGlowAmount * 17)
        .shadow(color: .white.opacity(aiEntryPromptGlowAmount * 0.28), radius: aiEntryPromptGlowAmount * 7)
    }

    @MainActor
    private func refreshAIEntryPrompt() async {
        aiEntryPrompt = nil

        guard aiWishPromptService.isAvailable else {
            isLoadingAIEntryPrompt = false
            return
        }

        isLoadingAIEntryPrompt = true
        var shouldGlow = false
        do {
            let prompt = try await aiWishPromptService.prompt(
                for: selectedEntryType,
                capsule: capsule,
                recentEntries: entries
            )
            try Task.checkCancellation()
            aiEntryPrompt = prompt
            shouldGlow = true
        } catch is CancellationError {
            isLoadingAIEntryPrompt = false
            return
        } catch {
            AppLog.ai.error("OpenAI capsule prompt fallback: \(error.localizedDescription, privacy: .public)")
            aiEntryPrompt = nil
            shouldGlow = true
        }

        isLoadingAIEntryPrompt = false

        if shouldGlow {
            glowEntryPrompt()
        }
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

    private func openCapsule(as status: CapsuleStatus, scrollProxy: ScrollViewProxy) {
        guard !isOpeningPending else { return }
        isEntryFieldFocused = false

        if reduceMotion {
            capsule.status = status
            capsule.openedAt = Date()
            CapsuleNotificationScheduler.shared.cancelSignals(for: capsule)
            return
        }

        openingStage = .centering
        openingTask?.cancel()

        withAnimation(.easeInOut(duration: 0.88)) {
            scrollProxy.scrollTo("capsule-orb", anchor: .center)
        }

        openingTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.smooth(duration: 2.0)) {
                    openingStage = .awakening
                }
            }

            try? await Task.sleep(for: .milliseconds(2000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.smooth(duration: 5.1)) {
                    openingStage = .tension
                }
            }

            try? await Task.sleep(for: .milliseconds(5100))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.smooth(duration: 0.78)) {
                    openingStage = .release
                }
            }

            try? await Task.sleep(for: .milliseconds(780))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                var transaction = Transaction()
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    capsule.status = status
                    capsule.openedAt = Date()
                    CapsuleNotificationScheduler.shared.cancelSignals(for: capsule)
                }
            }

            await MainActor.run {
                openingStage = .returning
            }

            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.smooth(duration: 1.20)) {
                    openingStage = .idle
                }
            }

            try? await Task.sleep(for: .milliseconds(1200))
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
