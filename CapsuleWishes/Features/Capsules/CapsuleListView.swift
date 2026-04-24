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
    @Query(sort: \WishCapsule.createdAt, order: .reverse) private var capsules: [WishCapsule]
    @State private var isCreatingCapsule = false

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
                            VStack(spacing: 16) {
                                ForEach(capsules) { capsule in
                                    NavigationLink {
                                        CapsuleDetailView(capsule: capsule)
                                    } label: {
                                        CapsuleCard(capsule: capsule)
                                    }
                                    .buttonStyle(.plain)
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
        }
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
}
