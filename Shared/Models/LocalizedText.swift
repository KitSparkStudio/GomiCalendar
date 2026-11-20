//
//  LocalizedText.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// 五语言本地化文案。系统语言不在支持列表内时回退到 `en`，再回退到 `ja`。
struct LocalizedText: Codable, Hashable, Sendable {
    var ja: String
    /// 日语平假名读音（検索・読み上げ用）。仅日语名称需要。
    var kana: String?
    var en: String
    var zhHans: String
    var vi: String
    var ko: String

    enum CodingKeys: String, CodingKey {
        case ja, kana, en, vi, ko
        case zhHans = "zh-Hans"
    }

    /// 按应用语言设置（含 Auto）解析；不在支持列表内则回退 `en` → `ja`。
    /// 优先读取 `@AppStorage("selectedLanguage")` / App Group，保证语言切换瞬间刷新内容文案。
    func resolved(locale: Locale = .autoupdatingCurrent) -> String {
        if let override = Self.inAppLanguageCode() {
            return text(for: override)
        }
        return text(for: Self.preferredLanguageCode(from: locale))
    }

    private func text(for code: String) -> String {
        switch code {
        case "ja": return ja
        case "en": return en.isEmpty ? ja : en
        case "zh-Hans": return zhHans
        case "vi": return vi
        case "ko": return ko
        default:
            return en.isEmpty ? ja : en
        }
    }

    private static func inAppLanguageCode() -> String? {
        let group = UserDefaults(suiteName: "group.com.kitsparkstudio.gomicalendar")
        let raw = group?.string(forKey: "selectedLanguage")
            ?? UserDefaults.standard.string(forKey: "selectedLanguage")
        guard let raw, raw != "auto" else { return nil }
        switch raw {
        case "ja", "en", "zh-Hans", "vi", "ko":
            return raw
        default:
            return nil
        }
    }

    static func preferredLanguageCode(from locale: Locale) -> String {
        let preferred = Locale.preferredLanguages.first ?? locale.identifier
        let lowered = preferred.lowercased()

        if lowered.hasPrefix("ja") { return "ja" }
        if lowered.hasPrefix("en") { return "en" }
        if lowered.hasPrefix("vi") { return "vi" }
        if lowered.hasPrefix("ko") { return "ko" }
        // 简体中文：zh-Hans / zh-CN / zh-SG 等
        if lowered.hasPrefix("zh-hans") || lowered.hasPrefix("zh-cn") || lowered.hasPrefix("zh-sg") {
            return "zh-Hans"
        }
        // 繁体中文：内容回退简体（五语言目标含 zh-Hans）；搜索层另做繁简折叠
        if lowered.hasPrefix("zh-hant") || lowered.hasPrefix("zh-tw") || lowered.hasPrefix("zh-hk") || lowered.hasPrefix("zh-mo") {
            return "zh-Hans"
        }
        if lowered.hasPrefix("zh") {
            return "zh-Hans"
        }
        return "en"
    }
}
