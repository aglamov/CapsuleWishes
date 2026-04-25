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

        switch entryType {
        case .sign:
            return "Сегодня попробуй заметить маленький знак вокруг \(wishReference): случайную фразу, взгляд, сцену или совпадение, которое почему-то задержалось внутри."
        case .thought:
            return "Какая мысль о \(wishReference) вернулась сегодня сама? Не оценивай ее сразу: просто запиши, куда она тихо указывает."
        case .dream:
            return "Если в сне, образе или полусне мелькнуло что-то рядом с \(wishReference), сохрани это как символ. Иногда желание говорит не планом, а картинкой."
        case .step:
            return "Какой самый маленький шаг сегодня может помочь \(wishReference) стать ближе к \(feelingReference)? Пусть это будет действие, которое не пугает своим размером."
        }
    }
}
