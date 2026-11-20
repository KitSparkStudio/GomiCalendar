//
//  GomiActivityAttributes.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import ActivityKit
import Foundation

/// 灵动岛 / 锁屏实时活动属性（主 App 与 WidgetExtension 共享）。
/// `nonisolated`：避免主 App 的默认 MainActor 隔离污染 ActivityKit 并发边界。
nonisolated struct GomiActivityAttributes: ActivityAttributes, Sendable {
    /// 动态内容：打卡状态 + 截止时刻（供 `Text(timerInterval:)` 绑定）。
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        /// 用户是否已点「已丢出」
        var isCompleted: Bool
        /// 展示用副文案（可随语言更新）
        var statusCaption: String
        /// 投放截止目标时间（与 attributes.deadlineDate 一致，供 UI 实时倒计时）
        var deadline: Date
    }

    /// 垃圾分类名称（已按语言解析）
    var categoryName: String
    /// 紧凑态用 2 字简称（如「可燃」）
    var compactCategoryLabel: String
    /// 主题色 Hex，如 `#FF6B4A`
    var themeColorHex: String
    /// 指定垃圾袋类型说明
    var bagTypeLabel: String
    /// 当前町名
    var districtName: String
    /// 投放截止目标时间（东京日历日的 deadline，如今日 08:00）
    var deadlineDate: Date
    /// SF Symbol 名称（按分类挑选）
    var symbolName: String

    nonisolated static func symbolName(for categoryId: String) -> String {
        switch categoryId {
        case "combustible": return "flame.fill"
        case "nonCombustible": return "cube.transparent.fill"
        case "recyclable": return "arrow.3.trianglepath"
        case "hazardous": return "exclamationmark.triangle.fill"
        case "oversized": return "sofa.fill"
        default: return "trash.fill"
        }
    }

    nonisolated static func compactLabel(for categoryId: String) -> String {
        // L10n 在非 MainActor 下可读（纯字典）；Widget / App 共用。
        switch categoryId {
        case "combustible": return L10n.t("live_activity_cat_combustible")
        case "nonCombustible": return L10n.t("live_activity_cat_noncombustible")
        case "recyclable": return L10n.t("live_activity_cat_recyclable")
        case "hazardous": return L10n.t("live_activity_cat_hazardous")
        case "oversized": return L10n.t("live_activity_cat_oversized")
        default: return L10n.t("live_activity_cat_combustible")
        }
    }
}
