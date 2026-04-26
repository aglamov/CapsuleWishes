//
//  WishCreationAssistantService.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import Foundation

struct WishCreationAssistantService {
    var isAvailable: Bool {
        OpenAIConfiguration.current != nil
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
                Верни одну короткую мягкую фразу на русском, которая помогает человеку записать личное желание.
                Без кавычек, без Markdown, без обращения к ИИ, до 76 символов.
                """,
                input: "Сгенерируй фоновую подсказку для пустого поля желания.",
                maxOutputTokens: 60
            )

            return sanitized(text, fallback: Self.defaultWishPrompt)
        } catch {
            AppLog.ai.error("OpenAI wish prompt fallback: \(error.localizedDescription, privacy: .public)")
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
                По желанию пользователя предложи фразу, какое чувство он может хотеть испытать.
                Верни одну короткую фразу на русском, без кавычек и Markdown, до 64 символов.
                Не утверждай, что это точный ответ: пусть звучит как мягкая подсказка.
                """,
                input: "Желание пользователя: \(cleanIntention)",
                maxOutputTokens: 70
            )

            return sanitized(text, fallback: fallbackFeelingPrompt(for: cleanIntention))
        } catch {
            AppLog.ai.error("OpenAI feeling prompt fallback: \(error.localizedDescription, privacy: .public)")
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
                Сохрани смысл пользователя, не добавляй новых фактов, не обещай исполнение.
                Сделай формулировку ясной, красивой, личной и живой.
                Верни только текст желания на русском, 1-2 предложения, без кавычек и Markdown.
                """,
                input: """
                Желание: \(cleanIntention)
                Желаемое чувство: \(feeling.trimmingCharacters(in: .whitespacesAndNewlines))
                """,
                maxOutputTokens: 140
            )

            return sanitizedOptional(text)
        } catch {
            AppLog.ai.error("OpenAI intention polish failed: \(error.localizedDescription, privacy: .public)")
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
                Верни короткое поэтичное название на русском, строго 2 слова.
                Название должно отражать желание, но не быть громким лозунгом.
                Без кавычек, без Markdown, без эмодзи.
                """,
                input: """
                Желание: \(intention.trimmingCharacters(in: .whitespacesAndNewlines))
                Желаемое чувство: \(feeling.trimmingCharacters(in: .whitespacesAndNewlines))
                """,
                maxOutputTokens: 60
            )

            return twoWordTitle(from: sanitized(text, fallback: fallback), fallback: fallback)
        } catch {
            AppLog.ai.error("OpenAI capsule title fallback: \(error.localizedDescription, privacy: .public)")
            return fallback
        }
    }

    private func localTitle(for intention: String, feeling: String) -> String {
        let cleanIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFeeling = feeling.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = [cleanIntention, cleanFeeling].joined(separator: " ").lowercased()

        if text.contains("дом") || text.contains("уют") {
            return "Теплое место"
        }

        if text.contains("работ") || text.contains("дело") || text.contains("проект") {
            return "Живое дело"
        }

        if text.contains("любов") || text.contains("отнош") || text.contains("близ") {
            return "Близкое сердце"
        }

        if text.contains("путеше") || text.contains("море") || text.contains("город") {
            return "Своя дорога"
        }

        if text.contains("здоров") || text.contains("тело") || text.contains("сил") {
            return "Возвращение силы"
        }

        if !cleanFeeling.isEmpty {
            return titleFromFeeling(cleanFeeling)
        }

        return "Тихое желание"
    }

    private func titleFromFeeling(_ feeling: String) -> String {
        let firstWord = feeling
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "." })
            .first
            .map(String.init)?
            .lowercased()

        guard let firstWord, !firstWord.isEmpty else {
            return "Тихое желание"
        }

        return "Капсула \(firstWord)"
    }

    private func fallbackFeelingPrompt(for intention: String) -> String {
        let text = intention.lowercased()

        if text.contains("дом") || text.contains("уют") {
            return "Например: безопасность, тепло, свое место"
        }

        if text.contains("работ") || text.contains("проект") || text.contains("дело") {
            return "Например: ясность, смелость, спокойная уверенность"
        }

        if text.contains("любов") || text.contains("отнош") || text.contains("близ") {
            return "Например: близость, принятие, живой отклик"
        }

        if text.contains("путеше") || text.contains("море") || text.contains("город") {
            return "Например: свобода, удивление, простор"
        }

        return Self.defaultFeelingPrompt
    }

    private func sanitized(_ text: String, fallback: String) -> String {
        sanitizedOptional(text) ?? fallback
    }

    private func sanitizedOptional(_ text: String) -> String? {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))

        guard !trimmed.isEmpty else { return nil }
        return trimmed
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

    private static let defaultWishPrompt = "Например: хочу почувствовать, что моя жизнь снова принадлежит мне"
    private static let defaultFeelingPrompt = "Например: свободу, нежность, уверенность или покой"

    private static let fallbackWishPrompts = [
        "Например: хочу мягко приблизиться к тому, что давно зовет",
        "Запиши желание так, как оно звучит внутри, без идеальной формы",
        "Например: хочу выбрать путь, от которого внутри становится светлее",
        "Что ты хочешь сохранить для будущего себя?"
    ]
}
