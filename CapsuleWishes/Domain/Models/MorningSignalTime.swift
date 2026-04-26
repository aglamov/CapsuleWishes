//
//  MorningSignalTime.swift
//  CapsuleWishes
//
//  Created by Codex on 26.04.2026.
//

import Foundation

struct MorningSignalTime: Hashable {
    var hour: Int
    var minute: Int

    private var totalMinutes: Int {
        hour * 60 + minute
    }

    static let defaultValue = MorningSignalTime(hour: 8, minute: 30)

    static let presets: [MorningSignalTime] = [
        MorningSignalTime(hour: 7, minute: 30),
        MorningSignalTime(hour: 8, minute: 30),
        MorningSignalTime(hour: 10, minute: 0),
    ]

    static func from(totalMinutes: Int) -> MorningSignalTime {
        let clampedMinutes = min(max(totalMinutes, 5 * 60), 12 * 60)
        return MorningSignalTime(hour: clampedMinutes / 60, minute: clampedMinutes % 60)
    }

    func adjustedToward(_ target: MorningSignalTime, weight: Double = 0.35) -> MorningSignalTime {
        let delta = Double(target.totalMinutes - totalMinutes)
        let adjustedMinutes = Double(totalMinutes) + delta * weight
        let roundedToFiveMinutes = Int((adjustedMinutes / 5).rounded() * 5)
        return MorningSignalTime.from(totalMinutes: roundedToFiveMinutes)
    }

    var title: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
