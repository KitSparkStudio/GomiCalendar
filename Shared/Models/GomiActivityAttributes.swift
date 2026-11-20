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
    /// 动态内容：打卡状态等。
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        /// 用户是否已点「已丢出」
        var isCompleted: Bool
        /// 展示用副文案（可随语言更新）
        var statusCaption: String
    }

    /// 垃圾分类名称（已按语言解析）
    var categoryName: String
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
}
