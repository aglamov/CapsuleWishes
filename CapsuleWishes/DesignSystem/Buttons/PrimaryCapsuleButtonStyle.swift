//
//  PrimaryCapsuleButtonStyle.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.45, green: 0.70, blue: 1.0),
                        Color(red: 0.73, green: 0.54, blue: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}
