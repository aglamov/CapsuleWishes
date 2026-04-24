//
//  CapsuleCard.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct CapsuleCard: View {
    let capsule: WishCapsule
    var isHighlighted = false

    var body: some View {
        HStack(spacing: 16) {
            CapsuleOrbView(capsule: capsule, size: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text(capsule.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.44))
        }
        .padding(16)
        .scaleEffect(isHighlighted ? 1.018 : 1)
        .background(.white.opacity(isHighlighted ? 0.15 : 0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isHighlighted ? Color(hex: capsule.colorHex).opacity(0.58) : .white.opacity(0.12),
                    lineWidth: isHighlighted ? 1.4 : 1
                )
        )
        .shadow(color: Color(hex: capsule.colorHex).opacity(isHighlighted ? 0.30 : 0), radius: 20)
        .animation(.easeInOut(duration: 0.42), value: isHighlighted)
    }

    private var subtitle: String {
        if capsule.isReadyToOpen {
            return "Готова открыться"
        }

        if capsule.status != .sealed {
            return capsule.status.title
        }

        return "Открытие: \(capsule.openAt.formatted(date: .abbreviated, time: .omitted))"
    }
}
