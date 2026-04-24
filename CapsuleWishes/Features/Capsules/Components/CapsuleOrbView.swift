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
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                highlight.opacity(index.isMultiple(of: 2) ? 0.44 : 0.30),
                                color.opacity(0.34),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * waveWidth(for: index), height: size * waveHeight(for: index))
                    .blur(radius: size * 0.02)
                    .rotationEffect(.degrees(waveAngle(for: index)))
                    .offset(waveOffset(for: index))
                    .opacity(waveOpacity(for: index))
            }

            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(index.isMultiple(of: 2) ? 0.46 : 0.30),
                                highlight.opacity(0.24),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: bubbleSize(for: index)
                        )
                    )
                    .frame(width: bubbleSize(for: index), height: bubbleSize(for: index))
                    .blur(radius: size * 0.004)
                    .offset(bubbleOffset(for: index))
                    .opacity(bubbleOpacity(for: index))
            }
        }
        .frame(width: size, height: size)
    }

    private func waveWidth(for index: Int) -> CGFloat {
        [1.45, 1.18, 1.34, 0.98][index]
    }

    private func waveHeight(for index: Int) -> CGFloat {
        [0.25, 0.18, 0.22, 0.15][index]
    }

    private func waveAngle(for index: Int) -> Double {
        let bases = [-28.0, 19.0, 62.0, -67.0]
        return bases[index] + sin(phaseAngle(for: index)) * 42
    }

    private func waveOffset(for index: Int) -> CGSize {
        let angle = phaseAngle(for: index)
        return CGSize(
            width: cos(angle) * size * waveRadius(for: index),
            height: sin(angle * 0.74 + Double(index)) * size * waveRadius(for: index) * 0.82
        )
    }

    private func waveOpacity(for index: Int) -> Double {
        0.34 + (sin(phaseAngle(for: index) + 1.2) + 1) * 0.12
    }

    private func waveRadius(for index: Int) -> Double {
        [0.22, 0.18, 0.14, 0.24][index]
    }

    private func bubbleSize(for index: Int) -> CGFloat {
        size * [0.15, 0.09, 0.12, 0.07, 0.18, 0.08, 0.11][index]
    }

    private func bubbleOffset(for index: Int) -> CGSize {
        let angle = phaseAngle(for: index + 4)
        let radius = bubbleRadius(for: index)
        return CGSize(
            width: cos(angle) * size * radius,
            height: sin(angle * 1.12 + Double(index) * 0.4) * size * radius
        )
    }

    private func bubbleOpacity(for index: Int) -> Double {
        0.24 + (sin(phaseAngle(for: index) * 1.4) + 1) * 0.15
    }

    private func bubbleRadius(for index: Int) -> Double {
        [0.22, 0.26, 0.18, 0.28, 0.16, 0.12, 0.24][index]
    }

    private func phaseAngle(for index: Int) -> Double {
        phase * .pi * 2 + Double(index) * 0.83
    }
}
