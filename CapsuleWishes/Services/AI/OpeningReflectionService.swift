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

struct CapsuleMeaningReflection {
    let themes: [String]
    let observation: String
    let question: String

    var themeLine: String {
        themes.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct SymbolSuggestion {
    let systemName: String
    let title: String
    let meaning: String
}

struct PersonalMeaningInsight {
    let themes: [String]
    let portrait: String
    let recurringPattern: String
    let innerTension: String
    let hiddenNeed: String
    let observation: String
    let question: String
}

struct MeaningReflectionService {
    var isAvailable: Bool {
        OpenAIConfiguration.isAvailable
    }

    func reflection(for capsule: WishCapsule, entries: [JournalEntry]) async throws -> CapsuleMeaningReflection? {
        guard let configuration = OpenAIConfiguration.current else { return nil }

        let client = OpenAIResponsesClient(configuration: configuration)
        let instructions = """
        Ты создаешь бережное отражение для запечатанной капсулы желания в CapsuleWishes.
        \(AIResponseLanguage.jsonInstruction)
        Ты не советчик и не терапевт. Ты показываешь пользователю его же повторяющиеся слова, чувства и маленькие движения.

        Верни только JSON без Markdown:
        {
          "themes": ["тема 1", "тема 2", "тема 3"],
          "observation": "...",
          "question": "..."
        }

        Ограничения:
        - themes: 2-3 короткие темы, без диагнозов и ярлыков личности.
        - observation: один абзац 45-80 слов.
        - question: один мягкий вопрос.
        - Не используй "на самом деле", "ты боишься", "тебе нужно", "это значит".
        - Используй осторожные формулировки: похоже, возможно, если откликается.
        - Не обещай исполнение желания и не давай план действий.
        """

        let input = AIResponseLanguage.text(
            ru: """
            Капсула: \(capsule.title)
            Желание: \(capsule.intentionText)
            Желаемое чувство: \(capsule.desiredFeeling)

            Записи вокруг желания:
            \(entries.prefix(12).map { "- \($0.type.title): \($0.text)" }.joined(separator: "\n"))
            """,
            en: """
            Capsule: \(capsule.title)
            Wish: \(capsule.intentionText)
            Desired feeling: \(capsule.desiredFeeling)

            Entries around the wish:
            \(entries.prefix(12).map { "- \($0.type.title): \($0.text)" }.joined(separator: "\n"))
            """
        )

        let text = try await client.generateText(
            instructions: instructions,
            input: input,
            maxOutputTokens: 340
        )

        guard let response = MeaningReflectionAIResponse.decode(from: text),
              let observation = AITextSanitizer.optional(response.observation),
              let question = AITextSanitizer.optional(response.question)
        else { return nil }

        let themes = response.themes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)

        return CapsuleMeaningReflection(themes: Array(themes), observation: observation, question: question)
    }

    func fallbackReflection(for capsule: WishCapsule, entries: [JournalEntry]) -> CapsuleMeaningReflection {
        let themes = localThemes(from: [capsule.title, capsule.intentionText, capsule.desiredFeeling] + entries.map(\.text))
        let primary = themes.first ?? AIResponseLanguage.text(ru: "внутреннее движение", en: "inner movement")
        let secondary = themes.dropFirst().first ?? AIResponseLanguage.text(ru: "внимание", en: "attention")

        return CapsuleMeaningReflection(
            themes: Array(themes.prefix(3)),
            observation: AIResponseLanguage.text(
                ru: "Похоже, вокруг этой капсулы уже собралась не только история результата, но и история внимания. Чаще всего рядом с ней звучит тема \(primary), а рядом появляется \(secondary). Если это откликается, возможно, желание сейчас помогает тебе заметить не только цель, но и то, каким способом ты хочешь к ней приближаться.",
                en: "It looks like this capsule has gathered not only a story about an outcome, but also a story about attention. The theme of \(primary) appears often, with \(secondary) close by. If that resonates, this wish may be helping you notice not only the goal, but the way you want to move toward it."
            ),
            question: AIResponseLanguage.text(
                ru: "Что в этом желании уже стало чуть яснее, даже если оно еще не сбылось?",
                en: "What has become a little clearer inside this wish, even if it has not come true yet?"
            )
        )
    }

    private func localThemes(from texts: [String]) -> [String] {
        let text = texts.joined(separator: " ").lowercased()
        let candidates: [(String, [String])] = [
            (AIResponseLanguage.text(ru: "спокойствие", en: "calm"), ["спокой", "тишин", "отдых", "calm", "quiet", "rest"]),
            (AIResponseLanguage.text(ru: "дом", en: "home"), ["дом", "уют", "мест", "home", "place"]),
            (AIResponseLanguage.text(ru: "свобода", en: "freedom"), ["свобод", "дыша", "простор", "freedom", "space"]),
            (AIResponseLanguage.text(ru: "смелость", en: "courage"), ["смел", "страх", "реш", "courage", "brave", "fear"]),
            (AIResponseLanguage.text(ru: "близость", en: "closeness"), ["любов", "близ", "отнош", "серд", "love", "close"]),
            (AIResponseLanguage.text(ru: "творчество", en: "creativity"), ["твор", "проект", "книг", "иде", "create", "project"]),
            (AIResponseLanguage.text(ru: "движение", en: "movement"), ["шаг", "движ", "дорог", "move", "step"])
        ]

        let matches = candidates.compactMap { title, fragments in
            fragments.contains(where: text.contains) ? title : nil
        }

        return matches.isEmpty
            ? [AIResponseLanguage.text(ru: "ясность", en: "clarity"), AIResponseLanguage.text(ru: "внимание", en: "attention")]
            : matches
    }
}

struct SymbolicAssistantService {
    var isAvailable: Bool {
        OpenAIConfiguration.isAvailable
    }

    private let allowedSymbols = [
        "star", "heart", "flag", "lightbulb", "circle", "seal", "key.fill",
        "sparkles", "leaf.fill", "moon.stars", "sun.max", "flame.fill",
        "waveform.path.ecg", "paperplane.fill", "house.fill", "book.closed.fill"
    ]

    func suggestion(for intention: String, feeling: String) async throws -> SymbolSuggestion? {
        guard let configuration = OpenAIConfiguration.current else { return nil }

        let client = OpenAIResponsesClient(configuration: configuration)
        let instructions = """
        Ты предлагаешь личный символ для капсулы желания в CapsuleWishes.
        \(AIResponseLanguage.jsonInstruction)
        Выбери один SF Symbol строго из списка: \(allowedSymbols.joined(separator: ", ")).

        Верни только JSON без Markdown:
        {
          "systemName": "sparkles",
          "title": "Искра",
          "meaning": "для желания, которое начинается с маленького видимого шага"
        }

        Ограничения:
        - title: 1-2 слова.
        - meaning: коротко, тепло, без мистических обещаний.
        - Не добавляй факты, которых нет в желании.
        """

        let input = AIResponseLanguage.text(
            ru: "Желание: \(intention)\nЖелаемое чувство: \(feeling)",
            en: "Wish: \(intention)\nDesired feeling: \(feeling)"
        )

        let text = try await client.generateText(instructions: instructions, input: input, maxOutputTokens: 140)
        guard let response = SymbolSuggestionAIResponse.decode(from: text),
              allowedSymbols.contains(response.systemName)
        else { return nil }

        return SymbolSuggestion(
            systemName: response.systemName,
            title: AITextSanitizer.value(response.title, fallback: fallbackSuggestion(for: intention, feeling: feeling).title),
            meaning: AITextSanitizer.value(response.meaning, fallback: fallbackSuggestion(for: intention, feeling: feeling).meaning)
        )
    }

    func fallbackSuggestion(for intention: String, feeling: String) -> SymbolSuggestion {
        let text = [intention, feeling].joined(separator: " ").lowercased()

        if text.contains("дом") || text.contains("уют") || text.contains("home") {
            return SymbolSuggestion(systemName: "house.fill", title: AIResponseLanguage.text(ru: "Дом", en: "Home"), meaning: AIResponseLanguage.text(ru: "для желания о месте, где внутри становится тише", en: "for a wish about a place that feels quieter inside"))
        }

        if text.contains("смел") || text.contains("страх") || text.contains("brave") {
            return SymbolSuggestion(systemName: "key.fill", title: AIResponseLanguage.text(ru: "Ключ", en: "Key"), meaning: AIResponseLanguage.text(ru: "для желания, которое открывается через смелость", en: "for a wish that opens through courage"))
        }

        if text.contains("проект") || text.contains("твор") || text.contains("idea") {
            return SymbolSuggestion(systemName: "lightbulb", title: AIResponseLanguage.text(ru: "Идея", en: "Idea"), meaning: AIResponseLanguage.text(ru: "для желания, которому нужна ясная искра", en: "for a wish that needs a clear spark"))
        }

        return SymbolSuggestion(systemName: "sparkles", title: AIResponseLanguage.text(ru: "Искра", en: "Spark"), meaning: AIResponseLanguage.text(ru: "для желания, которое начинается с маленького знака", en: "for a wish that begins with a small sign"))
    }
}

struct PersonalMeaningService {
    var isAvailable: Bool {
        OpenAIConfiguration.isAvailable
    }

    func insight(capsules: [WishCapsule], entries: [JournalEntry], symbols: [PersonalSymbol]) async throws -> PersonalMeaningInsight? {
        guard let configuration = OpenAIConfiguration.current else { return nil }

        let client = OpenAIResponsesClient(configuration: configuration)
        let instructions = """
        Ты создаешь слой личного смысла для приложения CapsuleWishes.
        \(AIResponseLanguage.jsonInstruction)
        Это не диагноз и не терапия. Но это должно быть откровеннее, чем просто "возможно, у тебя повторяются темы".
        Пиши как честный, внимательный собеседник, который видит паттерны и может назвать их прямо, без давления и без мистических обещаний.

        Верни только JSON без Markdown:
        {
          "themes": ["тема 1", "тема 2", "тема 3"],
          "portrait": "...",
          "recurringPattern": "...",
          "innerTension": "...",
          "hiddenNeed": "...",
          "observation": "...",
          "question": "..."
        }

        Ограничения:
        - themes: 3 короткие темы.
        - portrait: 1-2 предложения о том, каким человеком пользователь выглядит по своим желаниям, без ярлыков.
        - recurringPattern: 1 предложение о повторяющемся способе желать или избегать.
        - innerTension: 1 предложение о заметном внутреннем противоречии, если оно есть; если нет, назови главный фокус.
        - hiddenNeed: 1 предложение о потребности под желаниями.
        - observation: один более откровенный абзац 70-110 слов.
        - question: один прямой вопрос для саморазмышления.
        - Нельзя: диагнозы, клинические слова, "тебе нужно", "ты обязан", гарантии исполнения.
        - Можно: "похоже", "ты часто", "в твоих записях видно", "твои желания будто".
        """

        let input = AIResponseLanguage.text(
            ru: """
            Капсулы:
            \(capsules.prefix(10).map { "- \($0.title): \($0.intentionText), чувство: \($0.desiredFeeling), итог: \($0.status.title)" }.joined(separator: "\n"))

            Последние записи:
            \(entries.prefix(18).map { "- \($0.type.title): \($0.text)" }.joined(separator: "\n"))

            Личные символы:
            \(symbols.prefix(12).map { "- \($0.title): \($0.meaning)" }.joined(separator: "\n"))
            """,
            en: """
            Capsules:
            \(capsules.prefix(10).map { "- \($0.title): \($0.intentionText), feeling: \($0.desiredFeeling), outcome: \($0.status.title)" }.joined(separator: "\n"))

            Recent entries:
            \(entries.prefix(18).map { "- \($0.type.title): \($0.text)" }.joined(separator: "\n"))

            Personal symbols:
            \(symbols.prefix(12).map { "- \($0.title): \($0.meaning)" }.joined(separator: "\n"))
            """
        )

        let text = try await client.generateText(instructions: instructions, input: input, maxOutputTokens: 380)
        guard let response = MeaningReflectionAIResponse.decode(from: text),
              let observation = AITextSanitizer.optional(response.observation),
              let question = AITextSanitizer.optional(response.question)
        else { return nil }

        return PersonalMeaningInsight(
            themes: Array(response.themes.prefix(3)),
            portrait: AITextSanitizer.value(response.portrait ?? "", fallback: ""),
            recurringPattern: AITextSanitizer.value(response.recurringPattern ?? "", fallback: ""),
            innerTension: AITextSanitizer.value(response.innerTension ?? "", fallback: ""),
            hiddenNeed: AITextSanitizer.value(response.hiddenNeed ?? "", fallback: ""),
            observation: observation,
            question: question
        )
    }
}

private struct MeaningReflectionAIResponse: Decodable {
    let themes: [String]
    let portrait: String?
    let recurringPattern: String?
    let innerTension: String?
    let hiddenNeed: String?
    let observation: String
    let question: String

    static func decode(from text: String) -> MeaningReflectionAIResponse? {
        guard let json = text.extractedJSONObject(),
              let data = json.data(using: .utf8)
        else { return nil }

        return try? JSONDecoder().decode(MeaningReflectionAIResponse.self, from: data)
    }
}

private struct SymbolSuggestionAIResponse: Decodable {
    let systemName: String
    let title: String
    let meaning: String

    static func decode(from text: String) -> SymbolSuggestionAIResponse? {
        guard let json = text.extractedJSONObject(),
              let data = json.data(using: .utf8)
        else { return nil }

        return try? JSONDecoder().decode(SymbolSuggestionAIResponse.self, from: data)
    }
}
