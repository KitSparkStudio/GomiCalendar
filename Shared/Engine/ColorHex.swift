//
//  ColorHex.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/21.
//

import SwiftUI

extension Color {
    /// Shared 目标可用的十六进制色（主 App / Widget 共用）。
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    init(hexString: String) {
        var cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(hex: UInt32(value))
    }
}
