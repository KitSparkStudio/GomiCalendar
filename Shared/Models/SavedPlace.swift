//
//  SavedPlace.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// 常用地区标签。
enum PlaceLabelKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case home
    case work
    case family
    case other

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .home: return "🏠"
        case .work: return "🏢"
        case .family: return "👪"
        case .other: return "📍"
        }
    }

    var l10nKey: String {
        switch self {
        case .home: return "place_label_home"
        case .work: return "place_label_work"
        case .family: return "place_label_family"
        case .other: return "place_label_other"
        }
    }
}

/// 用户保存的常用地区（可跨城市）。
struct SavedPlace: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var labelKind: PlaceLabelKind
    /// `other` 时的自定义名称
    var customLabel: String?
    var prefectureCode: String
    var prefectureNameJa: String
    var cityId: String
    var cityNameJa: String
    var jisCode: String
    /// 町名 ID（可选）；模板城市通常为 `home`
    var districtId: String?
    /// 可选备注 / 町名展示
    var districtNote: String?
    var hasDetailedRules: Bool

    init(
        id: String = UUID().uuidString,
        labelKind: PlaceLabelKind = .home,
        customLabel: String? = nil,
        prefectureCode: String,
        prefectureNameJa: String,
        cityId: String,
        cityNameJa: String,
        jisCode: String,
        districtId: String? = nil,
        districtNote: String? = nil,
        hasDetailedRules: Bool
    ) {
        self.id = id
        self.labelKind = labelKind
        self.customLabel = customLabel
        self.prefectureCode = prefectureCode
        self.prefectureNameJa = prefectureNameJa
        self.cityId = cityId
        self.cityNameJa = cityNameJa
        self.jisCode = jisCode
        self.districtId = districtId
        self.districtNote = districtNote
        self.hasDetailedRules = hasDetailedRules
    }

    /// 解析后的标签文案（含自定义）。
    func resolvedLabelText() -> String {
        if labelKind == .other {
            let custom = customLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !custom.isEmpty { return custom }
        }
        return L10n.t(labelKind.l10nKey)
    }

    /// 例如 `🏠 自宅・鎌倉市`
    func displayTitle(labelText: String? = nil) -> String {
        let label = labelText ?? resolvedLabelText()
        return "\(labelKind.emoji) \(label)・\(cityNameJa)"
    }

    var regionLine: String {
        if prefectureNameJa.isEmpty { return cityNameJa }
        return "\(prefectureNameJa) / \(cityNameJa)"
    }
}
