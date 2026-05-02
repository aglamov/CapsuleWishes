//
//  OpeningReflectionService.swift
//  CapsuleWishes
//
//  Created by Codex on 02.05.2026.
//

import Foundation

struct OpeningReflectionService {
    var isAvailable: Bool {
        OpenAIConfiguration.isAvailable
    }

    func reflection(
        for capsule: WishCapsule,
        status: CapsuleStatus,
        entries: [JournalEntry]
    ) async throws -> String? {
        guard let configuration = OpenAIConfiguration.current else { return nil }

        let client = OpenAIResponsesClient(configuration: configuration)
        let instructions = """
        Ты пишешь финальный текст после открытия капсулы желания в приложении CapsuleWishes.
        \(AIResponseLanguage.instruction)
        Пользователь уже выбрал итог желания: сбылось, еще сбывается, сбылось иначе или не сбылось.

        Задача: бережно подвести итог этому желанию, как будто человек вернулся к своему прошлому запросу и теперь закрывает или продолжает его с ясностью.

        Стиль: тепло, взросло, немного поэтично, конкретно к данным пользователя.
        Нельзя: обещать исполнение, давать диагнозы, звучать как терапевт, стыдить, давить, использовать списки, заголовки, Markdown и кавычки.
        Если желание не сбылось, не утешай пустыми фразами и не называй это провалом.
        Если желание еще сбывается, не закрывай его как завершенное.
        Если сбылось иначе, покажи, что смысл мог измениться.

        Верни только один абзац, 45-75 слов.
        """

        let input = AIResponseLanguage.text(
            ru: """
            Итог желания: \(status.title)
            Название желания: \(capsule.title)
            Текст желания: \(capsule.intentionText)
            Желаемое чувство: \(capsule.desiredFeeling)
            Дата запечатывания: \(formatted(capsule.sealedAt))
            Дата открытия: \(formatted(capsule.openedAt ?? Date()))

            Последние записи вокруг желания:
            \(entries.prefix(8).map { "- \($0.type.title): \($0.text)" }.joined(separator: "\n"))
            """,
            en: """
            Wish outcome: \(status.title)
            Wish title: \(capsule.title)
            Wish text: \(capsule.intentionText)
            Desired feeling: \(capsule.desiredFeeling)
            Sealed date: \(formatted(capsule.sealedAt))
            Opening date: \(formatted(capsule.openedAt ?? Date()))

            Recent entries around the wish:
            \(entries.prefix(8).map { "- \($0.type.title): \($0.text)" }.joined(separator: "\n"))
            """
        )

        AppLog.ai.debug("AI backend opening reflection request: status=\(status.rawValue, privacy: .public), entries=\(entries.count, privacy: .public)")

        let text = try await client.generateText(
            instructions: instructions,
            input: input,
            maxOutputTokens: 220
        )

        return AITextSanitizer.optional(text)
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .complete, time: .shortened)
    }
}
