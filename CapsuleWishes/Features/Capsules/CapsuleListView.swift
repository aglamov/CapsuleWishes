//
//  CapsuleListView.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftData
import SwiftUI

struct CapsuleListView: View {
    @EnvironmentObject private var notificationRouteCenter: NotificationRouteCenter
    @AppStorage("hasSeenCapsuleIntro") private var hasSeenCapsuleIntro = false
    @Query(sort: \WishCapsule.openAt, order: .forward) private var capsules: [WishCapsule]
    @State private var isCreatingCapsule = false
    @State private var isShowingNotificationSettings = false
    @State private var highlightedCapsuleID: UUID?
    @State private var selectedCapsule: WishCapsule?
    @State private var pendingNavigationTask: Task<Void, Never>?
    @State private var readinessRefreshDate = Date()
    private let readinessTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                NightSkyBackground()

                if shouldShowIntro {
                    CapsuleIntroView {
                        withAnimation(.smooth(duration: 0.34)) {
                            hasSeenCapsuleIntro = true
                        }
                    } createAction: {
                        hasSeenCapsuleIntro = true
                        isCreatingCapsule = true
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            header

                            if capsules.isEmpty {
                                EmptyCapsulesView {
                                    isCreatingCapsule = true
                                }
                            } else {
                                VStack(spacing: 18) {
                                    capsuleSection(activeCapsules, showsConstellationThreads: true)

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
            }
            .navigationTitle("Капсула желания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !shouldShowIntro {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isShowingNotificationSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Настроить сигналы")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isCreatingCapsule = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Создать капсулу")
                    }
                }
            }
            .sheet(isPresented: $isCreatingCapsule) {
                CreateCapsuleView()
            }
            .sheet(isPresented: $isShowingNotificationSettings) {
                NotificationSettingsView()
            }
            .navigationDestination(item: $selectedCapsule) { capsule in
                CapsuleDetailView(capsule: capsule)
            }
            .onDisappear {
                pendingNavigationTask?.cancel()
                pendingNavigationTask = nil
                highlightedCapsuleID = nil
            }
            .onAppear {
                openRequestedCapsuleIfPossible()
            }
            .onChange(of: notificationRouteCenter.requestedCapsuleID) { _, _ in
                openRequestedCapsuleIfPossible()
            }
            .onChange(of: capsules.map(\.id)) { _, _ in
                openRequestedCapsuleIfPossible()
            }
            .onReceive(readinessTimer) { date in
                readinessRefreshDate = date
            }
        }
    }

    private func capsuleSection(_ sectionCapsules: [WishCapsule], showsConstellationThreads: Bool = false) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(sectionCapsules.enumerated()), id: \.element.id) { index, capsule in
                Button {
                    openCapsuleAfterPause(capsule)
                } label: {
                    CapsuleCard(
                        capsule: capsule,
                        isHighlighted: highlightedCapsuleID == capsule.id,
                        refreshDate: readinessRefreshDate
                    )
                }
                .buttonStyle(.plain)
                .disabled(pendingNavigationTask != nil)

                if showsConstellationThreads, index < sectionCapsules.count - 1 {
                    CapsuleConstellationThread(
                        fromColor: Color(hex: capsule.colorHex),
                        toColor: Color(hex: sectionCapsules[index + 1].colorHex)
                    )
                    .frame(height: 16)
                    .padding(.horizontal, 28)
                    .opacity(capsule.hasBeenOpened ? 0.18 : 1)
                } else if index < sectionCapsules.count - 1 {
                    Spacer()
                        .frame(height: 16)
                }
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

    private var shouldShowIntro: Bool {
        !hasSeenCapsuleIntro && notificationRouteCenter.requestedCapsuleID == nil
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

        AudioFeedbackService.shared.play(.softSelect)
        withAnimation(.easeInOut(duration: 0.38)) {
            highlightedCapsuleID = capsule.id
        }

        pendingNavigationTask = Task {
            try? await Task.sleep(for: .seconds(0.65))
            guard !Task.isCancelled else {
                await MainActor.run {
                    pendingNavigationTask = nil
                    highlightedCapsuleID = nil
                }
                return
            }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.32)) {
                    selectedCapsule = capsule
                    highlightedCapsuleID = nil
                }
                pendingNavigationTask = nil
            }
        }
    }

    private func openRequestedCapsuleIfPossible() {
        guard let requestedCapsuleID = notificationRouteCenter.requestedCapsuleID,
              let capsule = capsules.first(where: { $0.id == requestedCapsuleID })
        else { return }

        pendingNavigationTask?.cancel()
        pendingNavigationTask = nil
        highlightedCapsuleID = nil
        selectedCapsule = capsule
        notificationRouteCenter.consumeCapsuleOpenRequest()
    }
}

private struct CapsuleConstellationThread: View {
    let fromColor: Color
    let toColor: Color

    var body: some View {
        GeometryReader { proxy in
            let startX = threadX(in: proxy.size.width)
            let endX = threadX(in: proxy.size.width)

            Canvas { context, size in
                var path = Path()
                path.move(to: CGPoint(x: startX, y: 0))
                path.addCurve(
                    to: CGPoint(x: endX, y: size.height),
                    control1: CGPoint(x: startX + 18, y: size.height * 0.28),
                    control2: CGPoint(x: endX - 18, y: size.height * 0.72)
                )

                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            fromColor.opacity(0.52),
                            Color(hex: "FFE3AD").opacity(0.34),
                            toColor.opacity(0.46)
                        ]),
                        startPoint: CGPoint(x: startX, y: 0),
                        endPoint: CGPoint(x: endX, y: size.height)
                    ),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                )

                for sparkle in sparklePoints(startX: startX, endX: endX, height: size.height) {
                    context.fill(
                        Path(ellipseIn: CGRect(x: sparkle.x - 1.4, y: sparkle.y - 1.4, width: 2.8, height: 2.8)),
                        with: .color(.white.opacity(0.34))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func threadX(in width: CGFloat) -> CGFloat {
        min(max(33, 24), max(width - 24, 24))
    }

    private func sparklePoints(startX: CGFloat, endX: CGFloat, height: CGFloat) -> [CGPoint] {
        [
            CGPoint(x: startX + (endX - startX) * 0.35, y: height * 0.38),
            CGPoint(x: startX + (endX - startX) * 0.70, y: height * 0.66)
        ]
    }
}
