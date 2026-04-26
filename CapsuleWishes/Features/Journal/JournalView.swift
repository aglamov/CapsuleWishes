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
    @AppStorage(AIUsagePreferences.enabledKey) private var aiFeaturesEnabled = false
    @Query(sort: \WishCapsule.createdAt, order: .reverse) private var capsules: [WishCapsule]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @State private var selectedType: JournalEntryType = .sign
    @State private var selectedCapsuleID: UUID?
    @State private var text = ""
    @State private var aiPrompt: String?
    @State private var isIntroExpanded = false
    @State private var isLoadingAIPrompt = false
    @FocusState private var isTextEditorFocused: Bool

    private let aiWishPromptService = AIWishPromptService()

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

    private var currentPrompt: String {
        aiPrompt ?? WishPromptLibrary.prompt(
            for: selectedType,
            capsule: selectedCapsule,
            recentEntries: selectedCapsuleEntries
        )
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        introHeader

                        composer

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Последние записи")
                                .font(.headline)
                                .foregroundStyle(.white)

                            if entries.isEmpty {
                                Text("Сегодня можно начать с малого: что сделало день хотя бы на 1% легче?")
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
                    .padding(.bottom, 24)
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
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 16) {
            let controlLabelWidth: CGFloat = 86
            let typeControlsWidth: CGFloat = 206

            capsulePicker(labelWidth: controlLabelWidth, controlWidth: typeControlsWidth)

            HStack(alignment: .center, spacing: 12) {
                Text(selectedType.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: controlLabelWidth, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 10) {
                    ForEach(JournalEntryType.allCases) { type in
                        JournalTypeIconChip(
                            type: type,
                            isSelected: selectedType == type
                        ) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedType = type
                            }
                        }
                    }
                }
                .frame(width: typeControlsWidth, alignment: .leading)
            }

            promptView

            TextField("Что ты сегодня заметил?", text: $text, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.plain)
                .padding(16)
                .background(
                    isTextEditorFocused ? .white.opacity(0.16) : .white.opacity(0.11),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isTextEditorFocused ? .white.opacity(0.24) : .white.opacity(0.08), lineWidth: 1)
                )
                .foregroundStyle(.white)
                .focused($isTextEditorFocused)

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

    private var introHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Дневник знаков")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Записывай следы вокруг желаний")
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
                    Text("Когда желание названо, вокруг него начинают появляться следы: странные совпадения, возвращающиеся мысли и сны. Записывай то, что происходит вокруг и внутри тебя, и маленькие шаги, которые ты сделал навстречу желанию. Иногда именно так путь становится видимым.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func capsulePicker(labelWidth: CGFloat, controlWidth: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Капсула")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: labelWidth, alignment: .leading)
                .lineLimit(1)

            Menu {
                Button("Без привязки") {
                    selectedCapsuleID = nil
                }

                ForEach(activeCapsules) { capsule in
                    Button {
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

                    Text(selectedCapsule?.title ?? "Без привязки")
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
                .frame(width: controlWidth, alignment: .leading)
                .background(.white.opacity(0.11), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.13), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(activeCapsules.isEmpty)
        }
    }

    private func addEntry() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation {
            modelContext.insert(JournalEntry(capsuleID: selectedCapsule?.id, type: selectedType, text: trimmed))
            text = ""
            isTextEditorFocused = false
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

            Text(isLoadingAIPrompt ? "Ищу подсказку вокруг этого желания..." : currentPrompt)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    @MainActor
    private func refreshAIPrompt() async {
        aiPrompt = nil

        guard aiWishPromptService.isAvailable, let selectedCapsule else {
            isLoadingAIPrompt = false
            return
        }

        isLoadingAIPrompt = true
        do {
            let prompt = try await aiWishPromptService.prompt(
                for: selectedType,
                capsule: selectedCapsule,
                recentEntries: selectedCapsuleEntries
            )
            try Task.checkCancellation()
            aiPrompt = prompt
        } catch is CancellationError {
            return
        } catch {
            AppLog.ai.error("OpenAI journal prompt fallback: \(error.localizedDescription, privacy: .public)")
            aiPrompt = nil
        }

        isLoadingAIPrompt = false
    }
}

private struct JournalEntryDaySection: Identifiable {
    let date: Date
    let entries: [JournalEntry]

    var id: Date { date }

    var title: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Сегодня"
        }

        if calendar.isDateInYesterday(date) {
            return "Вчера"
        }

        return date.formatted(date: .long, time: .omitted)
    }
}
