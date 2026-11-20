//
//  CompleteGomiDropIntent.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import ActivityKit
import AppIntents
import Foundation
import WidgetKit

enum GomiLiveActivityKeys: Sendable {
    nonisolated static let wantsLiveActivity = "wantsLiveActivity"
    /// 小组件「已投放」打卡：`cityId|districtId|yyyy-MM-dd`
    nonisolated static let widgetDropCompletedKey = "widgetDropCompletedKey"
}

/// 灵动岛 / 中号小组件共用：「已投放」快捷操作。
struct CompleteGomiDropIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Mark dropped"
    static var description = IntentDescription("Mark trash as put out, update the widget, and dismiss Live Activity.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: ProAccess.appGroupID) ?? .standard
        let cityId = defaults.string(forKey: "selectedCityId") ?? ""
        let districtId = defaults.string(forKey: "selectedDistrictId") ?? "home"
        let deadline = {
            let custom = defaults.string(forKey: "customDropoffDeadline")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return custom.isEmpty ? "08:00" : custom
        }()
        let now = Date()
        let focusDate: Date = {
            if Self.isBeforeDeadline(now, deadline: deadline) {
                return JapanCalendar.startOfDay(for: now)
            }
            return JapanCalendar.calendar.date(
                byAdding: .day,
                value: 1,
                to: JapanCalendar.startOfDay(for: now)
            ) ?? JapanCalendar.startOfDay(for: now)
        }()
        let ymd = JapanCalendar.ymdString(from: focusDate)
        defaults.set("\(cityId)|\(districtId)|\(ymd)", forKey: GomiLiveActivityKeys.widgetDropCompletedKey)

        for activity in Activity<GomiActivityAttributes>.activities {
            let done = GomiActivityAttributes.ContentState(
                isCompleted: true,
                statusCaption: L10n.t("live_activity_status_done"),
                deadline: activity.attributes.deadlineDate
            )
            await activity.end(
                ActivityContent(state: done, staleDate: .now),
                dismissalPolicy: .immediate
            )
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "GomiWidget")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    private static func isBeforeDeadline(_ date: Date, deadline: String) -> Bool {
        guard let hm = JapanCalendar.parseHourMinute(deadline) else { return true }
        var components = JapanCalendar.calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hm.hour
        components.minute = hm.minute
        components.second = 0
        components.timeZone = JapanCalendar.timeZone
        guard let deadlineDate = JapanCalendar.calendar.date(from: components) else { return true }
        return date < deadlineDate
    }
}
