//
//  AppTheme.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI

enum AppTheme {
    static let lightBackground = Color(hex: 0xF7F8FA)
    static let darkBackground = Color(hex: 0x0B0E11)
    static let darkCard = Color(hex: 0x161A1E)
    static let lightCard = Color.white
    static let danger = Color(hex: 0xFF3B30)

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackground : lightBackground
    }

    static func card(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkCard : lightCard
    }
}

extension Color {
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

extension WasteCategory {
    var themeColor: Color { Color(hexString: themeColorHex) }
}
