//
//  CreateCapsuleView.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftData
import SwiftUI

struct CreateCapsuleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishCapsule.createdAt, order: .reverse) private var existingCapsules: [WishCapsule]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var recentJournalEntries: [JournalEntry]
    @Query(sort: \PersonalSymbol.createdAt, order: .reverse) private var personalSymbols: [PersonalSymbol]
    @State private var intention = ""
    @State private var feeling = ""
    @State private var wishPrompt = ""
    @State private var feelingPrompt = ""
    @State private var isBeautifyingIntention = false
    @State private var feelingPromptTask: Task<Void, Never>?
    @State private var beautifyTask: Task<Void, Never>?
    @State private var generatedTitle = ""
    @State private var didAttemptSeal = false
    @State private var openAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var selectedColor = CapsulePalette.options[0]
    @State private var selectedSymbol = "star"
    @State private var symbolSuggestion: SymbolSuggestion?
    @State private var isLoadingSymbolSuggestion = false
    @State private var isShowingPersonalSymbolCreator = false
    @State private var sealingStage: WishSealingStage = .idle
    @State private var sealingInspiration: WishSealingInspiration?
    @State private var sealingTask: Task<Void, Never>?
    @FocusState private var isTextInputFocused: Bool

    private let futureLetterService = FutureLetterService()
    private let creationAssistantService = WishCreationAssistantService()
    private let sealingInspirationService = WishSealingInspirationService()
    private let symbolicAssistantService = SymbolicAssistantService()
    private let symbols = CapsuleCreationSymbol.library

    var body: some View {
        NavigationStack {
            ZStack {
                NightSkyBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Новая капсула")
                                .font(.title.bold())
                                .foregroundStyle(.white)

                            Text("Не ищи идеальную фразу. Достаточно назвать желание так, чтобы через время ты узнал в нём себя.")
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if hasReachedActiveCapsuleLimit {
                            capsuleLimitNotice
                        }

                        VStack(spacing: 14) {
                            field(
                                "Желание",
                                text: $intention,
                                prompt: wishPrompt,
                                lines: 4,
                                showsValidation: didAttemptSeal && intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                trailingAction: creationAssistantService.isAvailable ? AnyView(intentionMagicButton) : nil
                            )
                            field(
                                "Чувство",
                                text: $feeling,
                                prompt: feelingPrompt,
                                lines: 1,
                                showsValidation: didAttemptSeal && feeling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                        }

                        DatePicker("Открыть капсулу", selection: $openAt, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))

                        colorPicker
                        symbolPicker
                        symbolAssistantPanel
                    }
                    .padding(20)
                    .padding(.bottom, 96)
                    .opacity(sealingStage.isActive ? 0.10 : 1)
                    .scaleEffect(sealingStage.isActive ? 0.985 : 1)
                    .blur(radius: sealingStage.isActive ? 12 : 0)
                }

                if sealingStage.isActive {
                    WishSealingOverlay(
                        stage: sealingStage,
                        title: generatedTitle.isEmpty ? String(localized: "Будущая капсула") : generatedTitle,
                        colorHex: selectedColor.hex,
                        symbol: selectedSymbol,
                        openAt: Calendar.current.startOfDay(for: openAt),
                        inspiration: sealingInspiration
                    ) {
                        dismiss()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .overlay(alignment: .topTrailing) {
                if !sealingStage.isActive {
                    closeButton
                        .padding(.top, 8)
                        .padding(.trailing, 16)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isTextInputFocused = false
            }
            .animation(.smooth(duration: 1.05), value: sealingStage)
            .toolbar(.hidden, for: .navigationBar)
            .interactiveDismissDisabled(sealingStage.isActive && sealingStage != .complete)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isTextInputFocused && !sealingStage.isActive {
                    Button {
                        sealCapsule()
                    } label: {
                        Label("Запечатать капсулу", systemImage: "lock.fill")
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle())
                    .disabled(hasReachedActiveCapsuleLimit)
                    .opacity(hasReachedActiveCapsuleLimit ? 0.55 : 1)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0),
                                Color.black.opacity(0.58)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingKeyboardDoneBar(isVisible: isTextInputFocused) {
                    isTextInputFocused = false
                }
            }
            .onDisappear {
                feelingPromptTask?.cancel()
                beautifyTask?.cancel()
                sealingTask?.cancel()
            }
            .sheet(isPresented: $isShowingPersonalSymbolCreator) {
                PersonalSymbolCreatorView { symbol in
                    modelContext.insert(symbol)
                    selectedSymbol = symbol.systemName
                }
            }
            .task {
                await refreshWishPrompt()
            }
            .onChange(of: intention) { _, newValue in
                refreshFeelingPrompt(for: newValue)
            }
        }
    }

    private var canCreate: Bool {
        !intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !feeling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasReachedActiveCapsuleLimit: Bool {
        !CapsuleCreationPolicy.canCreateCapsule(with: existingCapsules)
    }

    private var capsuleLimitNotice: some View {
        Label {
            Text("Сейчас у тебя уже \(CapsuleCreationPolicy.activeCapsuleLimit) активных капсул. Дай одной из них дойти до открытия или освободи место для нового желания.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "seal.fill")
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(Color(hex: "FFE3AD"))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "FFE3AD").opacity(0.28), lineWidth: 1)
        }
    }

    private var closeButton: some View {
        Button {
            sealingTask?.cancel()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.13), in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
        }
        .disabled(sealingStage.isActive && sealingStage != .complete)
        .accessibilityLabel("Закрыть")
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Цвет капсулы")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 36, maximum: 48), spacing: 8)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(CapsulePalette.options, id: \.hex) { option in
                    Button {
                        AudioFeedbackService.shared.play(.softSelect)
                        selectedColor = option
                    } label: {
                        Circle()
                            .fill(Color(hex: option.hex))
                            .frame(width: 36, height: 36)
                            .overlay {
                                if selectedColor.hex == option.hex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .shadow(color: Color(hex: option.hex).opacity(0.65), radius: 9)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(option.name)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Символ")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 44, maximum: 58), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(personalSymbols) { symbol in
                    Button {
                        AudioFeedbackService.shared.play(.softSelect)
                        selectedSymbol = symbol.systemName
                    } label: {
                        Image(systemName: symbol.systemName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                selectedSymbol == symbol.systemName ? .white.opacity(0.24) : .white.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedSymbol == symbol.systemName ? Color(hex: "FFD89A").opacity(0.48) : .white.opacity(0.12), lineWidth: 1)
                            }
                    }
                    .accessibilityLabel("\(symbol.title): \(symbol.meaning)")
                }

                ForEach(symbols) { symbol in
                    Button {
                        AudioFeedbackService.shared.play(.softSelect)
                        selectedSymbol = symbol.systemName
                    } label: {
                        Image(systemName: symbol.systemName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                selectedSymbol == symbol.systemName ? .white.opacity(0.22) : .white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedSymbol == symbol.systemName ? .white.opacity(0.36) : .white.opacity(0.10), lineWidth: 1)
                            }
                    }
                    .accessibilityLabel(symbol.accessibilityLabel)
                }
            }
        }
    }

    private var symbolAssistantPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Личные символы", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    isShowingPersonalSymbolCreator = true
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel("Создать личный символ")
            }

            if let symbolSuggestion {
                Button {
                    AudioFeedbackService.shared.play(.softSelect)
                    selectedSymbol = symbolSuggestion.systemName
                    saveSuggestedSymbolIfNeeded(symbolSuggestion)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: symbolSuggestion.systemName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Color(hex: "FFD89A").opacity(0.20), in: RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(symbolSuggestion.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(symbolSuggestion.meaning)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: selectedSymbol == symbolSuggestion.systemName ? "checkmark.circle.fill" : "plus.circle")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.70))
                    }
                    .padding(14)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "FFD89A").opacity(0.22), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                suggestSymbol()
            } label: {
                if isLoadingSymbolSuggestion {
                    HStack {
                        ProgressView()
                            .tint(.white)
                        Text("Слушаю смысл желания")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label("Подобрать символ", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(SecondaryCapsuleButtonStyle())
            .disabled(intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingSymbolSuggestion)
            .opacity(intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var intentionMagicButton: some View {
        Button {
            beautifyIntention()
        } label: {
            Image(systemName: isBeautifyingIntention ? "wand.and.rays" : "wand.and.stars")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.14), in: Circle())
        }
        .disabled(intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBeautifyingIntention)
        .opacity(intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        .accessibilityLabel("Уточнить формулировку желания")
    }

    private func field(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        prompt: String,
        lines: Int = 1,
        showsValidation: Bool = false,
        trailingAction: AnyView? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            HStack(alignment: .top, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty, !prompt.isEmpty {
                        Text(prompt)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(lines == 1 ? 1 : max(lines, 3))
                            .fixedSize(horizontal: false, vertical: true)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: text, axis: .vertical)
                        .lineLimit(lines...lines)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .focused($isTextInputFocused)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: CGFloat(lines) * 22)

                if let trailingAction {
                    trailingAction
                }
            }
            .padding(12)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(showsValidation ? Color(hex: "FF7A70").opacity(0.95) : .white.opacity(0.12), lineWidth: showsValidation ? 1.4 : 1)
            }

            if showsValidation {
                Text("Заполни поле, чтобы капсула могла сохранить желание.")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "FFB3AA"))
            }
        }
    }

    private func sealCapsule() {
        guard !sealingStage.isActive else { return }
        didAttemptSeal = true
        guard !hasReachedActiveCapsuleLimit else { return }
        guard canCreate else { return }

        let trimmedIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFeeling = feeling.trimmingCharacters(in: .whitespacesAndNewlines)

        isTextInputFocused = false
        sealingInspiration = nil
        generatedTitle = ""
        sealingStage = .gathering
        AudioFeedbackService.shared.play(.capsuleSeal)
        sealingTask?.cancel()

        sealingTask = Task {
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.smooth(duration: 0.90)) {
                    sealingStage = .launching
                }
            }

            try? await Task.sleep(for: .milliseconds(1050))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.smooth(duration: 0.55)) {
                    sealingStage = .listening
                }
            }

            let fallbackTitle = creationAssistantService.fallbackTitle(
                for: trimmedIntention,
                feeling: trimmedFeeling
            )
            async let titleRequest = creationAssistantService.title(
                for: trimmedIntention,
                feeling: trimmedFeeling
            )
            async let inspirationRequest = sealingInspirationService.inspiration(
                title: fallbackTitle,
                intention: trimmedIntention,
                feeling: trimmedFeeling,
                openAt: openAt,
                context: sealingContext(
                    title: fallbackTitle,
                    intention: trimmedIntention
                )
            )

            let titleForCapsule = await titleRequest
            let inspiration = await inspirationRequest
            guard !Task.isCancelled else { return }

            await MainActor.run {
                generatedTitle = titleForCapsule
            }

            await MainActor.run {
                sealingInspiration = inspiration
                let capsule = createCapsule(
                    title: titleForCapsule,
                    intention: trimmedIntention,
                    feeling: trimmedFeeling,
                    sealingFortuneText: inspiration.sealingText
                )
                schedulePlanCheckpoints(inspiration.checkpoints, for: capsule)

                withAnimation(.smooth(duration: 0.68)) {
                    sealingStage = .complete
                }
            }
        }
    }

    private func createCapsule(
        title: String,
        intention: String,
        feeling: String,
        sealingFortuneText: String?
    ) -> WishCapsule {
        let capsule = WishCapsule(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            intentionText: intention.trimmingCharacters(in: .whitespacesAndNewlines),
            desiredFeeling: feeling.trimmingCharacters(in: .whitespacesAndNewlines),
            openAt: Calendar.current.startOfDay(for: openAt),
            colorHex: selectedColor.hex,
            symbol: selectedSymbol,
            sealingFortuneText: sealingFortuneText
        )

        modelContext.insert(capsule)
        scheduleOpeningSignal(for: capsule)

        return capsule
    }

    private func schedulePlanCheckpoints(_ planCheckpoints: [WishPlanCheckpoint], for capsule: WishCapsule) {
        if !planCheckpoints.isEmpty {
            CapsuleNotificationScheduler.shared.schedulePlanCheckpoints(
                planCheckpoints,
                for: capsule,
                modelContext: modelContext
            )
        }
    }

    private func scheduleOpeningSignal(for capsule: WishCapsule) {
        Task {
            if await CapsuleNotificationScheduler.shared.requestAuthorizationIfNeeded() {
                await MainActor.run {
                    CapsuleNotificationScheduler.shared.scheduleOpeningSignal(
                        for: capsule,
                        modelContext: modelContext
                    )
                }
            }

            if let draft = await futureLetterService.draft(for: capsule) {
                await MainActor.run {
                    CapsuleNotificationScheduler.shared.scheduleFutureLetter(
                        draft,
                        for: capsule,
                        modelContext: modelContext
                    )
                }
            }
        }
    }

    private func refreshWishPrompt() async {
        if creationAssistantService.isAvailable {
            await MainActor.run {
                wishPrompt = ""
            }
        }

        let prompt = await creationAssistantService.wishPrompt()
        guard !Task.isCancelled else { return }

        await MainActor.run {
            wishPrompt = prompt
        }
    }

    private func refreshFeelingPrompt(for intention: String) {
        feelingPromptTask?.cancel()
        feelingPromptTask = Task {
            if creationAssistantService.isAvailable {
                await MainActor.run {
                    feelingPrompt = ""
                }
            }

            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }

            let prompt = await creationAssistantService.feelingPrompt(for: intention)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                feelingPrompt = prompt
            }
        }
    }

    private func beautifyIntention() {
        let cleanIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanIntention.isEmpty, !isBeautifyingIntention else { return }

        AudioFeedbackService.shared.play(.softSelect)
        isTextInputFocused = false
        isBeautifyingIntention = true
        beautifyTask?.cancel()
        beautifyTask = Task {
            let polished = await creationAssistantService.polishedIntention(cleanIntention, feeling: feeling)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                if let polished {
                    intention = polished
                }
                isBeautifyingIntention = false
            }
        }
    }

    private func suggestSymbol() {
        let cleanIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanIntention.isEmpty, !isLoadingSymbolSuggestion else { return }

        isTextInputFocused = false
        isLoadingSymbolSuggestion = true
        Task {
            var suggestion: SymbolSuggestion?
            do {
                if symbolicAssistantService.isAvailable {
                    suggestion = try await symbolicAssistantService.suggestion(for: cleanIntention, feeling: feeling)
                }
            } catch {
                AppLog.ai.error("AI backend symbol suggestion fallback: \(error.localizedDescription, privacy: .public)")
            }

            let resolvedSuggestion = suggestion ?? symbolicAssistantService.fallbackSuggestion(for: cleanIntention, feeling: feeling)
            await MainActor.run {
                symbolSuggestion = resolvedSuggestion
                selectedSymbol = resolvedSuggestion.systemName
                isLoadingSymbolSuggestion = false
            }
        }
    }

    private func saveSuggestedSymbolIfNeeded(_ suggestion: SymbolSuggestion) {
        guard !personalSymbols.contains(where: { $0.systemName == suggestion.systemName && $0.title == suggestion.title }) else { return }

        let symbol = PersonalSymbol(
            systemName: suggestion.systemName,
            title: suggestion.title,
            meaning: suggestion.meaning
        )
        modelContext.insert(symbol)
    }

    private func sealingContext(title: String, intention: String) -> WishSealingContext {
        let normalizedTitle = title.lowercased()
        let normalizedIntention = intention.lowercased()

        let relatedWishes = existingCapsules
            .filter { capsule in
                capsule.title.lowercased() != normalizedTitle ||
                capsule.intentionText.lowercased() != normalizedIntention
            }
            .prefix(5)
            .map {
                RelatedWishContext(
                    title: $0.title,
                    intention: $0.intentionText,
                    feeling: $0.desiredFeeling,
                    status: $0.status.title
                )
            }

        let journalEntries = recentJournalEntries
            .prefix(8)
            .map {
                JournalEntryContext(
                    type: $0.type.title,
                    text: $0.text
                )
            }

        return WishSealingContext(
            relatedWishes: Array(relatedWishes),
            journalEntries: Array(journalEntries)
        )
    }
}

private struct PersonalSymbolCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var meaning = ""
    @State private var selectedSystemName = "sparkles"

    let onCreate: (PersonalSymbol) -> Void

    private let symbolOptions = [
        "sparkles", "star", "heart", "key.fill", "leaf.fill", "moon.stars",
        "sun.max", "flame.fill", "house.fill", "paperplane.fill", "book.closed.fill",
        "waveform.path.ecg", "circle", "seal", "lightbulb"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                NightSkyBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Новый личный символ")
                            .font(.title.bold())
                            .foregroundStyle(.white)

                        Text("Выбери пиктограмму и дай ей свой смысл. Она появится рядом с обычными символами при создании капсулы.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 48, maximum: 60), spacing: 10)], spacing: 10) {
                            ForEach(symbolOptions, id: \.self) { systemName in
                                Button {
                                    AudioFeedbackService.shared.play(.softSelect)
                                    selectedSystemName = systemName
                                } label: {
                                    Image(systemName: systemName)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(selectedSystemName == systemName ? .white.opacity(0.22) : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedSystemName == systemName ? Color(hex: "FFD89A").opacity(0.46) : .white.opacity(0.10), lineWidth: 1)
                                        }
                                }
                            }
                        }

                        creatorField("Название", text: $title, prompt: "Например: Ключ")
                        creatorField("Смысл", text: $meaning, prompt: "Для желания, которое открывается постепенно", lines: 3)
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Создать") {
                        onCreate(PersonalSymbol(
                            systemName: selectedSystemName,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            meaning: meaning.trimmingCharacters(in: .whitespacesAndNewlines)
                        ))
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
        }
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func creatorField(_ title: LocalizedStringKey, text: Binding<String>, prompt: String, lines: Int = 1) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(lines...max(lines, 3))
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding(14)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }
        }
    }
}

private enum WishSealingStage: Equatable {
    case idle
    case gathering
    case launching
    case listening
    case complete

    var isActive: Bool {
        self != .idle
    }

}

private struct CapsuleCreationSymbol: Identifiable {
    let systemName: String
    let title: String
    let meaning: String

    var id: String { systemName }

    var accessibilityLabel: String {
        "\(title): \(meaning)"
    }

    static let library = [
        CapsuleCreationSymbol(systemName: "star", title: String(localized: "Звезда"), meaning: String(localized: "для желания, которое хочется держать в поле зрения")),
        CapsuleCreationSymbol(systemName: "heart", title: String(localized: "Сердце"), meaning: String(localized: "для личного и эмоционально важного желания")),
        CapsuleCreationSymbol(systemName: "flag", title: String(localized: "Флаг"), meaning: String(localized: "для цели, маршрута и выбранного направления")),
        CapsuleCreationSymbol(systemName: "lightbulb", title: String(localized: "Идея"), meaning: String(localized: "для ясности и нового понимания")),
        CapsuleCreationSymbol(systemName: "circle", title: String(localized: "Круг"), meaning: String(localized: "для целостности, спокойствия и внутренней опоры")),
        CapsuleCreationSymbol(systemName: "seal", title: String(localized: "Печать"), meaning: String(localized: "для обещания себе и бережного запечатывания"))
    ]
}

private struct WishSealingOverlay: View {
    @State private var ritualStartedAt = Date()
    @State private var revealsInspiration = false

    let stage: WishSealingStage
    let title: String
    let colorHex: String
    let symbol: String
    let openAt: Date
    let inspiration: WishSealingInspiration?
    let onDone: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: stage == .complete) {
                    VStack(spacing: 22) {
                        Spacer(minLength: 30)

                        CapsuleSealingRitualView(
                            title: title,
                            colorHex: colorHex,
                            symbol: symbol,
                            openAt: openAt,
                            isWaitingForInspiration: stage == .listening,
                            isComplete: stage == .complete,
                            showsFinalMessage: revealsInspiration,
                            startedAt: ritualStartedAt
                        )
                        .frame(height: min(max(proxy.size.height * 0.52, 360), 460))

                        if let inspiration, stage == .complete, revealsInspiration {
                            VStack(spacing: 14) {
                                Text(inspiration.fortuneText)
                                    .font(.title3.weight(.medium))
                                    .lineSpacing(5)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.white)
                                    .minimumScaleFactor(0.86)
                                    .fixedSize(horizontal: false, vertical: true)

                                if !inspiration.checkpoints.isEmpty {
                                    signalPreview(inspiration.checkpoints)
                                }
                            }
                            .padding(.horizontal, 26)
                            .transition(.opacity.combined(with: .offset(y: 12)))

                            Button {
                                onDone()
                            } label: {
                                Label("Вернуться к капсулам", systemImage: "checkmark.seal.fill")
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
        .onAppear {
            ritualStartedAt = Date()
            revealsInspiration = false
        }
        .task(id: stage) {
            guard stage == .complete else {
                await MainActor.run {
                    revealsInspiration = false
                }
                return
            }

            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.smooth(duration: 0.52)) {
                    revealsInspiration = true
                }
            }
        }
    }

    private func signalPreview(_ checkpoints: [WishPlanCheckpoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Капсула отметила точки на пути", systemImage: "bell.badge")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(checkpoints.enumerated()), id: \.offset) { _, checkpoint in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(.white.opacity(0.72))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(checkpoint.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(checkpoint.message)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.64))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

}

private struct CapsuleSealingRitualView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let colorHex: String
    let symbol: String
    let openAt: Date
    let isWaitingForInspiration: Bool
    let isComplete: Bool
    let showsFinalMessage: Bool
    let startedAt: Date

    private let ritualDuration: TimeInterval = 7.2
    private let countdownLift: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            if reduceMotion {
                scene(in: proxy.size, progress: isComplete ? 1 : 0.86, time: 0, now: Date())
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(startedAt)
                    let progress = min(max(elapsed / ritualDuration, 0), 1)

                    scene(in: proxy.size, progress: progress, time: elapsed, now: timeline.date)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func scene(in size: CGSize, progress: Double, time: TimeInterval, now: Date) -> some View {
        let color = Color(hex: colorHex)
        let capsuleSize = min(size.width * 0.44, 172)
        let centerY = max(size.height * 0.42, capsuleSize * 0.72 + 96)
        let center = CGPoint(x: size.width * 0.5, y: min(centerY, size.height * 0.52))

        return ZStack {
            ritualBackdrop(color: color, size: size, center: center, progress: progress, time: time)
            originParticles(color: color, size: size, center: center, progress: progress)
            formingCapsule(color: color, center: center, capsuleSize: capsuleSize, progress: progress, time: time)
            sealingRing(color: color, center: center, capsuleSize: capsuleSize, progress: progress, time: time)
            countdownSeal(color: color, center: center, capsuleSize: capsuleSize, progress: progress, now: now)
            statusBlock(progress: progress)
                .position(x: size.width * 0.5, y: min(size.height - 46, center.y + capsuleSize * 0.86 + 58))
        }
    }

    private func ritualBackdrop(color: Color, size: CGSize, center: CGPoint, progress: Double, time: TimeInterval) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.22 + phase(progress, from: 0.58, to: 1) * 0.08),
                            Color(hex: "111E3A").opacity(0.16),
                            .clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: min(size.width, size.height) * 0.62
                    )
                )
                .frame(width: min(size.width, size.height) * 1.24, height: min(size.width, size.height) * 1.24)
                .position(center)
                .blur(radius: 18)

            ForEach(0..<38, id: \.self) { index in
                let star = ambientStar(index: index, size: size, time: time)

                Circle()
                    .fill(.white.opacity(star.opacity))
                    .frame(width: star.size, height: star.size)
                    .position(star.position)
            }
        }
    }

    private func originParticles(color: Color, size: CGSize, center: CGPoint, progress: Double) -> some View {
        ZStack {
            ForEach(0..<72, id: \.self) { index in
                let particle = textParticle(index: index, size: size, center: center, progress: progress)

                Circle()
                    .fill((index.isMultiple(of: 3) ? color : .white).opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .shadow(color: color.opacity(particle.opacity * 0.72), radius: particle.size * 2.1)
                    .position(particle.position)
            }
        }
    }

    private func formingCapsule(color: Color, center: CGPoint, capsuleSize: CGFloat, progress: Double, time: TimeInterval) -> some View {
        let core = phase(progress, from: 0.10, to: 0.38)
        let gather = phase(progress, from: 0.18, to: 0.50)
        let solid = phase(progress, from: 0.42, to: 0.64)
        let boundary = phase(progress, from: 0.66, to: 0.80)
        let symbolReveal = phase(progress, from: 0.74, to: 0.92)
        let sealFlash = pulse(progress, center: 0.88, width: 0.045)
        let breathing = reduceMotion ? 0 : sin(time * 2.1) * 0.018
        let glowSize = capsuleSize * (0.56 + gather * 1.08 - solid * 0.34)
        let activeSize = capsuleSize * (0.78 + solid * 0.22)

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.78 * core + sealFlash * 0.22),
                            color.opacity(0.62 * core + 0.16 + gather * 0.18),
                            .clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: glowSize * 0.76
                    )
                )
                .frame(width: glowSize * 2.0, height: glowSize * 2.0)
                .scaleEffect(0.82 + gather * 0.18 + sealFlash * 0.12)
                .blur(radius: 24 - solid * 12)
                .opacity(0.34 + core * 0.58)
                .blendMode(.screen)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.78 + solid * 0.14),
                            color.mix(with: .white, by: 0.22).opacity(0.72 + solid * 0.14),
                            color.opacity(0.22 + solid * 0.44)
                        ],
                        center: .topLeading,
                        startRadius: 5,
                        endRadius: activeSize * 0.70
                    )
                )
                .frame(width: activeSize, height: activeSize)
                .opacity(solid)
                .blur(radius: (1 - boundary) * 8)
                .shadow(color: color.opacity(0.32 + solid * 0.58), radius: 18 + solid * 20)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(boundary * 0.48 + sealFlash * 0.36), lineWidth: 0.8 + boundary * 0.6 + sealFlash * 1.8)
                        .blur(radius: sealFlash * 1.6)
                }

            Circle()
                .trim(from: 0.05, to: 0.34)
                .stroke(.white.opacity(0.22 * boundary), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: activeSize * 0.82, height: activeSize * 0.82)
                .rotationEffect(.degrees(-34 + time * 12))
                .blendMode(.screen)

            Image(systemName: symbol)
                .font(.system(size: capsuleSize * 0.30, weight: .semibold))
                .foregroundStyle(.white.opacity(0.18 + symbolReveal * 0.78 + sealFlash * 0.18))
                .scaleEffect(0.78 + symbolReveal * 0.22 + sealFlash * 0.18)
                .shadow(color: .white.opacity(sealFlash * 0.68), radius: 14)
        }
        .scaleEffect(1 + breathing + sealFlash * 0.06)
        .position(center)
    }

    private func sealingRing(color: Color, center: CGPoint, capsuleSize: CGFloat, progress: Double, time: TimeInterval) -> some View {
        let seal = phase(progress, from: 0.68, to: 0.88)
        let flash = pulse(progress, center: 0.88, width: 0.045)
        let radius = capsuleSize * 1.10

        return ZStack {
            Circle()
                .trim(from: 0, to: seal)
                .stroke(
                    AngularGradient(
                        colors: [
                            .white.opacity(0.92),
                            color.opacity(0.84),
                            .white.opacity(0.92)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.4 + flash * 2.2, lineCap: .round)
                )
                .frame(width: radius, height: radius)
                .rotationEffect(.degrees(-90))
                .opacity(seal)
                .blur(radius: flash * 0.8)

            Circle()
                .stroke(.white.opacity(flash * 0.72), lineWidth: 2)
                .frame(width: radius, height: radius)
                .scaleEffect(1 + flash * 0.12)
                .blur(radius: 1 + flash * 5)
                .blendMode(.screen)
        }
        .position(center)
    }

    private func countdownSeal(color: Color, center: CGPoint, capsuleSize: CGFloat, progress: Double, now: Date) -> some View {
        let reveal = phase(progress, from: 0.90, to: 0.98)
        let countdownY = max(46, center.y - capsuleSize * 1.08 - countdownLift)

        return ZStack {
            VStack(spacing: 3) {
                Text(countdownText(to: openAt, from: now))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("до открытия")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(width: capsuleSize * 2.0)
            .position(x: center.x, y: countdownY)
            .opacity(reveal)
            .scaleEffect(0.92 + reveal * 0.08)

            Circle()
                .stroke(color.mix(with: .white, by: 0.45).opacity(0.28 * reveal), lineWidth: 1)
                .frame(width: capsuleSize * 1.26, height: capsuleSize * 1.26)
                .position(center)
                .scaleEffect(0.76 + reveal * 0.24)
        }
        .allowsHitTesting(false)
    }

    private func statusBlock(progress: Double) -> some View {
        VStack(spacing: 8) {
            Text(statusText(for: progress))
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .id(statusText(for: progress))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 28)
    }

    private func statusText(for progress: Double) -> String {
        if showsFinalMessage {
            return String(localized: "Капсула запечатана")
        }

        switch progress {
        case ..<0.36:
            return String(localized: "Желание становится капсулой")
        case ..<0.68:
            return String(localized: "Желание принимает форму")
        default:
            return String(localized: "Время берёт его на хранение")
        }
    }

    private func countdownText(to targetDate: Date, from currentDate: Date) -> String {
        let remaining = max(0, targetDate.timeIntervalSince(currentDate))
        let wholeSeconds = Int(remaining)
        let days = wholeSeconds / 86_400
        let hours = (wholeSeconds % 86_400) / 3_600
        let minutes = (wholeSeconds % 3_600) / 60
        let seconds = wholeSeconds % 60
        let milliseconds = Int((remaining - Double(wholeSeconds)) * 1_000)

        if days > 0 {
            return String(format: "%02d:%02d:%02d:%02d.%03d", days, hours, minutes, seconds, milliseconds)
        }

        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }

    private func textParticle(index: Int, size: CGSize, center: CGPoint, progress: Double) -> SealingParticle {
        let delay = random(index, salt: 1) * 0.20
        let travel = smoothstep((progress - 0.03 - delay) / 0.58)
        let row = CGFloat(index % 9)
        let column = CGFloat(index / 9)
        let start = CGPoint(
            x: size.width * (0.18 + row / 8 * 0.64) + CGFloat(random(index, salt: 2) - 0.5) * 26,
            y: size.height * (0.74 + column / 8 * 0.16) + CGFloat(random(index, salt: 3) - 0.5) * 22
        )
        let c1 = CGPoint(x: start.x + CGFloat(random(index, salt: 4) - 0.5) * 90, y: size.height * 0.54)
        let c2 = CGPoint(x: center.x + CGFloat(random(index, salt: 5) - 0.5) * 220, y: center.y + CGFloat(random(index, salt: 6) - 0.5) * 150)
        let endRadius = CGFloat(random(index, salt: 7)) * 46
        let endAngle = random(index, salt: 8) * .pi * 2
        let end = CGPoint(
            x: center.x + cos(endAngle) * endRadius,
            y: center.y + sin(endAngle) * endRadius * 0.70
        )
        let absorb = phase(progress, from: 0.52 + delay * 0.12, to: 0.74)
        let opacity = max(0, (0.20 + random(index, salt: 9) * 0.64) * smoothstep(travel / 0.18) * (1 - absorb))

        return SealingParticle(
            position: cubic(start, c1, c2, end, travel),
            size: CGFloat(1.7 + random(index, salt: 10) * 4.4) * CGFloat(1 - absorb * 0.42),
            opacity: opacity
        )
    }

    private func ambientStar(index: Int, size: CGSize, time: TimeInterval) -> SealingParticle {
        let twinkle = 0.56 + 0.44 * sin(time * (0.32 + random(index, salt: 19)) + random(index, salt: 20) * .pi * 2)

        return SealingParticle(
            position: CGPoint(
                x: size.width * CGFloat(random(index, salt: 21)),
                y: size.height * CGFloat(random(index, salt: 22))
            ),
            size: CGFloat(1.2 + random(index, salt: 23) * 2.8),
            opacity: (0.08 + random(index, salt: 24) * 0.20) * max(0, twinkle)
        )
    }

    private func phase(_ value: Double, from start: Double, to end: Double) -> Double {
        smoothstep((value - start) / (end - start))
    }

    private func pulse(_ value: Double, center: Double, width: Double) -> Double {
        max(0, 1 - abs(value - center) / width)
    }

    private func smoothstep(_ value: Double) -> Double {
        let clamped = max(0, min(1, value))
        return clamped * clamped * (3 - 2 * clamped)
    }

    private func cubic(_ start: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ end: CGPoint, _ progress: Double) -> CGPoint {
        let t = CGFloat(progress)
        let inverse = 1 - t
        return CGPoint(
            x: inverse * inverse * inverse * start.x + 3 * inverse * inverse * t * c1.x + 3 * inverse * t * t * c2.x + t * t * t * end.x,
            y: inverse * inverse * inverse * start.y + 3 * inverse * inverse * t * c1.y + 3 * inverse * t * t * c2.y + t * t * t * end.y
        )
    }

    private func random(_ index: Int, salt: Int) -> Double {
        var value = UInt64(index &+ 1) &* 0x9E37_79B9_7F4A_7C15
        value ^= UInt64(salt &+ 101) &* 0xBF58_476D_1CE4_E5B9
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31

        return Double(value & 0x00FF_FFFF) / Double(0x0100_0000)
    }
}

private struct SealingParticle {
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
}
