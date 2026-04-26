//
//  WishTextPanel.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct WishTextPanel: View {
    @State private var isFortuneButtonGlowing = false

    let capsule: WishCapsule
    var showsSealingFortuneButton = false
    var onOpenSealingFortune: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Label("Желание", systemImage: capsule.hasBeenOpened ? "lock.open.fill" : "lock.fill")
                    .font(.headline)
                    .foregroundStyle(titleColor)

                Spacer(minLength: 0)

                if showsSealingFortuneButton, let onOpenSealingFortune {
                    Button {
                        onOpenSealingFortune()
                    } label: {
                        Image(systemName: "bookmark.circle")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(isFortuneButtonGlowing ? 0.16 : 0.06), in: Circle())
                            .shadow(color: Color(hex: capsule.colorHex).opacity(isFortuneButtonGlowing ? 0.82 : 0.22), radius: isFortuneButtonGlowing ? 14 : 4)
                            .scaleEffect(isFortuneButtonGlowing ? 1.08 : 0.96)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Открыть послание при запечатывании")
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                            isFortuneButtonGlowing = true
                        }
                    }
                }
            }

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

    private var titleColor: Color {
        if capsule.hasBeenOpened {
            return .white.opacity(0.72)
        }

        if capsule.isReadyToOpen {
            return Color(hex: capsule.colorHex).opacity(0.95)
        }

        return .white
    }
}
