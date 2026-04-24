//
//  CapsuleWishesApp.swift
//  CapsuleWishes
//
//  Created by Рамиль Аглямов on 06.02.2025.
//

import SwiftUI

@main
struct CapsuleWishesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SwiftDataContainer.shared)
    }
}
