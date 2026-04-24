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
