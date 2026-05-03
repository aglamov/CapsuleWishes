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
    var refreshDate = Date()

    var body: some View {
        let _ = refreshDate
        let accentColor = Color(hex: capsule.colorHex)

        HStack(spacing: 16) {
            timeRingOrb(accentColor: accentColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(capsule.title)
                    .font(.headline)
                    .foregroundStyle(titleColor)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(subtitleColor)
            }
            .padding(.trailing, statusBadge == nil ? 0 : 58)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.44))
        }
        .padding(16)
        .scaleEffect(isHighlighted ? 1.018 : 1)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(backgroundOpacity))
                .overlay(alignment: .leading) {
                    LinearGradient(
                        colors: [
                            accentColor.opacity(capsule.hasBeenOpened ? 0.08 : 0.24),
                            accentColor.opacity(0.04),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isHighlighted ? accentColor.opacity(0.58) : .white.opacity(borderOpacity),
                    lineWidth: isHighlighted ? 1.4 : 1
                )
        )
        .overlay(alignment: .topTrailing) {
            if let statusBadge {
                Text(statusBadge)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(badgeTextColor)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeBackground(accentColor), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(capsule.isReadyToOpen ? 0.24 : 0.14), lineWidth: 1)
                    }
                    .fixedSize()
                    .padding(.top, 12)
                    .padding(.trailing, 14)
            }
        }
        .shadow(color: accentColor.opacity(cardGlowOpacity), radius: cardGlowRadius, x: 0, y: 8)
        .animation(.easeInOut(duration: 0.42), value: isHighlighted)
    }

    private func timeRingOrb(accentColor: Color) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(capsule.hasBeenOpened ? 0.08 : 0.12), lineWidth: 3)
                .frame(width: 86, height: 86)

            Circle()
                .trim(from: 0, to: timeProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            accentColor.opacity(0.42),
                            Color(hex: "FFD89A").opacity(capsule.isReadyToOpen ? 0.95 : 0.74),
                            accentColor.opacity(0.82)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: capsule.isReadyToOpen ? 4 : 3, lineCap: .round)
                )
                .frame(width: 86, height: 86)
                .rotationEffect(.degrees(-90))
                .shadow(color: accentColor.opacity(capsule.isReadyToOpen ? 0.58 : 0.22), radius: capsule.isReadyToOpen ? 10 : 5)

            CapsuleOrbView(capsule: capsule, size: 72, refreshDate: refreshDate)
                .opacity(capsule.hasBeenOpened ? 0.58 : 1)
        }
        .frame(width: 90, height: 90)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(capsule.title), \(subtitle)")
    }

    private var subtitle: String {
        if capsule.isReadyToOpen {
            return String(localized: "Готова открыться")
        }

        if capsule.status != .sealed {
            let openedDate = (capsule.openedAt ?? capsule.openAt).formatted(date: .abbreviated, time: .omitted)
            return String(
                format: String(localized: "%@ · открыта %@"),
                capsule.status.title,
                openedDate
            )
        }

        return String(
            format: String(localized: "Открытие: %@"),
            capsule.openAt.formatted(date: .abbreviated, time: .omitted)
        )
    }

    private var statusBadge: String? {
        if capsule.isReadyToOpen {
            return String(localized: "Готова")
        }

        if capsule.hasBeenOpened {
            return nil
        }

        if daysUntilOpening <= 7 {
            return String(localized: "Скоро")
        }

        return nil
    }

    private var timeProgress: CGFloat {
        if capsule.hasBeenOpened || capsule.isReadyToOpen {
            return 1
        }

        let total = capsule.openAt.timeIntervalSince(capsule.sealedAt)
        guard total > 0 else { return 1 }

        let elapsed = refreshDate.timeIntervalSince(capsule.sealedAt)
        return CGFloat(min(max(elapsed / total, 0), 1))
    }

    private var daysUntilOpening: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: refreshDate)
        let openingDay = calendar.startOfDay(for: capsule.openAt)
        return max(calendar.dateComponents([.day], from: today, to: openingDay).day ?? 0, 0)
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

    private var badgeTextColor: Color {
        capsule.isReadyToOpen ? Color(hex: "24170B") : .white.opacity(0.86)
    }

    private var cardGlowOpacity: Double {
        if isHighlighted { return 0.30 }
        if capsule.isReadyToOpen { return 0.22 }
        return capsule.hasBeenOpened ? 0 : 0.10
    }

    private var cardGlowRadius: CGFloat {
        if isHighlighted { return 22 }
        return capsule.isReadyToOpen ? 18 : 12
    }

    private func badgeBackground(_ accentColor: Color) -> some ShapeStyle {
        if capsule.isReadyToOpen {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "FFE7B8"), Color(hex: "F2A85E")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(accentColor.opacity(0.24))
    }
}
