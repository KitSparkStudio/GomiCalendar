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

    /// 统一默认强调色（环保绿）。
    static let accent = Color(hex: 0x34C759)

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackground : lightBackground
    }

    static func card(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkCard : lightCard
    }
}

extension WasteCategory {
    var themeColor: Color { Color(hexString: themeColorHex) }
}
