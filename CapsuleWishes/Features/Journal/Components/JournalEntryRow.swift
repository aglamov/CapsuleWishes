//
//  JournalEntryRow.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import SwiftUI

struct JournalEntryRow: View {
    enum TimestampStyle {
        case dateAndTime
        case timeOnly
    }

    let entry: JournalEntry
    let timestampStyle: TimestampStyle

    init(entry: JournalEntry, timestampStyle: TimestampStyle = .dateAndTime) {
        self.entry = entry
        self.timestampStyle = timestampStyle
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.type.symbolName)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(entry.type.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(timestampText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                }

                Text(entry.text)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private var timestampText: String {
        switch timestampStyle {
        case .dateAndTime:
            entry.createdAt.formatted(date: .abbreviated, time: .shortened)
        case .timeOnly:
            entry.createdAt.formatted(date: .omitted, time: .shortened)
        }
    }
}
