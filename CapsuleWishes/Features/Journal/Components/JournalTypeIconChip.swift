//
//  JournalTypeIconChip.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct JournalTypeIconChip: View {
    let type: JournalEntryType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: type.symbolName)
                .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(
                isSelected ? .white.opacity(0.22) : .white.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? .white.opacity(0.34) : .white.opacity(0.10), lineWidth: 1)
            )
            .shadow(
                color: isSelected ? .white.opacity(0.13) : .clear,
                radius: 10,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.title)
    }
}
