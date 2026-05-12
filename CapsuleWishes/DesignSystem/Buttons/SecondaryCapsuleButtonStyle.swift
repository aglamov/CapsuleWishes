//
//  SecondaryCapsuleButtonStyle.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct SecondaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.86)
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .background(.white.opacity(configuration.isPressed ? 0.22 : 0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}
