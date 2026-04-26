//
//  AIWishPromptService.swift
//  CapsuleWishes
//
//  Created by Codex on 25.04.2026.
//

import Foundation

struct AIWishPromptService {
    private let client: OpenAIResponsesClient?

    init(configuration: OpenAIConfiguration? = .current) {
        client = configuration.map { OpenAIResponsesClient(configuration: $0) }

        if configuration == nil {
            AppLog.ai.debug("OpenAI prompt disabled: OPENAI_API_KEY is missing")
        } else {
            AppLog.ai.debug("OpenAI prompt enabled")
        }
    }

    var isAvailable: Bool {
        client != nil
    }

    func prompt(
        for entryType: JournalEntryType,
        capsule: WishCapsule,
        recentEntries: [JournalEntry]
    ) async throws -> String? {
        guard let client else {
            AppLog.ai.debug("OpenAI prompt skipped: client is unavailable")
            return nil
        }

        let instructions = """
        Ты пишешь короткие подсказки для приложения CapsuleWishes.
        Задача: помочь человеку заметить жизнь вокруг его желания и мягко сделать шаг к нему.
        Стиль: русский язык, бережно, немного мистически, без обещаний магического результата.
        Нельзя: диагнозы, терапевтические утверждения, давление, гарантии исполнения, длинные объяснения.
        Верни только один текст подсказки, без заголовка, списков и кавычек. Максимум 2 предложения.
        """

        let input = """
        Категория записи: \(entryType.title)
        Желание: \(capsule.title)
        Текст желания: \(capsule.intentionText)
        Желаемое чувство: \(capsule.desiredFeeling)
        

        Последние записи вокруг желания:
        \(recentEntries.prefix(6).map { "- \($0.type.title): \($0.text)" }.joined(separator: "\n"))
        """

        AppLog.ai.debug("OpenAI prompt request: type=\(entryType.rawValue, privacy: .public), recentEntries=\(recentEntries.count, privacy: .public)")

        let text = try await client.generateText(
            instructions: instructions,
            input: input,
            maxOutputTokens: 140
        )

        return sanitized(text)
    }

    private func sanitized(_ text: String) -> String? {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))

        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
