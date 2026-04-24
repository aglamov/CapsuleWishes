//
//  ContentView.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CapsuleListView()
                .tabItem {
                    Label("Капсулы", systemImage: "sparkles")
                }

            JournalView()
                .tabItem {
                    Label("Дневник", systemImage: "book.closed")
                }
        }
        .tint(.white)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WishCapsule.self, JournalEntry.self], inMemory: true)
}
