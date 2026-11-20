//
//  AppLanguage.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// `@AppStorage("selectedLanguage")` 使用的语言码。
/// `auto` 在设置页固定显示英文单词「Auto」。
enum AppLanguageCode: String, CaseIterable, Identifiable, Sendable {
    case auto
    case ja
    case en
    case zhHans = "zh-Hans"
    case vi
    case ko

    static let storageKey = "selectedLanguage"

    var id: String { rawValue }

    /// 设置页展示名；跟随系统固定为 `Auto`。
    var settingsLabel: String {
        switch self {
        case .auto: return "Auto"
        case .ja: return "日本語"
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .vi: return "Tiếng Việt"
        case .ko: return "한국어"
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .auto: return nil
        case .ja: return "ja"
        case .en: return "en"
        case .zhHans: return "zh-Hans"
        case .vi: return "vi"
        case .ko: return "ko"
        }
    }

    func resolvedContentCode(systemLocale: Locale = .autoupdatingCurrent) -> String {
        switch self {
        case .auto:
            return LocalizedText.preferredLanguageCode(from: systemLocale)
        case .ja, .en, .zhHans, .vi, .ko:
            return rawValue
        }
    }

    nonisolated static func load() -> AppLanguageCode {
        // Widget / Live Activity 优先读 App Group；主 App 两边都会写入
        let group = UserDefaults(suiteName: "group.com.kitsparkstudio.gomicalendar")
        let raw = group?.string(forKey: storageKey)
            ?? UserDefaults.standard.string(forKey: storageKey)
        if let raw, let value = AppLanguageCode(rawValue: raw) {
            return value
        }
        return .auto
    }

    nonisolated func persist() {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
        UserDefaults(suiteName: "group.com.kitsparkstudio.gomicalendar")?.set(rawValue, forKey: Self.storageKey)
    }
}

extension LocalizedText {
    /// 尊重 `@AppStorage("selectedLanguage")`（与 `resolved()` 同源）。
    func resolvedForApp() -> String {
        resolved()
    }
}
