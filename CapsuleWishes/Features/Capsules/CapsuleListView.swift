//
//  CapsuleListView.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftData
import SwiftUI

struct CapsuleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishCapsule.openAt, order: .forward) private var capsules: [WishCapsule]
    @State private var isCreatingCapsule = false
    @State private var highlightedCapsuleID: UUID?
    @State private var selectedCapsule: WishCapsule?
    @State private var pendingNavigationTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                NightSkyBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        if capsules.isEmpty {
                            EmptyCapsulesView {
                                isCreatingCapsule = true
                            }
                        } else {
                            VStack(spacing: 18) {
                                capsuleSection(activeCapsules)

                                if !openedCapsules.isEmpty {
                                    openedCapsulesDivider
                                    capsuleSection(openedCapsules)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Капсула желания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreatingCapsule = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Создать капсулу")
                }
            }
            .sheet(isPresented: $isCreatingCapsule) {
                CreateCapsuleView()
            }
            .navigationDestination(item: $selectedCapsule) { capsule in
                CapsuleDetailView(capsule: capsule)
            }
        }
    }

    private func capsuleSection(_ sectionCapsules: [WishCapsule]) -> some View {
        VStack(spacing: 16) {
            ForEach(sectionCapsules) { capsule in
                Button {
                    openCapsuleAfterPause(capsule)
                } label: {
                    CapsuleCard(capsule: capsule, isHighlighted: highlightedCapsuleID == capsule.id)
                }
                .buttonStyle(.plain)
                .disabled(pendingNavigationTask != nil)
            }
        }
    }

    private var openedCapsulesDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)

            Label("Открытые", systemImage: "lock.open.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)
                .fixedSize()

            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Тихое место для желаний")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Запечатай намерение, замечай странности и маленькие радости, а потом открой капсулу в нужный день.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    private var activeCapsules: [WishCapsule] {
        capsules
            .filter { !$0.hasBeenOpened }
            .sorted { first, second in
                if first.openAt != second.openAt {
                    return first.openAt < second.openAt
                }

                return first.createdAt > second.createdAt
            }
    }

    private var openedCapsules: [WishCapsule] {
        capsules
            .filter(\.hasBeenOpened)
            .sorted { first, second in
                let firstOpenedAt = first.openedAt ?? first.openAt
                let secondOpenedAt = second.openedAt ?? second.openAt

                if firstOpenedAt != secondOpenedAt {
                    return firstOpenedAt > secondOpenedAt
                }

                return first.openAt > second.openAt
            }
    }

    private func openCapsuleAfterPause(_ capsule: WishCapsule) {
        guard pendingNavigationTask == nil else { return }

        withAnimation(.easeInOut(duration: 0.38)) {
            highlightedCapsuleID = capsule.id
        }

        pendingNavigationTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.32)) {
                    selectedCapsule = capsule
                    highlightedCapsuleID = nil
                }
                pendingNavigationTask = nil
            }
        }
    }
}
