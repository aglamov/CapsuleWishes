//
//  WishSealingInspirationService.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import Foundation

struct WishSealingInspiration {
    let message: String
    let planSummary: String?
    let recommendation: String?
    let checkpoints: [WishPlanCheckpoint]

    var fortuneText: String {
        [message, planSummary, recommendation]
            .compactMap { $0 }
            .joined(separator: "\n\n")
    }

    var sealingText: String {
        guard !checkpoints.isEmpty else { return fortuneText }

        let checkpointText = checkpoints
            .map { "\($0.title)\n\($0.message)" }
            .joined(separator: "\n\n")

        return [fortuneText, "\(AIResponseLanguage.text(ru: "Капсула оставила знаки на пути", en: "The capsule left signs along the way")):\n\n\(checkpointText)"]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    var isPlan: Bool {
        planSummary != nil || recommendation != nil || !checkpoints.isEmpty
    }
}

struct WishPlanCheckpoint {
    let title: String
    let message: String
    let afterDays: Int
}

struct WishSealingContext {
    let relatedWishes: [RelatedWishContext]
    let journalEntries: [JournalEntryContext]
}

struct RelatedWishContext {
    let title: String
    let intention: String
    let feeling: String
    let status: String
}

struct JournalEntryContext {
    let type: String
    let text: String
}

struct WishSealingInspirationService {
    func inspiration(
        title: String,
        intention: String,
        feeling: String,
        openAt: Date,
        context: WishSealingContext = WishSealingContext(relatedWishes: [], journalEntries: [])
    ) async -> WishSealingInspiration {
        let calendar = Calendar.current
        let daysUntilOpen = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: openAt)
        ).day ?? 0

        if let configuration = OpenAIConfiguration.current {
            do {
                let client = OpenAIResponsesClient(configuration: configuration)
                let text = try await aiInspiration(
                    title: title,
                    intention: intention,
                    feeling: feeling,
                    openAt: openAt,
                    daysUntilOpen: daysUntilOpen,
                    context: context,
                    client: client
                )

                if let response = WishSealingAIResponse.decode(from: text),
                   let inspiration = inspiration(from: response, daysUntilOpen: daysUntilOpen) {
                    AppLog.ai.debug("Wish sealing inspiration created by AI backend")
                    return inspiration
                }
            } catch {
                AppLog.ai.error("AI backend sealing inspiration fallback: \(error.localizedDescription, privacy: .public)")
            }
        }

        AppLog.ai.debug("Wish sealing inspiration created by local fallback")
        return fallbackInspiration(title: title, intention: intention, feeling: feeling, daysUntilOpen: daysUntilOpen)
    }

    private func aiInspiration(
        title: String,
        intention: String,
        feeling: String,
        openAt: Date,
        daysUntilOpen: Int,
        context: WishSealingContext,
        client: OpenAIResponsesClient
    ) async throws -> String {
        let instructions = """
        Ты анализируешь желание после запечатывания капсулы в приложении CapsuleWishes.
        \(AIResponseLanguage.jsonInstruction)
        Сначала определи, выглядит ли желание как реализуемый план: есть ли в тексте конкретный результат, шаги, срок, проект, обучение, переезд, запуск, покупка, привычка или действие.
        Если это скорее мечта, состояние или образ будущего, не притворяйся, что это план.
        Учитывай срок капсулы: план нужен только если маршрут реально помещается в срок. Завтра почти всегда слишком близко; 3 дня уже могут подойти для маленького конкретного плана.
        Оцени важность желания по тексту и желаемому чувству: личная значимость, эмоциональная ставка, долгий горизонт, изменения в жизни.
        Если это план, дай вдохновляющий вывод и мягкие практичные рекомендации, как реализовать желание без давления.
        Тон похож на доброе предсказание из печенья с предсказанием: кратко, образно, с ощущением знака и маленького следующего шага.
        Также тебе дан мягкий контекст: другие желания пользователя и записи дневника.
        Используй этот контекст только чтобы заметить повторяющиеся темы, опоры, ограничения, энергию и подходящий тон.
        Главное правило: исходное желание ниже всегда остается в фокусе. Не подменяй его другими желаниями, не раскрывай личный контекст явно и не делай выводов, которых нет в тексте.

        Верни только JSON без Markdown:
        {
          "isPlan": true,
          "planFitsTimeframe": true,
          "importanceScore": 0.72,
          "futureLetterNeed": false,
          "message": "...",
          "planSummary": "...",
          "recommendation": "...",
          "checkpoints": [
            { "title": "...", "message": "...", "afterDays": 1 },
            { "title": "...", "message": "...", "afterDays": 3 }
          ]
        }

        Ограничения:
        - message: 1-2 коротких вдохновляющих предложения в стилистике предсказания, мистично и тепло, но без гарантии исполнения.
        - planFitsTimeframe: true только если действия можно реально успеть до открытия капсулы.
        - importanceScore: число от 0 до 1, где 1 — очень личное/важное/трансформационное желание.
        - futureLetterNeed: true если желание выглядит важным и письмо из будущего может поддержать на длинной дистанции; для срока меньше 7 дней всегда false.
        - planSummary: только если isPlan=true и planFitsTimeframe=true, 1 короткое образное предложение с сутью маршрута.
        - recommendation: только если isPlan=true и planFitsTimeframe=true, 1 короткое предложение с реалистичным следующим шагом.
        - checkpoints: только если isPlan=true, planFitsTimeframe=true и до открытия минимум 3 дня, 1-3 ключевые точки для пушей.
        - afterDays: 1, 3, 7, 14 или 30.
        - afterDays должен быть раньше дня открытия; не ставь чекпоинт впритык к открытию.
        - title для пуша до 36 символов, message до 110 символов.
        - без коучинговых клише, списков в строках и медицинских/финансовых/юридических советов.
        """

        let input = AIResponseLanguage.text(
            ru: """
            Название желания: \(title)
            Текст желания: \(intention)
            Желаемое чувство: \(feeling)
            Дата открытия: \(openAt.formatted(date: .complete, time: .omitted))
            Дней до открытия: \(daysUntilOpen)

            Мягкий контекст других желаний:
            \(formattedRelatedWishes(context.relatedWishes))

            Мягкий контекст дневника:
            \(formattedJournalEntries(context.journalEntries))
            """,
            en: """
            Wish title: \(title)
            Wish text: \(intention)
            Desired feeling: \(feeling)
            Opening date: \(openAt.formatted(date: .complete, time: .omitted))
            Days until opening: \(daysUntilOpen)

            Gentle context from other wishes:
            \(formattedRelatedWishes(context.relatedWishes))

            Gentle journal context:
            \(formattedJournalEntries(context.journalEntries))
            """
        )

        AppLog.ai.debug("Wish sealing inspiration AI backend request")

        return try await client.generateText(
            instructions: instructions,
            input: input,
            maxOutputTokens: 420
        )
    }

    private func inspiration(from response: WishSealingAIResponse, daysUntilOpen: Int) -> WishSealingInspiration? {
        guard let message = AITextSanitizer.optional(response.message) else { return nil }

        let planFitsTimeframe = response.planFitsTimeframe ?? response.isPlan
        let canUseCheckpoints = response.isPlan && planFitsTimeframe && daysUntilOpen >= 3
        let checkpoints = canUseCheckpoints
            ? response.checkpoints.prefix(3).compactMap { checkpoint($0, daysUntilOpen: daysUntilOpen) }
            : []

        return WishSealingInspiration(
            message: message,
            planSummary: canUseCheckpoints ? AITextSanitizer.optional(response.planSummary ?? "") : nil,
            recommendation: canUseCheckpoints ? AITextSanitizer.optional(response.recommendation ?? "") : nil,
            checkpoints: checkpoints
        )
    }

    private func checkpoint(_ response: WishSealingAICheckpoint, daysUntilOpen: Int) -> WishPlanCheckpoint? {
        guard let title = AITextSanitizer.optional(response.title),
              let message = AITextSanitizer.optional(response.message)
        else { return nil }

        let allowedDays = [1, 3, 7, 14, 30]
        let afterDays = allowedDays.contains(response.afterDays) ? response.afterDays : 3
        guard afterDays < max(daysUntilOpen - 1, 1) else { return nil }

        return WishPlanCheckpoint(
            title: String(title.prefix(36)),
            message: String(message.prefix(110)),
            afterDays: afterDays
        )
    }

    private func formattedRelatedWishes(_ wishes: [RelatedWishContext]) -> String {
        let lines = wishes.prefix(5).map { wish in
            let feelingLabel = AIResponseLanguage.text(ru: "Желаемое чувство", en: "Desired feeling")
            return "- \(wish.title) [\(wish.status)]: \(wish.intention) \(wish.feeling.isEmpty ? "" : "\(feelingLabel): \(wish.feeling)")"
        }

        return lines.isEmpty ? AIResponseLanguage.text(ru: "Нет других желаний.", en: "No other wishes.") : lines.joined(separator: "\n")
    }

    private func formattedJournalEntries(_ entries: [JournalEntryContext]) -> String {
        let lines = entries.prefix(8).map { entry in
            "- \(entry.type): \(entry.text)"
        }

        return lines.isEmpty ? AIResponseLanguage.text(ru: "Нет записей дневника.", en: "No journal entries.") : lines.joined(separator: "\n")
    }

    private func fallbackInspiration(title: String, intention: String, feeling: String, daysUntilOpen: Int) -> WishSealingInspiration {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFeeling = feeling.trimmingCharacters(in: .whitespacesAndNewlines)

        guard daysUntilOpen >= 3, looksLikePlan(title: title, intention: intention) else {
            let message = cleanFeeling.isEmpty
                ? AIResponseLanguage.text(
                    ru: "Запрос «\(cleanTitle)» уже вышел за пределы этой минуты. Пусть ближайшие дни принесут тебе не громкий знак, а тихую ясность: где сделать первый честный шаг.",
                    en: "The wish \"\(cleanTitle)\" has already moved beyond this minute. May the coming days bring you not a loud sign, but quiet clarity about the first honest step."
                )
                : AIResponseLanguage.text(
                    ru: "Запрос «\(cleanTitle)» отправлен в большое темное небо. Пусть чувство \(cleanFeeling.lowercased()) начнет находить к тебе дорогу через маленькие совпадения, смелые решения и спокойные шаги.",
                    en: "The wish \"\(cleanTitle)\" has been sent into the wide dark sky. May the feeling of \(cleanFeeling.lowercased()) begin finding its way to you through small coincidences, brave choices, and calm steps."
                )
            return WishSealingInspiration(message: message, planSummary: nil, recommendation: nil, checkpoints: [])
        }

        return WishSealingInspiration(
            message: AIResponseLanguage.text(ru: "Там, где желание получает имя, дорога начинает узнавать твои шаги.", en: "Where a wish receives a name, the road begins to recognize your steps."),
            planSummary: AIResponseLanguage.text(ru: "Внутри этого запроса уже спрятан маршрут из нескольких спокойных действий.", en: "A route of several calm actions is already hidden inside this request."),
            recommendation: AIResponseLanguage.text(ru: "Начни с малого знака на земле: выбери один следующий шаг и время для него.", en: "Start with one small sign on the ground: choose the next step and a time for it."),
            checkpoints: [
                WishPlanCheckpoint(title: AIResponseLanguage.text(ru: "Первый шаг", en: "First step"), message: AIResponseLanguage.text(ru: "Выбери одно действие, которое приблизит желание без лишней подготовки.", en: "Choose one action that moves the wish closer without extra preparation."), afterDays: 1),
                WishPlanCheckpoint(title: AIResponseLanguage.text(ru: "Проверка маршрута", en: "Route check"), message: AIResponseLanguage.text(ru: "Посмотри, что уже сдвинулось, и выбери следующий честный шаг.", en: "Notice what has already shifted and choose the next honest step."), afterDays: 3),
                WishPlanCheckpoint(title: AIResponseLanguage.text(ru: "Точка опоры", en: "Anchor point"), message: AIResponseLanguage.text(ru: "Закрепи то, что работает, и убери один лишний источник трения.", en: "Keep what works and remove one unnecessary source of friction."), afterDays: 7),
            ]
        )
    }

    private func looksLikePlan(title: String, intention: String) -> Bool {
        let text = [title, intention].joined(separator: " ").lowercased()
        let planWords = [
            "план", "проект", "запустить", "сделать", "написать", "купить",
            "переехать", "выучить", "пройти", "начать", "закончить", "создать",
            "накопить", "найти", "работ", "бизнес", "курс", "книга"
        ]

        return planWords.contains(where: text.contains)
    }
}

private struct WishSealingAIResponse: Decodable {
    let isPlan: Bool
    let planFitsTimeframe: Bool?
    let importanceScore: Double?
    let futureLetterNeed: Bool?
    let message: String
    let planSummary: String?
    let recommendation: String?
    let checkpoints: [WishSealingAICheckpoint]

    static func decode(from text: String) -> WishSealingAIResponse? {
        guard let json = text.extractedJSONObject(),
              let data = json.data(using: .utf8)
        else { return nil }

        return try? JSONDecoder().decode(WishSealingAIResponse.self, from: data)
    }
}

private struct WishSealingAICheckpoint: Decodable {
    let title: String
    let message: String
    let afterDays: Int
}
