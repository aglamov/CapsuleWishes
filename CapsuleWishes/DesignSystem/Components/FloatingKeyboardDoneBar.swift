//
//  FloatingKeyboardDoneBar.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct FloatingKeyboardDoneBar: View {
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        if isVisible {
            HStack {
                Spacer()

                Button("Готово", action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.12), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(.clear)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
