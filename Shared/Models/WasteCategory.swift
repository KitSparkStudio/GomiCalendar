//
//  WasteCategory.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// 跨城市统一的垃圾分类 ID，便于东京・大阪等城市 JSON 复用同一套模型。
enum WasteCategoryID: String, Codable, CaseIterable, Sendable {
    case combustible
    case nonCombustible
    case recyclable
    case hazardous
    case oversized
}

/// 垃圾袋徽章（指定袋颜色等）。
struct BagBadge: Codable, Hashable, Sendable {
    /// 垃圾袋颜色标识，如 `yellow` / `clear` / `semiClear` / `greenPrint` / `none`
    var style: String
    var label: LocalizedText
}

/// 城市级垃圾分类定义（主题色 + 指定袋徽章）。
struct WasteCategory: Codable, Identifiable, Hashable, Sendable {
    var id: WasteCategoryID
    var names: LocalizedText
    /// 主题色十六进制，如 `#FF6B4A`
    var themeColorHex: String
    var bagBadge: BagBadge
    /// 是否需要预约（粗大ごみ等）
    var requiresAppointment: Bool
    /// 该城市是否实际启用此分类（秋田市无独立不燃ごみ时可为 `false`）
    var isActive: Bool
    var notes: LocalizedText?
}
