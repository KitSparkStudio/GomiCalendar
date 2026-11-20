//
//  DistrictRule.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// 町名・地区规则样本（按町名匹配用户住址）。
struct DistrictRule: Codable, Identifiable, Hashable, Sendable {
    /// 稳定 ID，如 `hiromote`
    var id: String
    var names: LocalizedText
    /// 匹配用别名（含常见写法・片假名）
    var aliases: [String]
    var schedules: [CollectionSchedule]
}
