//
//  AccentTheme.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/21.
//

import Foundation
import SwiftUI
import WidgetKit

extension Color {
    /// Shared 目标可用的十六进制色（主 App / Widget 共用，避免重复定义）。
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

/// Pro 可切换的全局强调色（App Group 持久化，主 App 与小组件共用）。
enum AccentTheme: String, CaseIterable, Identifiable, Sendable {
    /// 环保绿（默认，免费）
    case ecoGreen
    /// 珊瑚电光橙（Pro）
    case coralOrange
    /// 冰川极光蓝（Pro）
    case glacierBlue
    /// 琥珀暖金（Pro）
    case amberGold

    var id: String { rawValue }

    nonisolated static let storageKey = "accentThemeID"

    /// 是否需要 Pro 才能选用
    var requiresPro: Bool {
        self != .ecoGreen
    }

    var hex: UInt32 {
        switch self {
        case .ecoGreen: return 0x34C759
        case .coralOrange: return 0xFF6B4A
        case .glacierBlue: return 0x00D2FF
        case .amberGold: return 0xF59E0B
        }
    }

    var hexString: String {
        String(format: "#%06X", hex)
    }

    var color: Color {
        Color(hex: hex)
    }

    /// 本地化显示名（走 L10n）
    var displayNameKey: String {
        switch self {
        case .ecoGreen: return "accent_eco_green"
        case .coralOrange: return "accent_coral_orange"
        case .glacierBlue: return "accent_glacier_blue"
        case .amberGold: return "accent_amber_gold"
        }
    }

    nonisolated private static var defaults: UserDefaults {
        UserDefaults(suiteName: ProAccess.appGroupID) ?? .standard
    }

    /// 当前选中主题；若选中 Pro 色但未解锁，回退环保绿。
    nonisolated static var current: AccentTheme {
        let raw = defaults.string(forKey: storageKey) ?? AccentTheme.ecoGreen.rawValue
        let theme = AccentTheme(rawValue: raw) ?? .ecoGreen
        if theme.requiresPro, !ProAccess.isPro {
            return .ecoGreen
        }
        return theme
    }

    /// 写入 App Group 并刷新小组件时间线。
    @MainActor
    static func select(_ theme: AccentTheme, isPro: Bool) -> Bool {
        if theme.requiresPro, !isPro {
            return false
        }
        defaults.set(theme.rawValue, forKey: storageKey)
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .accentThemeDidChange, object: theme.rawValue)
        return true
    }

    /// 退款后若当前是 Pro 色，强制回退免费绿。
    @MainActor
    static func clampToEntitlement(isPro: Bool) {
        let raw = defaults.string(forKey: storageKey) ?? AccentTheme.ecoGreen.rawValue
        guard let theme = AccentTheme(rawValue: raw), theme.requiresPro, !isPro else { return }
        _ = select(.ecoGreen, isPro: true)
    }
}

extension Notification.Name {
    static let accentThemeDidChange = Notification.Name("accentThemeDidChange")
}
