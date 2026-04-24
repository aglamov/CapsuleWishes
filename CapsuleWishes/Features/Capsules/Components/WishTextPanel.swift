//
//  WishTextPanel.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct WishTextPanel: View {
    let capsule: WishCapsule

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Желание", systemImage: "lock.open")
                .font(.headline)
                .foregroundStyle(.white)

            Text(capsule.intentionText)
                .font(.body)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            if !capsule.desiredFeeling.isEmpty {
                Divider()
                    .overlay(.white.opacity(0.18))

                Label(capsule.desiredFeeling, systemImage: "heart")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.74))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}
