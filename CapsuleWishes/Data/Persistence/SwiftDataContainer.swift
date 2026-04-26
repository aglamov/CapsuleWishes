//
//  SwiftDataContainer.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftData

enum SwiftDataContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            WishCapsule.self,
            JournalEntry.self,
            NotificationSignal.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
