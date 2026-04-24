//
//  CapsuleOrbView.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct CapsuleOrbView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false
    @State private var isEager = false

    let capsule: WishCapsule
    let size: CGFloat

    var body: some View {
        let color = Color(hex: capsule.colorHex)
        let ready = capsule.isReadyToOpen

        ZStack {
            Circle()
                .fill(color.opacity(ready ? 0.26 : 0.16))
                .frame(width: size * 1.25, height: size * 1.25)
                .blur(radius: size * (ready ? 0.15 : 0.12))
                .scaleEffect(glowScale)
                .opacity(glowOpacity)

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
                    Circle()
                        .stroke(.white.opacity(0.36), lineWidth: 1)
                }

            Image(systemName: capsule.symbol)
                .font(.system(size: size * 0.30, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .scaleEffect(symbolScale)
        }
        .scaleEffect(orbScale)
        .offset(y: verticalOffset)
        .rotationEffect(.degrees(rotation))
        .accessibilityLabel(capsule.title)
        .animation(reduceMotion ? nil : breathingAnimation, value: isBreathing)
        .animation(reduceMotion ? nil : eagerAnimation, value: isEager)
        .onAppear {
            guard !reduceMotion else { return }
            isBreathing = true
            isEager = capsule.isReadyToOpen
        }
        .onChange(of: capsule.isReadyToOpen) { _, isReady in
            guard !reduceMotion else { return }
            isEager = isReady
        }
    }

    private var breathingAnimation: Animation {
        .easeInOut(duration: 2.8).repeatForever(autoreverses: true)
    }

    private var eagerAnimation: Animation {
        .interpolatingSpring(stiffness: 250, damping: 7)
            .repeatForever(autoreverses: true)
            .speed(1.7)
    }

    private var orbScale: CGFloat {
        if reduceMotion { return 1 }
        if capsule.isReadyToOpen {
            return isEager ? 1.045 : 0.985
        }
        return isBreathing ? 1.025 : 0.985
    }

    private var glowScale: CGFloat {
        if reduceMotion { return 1 }
        if capsule.isReadyToOpen {
            return isEager ? 1.22 : 1.02
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
        return isEager ? 1.08 : 0.96
    }

    private var verticalOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        if capsule.isReadyToOpen {
            return isEager ? -size * 0.045 : size * 0.018
        }
        return isBreathing ? -size * 0.018 : size * 0.012
    }

    private var rotation: Double {
        guard capsule.isReadyToOpen, !reduceMotion else { return 0 }
        return isEager ? 2.2 : -1.8
    }
}
