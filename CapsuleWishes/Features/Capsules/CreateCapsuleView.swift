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
    @State private var title = ""
    @State private var intention = ""
    @State private var feeling = ""
    @State private var openAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var selectedColor = CapsulePalette.options[0]
    @State private var selectedSymbol = "sparkles"
    @State private var sealingStage: WishSealingStage = .idle
    @State private var sealingInspiration: WishSealingInspiration?
    @State private var sealingTask: Task<Void, Never>?
    @FocusState private var isTextInputFocused: Bool

    private let futureLetterService = FutureLetterService()
    private let sealingInspirationService = WishSealingInspirationService()
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
                            sealCapsule()
                        } label: {
                            Label(sealingStage.isActive ? "Капсула запечатывается" : "Запечатать капсулу", systemImage: "lock.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryCapsuleButtonStyle())
                        .disabled(!canCreate || sealingStage.isActive)
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                    .opacity(sealingStage.isActive ? 0.16 : 1)
                    .scaleEffect(sealingStage.isActive ? 0.97 : 1)
                    .blur(radius: sealingStage.isActive ? 8 : 0)
                }

                if sealingStage.isActive {
                    WishSealingOverlay(
                        stage: sealingStage,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        colorHex: selectedColor.hex,
                        symbol: selectedSymbol,
                        inspiration: sealingInspiration
                    ) {
                        dismiss()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isTextInputFocused = false
            }
            .animation(.smooth(duration: 0.42), value: sealingStage)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        sealingTask?.cancel()
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .disabled(sealingStage.isActive && sealingStage != .complete)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingKeyboardDoneBar(isVisible: isTextInputFocused) {
                    isTextInputFocused = false
                }
            }
            .onDisappear {
                sealingTask?.cancel()
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

    private func sealCapsule() {
        guard canCreate, !sealingStage.isActive else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFeeling = feeling.trimmingCharacters(in: .whitespacesAndNewlines)

        isTextInputFocused = false
        sealingInspiration = nil
        sealingStage = .gathering
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

            let inspiration = await sealingInspirationService.inspiration(
                title: trimmedTitle,
                intention: trimmedIntention,
                feeling: trimmedFeeling,
                context: sealingContext(
                    title: trimmedTitle,
                    intention: trimmedIntention
                )
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                sealingInspiration = inspiration
                createCapsule(
                    title: trimmedTitle,
                    intention: trimmedIntention,
                    feeling: trimmedFeeling,
                    planCheckpoints: inspiration.checkpoints
                )

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
        planCheckpoints: [WishPlanCheckpoint]
    ) {
        let capsule = WishCapsule(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            intentionText: intention.trimmingCharacters(in: .whitespacesAndNewlines),
            desiredFeeling: feeling.trimmingCharacters(in: .whitespacesAndNewlines),
            openAt: openAt,
            colorHex: selectedColor.hex,
            symbol: selectedSymbol
        )

        modelContext.insert(capsule)

        if !planCheckpoints.isEmpty {
            CapsuleNotificationScheduler.shared.schedulePlanCheckpoints(
                planCheckpoints,
                for: capsule,
                modelContext: modelContext
            )
        }

        Task {
            if let draft = await futureLetterService.draft(for: capsule) {
                await MainActor.run {
                    CapsuleNotificationScheduler.shared.scheduleFutureLetter(
                        draft,
                        for: capsule,
                        modelContext: modelContext
                    )
                }
            }

            guard await CapsuleNotificationScheduler.shared.requestAuthorizationIfNeeded() else { return }
            CapsuleNotificationScheduler.shared.scheduleOpeningSignal(for: capsule)
        }
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

private enum WishSealingStage: Equatable {
    case idle
    case gathering
    case launching
    case listening
    case complete

    var isActive: Bool {
        self != .idle
    }

    var statusText: String {
        switch self {
        case .idle:
            return ""
        case .gathering:
            return "Капсула собирает свет вокруг желания"
        case .launching:
            return "Запрос уходит во вселенную"
        case .listening:
            return "OpenAI вслушивается в формулировку"
        case .complete:
            return "Капсула запечатана"
        }
    }
}

private struct WishSealingOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let stage: WishSealingStage
    let title: String
    let colorHex: String
    let symbol: String
    let inspiration: WishSealingInspiration?
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
                        sealingField(in: proxy.size, time: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }

                VStack(spacing: 22) {
                    Spacer(minLength: 30)

                    sealingOrb

                    VStack(spacing: 8) {
                        Text(stage.statusText)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 28)

                    if let inspiration, stage == .complete {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 14) {
                                Text(inspiration.message)
                                    .font(.title3.weight(.medium))
                                    .lineSpacing(5)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.white)

                                if inspiration.isPlan {
                                    planInsight(inspiration)
                                }
                            }
                            .padding(.horizontal, 26)
                        }
                        .frame(maxHeight: 250)
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
                    } else {
                        ProgressView()
                            .tint(.white)
                            .controlSize(.regular)
                            .padding(.top, 6)
                    }

                    Spacer(minLength: 34)
                }
            }
        }
    }

    private func planInsight(_ inspiration: WishSealingInspiration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("В этом желании есть маршрут", systemImage: "point.topleft.down.curvedto.point.bottomright.up.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            if let planSummary = inspiration.planSummary {
                Text(planSummary)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let recommendation = inspiration.recommendation {
                Text(recommendation)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !inspiration.checkpoints.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(inspiration.checkpoints.enumerated()), id: \.offset) { _, checkpoint in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "bell.badge")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(width: 18)

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var sealingOrb: some View {
        let color = Color(hex: colorHex)

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(stage == .complete ? 0.86 : 0.42),
                            color.opacity(stage == .launching ? 0.80 : 0.52),
                            .clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 168
                    )
                )
                .frame(width: 260, height: 260)
                .scaleEffect(glowScale)
                .blur(radius: stage == .complete ? 18 : 10)
                .blendMode(.screen)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.92),
                            color.opacity(0.88),
                            color.opacity(0.22)
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 96
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .shadow(color: color.opacity(0.86), radius: 34)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                }

            Image(systemName: symbol)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white.opacity(stage == .complete ? 1 : 0.88))
                .scaleEffect(stage == .launching ? 1.34 : 1)
        }
        .frame(width: 280, height: 280)
        .scaleEffect(stage == .complete ? 1.05 : 1)
    }

    private var orbSize: CGFloat {
        switch stage {
        case .idle:
            return 126
        case .gathering:
            return 146
        case .launching:
            return 112
        case .listening:
            return 132
        case .complete:
            return 154
        }
    }

    private var glowScale: CGFloat {
        switch stage {
        case .idle:
            return 0.8
        case .gathering:
            return 1.0
        case .launching:
            return 1.65
        case .listening:
            return 1.24
        case .complete:
            return 1.42
        }
    }

    @ViewBuilder
    private func sealingField(in size: CGSize, time: TimeInterval) -> some View {
        ForEach(0..<72, id: \.self) { index in
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
        ForEach(0..<44, id: \.self) { index in
            Circle()
                .fill(.white.opacity(0.20 + random(index, salt: 40) * 0.34))
                .frame(width: 1.8 + random(index, salt: 41) * 3.2)
                .position(
                    x: size.width * random(index, salt: 42),
                    y: size.height * random(index, salt: 43)
                )
        }
    }

    private func particle(index: Int, time: TimeInterval, in size: CGSize) -> SealingParticle {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.34)
        let baseAngle = random(index, salt: 1) * .pi * 2
        let speed = 0.12 + random(index, salt: 2) * 0.34
        let phase = time * speed + random(index, salt: 3) * .pi * 2
        let orbit = CGFloat(52 + random(index, salt: 4) * 168)
        let pulse = CGFloat((sin(phase * 2.4) + 1) * 0.5)
        let launchLift = stage == .launching ? CGFloat(time.truncatingRemainder(dividingBy: 1.8) / 1.8) * -220 : 0
        let listeningDrift = stage == .listening ? CGFloat(sin(phase * 1.8)) * 26 : 0
        let completionBloom = stage == .complete ? CGFloat(1 + pulse * 0.42) : 1

        let position = CGPoint(
            x: center.x + cos(baseAngle + phase) * orbit * completionBloom,
            y: center.y + sin(baseAngle * 0.72 + phase) * orbit * 0.64 + launchLift + listeningDrift
        )
        let opacity = 0.18 + Double(pulse) * 0.58
        let starSize = CGFloat(1.8 + random(index, salt: 5) * 4.8) * (stage == .complete ? 1.18 : 1)

        return SealingParticle(position: position, size: starSize, opacity: opacity)
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
