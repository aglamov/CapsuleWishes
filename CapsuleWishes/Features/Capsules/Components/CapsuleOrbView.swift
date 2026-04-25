//
//  CapsuleOrbView.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI
import UIKit

enum CapsuleOrbOpeningPhase {
    case idle
    case awakening
    case tension
    case release
    case afterglow
    case returning

    var isActive: Bool {
        self != .idle
    }
}

struct CapsuleOrbView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false
    @State private var isEager = false
    @State private var isPressingOrb = false
    @State private var isShimmering = false
    @State private var hapticTask: Task<Void, Never>?
    @State private var openingPhaseStartedAt = Date()

    let capsule: WishCapsule
    let size: CGFloat
    var isInteractive = false
    var freezesMotion = false
    var openingPhase: CapsuleOrbOpeningPhase = .idle

    var body: some View {
        if capsule.status == .sealed || openingPhase.isActive {
            animatedOrb
        } else {
            staticOrb
        }
    }

    private var animatedOrb: some View {
        let baseColor = Color(hex: capsule.colorHex)
        let color = baseColor.mix(with: Color(hex: "F2A85E"), by: openingWarmth)
        let highlight = color.mix(with: .white, by: 0.34)
        let ready = capsule.isReadyToOpen || openingPhase != .idle

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(releaseGlowCenterOpacity),
                            Color(hex: "FFE6B3").opacity(releaseGlowMidOpacity),
                            color.opacity(releaseGlowEdgeOpacity),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.82
                    )
                )
                .frame(width: size * 1.18, height: size * 1.18)
                .scaleEffect(releaseGlowScale)
                .blur(radius: releaseGlowBlur)
                .opacity(releaseGlowOpacity)
                .blendMode(.screen)
                .allowsHitTesting(false)

            Circle()
                .fill(color.opacity((ready ? 0.26 : 0.16) * shellOpacity))
                .frame(width: size * 1.25, height: size * 1.25)
                .blur(radius: size * (ready ? 0.15 : 0.12))
                .scaleEffect(glowScale)
                .opacity(glowOpacity)

            if ready {
                if wakeRingIntensity <= 0 {
                    EmptyView()
                } else if reduceMotion || freezesMotion {
                    Circle()
                        .stroke(color.opacity(0.42 * shellStrokeOpacity), lineWidth: max(size * 0.026, 2))
                        .frame(width: currentCapsuleDiameter, height: currentCapsuleDiameter)
                        .blur(radius: size * 0.012)
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                        CapsuleOrbWakeRings(
                            color: color,
                            size: size,
                            startDiameter: currentCapsuleDiameter,
                            time: timeline.date.timeIntervalSince(openingPhaseStartedAt),
                            intensity: wakeRingIntensity,
                            expansion: wakeRingExpansion,
                            softness: wakeRingSoftness,
                            duration: wakeRingDuration,
                            ringCount: wakeRingCount
                        )
                    }
                    .allowsHitTesting(false)
                }
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(ready ? 0.90 : 0.72),
                            color.opacity(coreColorOpacity),
                            color.opacity(edgeColorOpacity)
                        ],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: size * 0.62
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: shellBlur)
                .opacity(coreOrbOpacity)
                .shadow(color: color.opacity(ready ? 0.95 : 0.55), radius: shadowRadius)
                .overlay {
                    if showsInternalMotion {
                        TimelineView(.animation) { timeline in
                            CapsuleOrbRippleOverlay(
                                color: color,
                                highlight: highlight,
                                size: size,
                                phase: timeline.date.timeIntervalSinceReferenceDate / rippleSpeed,
                                expansion: rippleExpansion,
                                intensity: rippleIntensity
                            )
                        }
                        .clipShape(Circle().scale(x: rippleClipScale, y: rippleClipScale, anchor: .center))
                        .blendMode(.screen)
                        .transition(.opacity)
                    }
                }
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.36 * shellStrokeOpacity), lineWidth: 1)
                        .blur(radius: shellStrokeBlur)
                }

            Image(systemName: capsule.symbol)
                .font(.system(size: size * 0.30, weight: .semibold))
                .foregroundStyle(.white.opacity(symbolOpacity))
                .scaleEffect(symbolScale)
        }
        .frame(width: size * 1.25, height: size * 1.25)
        .scaleEffect(orbScale * pressScale * openingScale)
        .offset(y: verticalOffset)
        .rotationEffect(.degrees(rotation))
        .contentShape(Circle())
        .accessibilityLabel(capsule.title)
        .animation(allowsAmbientMotion ? breathingAnimation : nil, value: isBreathing)
        .animation(allowsAmbientMotion ? eagerAnimation : nil, value: isEager)
        .simultaneousGesture(pressGesture)
        .onAppear {
            guard !reduceMotion else { return }
            isBreathing = capsule.status == .sealed
            isEager = capsule.status == .sealed && capsule.isReadyToOpen
        }
        .onChange(of: capsule.isReadyToOpen) { _, isReady in
            guard !reduceMotion else { return }
            isEager = capsule.status == .sealed && isReady
        }
        .onChange(of: capsule.status) { _, status in
            let sealed = status == .sealed
            isBreathing = !reduceMotion && sealed
            isEager = !reduceMotion && sealed && capsule.isReadyToOpen

            if !sealed {
                stopMotionEffects()
            }
        }
        .onChange(of: openingPhase) { _, phase in
            guard !reduceMotion else { return }
            openingPhaseStartedAt = Date()

            if phase == .awakening || phase == .tension || phase == .release || phase == .afterglow {
                isEager = true
                isShimmering = true
            }

            if phase == .idle && capsule.status != .sealed {
                stopMotionEffects()
            }

            updateOpeningHaptics(for: phase)
        }
        .onDisappear {
            stopPressTasks()
        }
    }

    private var staticOrb: some View {
        let color = Color(hex: capsule.colorHex)

        return ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: size * 1.25, height: size * 1.25)
                .blur(radius: size * 0.12)
                .opacity(0.58)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.72),
                            color.opacity(0.82),
                            color.opacity(0.18)
                        ],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: size * 0.62
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.55), radius: size * 0.18)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.36), lineWidth: 1)
                }

            Image(systemName: capsule.symbol)
                .font(.system(size: size * 0.30, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
        }
        .contentShape(Circle())
        .accessibilityLabel(capsule.title)
        .onAppear {
            stopMotionEffects()
        }
    }

    private var breathingAnimation: Animation {
        .easeInOut(duration: 2.8).repeatForever(autoreverses: true)
    }

    private var eagerAnimation: Animation {
        .easeInOut(duration: 0.82).repeatForever(autoreverses: true)
    }

    private var allowsAmbientMotion: Bool {
        (capsule.status == .sealed || openingPhase == .awakening || openingPhase == .tension || openingPhase == .release || openingPhase == .afterglow) && !freezesMotion && !reduceMotion
    }

    private var orbScale: CGFloat {
        if reduceMotion { return 1 }
        if openingPhase.isActive { return 1 }
        guard !freezesMotion else { return 1 }
        guard capsule.status == .sealed else { return 1 }
        if capsule.isReadyToOpen {
            return 1
        }
        return isBreathing ? 1.025 : 0.985
    }

    private var pressScale: CGFloat {
        if openingPhase.isActive { return 1 }
        guard !freezesMotion, capsule.status == .sealed, isInteractive, !reduceMotion else { return 1 }
        return isPressingOrb ? 1.38 : 1
    }

    private var wakeRingDuration: TimeInterval {
        switch openingPhase {
        case .awakening:
            return 2.45
        case .tension:
            return 2.12
        case .release:
            return 1.05
        case .afterglow:
            return 3.4
        default:
            return 2.45
        }
    }

    private var openingScale: CGFloat {
        guard !reduceMotion else { return 1 }

        switch openingPhase {
        case .idle:
            return 1
        case .awakening:
            return 1.18
        case .tension:
            return 1.42
        case .release:
            return 1.66
        case .afterglow, .returning:
            return 1
        }
    }

    private var openingWarmth: Double {
        switch openingPhase {
        case .idle:
            return 0
        case .awakening:
            return 0.24
        case .tension:
            return 0.38
        case .release:
            return 0.58
        case .afterglow:
            return 0.46
        case .returning:
            return 0.18
        }
    }

    private var showsInternalMotion: Bool {
        switch openingPhase {
        case .idle:
            return isShimmering
        case .awakening, .tension:
            return true
        case .release, .afterglow, .returning:
            return false
        }
    }

    private var shellOpacity: Double {
        switch openingPhase {
        case .idle:
            return 1
        case .awakening:
            return 0.88
        case .tension:
            return 0.22
        case .release:
            return 0.02
        case .afterglow:
            return 0
        case .returning:
            return 0
        }
    }

    private var shellStrokeOpacity: Double {
        switch openingPhase {
        case .idle:
            return 1
        case .awakening:
            return 0.64
        case .tension:
            return 0.06
        case .release:
            return 0
        case .afterglow:
            return 0
        case .returning:
            return 0
        }
    }

    private var shellBlur: CGFloat {
        switch openingPhase {
        case .idle:
            return 0
        case .awakening:
            return size * 0.008
        case .tension:
            return size * 0.105
        case .release:
            return size * 0.13
        case .afterglow, .returning:
            return 0
        }
    }

    private var shellStrokeBlur: CGFloat {
        switch openingPhase {
        case .idle:
            return 0
        case .awakening:
            return size * 0.018
        case .tension:
            return size * 0.145
        case .release:
            return size * 0.11
        case .afterglow, .returning:
            return 0
        }
    }

    private var coreOrbOpacity: Double {
        switch openingPhase {
        case .idle, .awakening:
            return 1
        case .tension:
            return 0.34
        case .release:
            return 0.06
        case .afterglow:
            return 0
        case .returning:
            return 0
        }
    }

    private var coreColorOpacity: Double {
        switch openingPhase {
        case .idle:
            return 0.82
        case .awakening:
            return 0.86
        case .tension:
            return 0.30
        case .release:
            return 0.14
        case .afterglow:
            return 0
        case .returning:
            return 0
        }
    }

    private var edgeColorOpacity: Double {
        switch openingPhase {
        case .idle:
            return 0.18
        case .awakening:
            return 0.24
        case .tension:
            return 0.10
        case .release:
            return 0.02
        case .afterglow:
            return 0
        case .returning:
            return 0
        }
    }

    private var rippleSpeed: Double {
        switch openingPhase {
        case .awakening:
            return 2.25
        case .tension:
            return 1.55
        case .release:
            return 1.75
        case .afterglow:
            return 3.4
        default:
            return 3.2
        }
    }

    private var rippleExpansion: Double {
        switch openingPhase {
        case .awakening:
            return 1.16
        case .tension:
            return 1.36
        case .release:
            return 1.80
        case .afterglow:
            return 2.25
        default:
            return 1
        }
    }

    private var rippleIntensity: Double {
        switch openingPhase {
        case .awakening:
            return 1.18
        case .tension:
            return 0.96
        case .release:
            return 0
        case .afterglow:
            return 0
        default:
            return 1
        }
    }

    private var rippleClipScale: CGFloat {
        switch openingPhase {
        case .release:
            return 1.35
        case .afterglow:
            return 2.4
        default:
            return 1
        }
    }

    private var wakeRingIntensity: Double {
        switch openingPhase {
        case .awakening:
            return 1.18
        case .tension:
            return 1.04
        case .release:
            return 1.58
        case .afterglow, .returning:
            return 0
        default:
            return 1
        }
    }

    private var wakeRingCount: Int {
        openingPhase == .release ? 1 : 3
    }

    private var currentCapsuleDiameter: CGFloat {
        size * 1.25 * glowScale
    }

    private var wakeRingExpansion: Double {
        switch openingPhase {
        case .awakening:
            return 0.82
        case .tension:
            return 1.42
        case .release:
            return 2.65
        case .afterglow:
            return 2.15
        default:
            return 1
        }
    }

    private var wakeRingSoftness: Double {
        switch openingPhase {
        case .awakening:
            return 1.28
        case .tension:
            return 3.35
        case .release:
            return 3.05
        case .afterglow:
            return 4.2
        default:
            return 1
        }
    }

    private var releaseGlowOpacity: Double {
        switch openingPhase {
        case .idle:
            return 0
        case .awakening:
            return 0.24
        case .tension:
            return 0.50
        case .release:
            return 1
        case .afterglow:
            return 0
        case .returning:
            return 0
        }
    }

    private var releaseGlowScale: CGFloat {
        switch openingPhase {
        case .idle:
            return 0.72
        case .awakening:
            return 1.14
        case .tension:
            return 2.35
        case .release:
            return 5.2
        case .afterglow:
            return 1
        case .returning:
            return 1
        }
    }

    private var releaseGlowBlur: CGFloat {
        switch openingPhase {
        case .idle:
            return 0
        case .awakening:
            return size * 0.04
        case .tension:
            return size * 0.12
        case .release:
            return size * 0.14
        case .afterglow:
            return 0
        case .returning:
            return 0
        }
    }

    private var releaseGlowCenterOpacity: Double {
        switch openingPhase {
        case .tension:
            return 0.18
        case .release:
            return 0.96
        case .afterglow:
            return 0
        default:
            return 0.18
        }
    }

    private var releaseGlowMidOpacity: Double {
        switch openingPhase {
        case .tension:
            return 0.42
        case .release:
            return 0.86
        case .afterglow:
            return 0
        default:
            return 0.24
        }
    }

    private var releaseGlowEdgeOpacity: Double {
        switch openingPhase {
        case .tension:
            return 0.38
        case .release:
            return 0.52
        case .afterglow:
            return 0
        default:
            return 0.12
        }
    }

    private var glowScale: CGFloat {
        if reduceMotion { return 1 }
        if openingPhase == .awakening { return isEager ? 1.32 : 1.08 }
        if openingPhase == .tension { return isEager ? 1.34 : 1.16 }
        if openingPhase == .release { return 1.18 }
        if openingPhase == .afterglow { return 1 }
        guard !freezesMotion else { return 1 }
        guard capsule.status == .sealed else { return 1 }
        if capsule.isReadyToOpen {
            return 1.18
        }
        return isBreathing ? 1.10 : 0.96
    }

    private var glowOpacity: Double {
        if openingPhase == .awakening { return isEager && !reduceMotion ? 1 : 0.76 }
        if openingPhase == .tension { return 0.72 }
        if openingPhase == .release { return 0.40 }
        if openingPhase == .afterglow { return 0 }
        guard capsule.status == .sealed else { return 0.58 }
        if capsule.isReadyToOpen {
            return isEager && !reduceMotion ? 0.95 : 0.70
        }
        return isBreathing && !reduceMotion ? 0.78 : 0.58
    }

    private var shadowRadius: CGFloat {
        if openingPhase == .awakening {
            return size * (isEager && !reduceMotion ? 0.36 : 0.26)
        }

        if openingPhase == .tension {
            return size * 0.26
        }

        if openingPhase == .release {
            return size * 0.16
        }

        if openingPhase == .afterglow {
            return 0
        }

        guard capsule.status == .sealed else { return size * 0.18 }
        if capsule.isReadyToOpen {
            return size * (isEager && !reduceMotion ? 0.30 : 0.23)
        }
        return size * (isBreathing && !reduceMotion ? 0.24 : 0.20)
    }

    private var symbolScale: CGFloat {
        if openingPhase == .awakening { return isEager && !reduceMotion ? 1.10 : 0.96 }
        if openingPhase == .tension { return 1.36 }
        if openingPhase == .release { return 2.05 }
        if openingPhase == .afterglow { return 2.05 }
        guard !freezesMotion else { return 1 }
        guard capsule.status == .sealed, capsule.isReadyToOpen, !reduceMotion else { return 1 }
        return 1
    }

    private var verticalOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        guard !freezesMotion else { return 0 }
        guard capsule.status == .sealed else { return 0 }
        if capsule.isReadyToOpen {
            return 0
        }
        return isBreathing ? -size * 0.018 : size * 0.012
    }

    private var rotation: Double {
        0
    }

    private var symbolOpacity: Double {
        switch openingPhase {
        case .idle, .awakening:
            return 0.90
        case .tension:
            return 1
        case .release:
            return 0.52
        case .afterglow:
            return 0
        case .returning:
            return 0
        }
    }

    private func startPressEffect() {
        guard !freezesMotion, capsule.status == .sealed, isInteractive, !reduceMotion, !isPressingOrb else { return }

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

    private func updateOpeningHaptics(for phase: CapsuleOrbOpeningPhase) {
        guard !reduceMotion else { return }

        switch phase {
        case .awakening:
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: 0.16)
        case .tension:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred(intensity: 0.44)
        case .release:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred(intensity: 1)
        default:
            break
        }
    }

    private func stopMotionEffects() {
        stopPressTasks()
        isBreathing = false
        isEager = false
        isShimmering = false
        isPressingOrb = false
    }
}

private struct CapsuleOrbRippleOverlay: View {
    let color: Color
    let highlight: Color
    let size: CGFloat
    let phase: Double
    let expansion: Double
    let intensity: Double

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity((index.isMultiple(of: 3) ? 0.34 : 0.18) * intensity),
                                highlight.opacity((index.isMultiple(of: 2) ? 0.46 : 0.32) * intensity),
                                color.opacity(0.22 * intensity),
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
        let radius = bubbleRadius(for: index) * expansion
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

private struct CapsuleOrbWakeRings: View {
    let color: Color
    let size: CGFloat
    let startDiameter: CGFloat
    let time: TimeInterval
    let intensity: Double
    let expansion: Double
    let softness: Double
    let duration: TimeInterval
    let ringCount: Int

    var body: some View {
        ZStack {
            ForEach(0..<ringCount, id: \.self) { index in
                let progress = ringProgress(for: index)

                Circle()
                    .stroke(color.opacity(ringOpacity(for: progress)), lineWidth: ringWidth(for: progress))
                    .frame(width: startDiameter, height: startDiameter)
                    .scaleEffect(1 + CGFloat(progress) * 0.62 * CGFloat(expansion))
                    .blur(radius: size * (0.006 + CGFloat(progress) * 0.020) * CGFloat(softness))
            }
        }
        .frame(
            width: startDiameter * (1.65 + CGFloat(expansion - 1) * 0.64),
            height: startDiameter * (1.65 + CGFloat(expansion - 1) * 0.64)
        )
    }

    private func ringProgress(for index: Int) -> Double {
        let offset = ringCount > 1 ? duration / Double(ringCount) * Double(index) : 0
        let shiftedTime = time + offset
        return shiftedTime.truncatingRemainder(dividingBy: duration) / duration
    }

    private func ringOpacity(for progress: Double) -> Double {
        let fadeIn = min(progress / 0.16, 1)
        let fadeOut = max(1 - progress, 0)
        return 0.56 * intensity * fadeIn * pow(fadeOut, 1.55)
    }

    private func ringWidth(for progress: Double) -> CGFloat {
        max(size * (0.030 + CGFloat(softness - 1) * 0.010 - CGFloat(progress) * 0.010), 1.4)
    }
}
