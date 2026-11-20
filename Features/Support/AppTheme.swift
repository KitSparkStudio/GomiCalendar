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

    /// 当前全局强调色（跟随 `AccentTheme` / App Group）。
    static var accent: Color { AccentTheme.current.color }

    /// 精选强调色常量（与 `AccentTheme` 一一对应）。
    static let accentEcoGreen = Color(hex: 0x34C759)
    static let accentCoralOrange = Color(hex: 0xFF6B4A)
    static let accentGlacierBlue = Color(hex: 0x00D2FF)
    static let accentAmberGold = Color(hex: 0xF59E0B)

    /// 可选强调色列表（设置页色块选择器）。
    static var accentOptions: [AccentTheme] { AccentTheme.allCases }

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
