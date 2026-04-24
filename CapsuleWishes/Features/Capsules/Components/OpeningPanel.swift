//
//  OpeningPanel.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct OpeningPanel: View {
    let isOpening: Bool
    let onOutcome: (CapsuleStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Время открыть")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Посмотри на исходное желание и выбери, что с ним произошло. Иногда исполнение выглядит иначе, чем мы представляли.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                outcomeButton(.fulfilled, title: "Сбылось")
                outcomeButton(.unfolding, title: "Сбывается")
                outcomeButton(.changed, title: "Изменилось")
                outcomeButton(.released, title: "Отпустить")
            }
        }
        .padding(18)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func outcomeButton(_ status: CapsuleStatus, title: String) -> some View {
        Button {
            onOutcome(status)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryCapsuleButtonStyle())
        .disabled(isOpening)
        .opacity(isOpening ? 0.62 : 1)
    }
}
