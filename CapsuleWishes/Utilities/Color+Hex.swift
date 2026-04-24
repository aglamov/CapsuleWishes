//
//  Color+Hex.swift
//  CapsuleWishes
//
//  Created by Codex on 24.04.2026.
//

import Foundation
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch hex.count {
        case 6:
            (red, green, blue) = ((int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:
            (red, green, blue) = (118, 214, 255)
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}
