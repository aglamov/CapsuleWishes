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
    @State private var sealingStage: WishSealingStage = .idle
    @State private var sealingInspiration: WishSealingInspiration?
    @State private var sealingTask: Task<Void, Never>?
    @FocusState private var isTextInputFocused: Bool

    private let futureLetterService = FutureLetterService()
    private let creationAssistantService = WishCreationAssistantService()
    private let sealingInspirationService = WishSealingInspirationService()
    private let symbols = CapsuleCreationSymbol.library

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
                                lines: 2,
                                showsValidation: didAttemptSeal && feeling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
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
                        .disabled(sealingStage.isActive)
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
                        title: generatedTitle.isEmpty ? "Будущая капсула" : generatedTitle,
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
                feelingPromptTask?.cancel()
                beautifyTask?.cancel()
                sealingTask?.cancel()
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

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Цвет капсулы")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 42, maximum: 42), spacing: 14)],
                alignment: .leading,
                spacing: 14
            ) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Символ")
                .font(.headline)
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(symbols) { symbol in
                        Button {
                            selectedSymbol = symbol.systemName
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: symbol.systemName)
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 34)

                                Text(symbol.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                            }
                            .frame(width: 68, height: 64)
                            .background(
                                selectedSymbol == symbol.systemName ? .white.opacity(0.22) : .white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                        .accessibilityLabel(symbol.accessibilityLabel)
                    }
                }
            }
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
        .accessibilityLabel("Переписать желание красивее")
    }

    private func field(
        _ title: String,
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
                            .fixedSize(horizontal: false, vertical: true)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: text, axis: .vertical)
                        .lineLimit(lines...max(lines, 6))
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .focused($isTextInputFocused)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: lines == 1 ? 22 : CGFloat(lines) * 24)

                if let trailingAction {
                    trailingAction
                }
            }
            .padding(14)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(showsValidation ? Color(hex: "FF7A70").opacity(0.95) : .white.opacity(0.12), lineWidth: showsValidation ? 1.4 : 1)
            }

            if showsValidation {
                Text("Заполни это поле, чтобы запечатать капсулу.")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "FFB3AA"))
            }
        }
    }

    private func sealCapsule() {
        guard !sealingStage.isActive else { return }
        didAttemptSeal = true
        guard canCreate else { return }

        let trimmedIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFeeling = feeling.trimmingCharacters(in: .whitespacesAndNewlines)

        isTextInputFocused = false
        sealingInspiration = nil
        generatedTitle = ""
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

            let titleForCapsule = await creationAssistantService.title(
                for: trimmedIntention,
                feeling: trimmedFeeling
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                generatedTitle = titleForCapsule
            }

            let inspiration = await sealingInspirationService.inspiration(
                title: titleForCapsule,
                intention: trimmedIntention,
                feeling: trimmedFeeling,
                context: sealingContext(
                    title: titleForCapsule,
                    intention: trimmedIntention
                )
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                sealingInspiration = inspiration
                createCapsule(
                    title: titleForCapsule,
                    intention: trimmedIntention,
                    feeling: trimmedFeeling,
                    sealingFortuneText: inspiration.sealingText,
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
        sealingFortuneText: String,
        planCheckpoints: [WishPlanCheckpoint]
    ) {
        let capsule = WishCapsule(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            intentionText: intention.trimmingCharacters(in: .whitespacesAndNewlines),
            desiredFeeling: feeling.trimmingCharacters(in: .whitespacesAndNewlines),
            openAt: openAt,
            colorHex: selectedColor.hex,
            symbol: selectedSymbol,
            sealingFortuneText: sealingFortuneText
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
            return "Невидимые механизмы приходят в движение"
        case .complete:
            return "Капсула запечатана"
        }
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
        CapsuleCreationSymbol(systemName: "star", title: "Звезда", meaning: "для желания, которое хочется держать в поле зрения"),
        CapsuleCreationSymbol(systemName: "heart", title: "Сердце", meaning: "для личного и эмоционально важного желания"),
        CapsuleCreationSymbol(systemName: "flag", title: "Флаг", meaning: "для цели, маршрута и выбранного направления"),
        CapsuleCreationSymbol(systemName: "lightbulb", title: "Идея", meaning: "для ясности и нового понимания"),
        CapsuleCreationSymbol(systemName: "circle", title: "Круг", meaning: "для целостности, спокойствия и внутренней опоры"),
        CapsuleCreationSymbol(systemName: "seal", title: "Печать", meaning: "для обещания себе и бережного запечатывания")
    ]
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

                ScrollView(showsIndicators: stage == .complete) {
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
                        } else {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.regular)
                                .padding(.top, 6)
                        }

                        Spacer(minLength: 34)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
    }

    private func signalPreview(_ checkpoints: [WishPlanCheckpoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Капсула оставила знаки на пути", systemImage: "bell.badge")
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
