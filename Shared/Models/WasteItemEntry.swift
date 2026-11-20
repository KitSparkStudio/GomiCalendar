//
//  WasteItemEntry.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// 垃圾分类速查词典条目。
struct WasteItemEntry: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var categoryId: WasteCategoryID
    var names: LocalizedText
    /// 五语言搜索关键词（可含别名・俗称）
    var keywords: LocalizedKeywords
    /// 投放前预处理避坑提示
    var tips: LocalizedText
}

/// 按语言拆分的搜索关键词。
struct LocalizedKeywords: Codable, Hashable, Sendable {
    var ja: [String]
    var en: [String]
    var zhHans: [String]
    var vi: [String]
    var ko: [String]

    enum CodingKeys: String, CodingKey {
        case ja, en, vi, ko
        case zhHans = "zh-Hans"
    }

    func all(for locale: Locale = .autoupdatingCurrent) -> [String] {
        switch LocalizedText.preferredLanguageCode(from: locale) {
        case "ja": return ja
        case "zh-Hans": return zhHans
        case "vi": return vi
        case "ko": return ko
        default: return en
        }
    }
}
