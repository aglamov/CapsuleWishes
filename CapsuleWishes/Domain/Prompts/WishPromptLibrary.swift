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
        let wishReference = wishName.isEmpty ? "этого желания" : "желания «\(wishName)»"
        let feelingReference = feeling.isEmpty ? "внутреннего отклика" : "ощущения «\(feeling)»"
        let recent = recentEntries.prefix(5)
        let latest = recent.first

        if let latest, let echo = shortEcho(from: latest.text) {
            switch entryType {
            case .sign:
                return "В прошлых следах уже звучало «\(echo)». Сегодня не ищи подтверждений: просто отметь одну странную деталь вокруг \(wishReference), если она сама задержится в тебе."
            case .thought:
                return "Кажется, рядом с \(wishReference) уже появился оттенок «\(echo)». Запиши мысль, которая возвращается сейчас, не превращая ее в вывод или обещание."
            case .dream:
                return "Если образы последних дней перекликаются с «\(echo)», сохрани сегодняшний сон или обрывок как символ. Ему не нужно сразу иметь смысл."
            case .step:
                if latest.type == .step {
                    return "Ты уже отмечал движение рядом с \(wishReference). Сегодня можно записать не новый рывок, а что изменилось после него: стало ли чуть яснее, тише или честнее."
                }

                return "После «\(echo)» важно не торопить себя. Если сегодня появился жест в сторону \(feelingReference), запиши его; если нет, отметь, что тебя удержало или поддержало."
            }
        }

        switch entryType {
        case .sign:
            return "Не нужно искать знак специально. Если рядом с \(wishReference) сегодня мелькнет странная фраза, взгляд или сцена, сохрани только то, что действительно зацепило."
        case .thought:
            return "Какая мысль о \(wishReference) вернулась сама, без усилия? Запиши ее как след, а не как обязанность что-то решать."
        case .dream:
            return "Если в сне, образе или полусне мелькнуло что-то рядом с \(wishReference), сохрани это как символ. Картинке не обязательно сразу объясняться."
        case .step:
            return "Если сегодня был жест в сторону \(feelingReference), даже почти незаметный, запиши его без оценки. Если шага не было, можно честно заметить, что именно остановило или берегло силы."
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
