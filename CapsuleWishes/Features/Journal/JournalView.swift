//
//  JournalView.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftData
import SwiftUI

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationRouteCenter: NotificationRouteCenter
    @AppStorage(AIUsagePreferences.enabledKey) private var aiFeaturesEnabled = AIUsagePreferences.defaultEnabled
    @Query(sort: \WishCapsule.createdAt, order: .reverse) private var capsules: [WishCapsule]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @State private var selectedType: JournalEntryType = .sign
    @State private var selectedCapsuleID: UUID?
    @State private var text = ""
    @State private var promptText: String?
    @State private var promptPresentationID = UUID()
    @State private var isIntroExpanded = false
    @State private var isLoadingAIPrompt = false
    @State private var aiPromptGlowAmount = 0.0
    @State private var aiPromptGlowTask: Task<Void, Never>?
    @State private var isBeautifyingEntry = false
    @FocusState private var isTextEditorFocused: Bool

    private let aiWishPromptService = AIWishPromptService()
    private let creationAssistantService = WishCreationAssistantService()

    private var activeCapsules: [WishCapsule] {
        capsules.filter { !$0.hasBeenOpened }
    }

    private var selectedCapsule: WishCapsule? {
        guard let selectedCapsuleID else { return nil }
        return activeCapsules.first { $0.id == selectedCapsuleID }
    }

    private var selectedCapsuleEntries: [JournalEntry] {
        guard let selectedCapsuleID else { return [] }
        return entries.filter { $0.capsuleID == selectedCapsuleID }
    }

    private var fallbackPrompt: String {
        WishPromptLibrary.prompt(
            for: selectedType,
            capsule: selectedCapsule,
            recentEntries: selectedCapsuleEntries
        )
    }

    private var currentPrompt: String {
        promptText ?? fallbackPrompt
    }

    private var promptRequestKey: String {
        [
            selectedCapsuleID?.uuidString ?? "none",
            selectedType.rawValue,
            aiFeaturesEnabled.description,
            selectedCapsuleEntries.first?.id.uuidString ?? "empty",
        ].joined(separator: "-")
    }

    private var entrySections: [JournalEntryDaySection] {
        let calendar = Calendar.current
        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }

        return groupedEntries
            .map { JournalEntryDaySection(date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NightSkyBackground()

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            introHeader

                            composer

                            VStack(alignment: .leading, spacing: 14) {
                                Text("Последние записи")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                if entries.isEmpty {
                                    Text("Начни с одного наблюдения: что сегодня осталось с тобой дольше обычного?")
                                        .foregroundStyle(.white.opacity(0.64))
                                } else {
                                    ForEach(entrySections) { section in
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text(section.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white.opacity(0.68))
                                                .textCase(.uppercase)

                                            ForEach(section.entries) { entry in
                                                JournalEntryRow(entry: entry, timestampStyle: .timeOnly)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .padding(.bottom, isTextEditorFocused ? 170 : 24)
                    }
                    .onChange(of: isTextEditorFocused) { _, isFocused in
                        guard isFocused else { return }
                        scrollEntryFieldIntoView(scrollProxy)
                    }
                    .onChange(of: text) { _, _ in
                        guard isTextEditorFocused else { return }
                        scrollEntryFieldIntoView(scrollProxy)
                    }
                    .onChange(of: notificationRouteCenter.requestedJournalEntryType) { _, entryType in
                        guard let entryType else { return }
                        openJournalEntryRequest(entryType, scrollProxy: scrollProxy)
                    }
                    .onAppear {
                        guard let entryType = notificationRouteCenter.requestedJournalEntryType else { return }
                        openJournalEntryRequest(entryType, scrollProxy: scrollProxy)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isTextEditorFocused = false
            }
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingKeyboardDoneBar(isVisible: isTextEditorFocused) {
                    isTextEditorFocused = false
                }
            }
            .task(id: promptRequestKey) {
                await refreshAIPrompt()
            }
            .onChange(of: activeCapsules.map(\.id)) { _, activeCapsuleIDs in
                guard let selectedCapsuleID, !activeCapsuleIDs.contains(selectedCapsuleID) else { return }
                self.selectedCapsuleID = nil
            }
            .onDisappear {
                aiPromptGlowTask?.cancel()
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 16) {
            let controlLabelWidth: CGFloat = 86
            let typeControlsWidth: CGFloat = 206

            capsulePicker(labelWidth: controlLabelWidth, controlWidth: typeControlsWidth)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    typeControlLabel(width: controlLabelWidth)

                    journalTypeChips
                        .frame(width: typeControlsWidth, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 10) {
                    typeControlLabel(width: nil)
                    journalTypeChips
                }
            }

            promptView

            HStack(alignment: .top, spacing: 10) {
                TextField("Что ты сегодня заметил?", text: $text, axis: .vertical)
                    .lineLimit(4...8)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .focused($isTextEditorFocused)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("journal-entry-field")

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
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBeautifyingEntry)
                .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                .accessibilityLabel("Сделать наблюдение яснее")
            }
            .padding(16)
            .background(
                isTextEditorFocused ? .white.opacity(0.16) : .white.opacity(0.11),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isTextEditorFocused ? .white.opacity(0.24) : .white.opacity(0.08), lineWidth: 1)
            )

            Button {
                addEntry()
            } label: {
                Label("Сохранить запись", systemImage: selectedType.symbolName)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryCapsuleButtonStyle())
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func typeControlLabel(width: CGFloat?) -> some View {
        Text(selectedType.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
            .frame(width: width, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private var journalTypeChips: some View {
        HStack(spacing: 10) {
            ForEach(JournalEntryType.allCases) { type in
                JournalTypeIconChip(
                    type: type,
                    isSelected: selectedType == type
                ) {
                    AudioFeedbackService.shared.play(.softSelect)
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedType = type
                    }
                }
            }
        }
    }

    private var introHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Дневник знаков")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Собирай знаки, мысли и сны вокруг желаний")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.74))

                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isIntroExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                    .buttonStyle(.plain)
                }

                if isIntroExpanded {
                    Text("Когда желание получает имя, внимание начинает замечать больше: совпадения, возвращающиеся мысли, сны и тихие сдвиги. Записывай не доказательства, а то, что действительно задержалось внутри.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func capsulePicker(labelWidth: CGFloat, controlWidth: CGFloat) -> some View {
        ViewThatFits(in: .horizontal) {
            capsulePickerRow(labelWidth: labelWidth, controlWidth: controlWidth)

            VStack(alignment: .leading, spacing: 10) {
                Text("Капсула")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))

                capsuleMenu
            }
        }
    }

    private func capsulePickerRow(labelWidth: CGFloat, controlWidth: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Капсула")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: labelWidth, alignment: .leading)
                .lineLimit(1)

            capsuleMenu
                .frame(width: controlWidth, alignment: .leading)
        }
    }

    private var capsuleMenu: some View {
        Menu {
            Button("Без привязки") {
                AudioFeedbackService.shared.play(.softSelect)
                selectedCapsuleID = nil
            }

            ForEach(activeCapsules) { capsule in
                Button {
                    AudioFeedbackService.shared.play(.softSelect)
                    selectedCapsuleID = capsule.id
                } label: {
                    Text(capsule.title)
                }
            }
        } label: {
            HStack(spacing: 9) {
                if let selectedCapsule {
                    Image(systemName: selectedCapsule.symbol)
                        .font(.subheadline.weight(.semibold))
                } else {
                    Image(systemName: "link")
                        .font(.subheadline.weight(.semibold))
                }

                Text(selectedCapsule?.title ?? String(localized: "Без привязки"))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.11), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.13), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(activeCapsules.isEmpty)
    }

    private func addEntry() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        AudioFeedbackService.shared.play(.journalSave)
        withAnimation {
            modelContext.insert(JournalEntry(capsuleID: selectedCapsule?.id, type: selectedType, text: trimmed))
            text = ""
            isTextEditorFocused = false
        }
    }

    private func openJournalEntryRequest(_ entryType: JournalEntryType, scrollProxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedType = entryType
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeInOut(duration: 0.28)) {
                scrollProxy.scrollTo("journal-entry-field", anchor: .center)
            }
            isTextEditorFocused = true
            notificationRouteCenter.consumeJournalEntryRequest()
        }
    }

    private func beautifyEntry() {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isBeautifyingEntry else { return }

        isTextEditorFocused = false
        isBeautifyingEntry = true

        Task {
            let polished = await creationAssistantService.polishedObservation(clean, entryType: selectedType)
            await MainActor.run {
                if let polished { text = polished }
                isBeautifyingEntry = false
            }
        }
    }

    private var promptView: some View {
        HStack(alignment: .top, spacing: 8) {
            if isLoadingAIPrompt {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white.opacity(0.70))
                    .padding(.top, 1)
            }

            Text(isLoadingAIPrompt ? String(localized: "Прислушиваюсь к этому желанию...") : currentPrompt)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.76 + aiPromptGlowAmount * 0.24))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(isLoadingAIPrompt ? "loading" : promptPresentationID.uuidString)
                .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .leading)))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: Color(hex: "F2C46D").opacity(0.14 + aiPromptGlowAmount * 0.64), radius: 3 + aiPromptGlowAmount * 17)
        .shadow(color: .white.opacity(aiPromptGlowAmount * 0.28), radius: aiPromptGlowAmount * 7)
    }

    @MainActor
    private func refreshAIPrompt() async {
        let libraryPrompt = fallbackPrompt
        promptText = nil

        guard aiWishPromptService.isAvailable, let selectedCapsule else {
            isLoadingAIPrompt = false
            presentPrompt(libraryPrompt)
            return
        }

        isLoadingAIPrompt = true
        var resolvedPrompt = libraryPrompt
        do {
            let prompt = try await aiWishPromptService.prompt(
                for: selectedType,
                capsule: selectedCapsule,
                recentEntries: selectedCapsuleEntries
            )
            try Task.checkCancellation()
            if let prompt {
                resolvedPrompt = prompt
            }
        } catch is CancellationError {
            isLoadingAIPrompt = false
            return
        } catch {
            AppLog.ai.error("AI backend journal prompt fallback: \(error.localizedDescription, privacy: .public)")
            resolvedPrompt = libraryPrompt
        }

        presentPrompt(resolvedPrompt)
    }

    @MainActor
    private func presentPrompt(_ prompt: String) {
        withAnimation(.easeInOut(duration: 0.28)) {
            isLoadingAIPrompt = false
            promptText = prompt
            promptPresentationID = UUID()
        }

        glowPrompt()
    }

    @MainActor
    private func glowPrompt() {
        aiPromptGlowTask?.cancel()

        withAnimation(.easeOut(duration: 0.36)) {
            aiPromptGlowAmount = 1
        }

        aiPromptGlowTask = Task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 2.4)) {
                    aiPromptGlowAmount = 0
                }
            }
        }
    }

    private func scrollEntryFieldIntoView(_ scrollProxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.24)) {
                scrollProxy.scrollTo("journal-entry-field", anchor: .bottom)
            }
        }
    }
}

private struct JournalEntryDaySection: Identifiable {
    let date: Date
    let entries: [JournalEntry]

    var id: Date { date }

    var title: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return String(localized: "Сегодня")
        }

        if calendar.isDateInYesterday(date) {
            return String(localized: "Вчера")
        }

        return date.formatted(date: .long, time: .omitted)
    }
}
