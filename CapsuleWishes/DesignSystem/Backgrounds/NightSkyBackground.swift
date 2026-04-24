//
//  NightSkyBackground.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct NightSkyBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.07, blue: 0.16),
                Color(red: 0.13, green: 0.12, blue: 0.28),
                Color(red: 0.04, green: 0.12, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            SparkleField()
        }
    }
}
