//
//  EmptyCapsulesView.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct EmptyCapsulesView: View {
    let createAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.86))

            Text("Первая капсула ждет")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Начни с одного желания. Не самого правильного, а самого живого.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.68))

            Button {
                createAction()
            } label: {
                Label("Создать капсулу", systemImage: "plus")
            }
            .buttonStyle(PrimaryCapsuleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}
