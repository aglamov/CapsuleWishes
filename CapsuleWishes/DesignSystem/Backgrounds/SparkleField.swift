//
//  SparkleField.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct SparkleField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTwinkling = false

    private let sparkles: [CGPoint] = [
        CGPoint(x: 0.12, y: 0.14),
        CGPoint(x: 0.28, y: 0.32),
        CGPoint(x: 0.76, y: 0.18),
        CGPoint(x: 0.88, y: 0.42),
        CGPoint(x: 0.18, y: 0.68),
        CGPoint(x: 0.52, y: 0.78),
        CGPoint(x: 0.72, y: 0.62),
        CGPoint(x: 0.38, y: 0.12)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(sparkles.indices, id: \.self) { index in
                let size: CGFloat = index.isMultiple(of: 3) ? 4 : 2
                let phase = Double(index) * 0.17

                Circle()
                    .fill(.white.opacity(opacity(for: index)))
                    .frame(width: size, height: size)
                    .scaleEffect(scale(for: index))
                    .shadow(color: .white.opacity(0.24), radius: size)
                    .position(
                        x: proxy.size.width * sparkles[index].x + drift(for: index, axis: .horizontal),
                        y: proxy.size.height * sparkles[index].y + drift(for: index, axis: .vertical)
                    )
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.8 + phase)
                            .repeatForever(autoreverses: true)
                            .delay(phase),
                        value: isTwinkling
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            isTwinkling = true
        }
    }

    private func opacity(for index: Int) -> Double {
        let base = index.isMultiple(of: 2) ? 0.34 : 0.18
        guard !reduceMotion else { return base }
        return isTwinkling ? min(base + 0.24, 0.58) : base
    }

    private func scale(for index: Int) -> CGFloat {
        guard !reduceMotion else { return 1 }
        let amount: CGFloat = index.isMultiple(of: 2) ? 0.42 : 0.28
        return isTwinkling ? 1 + amount : 1
    }

    private func drift(for index: Int, axis: Axis) -> CGFloat {
        guard !reduceMotion else { return 0 }

        let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        let distance: CGFloat = index.isMultiple(of: 3) ? 5 : 3

        switch axis {
        case .horizontal:
            return isTwinkling ? distance * direction : -distance * 0.5 * direction
        case .vertical:
            return isTwinkling ? -distance * 0.7 * direction : distance * 0.4 * direction
        }
    }
}
