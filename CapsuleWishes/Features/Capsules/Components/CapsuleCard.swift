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
                .opacity(capsule.hasBeenOpened ? 0.58 : 1)

            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(capsule.title)
                        .lineLimit(2)
                } icon: {
                    Image(systemName: capsule.hasBeenOpened ? "lock.open.fill" : "lock.fill")
                        .font(.caption.bold())
                        .foregroundStyle(lockColor)
                }
                .font(.headline)
                .foregroundStyle(titleColor)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(subtitleColor)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.44))
        }
        .padding(16)
        .scaleEffect(isHighlighted ? 1.018 : 1)
        .background(.white.opacity(backgroundOpacity), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isHighlighted ? Color(hex: capsule.colorHex).opacity(0.58) : .white.opacity(borderOpacity),
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
            let openedDate = (capsule.openedAt ?? capsule.openAt).formatted(date: .abbreviated, time: .omitted)
            return "\(capsule.status.title) · открыта \(openedDate)"
        }

        return "Открытие: \(capsule.openAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private var backgroundOpacity: Double {
        if isHighlighted { return 0.15 }
        return capsule.hasBeenOpened ? 0.045 : 0.08
    }

    private var borderOpacity: Double {
        capsule.hasBeenOpened ? 0.07 : 0.12
    }

    private var titleColor: Color {
        .white.opacity(capsule.hasBeenOpened ? 0.58 : 1)
    }

    private var subtitleColor: Color {
        .white.opacity(capsule.hasBeenOpened ? 0.44 : 0.66)
    }

    private var lockColor: Color {
        if capsule.hasBeenOpened {
            return .white.opacity(0.38)
        }

        if capsule.isReadyToOpen {
            return Color(hex: capsule.colorHex).opacity(0.95)
        }

        return .white.opacity(0.72)
    }
}
