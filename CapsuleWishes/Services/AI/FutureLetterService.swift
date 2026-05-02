//
//  FutureLetterService.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import Foundation

struct FutureLetterDraft {
    let shouldCreate: Bool
    let reason: String
    let title: String
    let letter: String
    let scheduledAt: Date
}

struct FutureLetterService {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func draft(for capsule: WishCapsule) async -> FutureLetterDraft? {
        if let configuration = OpenAIConfiguration.current {
            do {
                let client = OpenAIResponsesClient(configuration: configuration)
                let decision = try await aiDraft(for: capsule, client: client)

                switch decision {
                case .create(let draft):
                    AppLog.ai.debug("Future letter created by AI backend: reason=\(draft.reason, privacy: .public), scheduledAt=\(draft.scheduledAt.formatted(date: .abbreviated, time: .shortened), privacy: .public)")
                    return draft
                case .skip(let reason):
                    AppLog.ai.debug("Future letter skipped by AI backend: reason=\(reason, privacy: .public)")
                    return nil
                case .malformed:
                    AppLog.ai.debug("Future letter AI backend response malformed; using local fallback")
                }
            } catch {
                AppLog.ai.error("AI backend future letter fallback: \(error.localizedDescription, privacy: .public)")
            }
        }

        let draft = fallbackDraft(for: capsule)
        if let draft {
            AppLog.ai.debug("Future letter created by local fallback: reason=\(draft.reason, privacy: .public), scheduledAt=\(draft.scheduledAt.formatted(date: .abbreviated, time: .shortened), privacy: .public)")
        } else {
            AppLog.ai.debug("Future letter skipped by local fallback")
        }
        return draft
    }

    private func aiDraft(for capsule: WishCapsule, client: OpenAIResponsesClient) async throws -> FutureLetterAIDecision {
        let instructions = """
        Ты создаешь письмо из будущего для приложения CapsuleWishes.
        \(AIResponseLanguage.jsonInstruction)
        Это эмоциональное письмо от самого пользователя из момента, где его желание стало реальнее.
        Сначала реши, нужно ли письмо: не создавай его для бытовых задач, коротких errands и маленьких целей на завтра.
        Создавай письмо для личных, эмоциональных, долгосрочных или трансформационных желаний.

        Верни только JSON без Markdown:
        {
          "shouldCreate": true,
          "reason": "short_snake_case",
          "sendAfterDays": 3,
          "letter": "..."
        }

        Ограничения:
        - sendAfterDays: 1, 3, 7 или 14, это количество дней после запечатывания, а не дата открытия.
        - письмо должно прийти заметно раньше даты открытия капсулы.
        - если до открытия меньше недели, выбирай 1.
        - если до открытия меньше трех дней, обычно верни shouldCreate=false, кроме очень эмоциональных желаний.
        - письмо от первого лица будущего "я".
        - 170-260 слов.
        - спокойно, тепло, конкретно, без коучинговых клише.
        - не обещай гарантированный результат буквально.
        - не используй списки, заголовки и кавычки.
        """

        let daysUntilOpen = calendar.dateComponents([.day], from: capsule.sealedAt, to: capsule.openAt).day ?? 0

        let input = AIResponseLanguage.text(
            ru: """
            Название желания: \(capsule.title)
            Текст желания: \(capsule.intentionText)
            Желаемое чувство: \(capsule.desiredFeeling)
            Дата запечатывания: \(formatted(capsule.sealedAt))
            Дата открытия: \(formatted(capsule.openAt))
            Дней до открытия: \(daysUntilOpen)
            Важно: письмо нельзя датировать днем открытия; оно должно прийти раньше и поддержать путь к капсуле.
            """,
            en: """
            Wish title: \(capsule.title)
            Wish text: \(capsule.intentionText)
            Desired feeling: \(capsule.desiredFeeling)
            Sealed date: \(formatted(capsule.sealedAt))
            Opening date: \(formatted(capsule.openAt))
            Days until opening: \(daysUntilOpen)
            Important: the letter cannot be dated on the opening day; it must arrive earlier and support the path toward the capsule.
            """
        )

        AppLog.ai.debug("Future letter AI backend request: daysUntilOpen=\(daysUntilOpen, privacy: .public)")

        let text = try await client.generateText(
            instructions: instructions,
            input: input,
            maxOutputTokens: 520
        )

        AppLog.ai.debug("Future letter AI backend response received")

        guard let response = FutureLetterAIResponse.decode(from: text) else {
            return .malformed
        }

        guard response.shouldCreate else {
            return .skip(response.reason)
        }

        guard let letter = AITextSanitizer.optional(response.letter) else { return .malformed }

        return .create(FutureLetterDraft(
            shouldCreate: true,
            reason: response.reason,
            title: AIResponseLanguage.text(ru: "Тебе письмо из будущего", en: "A letter from your future"),
            letter: letter,
            scheduledAt: scheduledDate(for: capsule, requestedDays: response.sendAfterDays)
        ))
    }

    private func fallbackDraft(for capsule: WishCapsule) -> FutureLetterDraft? {
        guard shouldCreateFallbackLetter(for: capsule) else { return nil }

        let feeling = capsule.desiredFeeling.trimmingCharacters(in: .whitespacesAndNewlines)
        let feelingLine = feeling.isEmpty
            ? AIResponseLanguage.text(ru: "Главное изменилось не снаружи, а внутри: стало тише, яснее и чуть свободнее.", en: "The main change did not happen outside, but inside: things became quieter, clearer, and a little freer.")
            : AIResponseLanguage.text(ru: "Ты хотел почувствовать \(feeling.lowercased()). И знаешь, это чувство действительно стало появляться чаще.", en: "You wanted to feel \(feeling.lowercased()). And you know, that feeling really did start appearing more often.")

        let letter = AIResponseLanguage.text(
            ru: """
            Привет.

            Пишу тебе из момента, о котором ты сейчас только думаешь. Я помню, как это желание звучало в голове: \(capsule.title.lowercased()). Тогда оно могло казаться слишком большим, слишком хрупким или просто далеким.

            Но ты не отложил его в сторону.

            Не все получилось одним рывком. Были дни, когда хотелось снова сделать вид, что это не так важно. Были маленькие шаги, которые почти не ощущались как движение. И все же именно они начали менять траекторию.

            \(feelingLine)

            Сейчас я смотрю назад и вижу не идеальную историю, а человека, который продолжил. Ты не обязан был каждый день быть уверенным. Достаточно было возвращаться к этому желанию и делать следующий честный шаг.

            Если коротко: то, что сейчас кажется будущим, уже начало происходить.

            И да, ты справился бережнее и сильнее, чем сам от себя ожидал.
            """,
            en: """
            Hi.

            I am writing to you from a moment you are only imagining right now. I remember how this wish sounded in your head: \(capsule.title.lowercased()). Back then it may have felt too big, too fragile, or simply far away.

            But you did not put it aside.

            It did not happen in one single push. There were days when it was tempting to pretend it did not matter that much. There were small steps that barely felt like movement. And still, those were the ones that started changing the trajectory.

            \(feelingLine)

            Looking back now, I do not see a perfect story. I see a person who continued. You did not have to be certain every day. It was enough to return to this wish and take the next honest step.

            In short: what feels like the future right now has already begun.

            And yes, you handled it more gently and more strongly than you expected from yourself.
            """
        )

        return FutureLetterDraft(
            shouldCreate: true,
            reason: "local_emotional_wish",
            title: AIResponseLanguage.text(ru: "Тебе письмо из будущего", en: "A letter from your future"),
            letter: letter,
            scheduledAt: scheduledDate(for: capsule, requestedDays: fallbackSendAfterDays(for: capsule))
        )
    }

    private func shouldCreateFallbackLetter(for capsule: WishCapsule) -> Bool {
        let text = [capsule.title, capsule.intentionText, capsule.desiredFeeling]
            .joined(separator: " ")
            .lowercased()

        let daysUntilOpen = calendar.dateComponents([.day], from: capsule.sealedAt, to: capsule.openAt).day ?? 0
        let tinyTaskWords = [
            "купить", "оплатить", "позвонить", "написать", "отправить", "забрать",
            "сходить", "убраться", "сдать отчет", "встреча", "задача"
        ]
        let emotionalWords = [
            "мечта", "дом", "переезд", "любов", "отнош", "здоров", "свобод",
            "деньг", "проект", "книг", "работ", "бизнес", "спокой", "смел",
            "жизн", "творч", "семь", "нов"
        ]

        if daysUntilOpen <= 2 && tinyTaskWords.contains(where: text.contains) {
            return false
        }

        return daysUntilOpen >= 5 || emotionalWords.contains(where: text.contains)
    }

    private func fallbackSendAfterDays(for capsule: WishCapsule) -> Int {
        let daysUntilOpen = calendar.dateComponents([.day], from: capsule.sealedAt, to: capsule.openAt).day ?? 0

        switch daysUntilOpen {
        case ..<4:
            return 1
        case 4..<15:
            return 1
        case 15..<61:
            return 3
        case 61..<181:
            return 7
        default:
            return 14
        }
    }

    private func scheduledDate(for capsule: WishCapsule, requestedDays: Int) -> Date {
        let now = Date()
        let latestComfortableDate = calendar.date(byAdding: .hour, value: -2, to: capsule.openAt) ?? capsule.openAt
        let hoursUntilOpen = calendar.dateComponents([.hour], from: now, to: capsule.openAt).hour ?? 0

        guard hoursUntilOpen > 4 else {
            return calendar.date(byAdding: .minute, value: 30, to: now) ?? now
        }

        let allowedDays = [1, 3, 7, 14]
        let normalizedDays = allowedDays.contains(requestedDays) ? requestedDays : fallbackSendAfterDays(for: capsule)
        let rawDate = calendar.date(byAdding: .day, value: normalizedDays, to: capsule.sealedAt) ?? capsule.sealedAt

        var scheduled = resonantDate(on: rawDate, for: capsule, salt: "future-letter")

        if scheduled >= latestComfortableDate {
            scheduled = fallbackScheduledDateBeforeOpening(for: capsule, latestComfortableDate: latestComfortableDate)
        }

        if scheduled <= now {
            let soon = calendar.date(byAdding: .hour, value: 2, to: now) ?? now
            scheduled = min(soon, latestComfortableDate)
        }

        return scheduled > now ? scheduled : calendar.date(byAdding: .minute, value: 30, to: now) ?? now
    }

    private func fallbackScheduledDateBeforeOpening(for capsule: WishCapsule, latestComfortableDate: Date) -> Date {
        let now = Date()
        let daysUntilOpen = calendar.dateComponents([.day], from: capsule.sealedAt, to: capsule.openAt).day ?? 0

        if daysUntilOpen <= 3 {
            return calendar.date(byAdding: .hour, value: 2, to: now) ?? now
        }

        let fallbackDays = fallbackSendAfterDays(for: capsule)
        let fallbackRawDate = calendar.date(byAdding: .day, value: fallbackDays, to: capsule.sealedAt) ?? capsule.sealedAt
        let fallbackDate = resonantDate(on: fallbackRawDate, for: capsule, salt: "future-letter-fallback")

        return min(fallbackDate, latestComfortableDate)
    }

    private func resonantDate(on date: Date, for capsule: WishCapsule, salt: String) -> Date {
        let day = calendar.startOfDay(for: date)
        let startMinute = 11 * 60
        let endMinute = 20 * 60 + 45
        let minute = startMinute + stableMinuteOffset(
            for: capsule,
            on: day,
            salt: salt,
            availableMinutes: endMinute - startMinute
        )

        return calendar.date(
            bySettingHour: minute / 60,
            minute: minute % 60,
            second: 0,
            of: day
        ) ?? date
    }

    private func stableMinuteOffset(
        for capsule: WishCapsule,
        on day: Date,
        salt: String,
        availableMinutes: Int
    ) -> Int {
        guard availableMinutes > 0 else { return 0 }

        var seed: UInt64 = 1469598103934665603
        let uuid = capsule.id.uuid
        withUnsafeBytes(of: uuid) { bytes in
            for byte in bytes {
                seed ^= UInt64(byte)
                seed &*= 1099511628211
            }
        }

        for byte in salt.utf8 {
            seed ^= UInt64(byte)
            seed &*= 1099511628211
        }

        let components = calendar.dateComponents([.year, .month, .day], from: day)
        for value in [components.year, components.month, components.day].compactMap(\.self) {
            seed ^= UInt64(value)
            seed &*= 1099511628211
        }

        return Int(seed % UInt64(availableMinutes + 1))
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .complete, time: .omitted)
    }
}

private enum FutureLetterAIDecision {
    case create(FutureLetterDraft)
    case skip(String)
    case malformed
}

private struct FutureLetterAIResponse: Decodable {
    let shouldCreate: Bool
    let reason: String
    let sendAfterDays: Int
    let letter: String

    static func decode(from text: String) -> FutureLetterAIResponse? {
        guard let json = text.extractedJSONObject(),
              let data = json.data(using: .utf8)
        else { return nil }

        return try? JSONDecoder().decode(FutureLetterAIResponse.self, from: data)
    }
}
