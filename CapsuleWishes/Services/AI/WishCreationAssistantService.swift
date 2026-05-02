//
//  WishCreationAssistantService.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import Foundation

struct WishCreationAssistantService {
    var isAvailable: Bool {
        OpenAIConfiguration.isAvailable
    }

    func wishPrompt() async -> String {
        guard let configuration = OpenAIConfiguration.current else {
            return Self.fallbackWishPrompts.randomElement() ?? Self.defaultWishPrompt
        }

        do {
            let client = OpenAIResponsesClient(configuration: configuration)
            let text = try await client.generateText(
                instructions: """
                Ты пишешь плейсхолдер для поля желания в приложении CapsuleWishes.
                \(AIResponseLanguage.instruction)
                Верни одну короткую мягкую фразу, которая помогает человеку записать личное желание.
                Без кавычек, без Markdown, без обращения к ИИ, до 76 символов.
                """,
                input: AIResponseLanguage.text(
                    ru: "Сгенерируй фоновую подсказку для пустого поля желания.",
                    en: "Generate a background prompt for an empty wish field."
                ),
                maxOutputTokens: 60
            )

            return AITextSanitizer.value(text, fallback: Self.defaultWishPrompt)
        } catch {
            AppLog.ai.error("AI backend wish prompt fallback: \(error.localizedDescription, privacy: .public)")
            return Self.fallbackWishPrompts.randomElement() ?? Self.defaultWishPrompt
        }
    }

    func feelingPrompt(for intention: String) async -> String {
        let cleanIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanIntention.isEmpty else { return Self.defaultFeelingPrompt }

        guard let configuration = OpenAIConfiguration.current else {
            return fallbackFeelingPrompt(for: cleanIntention)
        }

        do {
            let client = OpenAIResponsesClient(configuration: configuration)
            let text = try await client.generateText(
                instructions: """
                Ты пишешь плейсхолдер для поля чувства в приложении CapsuleWishes.
                \(AIResponseLanguage.instruction)
                По желанию пользователя предложи фразу, какое чувство он может хотеть испытать.
                Верни одну короткую фразу, без кавычек и Markdown, до 64 символов.
                Не утверждай, что это точный ответ: пусть звучит как мягкая подсказка.
                """,
                input: AIResponseLanguage.text(
                    ru: "Желание пользователя: \(cleanIntention)",
                    en: "User wish: \(cleanIntention)"
                ),
                maxOutputTokens: 70
            )

            return AITextSanitizer.value(text, fallback: fallbackFeelingPrompt(for: cleanIntention))
        } catch {
            AppLog.ai.error("AI backend feeling prompt fallback: \(error.localizedDescription, privacy: .public)")
            return fallbackFeelingPrompt(for: cleanIntention)
        }
    }

    func polishedIntention(_ intention: String, feeling: String) async -> String? {
        let cleanIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanIntention.isEmpty, let configuration = OpenAIConfiguration.current else { return nil }

        do {
            let client = OpenAIResponsesClient(configuration: configuration)
            let text = try await client.generateText(
                instructions: """
                Ты бережно переписываешь желание для приложения CapsuleWishes.
                \(AIResponseLanguage.instruction)
                Сохрани смысл пользователя, не добавляй новых фактов, не обещай исполнение.
                Сделай формулировку ясной, красивой, личной и живой.
                Верни только текст желания, 1-2 предложения, без кавычек и Markdown.
                """,
                input: AIResponseLanguage.text(
                    ru: """
                    Желание: \(cleanIntention)
                    Желаемое чувство: \(feeling.trimmingCharacters(in: .whitespacesAndNewlines))
                    """,
                    en: """
                    Wish: \(cleanIntention)
                    Desired feeling: \(feeling.trimmingCharacters(in: .whitespacesAndNewlines))
                    """
                ),
                maxOutputTokens: 140
            )

            return AITextSanitizer.optional(text)
        } catch {
            AppLog.ai.error("AI backend intention polish failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func polishedObservation(_ observation: String, entryType: JournalEntryType) async -> String? {
        let cleanObservation = observation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanObservation.isEmpty, let configuration = OpenAIConfiguration.current else { return nil }

        do {
            let client = OpenAIResponsesClient(configuration: configuration)
            let text = try await client.generateText(
                instructions: """
                Ты бережно переписываешь дневниковое наблюдение для приложения CapsuleWishes.
                \(AIResponseLanguage.instruction)
                Это не формулировка желания и не совет. Не превращай запись в цель, план, обещание или вывод.
                Сохрани факты, живые детали, сомнения и тон пользователя. Можно связать обрывочные фразы в ясный текст, но нельзя добавлять события, причины или эмоции, которых не было.
                Верни только текст наблюдения, 1-3 коротких предложения, без кавычек и Markdown.
                """,
                input: AIResponseLanguage.text(
                    ru: """
                    Категория наблюдения: \(entryType.title)
                    Текст пользователя: \(cleanObservation)
                    """,
                    en: """
                    Observation category: \(entryType.title)
                    User text: \(cleanObservation)
                    """
                ),
                maxOutputTokens: 170
            )

            return AITextSanitizer.optional(text)
        } catch {
            AppLog.ai.error("AI backend observation polish failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func title(for intention: String, feeling: String) async -> String {
        let fallback = localTitle(for: intention, feeling: feeling)
        guard let configuration = OpenAIConfiguration.current else { return fallback }

        do {
            let client = OpenAIResponsesClient(configuration: configuration)
            let text = try await client.generateText(
                instructions: """
                Ты называешь капсулу желания в приложении CapsuleWishes.
                \(AIResponseLanguage.instruction)
                Верни короткое поэтичное название, строго 2 слова.
                Название должно отражать желание, но не быть громким лозунгом.
                Без кавычек, без Markdown, без эмодзи.
                """,
                input: AIResponseLanguage.text(
                    ru: """
                    Желание: \(intention.trimmingCharacters(in: .whitespacesAndNewlines))
                    Желаемое чувство: \(feeling.trimmingCharacters(in: .whitespacesAndNewlines))
                    """,
                    en: """
                    Wish: \(intention.trimmingCharacters(in: .whitespacesAndNewlines))
                    Desired feeling: \(feeling.trimmingCharacters(in: .whitespacesAndNewlines))
                    """
                ),
                maxOutputTokens: 60
            )

            return twoWordTitle(from: AITextSanitizer.value(text, fallback: fallback), fallback: fallback)
        } catch {
            AppLog.ai.error("AI backend capsule title fallback: \(error.localizedDescription, privacy: .public)")
            return fallback
        }
    }

    private func localTitle(for intention: String, feeling: String) -> String {
        let cleanIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFeeling = feeling.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = [cleanIntention, cleanFeeling].joined(separator: " ").lowercased()

        if text.contains("дом") || text.contains("уют") {
            return AIResponseLanguage.text(ru: "Теплое место", en: "Warm Place")
        }

        if text.contains("работ") || text.contains("дело") || text.contains("проект") {
            return AIResponseLanguage.text(ru: "Живое дело", en: "Living Work")
        }

        if text.contains("любов") || text.contains("отнош") || text.contains("близ") {
            return AIResponseLanguage.text(ru: "Близкое сердце", en: "Close Heart")
        }

        if text.contains("путеше") || text.contains("море") || text.contains("город") {
            return AIResponseLanguage.text(ru: "Своя дорога", en: "Own Road")
        }

        if text.contains("здоров") || text.contains("тело") || text.contains("сил") {
            return AIResponseLanguage.text(ru: "Возвращение силы", en: "Returning Strength")
        }

        if !cleanFeeling.isEmpty {
            return titleFromFeeling(cleanFeeling)
        }

        return AIResponseLanguage.text(ru: "Тихое желание", en: "Quiet Wish")
    }

    private func titleFromFeeling(_ feeling: String) -> String {
        let firstWord = feeling
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "." })
            .first
            .map(String.init)?
            .lowercased()

        guard let firstWord, !firstWord.isEmpty else {
            return AIResponseLanguage.text(ru: "Тихое желание", en: "Quiet Wish")
        }

        return AIResponseLanguage.text(ru: "Капсула \(firstWord)", en: "\(firstWord.capitalized) Capsule")
    }

    private func fallbackFeelingPrompt(for intention: String) -> String {
        let text = intention.lowercased()

        if text.contains("дом") || text.contains("уют") {
            return AIResponseLanguage.text(ru: "Например: безопасность, тепло, свое место", en: "For example: safety, warmth, a place of my own")
        }

        if text.contains("работ") || text.contains("проект") || text.contains("дело") {
            return AIResponseLanguage.text(ru: "Например: ясность, смелость, спокойная уверенность", en: "For example: clarity, courage, calm confidence")
        }

        if text.contains("любов") || text.contains("отнош") || text.contains("близ") {
            return AIResponseLanguage.text(ru: "Например: близость, принятие, живой отклик", en: "For example: closeness, acceptance, a living response")
        }

        if text.contains("путеше") || text.contains("море") || text.contains("город") {
            return AIResponseLanguage.text(ru: "Например: свобода, удивление, простор", en: "For example: freedom, wonder, spaciousness")
        }

        return Self.defaultFeelingPrompt
    }

    private func twoWordTitle(from title: String, fallback: String) -> String {
        let words = title
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map { word in
                String(word).trimmingCharacters(in: CharacterSet(charactersIn: "\"“”.,:;!?"))
            }
            .filter { !$0.isEmpty }

        guard words.count >= 2 else { return fallback }
        return words.prefix(2).joined(separator: " ")
    }

    private static var defaultWishPrompt: String {
        AIResponseLanguage.text(
            ru: "Например: хочу почувствовать, что моя жизнь снова принадлежит мне",
            en: "For example: I want to feel that my life belongs to me again"
        )
    }

    private static var defaultFeelingPrompt: String {
        AIResponseLanguage.text(
            ru: "Например: свободу, нежность, уверенность или покой",
            en: "For example: freedom, tenderness, confidence, or peace"
        )
    }

    private static var fallbackWishPrompts: [String] {
        [
            AIResponseLanguage.text(ru: "Например: хочу мягко приблизиться к тому, что давно зовет", en: "For example: I want to gently move closer to what has long been calling"),
            AIResponseLanguage.text(ru: "Запиши желание так, как оно звучит внутри, без идеальной формы", en: "Write the wish as it sounds inside, without making it perfect"),
            AIResponseLanguage.text(ru: "Например: хочу выбрать путь, от которого внутри становится светлее", en: "For example: I want to choose a path that makes things feel lighter inside"),
            AIResponseLanguage.text(ru: "Что ты хочешь сохранить для будущего себя?", en: "What do you want to save for your future self?")
        ]
    }
}
