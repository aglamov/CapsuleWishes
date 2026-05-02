//
//  WishPromptLibrary.swift
//  CapsuleWishes
//
//  Created by Codex on 25.04.2026.
//

import Foundation

enum WishPromptLibrary {
    static func prompt(
        for entryType: JournalEntryType,
        capsule: WishCapsule?,
        recentEntries: [JournalEntry] = []
    ) -> String {
        guard let capsule else {
            return entryType.prompt
        }

        let wishName = capsule.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let feeling = capsule.desiredFeeling.trimmingCharacters(in: .whitespacesAndNewlines)
        let wishReference = AIResponseLanguage.text(
            ru: wishName.isEmpty ? "этого желания" : "желания «\(wishName)»",
            en: wishName.isEmpty ? "this wish" : "the wish \"\(wishName)\""
        )
        let feelingReference = AIResponseLanguage.text(
            ru: feeling.isEmpty ? "внутреннего отклика" : "ощущения «\(feeling)»",
            en: feeling.isEmpty ? "the inner response" : "the feeling \"\(feeling)\""
        )
        let recent = recentEntries.prefix(5)
        let latest = recent.first

        if let latest, let echo = shortEcho(from: latest.text) {
            switch entryType {
            case .sign:
                return AIResponseLanguage.text(ru: "В прошлых следах уже звучало «\(echo)». Сегодня не ищи подтверждений: просто отметь одну странную деталь вокруг \(wishReference), если она сама задержится в тебе.", en: "The earlier traces already carried \"\(echo)\". Today, do not look for proof: simply note one odd detail around \(wishReference), if it lingers on its own.")
            case .thought:
                return AIResponseLanguage.text(ru: "Кажется, рядом с \(wishReference) уже появился оттенок «\(echo)». Запиши мысль, которая возвращается сейчас, не превращая ее в вывод или обещание.", en: "It seems a shade of \"\(echo)\" has already appeared near \(wishReference). Write down the thought returning now, without turning it into a conclusion or promise.")
            case .dream:
                return AIResponseLanguage.text(ru: "Если образы последних дней перекликаются с «\(echo)», сохрани сегодняшний сон или обрывок как символ. Ему не нужно сразу иметь смысл.", en: "If recent images echo \"\(echo)\", save today's dream or fragment as a symbol. It does not need to make sense right away.")
            case .step:
                if latest.type == .step {
                    return AIResponseLanguage.text(ru: "Ты уже отмечал движение рядом с \(wishReference). Сегодня можно записать не новый рывок, а что изменилось после него: стало ли чуть яснее, тише или честнее.", en: "You have already noticed movement near \(wishReference). Today you can record not a new push, but what changed after it: whether things became a little clearer, quieter, or more honest.")
                }

                return AIResponseLanguage.text(ru: "После «\(echo)» важно не торопить себя. Если сегодня появился жест в сторону \(feelingReference), запиши его; если нет, отметь, что тебя удержало или поддержало.", en: "After \"\(echo)\", it matters not to rush yourself. If a gesture toward \(feelingReference) appeared today, write it down; if not, note what held you back or supported you.")
            }
        }

        switch entryType {
        case .sign:
            return AIResponseLanguage.text(ru: "Не нужно искать знак специально. Если рядом с \(wishReference) сегодня мелькнет странная фраза, взгляд или сцена, сохрани только то, что действительно зацепило.", en: "You do not need to hunt for a sign. If a strange phrase, glance, or scene flickers near \(wishReference) today, save only what truly caught you.")
        case .thought:
            return AIResponseLanguage.text(ru: "Какая мысль о \(wishReference) вернулась сама, без усилия? Запиши ее как след, а не как обязанность что-то решать.", en: "What thought about \(wishReference) returned on its own, without effort? Record it as a trace, not as an obligation to solve something.")
        case .dream:
            return AIResponseLanguage.text(ru: "Если в сне, образе или полусне мелькнуло что-то рядом с \(wishReference), сохрани это как символ. Картинке не обязательно сразу объясняться.", en: "If something near \(wishReference) flickered in a dream, image, or half-sleep, save it as a symbol. The image does not have to explain itself right away.")
        case .step:
            return AIResponseLanguage.text(ru: "Если сегодня был жест в сторону \(feelingReference), даже почти незаметный, запиши его без оценки. Если шага не было, можно честно заметить, что именно остановило или берегло силы.", en: "If today held a gesture toward \(feelingReference), even a barely visible one, record it without judging. If there was no step, you can honestly notice what stopped you or protected your strength.")
        }
    }

    private static func shortEcho(from text: String) -> String? {
        let words = text
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { return nil }
        let echo = words.prefix(7).joined(separator: " ")
        return echo.count > 64 ? String(echo.prefix(61)) + "..." : echo
    }
}
