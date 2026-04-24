//
//  CapsuleOrbView.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI
import UIKit

struct CapsuleOrbView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false
    @State private var isEager = false
    @State private var isPressingOrb = false
    @State private var isShimmering = false
    @State private var hapticTask: Task<Void, Never>?

    let capsule: WishCapsule
    let size: CGFloat
    var isInteractive = false

    var body: some View {
        let color = Color(hex: capsule.colorHex)
        let highlight = color.mix(with: .white, by: 0.34)
        let ready = capsule.isReadyToOpen

        ZStack {
            Circle()
                .fill(color.opacity(ready ? 0.26 : 0.16))
                .frame(width: size * 1.25, height: size * 1.25)
                .blur(radius: size * (ready ? 0.15 : 0.12))
                .scaleEffect(glowScale)
                .opacity(glowOpacity)

            if ready {
                Circle()
                    .stroke(color.opacity(0.58), lineWidth: max(size * 0.035, 2))
                    .frame(width: size * 1.14, height: size * 1.14)
                    .scaleEffect(isEager && !reduceMotion ? 1.22 : 0.88)
                    .opacity(isEager && !reduceMotion ? 0.08 : 0.72)
                    .blur(radius: size * 0.015)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(ready ? 0.90 : 0.72),
                            color.opacity(0.82),
                            color.opacity(0.18)
                        ],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: size * 0.62
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: color.opacity(ready ? 0.95 : 0.55), radius: shadowRadius)
                .overlay {
                    if isShimmering {
                        TimelineView(.animation) { timeline in
                            CapsuleOrbRippleOverlay(
                                color: color,
                                highlight: highlight,
                                size: size,
                                phase: timeline.date.timeIntervalSinceReferenceDate / 3.2
                            )
                        }
                        .clipShape(Circle())
                        .blendMode(.screen)
                        .transition(.opacity)
                    }
                }
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.36), lineWidth: 1)
                }

            Image(systemName: capsule.symbol)
                .font(.system(size: size * 0.30, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .scaleEffect(symbolScale)
        }
        .scaleEffect(orbScale * pressScale)
        .offset(y: verticalOffset)
        .rotationEffect(.degrees(rotation))
        .contentShape(Circle())
        .accessibilityLabel(capsule.title)
        .animation(reduceMotion ? nil : breathingAnimation, value: isBreathing)
        .animation(reduceMotion ? nil : eagerAnimation, value: isEager)
        .simultaneousGesture(pressGesture)
        .onAppear {
            guard !reduceMotion else { return }
            isBreathing = true
            isEager = capsule.isReadyToOpen
        }
        .onChange(of: capsule.isReadyToOpen) { _, isReady in
            guard !reduceMotion else { return }
            isEager = isReady
        }
        .onDisappear {
            stopPressTasks()
        }
    }

    private var breathingAnimation: Animation {
        .easeInOut(duration: 2.8).repeatForever(autoreverses: true)
    }

    private var eagerAnimation: Animation {
        .easeInOut(duration: 0.36).repeatForever(autoreverses: true)
    }

    private var orbScale: CGFloat {
        if reduceMotion { return 1 }
        if capsule.isReadyToOpen {
            return isEager ? 1.08 : 0.96
        }
        return isBreathing ? 1.025 : 0.985
    }

    private var pressScale: CGFloat {
        guard isInteractive, !reduceMotion else { return 1 }
        return isPressingOrb ? 1.38 : 1
    }

    private var glowScale: CGFloat {
        if reduceMotion { return 1 }
        if capsule.isReadyToOpen {
            return isEager ? 1.42 : 1.00
        }
        return isBreathing ? 1.10 : 0.96
    }

    private var glowOpacity: Double {
        if capsule.isReadyToOpen {
            return isEager && !reduceMotion ? 0.95 : 0.70
        }
        return isBreathing && !reduceMotion ? 0.78 : 0.58
    }

    private var shadowRadius: CGFloat {
        if capsule.isReadyToOpen {
            return size * (isEager && !reduceMotion ? 0.30 : 0.23)
        }
        return size * (isBreathing && !reduceMotion ? 0.24 : 0.20)
    }

    private var symbolScale: CGFloat {
        guard capsule.isReadyToOpen, !reduceMotion else { return 1 }
        return isEager ? 1.16 : 0.92
    }

    private var verticalOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        if capsule.isReadyToOpen {
            return isEager ? -size * 0.14 : size * 0.04
        }
        return isBreathing ? -size * 0.018 : size * 0.012
    }

    private var rotation: Double {
        guard capsule.isReadyToOpen, !reduceMotion else { return 0 }
        return isEager ? 7 : -5
    }

    private func startPressEffect() {
        guard isInteractive, !reduceMotion, !isPressingOrb else { return }

        withAnimation(.easeInOut(duration: 1.15)) {
            isPressingOrb = true
        }
        isShimmering = true

        startHapticRamp()
    }

    private func endPressEffect() {
        guard isInteractive, !reduceMotion else { return }

        hapticTask?.cancel()
        stopPressTasks()

        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            isPressingOrb = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.easeOut(duration: 0.24)) {
                isShimmering = false
            }
        }
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                startPressEffect()
            }
            .onEnded { _ in
                endPressEffect()
            }
    }

    private func startHapticRamp() {
        hapticTask?.cancel()
        hapticTask = Task {
            var intensity: CGFloat = 0.18

            while !Task.isCancelled {
                await MainActor.run {
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.prepare()
                    generator.impactOccurred(intensity: intensity)
                }

                intensity = min(intensity + 0.08, 0.88)
                try? await Task.sleep(for: .milliseconds(190))
            }
        }
    }

    private func stopPressTasks() {
        hapticTask?.cancel()
        hapticTask = nil
    }
}

private struct CapsuleOrbRippleOverlay: View {
    let color: Color
    let highlight: Color
    let size: CGFloat
    let phase: Double

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(index.isMultiple(of: 3) ? 0.34 : 0.18),
                                highlight.opacity(index.isMultiple(of: 2) ? 0.46 : 0.32),
                                color.opacity(0.22),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: bubbleSize(for: index) * 0.08,
                            endRadius: bubbleSize(for: index) * 0.62
                        )
                    )
                    .frame(width: bubbleSize(for: index), height: bubbleSize(for: index))
                    .blur(radius: size * blurAmount(for: index))
                    .offset(bubbleOffset(for: index))
                    .opacity(bubbleOpacity(for: index))
                    .scaleEffect(bubbleScale(for: index))
            }
        }
        .frame(width: size, height: size)
    }

    private func bubbleSize(for index: Int) -> CGFloat {
        size * [0.56, 0.44, 0.62, 0.36, 0.50, 0.30][index]
    }

    private func bubbleOffset(for index: Int) -> CGSize {
        let angle = phaseAngle(for: index)
        let radius = bubbleRadius(for: index)
        return CGSize(
            width: cos(angle) * size * radius,
            height: sin(angle * 0.82 + Double(index) * 0.54) * size * radius
        )
    }

    private func bubbleOpacity(for index: Int) -> Double {
        0.26 + (sin(phaseAngle(for: index) * 1.18) + 1) * 0.13
    }

    private func bubbleScale(for index: Int) -> CGFloat {
        0.92 + CGFloat((sin(phaseAngle(for: index) * 0.72) + 1) * 0.08)
    }

    private func blurAmount(for index: Int) -> CGFloat {
        [0.055, 0.065, 0.050, 0.070, 0.060, 0.075][index]
    }

    private func bubbleRadius(for index: Int) -> Double {
        [0.20, 0.28, 0.18, 0.24, 0.30, 0.16][index]
    }

    private func phaseAngle(for index: Int) -> Double {
        phase * .pi * 2 * speed(for: index) + Double(index) * 0.96
    }

    private func speed(for index: Int) -> Double {
        [0.82, 1.05, 0.70, 1.24, 0.92, 1.14][index]
    }
}
