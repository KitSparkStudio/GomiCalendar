//
//  GomiLiveActivityManager.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import ActivityKit
import Foundation
import Observation

/// 看板焦点日快照，用于启动 / 续期灵动岛。
struct LiveActivityLaunchPayload: Sendable {
    var categoryName: String
    var themeColorHex: String
    var bagTypeLabel: String
    var districtName: String
    var deadlineDate: Date
    var categoryId: String
}

@Observable
@MainActor
final class GomiLiveActivityManager {
    static let shared = GomiLiveActivityManager()

    private(set) var isActive = false
    private(set) var lastError: String?

    /// 用户偏好：默认开启；仅设置页开关可主动关闭。
    var wantsLiveActivity: Bool {
        didSet {
            defaults.set(wantsLiveActivity, forKey: GomiLiveActivityKeys.wantsLiveActivity)
        }
    }

    private let defaults: UserDefaults

    private init() {
        let suite = UserDefaults(suiteName: ProAccess.appGroupID) ?? .standard
        defaults = suite
        // 缺省 true：老版本未写入过 key 时也默认开启
        if suite.object(forKey: GomiLiveActivityKeys.wantsLiveActivity) == nil {
            suite.set(true, forKey: GomiLiveActivityKeys.wantsLiveActivity)
        }
        wantsLiveActivity = suite.bool(forKey: GomiLiveActivityKeys.wantsLiveActivity)
        isActive = !Activity<GomiActivityAttributes>.activities.isEmpty
    }

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func refreshActiveFlag() {
        isActive = !Activity<GomiActivityAttributes>.activities.isEmpty
    }

    /// 静默同步：有待投放则启动/刷新；无收集则结束；不改动用户偏好。
    func syncAutomatically(payloadProvider: () -> LiveActivityLaunchPayload?) async {
        lastError = nil
        guard DeviceCapability.hasDynamicIsland else {
            await endAll(markPreference: false)
            return
        }
        guard wantsLiveActivity else {
            await endAll(markPreference: false)
            return
        }

        let now = Date()
        guard let payload = payloadProvider(), payload.deadlineDate > now else {
            await endAll(markPreference: false)
            return
        }

        _ = await start(payload: payload, preservePreference: true)
    }

    /// 兼容旧调用名。
    func renewIfNeeded(payloadProvider: () -> LiveActivityLaunchPayload?) async {
        await syncAutomatically(payloadProvider: payloadProvider)
    }

    /// 开启或刷新灵动岛倒计时。
    @discardableResult
    func start(payload: LiveActivityLaunchPayload, preservePreference: Bool = true) async -> Bool {
        lastError = nil
        guard areActivitiesEnabled else {
            lastError = L10n.t("live_activity_disabled")
            await endAll(markPreference: false)
            return false
        }
        guard payload.deadlineDate > Date() else {
            lastError = L10n.t("live_activity_deadline_passed")
            await endAll(markPreference: false)
            return false
        }

        await endAll(markPreference: false)

        let attributes = GomiActivityAttributes(
            categoryName: payload.categoryName,
            themeColorHex: payload.themeColorHex,
            bagTypeLabel: payload.bagTypeLabel,
            districtName: payload.districtName,
            deadlineDate: payload.deadlineDate,
            symbolName: GomiActivityAttributes.symbolName(for: payload.categoryId)
        )
        let state = GomiActivityAttributes.ContentState(
            isCompleted: false,
            statusCaption: L10n.t("live_activity_status_counting")
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: payload.deadlineDate),
                pushType: nil
            )
            if !preservePreference {
                wantsLiveActivity = true
            }
            refreshActiveFlag()
            return true
        } catch {
            lastError = error.localizedDescription
            refreshActiveFlag()
            return false
        }
    }

    func endAll(markPreference: Bool = true) async {
        for activity in Activity<GomiActivityAttributes>.activities {
            let done = GomiActivityAttributes.ContentState(
                isCompleted: true,
                statusCaption: L10n.t("live_activity_status_done")
            )
            await activity.end(
                ActivityContent(state: done, staleDate: Date()),
                dismissalPolicy: .immediate
            )
        }
        if markPreference {
            wantsLiveActivity = false
        }
        refreshActiveFlag()
    }
}

extension LiveActivityLaunchPayload {
    /// 从看板焦点日构建 payload；无收集分类时返回 nil。
    static func from(
        focus: DayCollectionResult,
        districtName: String,
        now: Date = Date()
    ) -> LiveActivityLaunchPayload? {
        guard let category = focus.categories.first else { return nil }
        guard let hm = JapanCalendar.parseHourMinute(focus.dropoffDeadline) else { return nil }

        var components = JapanCalendar.calendar.dateComponents(
            [.year, .month, .day],
            from: focus.date
        )
        components.hour = hm.hour
        components.minute = hm.minute
        components.second = 0
        components.timeZone = JapanCalendar.timeZone
        guard let deadline = JapanCalendar.calendar.date(from: components), deadline > now else {
            return nil
        }

        return LiveActivityLaunchPayload(
            categoryName: focus.categories.map { $0.names.resolved() }.joined(separator: " · "),
            themeColorHex: category.themeColorHex,
            bagTypeLabel: category.bagBadge.label.resolved(),
            districtName: districtName,
            deadlineDate: deadline,
            categoryId: category.id.rawValue
        )
    }
}
