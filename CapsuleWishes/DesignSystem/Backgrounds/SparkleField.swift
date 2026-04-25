//
//  SparkleField.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct SparkleField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let starCount = 46

    var body: some View {
        GeometryReader { proxy in
            if reduceMotion {
                staticField(in: proxy.size)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate

                    ForEach(0..<starCount, id: \.self) { index in
                        let star = movingStar(index: index, time: time, in: proxy.size)

                        Circle()
                            .fill(.white.opacity(star.opacity))
                            .frame(width: star.size, height: star.size)
                            .scaleEffect(star.scale)
                            .shadow(color: .white.opacity(star.opacity * 0.55), radius: star.size * 1.6)
                            .position(star.position)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func staticField(in size: CGSize) -> some View {
        ForEach(0..<starCount, id: \.self) { index in
            let position = CGPoint(
                x: size.width * CGFloat(random(index, salt: 11)),
                y: size.height * CGFloat(random(index, salt: 23))
            )
            let starSize = CGFloat(1.6 + random(index, salt: 31) * 2.4)

            Circle()
                .fill(.white.opacity(0.18 + random(index, salt: 47) * 0.28))
                .frame(width: starSize, height: starSize)
                .shadow(color: .white.opacity(0.18), radius: starSize)
                .position(position)
        }
    }

    private func movingStar(index: Int, time: TimeInterval, in size: CGSize) -> StarSnapshot {
        let period = 7.0 + random(index, salt: 1) * 16.0
        let offset = random(index, salt: 2) * period
        let cycleTime = time + offset
        let cycle = Int(floor(cycleTime / period))
        let progress = (cycleTime / period).truncatingRemainder(dividingBy: 1)
        let activeShare = 0.48 + random(index, cycle: cycle, salt: 3) * 0.46

        guard progress <= activeShare else {
            return StarSnapshot(position: hiddenPosition(in: size), size: 0.1, opacity: 0, scale: 1)
        }

        let activeProgress = progress / activeShare
        let start = startPosition(index: index, cycle: cycle, in: size)
        let distance = CGFloat(18 + random(index, cycle: cycle, salt: 4) * 92)
        let angle = random(index, cycle: cycle, salt: 5) * .pi * 2
        let curve = CGFloat(sin(activeProgress * .pi) * (random(index, cycle: cycle, salt: 6) - 0.5) * 24)
        let end = CGPoint(
            x: start.x + CGFloat(cos(angle)) * distance + CGFloat(cos(angle + .pi / 2)) * curve,
            y: start.y + CGFloat(sin(angle)) * distance + CGFloat(sin(angle + .pi / 2)) * curve
        )
        let position = CGPoint(
            x: start.x + (end.x - start.x) * CGFloat(activeProgress),
            y: start.y + (end.y - start.y) * CGFloat(activeProgress)
        )

        let fadeIn = smoothstep(activeProgress / 0.18)
        let fadeOut = 1 - smoothstep((activeProgress - 0.72) / 0.28)
        let twinkle = 0.58 + 0.42 * sin((time * (1.4 + random(index, salt: 7) * 2.8)) + random(index, cycle: cycle, salt: 8) * .pi * 2)
        let baseOpacity = 0.16 + random(index, cycle: cycle, salt: 9) * 0.42
        let opacity = max(0, min(0.72, baseOpacity * fadeIn * fadeOut * twinkle))
        let starSize = CGFloat(1.4 + random(index, cycle: cycle, salt: 10) * 3.2)
        let scale = 0.74 + twinkle * 0.46

        return StarSnapshot(position: position, size: starSize, opacity: opacity, scale: scale)
    }

    private func startPosition(index: Int, cycle: Int, in size: CGSize) -> CGPoint {
        let margin: CGFloat = 24
        return CGPoint(
            x: -margin + (size.width + margin * 2) * CGFloat(random(index, cycle: cycle, salt: 12)),
            y: -margin + (size.height + margin * 2) * CGFloat(random(index, cycle: cycle, salt: 13))
        )
    }

    private func hiddenPosition(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.5, y: size.height * 0.5)
    }

    private func smoothstep(_ value: Double) -> Double {
        let clamped = max(0, min(1, value))
        return clamped * clamped * (3 - 2 * clamped)
    }

    private func random(_ index: Int, salt: Int) -> Double {
        random(index, cycle: 0, salt: salt)
    }

    private func random(_ index: Int, cycle: Int, salt: Int) -> Double {
        var value = UInt64(index &+ 1) &* 0x9E37_79B9_7F4A_7C15
        value ^= UInt64(cycle &+ 37) &* 0xBF58_476D_1CE4_E5B9
        value ^= UInt64(salt &+ 91) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31

        return Double(value & 0x00FF_FFFF) / Double(0x0100_0000)
    }
}

private struct StarSnapshot {
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
    let scale: Double
}
