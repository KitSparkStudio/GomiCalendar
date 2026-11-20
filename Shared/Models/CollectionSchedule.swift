//
//  CollectionSchedule.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// 日本常见三种收集周期。
enum CollectionScheduleKind: String, Codable, Sendable {
    /// 每周固定星期几（可多个）
    case weekly
    /// 每月第 N 个星期几（如第1・第3个星期二）
    case monthlyNthWeekday
    /// 双周循环（隔周）
    case biweekly
}

/// 双周奇偶：以 `anchorDate` 所在周为基准。
enum BiweeklyParity: String, Codable, Sendable {
    case odd
    case even
}

/// 某分类在某町名下的收集规则。
///
/// `weekday` / `weekdays` 使用 ISO 8601：1 = 月曜日 … 7 = 日曜日。
struct CollectionSchedule: Codable, Hashable, Sendable {
    var categoryId: WasteCategoryID
    var kind: CollectionScheduleKind

    /// `weekly`：每周投放的星期几列表
    var weekdays: [Int]?

    /// `monthlyNthWeekday` / `biweekly`：目标星期几
    var weekday: Int?

    /// `monthlyNthWeekday`：月份内第几个该星期几，如 `[1, 3]`
    var weeksOfMonth: [Int]?

    /// `biweekly`：锚定日（`YYYY-MM-DD`），用于判定奇偶周
    var biweeklyAnchor: String?

    /// `biweekly`：相对锚定周的奇偶
    var biweeklyParity: BiweeklyParity?

    enum CodingKeys: String, CodingKey {
        case categoryId, kind, weekdays, weekday, weeksOfMonth
        case biweeklyAnchor, biweeklyParity
    }
}
