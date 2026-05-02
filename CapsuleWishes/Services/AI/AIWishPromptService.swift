//
//  AIWishPromptService.swift
//  CapsuleWishes
//
//  Created by Codex on 25.04.2026.
//

import Foundation

struct AIWishPromptService {
    var isAvailable: Bool {
        OpenAIConfiguration.isAvailable
    }

    func prompt(
        for entryType: JournalEntryType,
        capsule: WishCapsule,
        recentEntries: [JournalEntry]
    ) async throws -> String? {
        guard let configuration = OpenAIConfiguration.current else {
            AppLog.ai.debug("AI backend prompt skipped: client is unavailable")
            return nil
        }

        let client = OpenAIResponsesClient(configuration: configuration)

        let instructions = """
        Ты пишешь короткие подсказки для приложения CapsuleWishes.
        \(AIResponseLanguage.instruction)
        Задача: анализировать последние записи вокруг желания и дать человеку внимательную поддержку без давления.
        Смотри на повторяющиеся мотивы, смену тона, отсутствие движения, маленькие странности, сны и мысли.
        Стиль: бережно, немного мистически, живо и конкретно, без обещаний магического результата.
        Не пиши банальности вроде «все получится», «просто начни», «сделай маленький шаг», «доверься процессу».
        Не подталкивай к действию, если категория записи не «Шаг». Для категории «Шаг» говори о том, что уже произошло или что мягко можно заметить, а не о долге действовать.
        Нельзя: диагнозы, терапевтические утверждения, давление, гарантии исполнения, длинные объяснения.
        Верни только один текст подсказки, без заголовка, списков и кавычек. Максимум 2 предложения.
        """

        let input = AIResponseLanguage.text(
            ru: """
            Категория записи: \(entryType.title)
            Желание: \(capsule.title)
            Текст желания: \(capsule.intentionText)
            Желаемое чувство: \(capsule.desiredFeeling)

            Последние записи вокруг желания:
            \(recentEntries.prefix(6).map { "- \($0.type.title): \($0.text)" }.joined(separator: "\n"))
            """,
            en: """
            Entry category: \(entryType.title)
            Wish: \(capsule.title)
            Wish text: \(capsule.intentionText)
            Desired feeling: \(capsule.desiredFeeling)

            Recent entries around the wish:
            \(recentEntries.prefix(6).map { "- \($0.type.title): \($0.text)" }.joined(separator: "\n"))
            """
        )

        AppLog.ai.debug("AI backend prompt request: type=\(entryType.rawValue, privacy: .public), recentEntries=\(recentEntries.count, privacy: .public)")

        let text = try await client.generateText(
            instructions: instructions,
            input: input,
            maxOutputTokens: 140
        )

        return AITextSanitizer.optional(text)
    }
}
