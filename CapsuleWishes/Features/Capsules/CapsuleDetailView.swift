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
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry]
    @Bindable var capsule: WishCapsule
    @State private var selectedEntryType: JournalEntryType = .sign
    @State private var entryText = ""
    @State private var didEnter = false
    @State private var isShowingDeleteConfirmation = false
    @State private var openingStage: CapsuleOpeningStage = .idle
    @State private var openingTask: Task<Void, Never>?
    @FocusState private var isEntryFieldFocused: Bool

    private var entries: [JournalEntry] {
        allEntries.filter { $0.capsuleID == capsule.id }
    }

    private var isOpeningPending: Bool {
        openingStage != .idle
    }

    private var freezesCapsuleMotion: Bool {
        openingStage == .settled
    }

    private var focusOpacity: Double {
        freezesCapsuleMotion ? 0.22 : 1
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
                            freezesMotion: freezesCapsuleMotion
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

            Text(selectedEntryType.prompt)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.66))

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

    private func openCapsule(as status: CapsuleStatus, scrollProxy: ScrollViewProxy) {
        guard !isOpeningPending else { return }
        isEntryFieldFocused = false

        if reduceMotion {
            capsule.status = status
            capsule.openedAt = Date()
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
                withAnimation(.easeInOut(duration: 0.44)) {
                    openingStage = .settled
                }
            }

            try? await Task.sleep(for: .milliseconds(520))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                var transaction = Transaction()
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    capsule.status = status
                    capsule.openedAt = Date()
                }
            }

            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                openingStage = .idle
                openingTask = nil
            }
        }
    }

    private func deleteCapsule() {
        openingTask?.cancel()
        openingTask = nil
        isEntryFieldFocused = false

        let capsuleID = capsule.id
        allEntries
            .filter { $0.capsuleID == capsuleID }
            .forEach(modelContext.delete)

        modelContext.delete(capsule)
        dismiss()
    }
}

private enum CapsuleOpeningStage {
    case idle
    case centering
    case settled
}
