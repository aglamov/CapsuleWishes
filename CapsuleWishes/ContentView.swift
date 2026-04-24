//
//  ContentView.swift
//  CapsuleWishes
//
//  Created by Рамиль Аглямов on 06.02.2025.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CapsuleListView()
                .tabItem {
                    Label("Капсулы", systemImage: "sparkles")
                }

            JournalView()
                .tabItem {
                    Label("Дневник", systemImage: "book.closed")
                }
        }
        .tint(.white)
    }
}

struct CapsuleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishCapsule.createdAt, order: .reverse) private var capsules: [WishCapsule]
    @State private var isCreatingCapsule = false

    var body: some View {
        NavigationStack {
            ZStack {
                NightSkyBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        if capsules.isEmpty {
                            EmptyCapsulesView {
                                isCreatingCapsule = true
                            }
                        } else {
                            VStack(spacing: 16) {
                                ForEach(capsules) { capsule in
                                    NavigationLink {
                                        CapsuleDetailView(capsule: capsule)
                                    } label: {
                                        CapsuleCard(capsule: capsule)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Капсула желания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreatingCapsule = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Создать капсулу")
                }
            }
            .sheet(isPresented: $isCreatingCapsule) {
                CreateCapsuleView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Тихое место для желаний")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Запечатай намерение, замечай странности и маленькие радости, а потом открой капсулу в нужный день.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }
}

struct CapsuleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry]
    @Bindable var capsule: WishCapsule
    @State private var selectedEntryType: JournalEntryType = .sign
    @State private var entryText = ""
    @FocusState private var isEntryFieldFocused: Bool

    private var entries: [JournalEntry] {
        allEntries.filter { $0.capsuleID == capsule.id }
    }

    var body: some View {
        ZStack {
            NightSkyBackground()

            ScrollView {
                VStack(spacing: 22) {
                    CapsuleOrbView(capsule: capsule, size: 168)
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

                    WishTextPanel(capsule: capsule)

                    if capsule.isReadyToOpen {
                        OpeningPanel(capsule: capsule)
                    }

                    addEntryPanel

                    entriesPanel
                }
                .padding(20)
                .padding(.bottom, 32)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isEntryFieldFocused = false
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingKeyboardDoneBar(isVisible: isEntryFieldFocused) {
                isEntryFieldFocused = false
            }
        }
    }

    private var statusText: String {
        if capsule.isReadyToOpen {
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
}

struct CreateCapsuleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var intention = ""
    @State private var feeling = ""
    @State private var openAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var selectedColor = CapsulePalette.options[0]
    @State private var selectedSymbol = "sparkles"
    @FocusState private var isTextInputFocused: Bool

    private let symbols = ["sparkles", "moon.stars", "heart", "star", "sun.max", "leaf", "flame"]

    var body: some View {
        NavigationStack {
            ZStack {
                NightSkyBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Новая капсула")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)

                            Text("Не обязательно формулировать идеально. Иногда желание становится яснее уже после того, как его бережно записали.")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 14) {
                            field("Название", text: $title, prompt: "Например: дом у моря")
                            field("Желание", text: $intention, prompt: "Чего ты хочешь на самом деле?", lines: 4)
                            field("Чувство", text: $feeling, prompt: "Что ты хочешь почувствовать?", lines: 2)
                        }

                        DatePicker("Открыть капсулу", selection: $openAt, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))

                        colorPicker
                        symbolPicker

                        Button {
                            createCapsule()
                        } label: {
                            Label("Запечатать капсулу", systemImage: "lock.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryCapsuleButtonStyle())
                        .disabled(!canCreate)
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isTextInputFocused = false
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingKeyboardDoneBar(isVisible: isTextInputFocused) {
                    isTextInputFocused = false
                }
            }
        }
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Цвет капсулы")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                ForEach(CapsulePalette.options, id: \.hex) { option in
                    Button {
                        selectedColor = option
                    } label: {
                        Circle()
                            .fill(Color(hex: option.hex))
                            .frame(width: 42, height: 42)
                            .overlay {
                                if selectedColor.hex == option.hex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .shadow(color: Color(hex: option.hex).opacity(0.65), radius: 12)
                    }
                    .accessibilityLabel(option.name)
                }
            }
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Символ")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                ForEach(symbols, id: \.self) { symbol in
                    Button {
                        selectedSymbol = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                selectedSymbol == symbol ? .white.opacity(0.22) : .white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                    }
                }
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, prompt: String, lines: Int = 1) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(lines...max(lines, 6))
                .textFieldStyle(.plain)
                .padding(14)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
                .focused($isTextInputFocused)
        }
    }

    private func createCapsule() {
        let capsule = WishCapsule(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            intentionText: intention.trimmingCharacters(in: .whitespacesAndNewlines),
            desiredFeeling: feeling.trimmingCharacters(in: .whitespacesAndNewlines),
            openAt: openAt,
            colorHex: selectedColor.hex,
            symbol: selectedSymbol
        )

        withAnimation {
            modelContext.insert(capsule)
            isTextInputFocused = false
            dismiss()
        }
    }
}

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishCapsule.createdAt, order: .reverse) private var capsules: [WishCapsule]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @State private var selectedType: JournalEntryType = .smallJoy
    @State private var selectedCapsuleID: UUID?
    @State private var text = ""
    @FocusState private var isTextEditorFocused: Bool

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
                                ForEach(entries) { entry in
                                    JournalEntryRow(entry: entry)
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

struct JournalTypeIconChip: View {
    let type: JournalEntryType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: type.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
            .background(
                isSelected ? .white.opacity(0.22) : .white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? .white.opacity(0.28) : .white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FloatingKeyboardDoneBar: View {
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        if isVisible {
            HStack {
                Spacer()

                Button("Готово", action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.12), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(.clear)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct OpeningPanel: View {
    @Bindable var capsule: WishCapsule

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Время открыть")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Посмотри на исходное желание и выбери, что с ним произошло. Иногда исполнение выглядит иначе, чем мы представляли.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                outcomeButton(.fulfilled, title: "Сбылось")
                outcomeButton(.unfolding, title: "Сбывается")
                outcomeButton(.changed, title: "Изменилось")
                outcomeButton(.released, title: "Отпустить")
            }
        }
        .padding(18)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func outcomeButton(_ status: CapsuleStatus, title: String) -> some View {
        Button {
            withAnimation {
                capsule.status = status
                capsule.openedAt = Date()
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryCapsuleButtonStyle())
    }
}

struct WishTextPanel: View {
    let capsule: WishCapsule

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Желание", systemImage: "lock.open")
                .font(.headline)
                .foregroundStyle(.white)

            Text(capsule.intentionText)
                .font(.body)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            if !capsule.desiredFeeling.isEmpty {
                Divider()
                    .overlay(.white.opacity(0.18))

                Label(capsule.desiredFeeling, systemImage: "heart")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.74))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct CapsuleCard: View {
    let capsule: WishCapsule

    var body: some View {
        HStack(spacing: 16) {
            CapsuleOrbView(capsule: capsule, size: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text(capsule.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.44))
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var subtitle: String {
        if capsule.isReadyToOpen {
            return "Готова открыться"
        }

        if capsule.status != .sealed {
            return capsule.status.title
        }

        return "Открытие: \(capsule.openAt.formatted(date: .abbreviated, time: .omitted))"
    }
}

struct CapsuleOrbView: View {
    let capsule: WishCapsule
    let size: CGFloat

    var body: some View {
        let color = Color(hex: capsule.colorHex)

        ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: size * 1.25, height: size * 1.25)
                .blur(radius: size * 0.12)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(capsule.isReadyToOpen ? 0.90 : 0.72),
                            color.opacity(0.82),
                            color.opacity(0.18)
                        ],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: size * 0.62
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: color.opacity(capsule.isReadyToOpen ? 0.95 : 0.55), radius: size * 0.22)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.36), lineWidth: 1)
                }

            Image(systemName: capsule.symbol)
                .font(.system(size: size * 0.30, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
        }
        .accessibilityLabel(capsule.title)
    }
}

struct JournalEntryRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.type.symbolName)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(entry.type.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                }

                Text(entry.text)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct EmptyCapsulesView: View {
    let createAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.86))

            Text("Первая капсула ждет")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Начни с одного желания. Не самого правильного, а самого живого.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.68))

            Button {
                createAction()
            } label: {
                Label("Создать капсулу", systemImage: "plus")
            }
            .buttonStyle(PrimaryCapsuleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct NightSkyBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.07, blue: 0.16),
                Color(red: 0.13, green: 0.12, blue: 0.28),
                Color(red: 0.04, green: 0.12, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            SparkleField()
        }
    }
}

struct SparkleField: View {
    private let sparkles: [CGPoint] = [
        CGPoint(x: 0.12, y: 0.14),
        CGPoint(x: 0.28, y: 0.32),
        CGPoint(x: 0.76, y: 0.18),
        CGPoint(x: 0.88, y: 0.42),
        CGPoint(x: 0.18, y: 0.68),
        CGPoint(x: 0.52, y: 0.78),
        CGPoint(x: 0.72, y: 0.62),
        CGPoint(x: 0.38, y: 0.12)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(sparkles.indices, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(index.isMultiple(of: 2) ? 0.34 : 0.18))
                    .frame(width: index.isMultiple(of: 3) ? 4 : 2, height: index.isMultiple(of: 3) ? 4 : 2)
                    .position(
                        x: proxy.size.width * sparkles[index].x,
                        y: proxy.size.height * sparkles[index].y
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.45, green: 0.70, blue: 1.0),
                        Color(red: 0.73, green: 0.54, blue: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct SecondaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .background(.white.opacity(configuration.isPressed ? 0.22 : 0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}

enum CapsulePalette {
    static let options: [(name: String, hex: String)] = [
        ("Лунный голубой", "76D6FF"),
        ("Теплое золото", "F2C46D"),
        ("Розовое сияние", "F58AB8"),
        ("Тихая мята", "7EE0B3"),
        ("Сиреневый свет", "A78BFA")
    ]
}

#Preview {
    ContentView()
        .modelContainer(for: [WishCapsule.self, JournalEntry.self], inMemory: true)
}
