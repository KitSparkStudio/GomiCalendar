//
//  SearchNormalizer.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

enum SearchNormalizer {
    /// 大小写 / 全半角 / 变音符号不敏感；片假名→平假名；繁体→简体，便于多语言同条检索。
    static func folded(_ string: String) -> String {
        var result = string
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        result = katakanaToHiragana(result)
        result = traditionalToSimplified(result)
        return result
    }

    static func matches(_ query: String, in candidates: [String]) -> Bool {
        let q = folded(query)
        guard !q.isEmpty else { return true }
        return candidates.contains { folded($0).contains(q) }
    }

    /// 词典条目多语言 token（日汉字/假名、英、简中、繁中检索、越、韩）。
    static func dictionaryTokens(for item: WasteItemEntry) -> [String] {
        var result: [String] = [
            item.names.ja,
            item.names.en,
            item.names.zhHans,
            item.names.vi,
            item.names.ko,
        ]
        if let kana = item.names.kana {
            result.append(kana)
            result.append(hiraganaToKatakana(kana))
        }
        result.append(contentsOf: item.keywords.ja)
        result.append(contentsOf: item.keywords.en)
        result.append(contentsOf: item.keywords.zhHans)
        result.append(contentsOf: item.keywords.vi)
        result.append(contentsOf: item.keywords.ko)
        // tips 中的清洗/去盖等关键词也可命中
        result.append(item.tips.ja)
        result.append(item.tips.en)
        result.append(item.tips.zhHans)
        result.append(item.tips.ko)
        return result
    }

    // MARK: - Kana

    static func katakanaToHiragana(_ string: String) -> String {
        String(string.unicodeScalars.map { scalar -> Character in
            let v = scalar.value
            // ァ(0x30A1)…ン(0x30F3) → ぁ…ん
            if (0x30A1...0x30F6).contains(v) {
                return Character(UnicodeScalar(v - 0x60)!)
            }
            return Character(scalar)
        })
    }

    static func hiraganaToKatakana(_ string: String) -> String {
        String(string.unicodeScalars.map { scalar -> Character in
            let v = scalar.value
            if (0x3041...0x3096).contains(v) {
                return Character(UnicodeScalar(v + 0x60)!)
            }
            return Character(scalar)
        })
    }

    // MARK: - Chinese

    static func traditionalToSimplified(_ string: String) -> String {
        let mutable = NSMutableString(string: string)
        CFStringTransform(mutable, nil, "Traditional-Simplified" as CFString, false)
        return mutable as String
    }
}

/// 五十音行快捷筛选。
enum GojuonRow: String, CaseIterable, Identifiable, Sendable {
    case all
    case a, ka, sa, ta, na, ha, ma, ya, ra, wa

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return L10n.t("gojuon_all")
        case .a: return "あ"
        case .ka: return "か"
        case .sa: return "さ"
        case .ta: return "た"
        case .na: return "な"
        case .ha: return "は"
        case .ma: return "ま"
        case .ya: return "や"
        case .ra: return "ら"
        case .wa: return "わ"
        }
    }

    private var kanaSet: Set<Character> {
        switch self {
        case .all: return []
        case .a: return Set("あいうえおぁぃぅぇぉアイウエオ")
        case .ka: return Set("かきくけこがぎぐげごカキクケコ")
        case .sa: return Set("さしすせそざじずぜぞサシスセソ")
        case .ta: return Set("たちつてとだぢづでどっタチツテトッ")
        case .na: return Set("なにぬねのナニヌネノ")
        case .ha: return Set("はひふへほばびぶべぼぱぴぷぺぽハヒフヘホ")
        case .ma: return Set("まみむめもマミムメモ")
        case .ya: return Set("やゆよゃゅょヤユヨ")
        case .ra: return Set("らりるれろラリルレロ")
        case .wa: return Set("わをんワヲン")
        }
    }

    func matches(kana: String?) -> Bool {
        guard self != .all else { return true }
        guard let first = kana?.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return false
        }
        return kanaSet.contains(first)
    }
}
