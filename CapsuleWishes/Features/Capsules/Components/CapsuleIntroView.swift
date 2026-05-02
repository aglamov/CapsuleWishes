//
//  CapsuleIntroView.swift
//  CapsuleWishes
//
//  Created by Codex on 02.05.2026.
//

import SwiftUI

struct CapsuleIntroView: View {
    let continueAction: () -> Void
    let createAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.10))
                            .frame(width: 82, height: 82)
                            .blur(radius: 1)

                        Image(systemName: "sparkles")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .white.opacity(0.28), radius: 26)
                    .accessibilityHidden(true)

                    Text("Здесь желания получают время")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Капсула не обещает чудо по расписанию. Она помогает бережно сформулировать желание, прожить с ним несколько дней и потом увидеть, что изменилось внутри и вокруг.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.74))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    introRow(
                        icon: "lock.fill",
                        title: "Запечатай намерение",
                        text: "Опиши желание и чувство, которое стоит за ним."
                    )

                    introRow(
                        icon: "book.closed.fill",
                        title: "Замечай путь",
                        text: "Сохраняй сны, знаки, мысли и маленькие шаги в дневнике."
                    )

                    introRow(
                        icon: "lock.open.fill",
                        title: "Открой позже",
                        text: "Вернись к капсуле в выбранный день и честно посмотри, как желание изменилось."
                    )
                }
                .padding(18)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )

                VStack(spacing: 12) {
                    Button {
                        createAction()
                    } label: {
                        Label("Создать первую капсулу", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle())

                    Button {
                        continueAction()
                    } label: {
                        Text("Сначала посмотреть приложение")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryCapsuleButtonStyle())
                }
            }
            .padding(20)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func introRow(icon: String, title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ZStack {
        NightSkyBackground()
        CapsuleIntroView {} createAction: {}
    }
}
