//
//  SwiftDataContainer.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftData

enum SwiftDataContainer {
    private static let cloudKitContainerIdentifier = "iCloud.Ramil-Aglyamov.CapsuleWishes"

    static let shared: ModelContainer = {
        let schema = Schema([
            WishCapsule.self,
            JournalEntry.self,
            NotificationSignal.self,
            PersonalSymbol.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
