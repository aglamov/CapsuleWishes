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
    @Query(sort: \WishCapsule.createdAt, order: .reverse) private var capsules: [WishCapsule]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @State private var selectedType: JournalEntryType = .smallJoy
    @State private var selectedCapsuleID: UUID?
    @State private var text = ""
    @FocusState private var isTextEditorFocused: Bool

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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Дневник знаков")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)

                            Text("Фиксируй странности, маленькие радости и мысли. Даже короткая запись может стать ниточкой к настоящему желанию.")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                        }

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
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Тип записи")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    ForEach(JournalEntryType.allCases) { type in
                        JournalTypeIconChip(
                            type: type,
                            isSelected: selectedType == type
                        ) {
                            selectedType = type
                        }
                    }
                }

                Label(selectedType.title, systemImage: selectedType.symbolName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Привязка к капсуле")
                    .font(.headline)
                    .foregroundStyle(.white)

                Picker("Капсула", selection: $selectedCapsuleID) {
                    Text("Без привязки").tag(Optional<UUID>.none)
                    ForEach(capsules) { capsule in
                        Text(capsule.title).tag(Optional(capsule.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            }

            Text(selectedType.prompt)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.66))

            TextField("Запиши одну строку или целую мысль", text: $text, axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.plain)
                .padding(14)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
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
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func addEntry() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation {
            modelContext.insert(JournalEntry(capsuleID: selectedCapsuleID, type: selectedType, text: trimmed))
            text = ""
            isTextEditorFocused = false
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
            return "Сегодня"
        }

        if calendar.isDateInYesterday(date) {
            return "Вчера"
        }

        return date.formatted(date: .long, time: .omitted)
    }
}
