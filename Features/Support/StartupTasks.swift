//
//  StartupTasks.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation
import WidgetKit

/// 首帧出现后再跑的后台任务，避免冷启动卡顿 / 白屏。
enum StartupTasks {
    @MainActor
    static func runAfterFirstFrame(appModel: AppModel) async {
        #if DEBUG
        ScheduleCalculator.debugAssertInvariants(config: appModel.effectiveConfig)
        #endif

        // 0) 语言写入 App Group，保证 Widget / Live Activity 的 L10n 与主 App 一致
        AppLanguageCode.load().persist()

        // 1) iCloud KV 轻量同步（不阻塞首帧）
        await Task.detached(priority: .utility) {
            _ = NSUbiquitousKeyValueStore.default.synchronize()
        }.value

        // 2) StoreKit 历史权益校验（正式包默认未解锁，仅在有有效终身买断交易后打开）
        ProStore.shared.startIfNeeded()
        await ProStore.shared.refresh()

        // 3) 远端规则热更新（无网静默失败）
        await appModel.checkRuleUpdates(userInitiated: false)

        // 4) 小组件时间线刷新（依赖 App Group 最新地区 / Pro 状态）
        WidgetCenter.shared.reloadAllTimelines()

        // 5) 若已选地区，静默重建通知
        if let districtId = appModel.settings.selectedDistrictId {
            await NotificationScheduler.shared.reschedule(
                config: appModel.effectiveConfig,
                districtId: districtId,
                preferences: NotificationPreferences.load(),
                temporaryRules: appModel.activeTemporaryRules
            )
        }

        // 6) 灵动岛：有岛设备 + 默认开启时静默启动 / 刷新
        await GomiLiveActivityManager.shared.syncAutomatically {
            LiveActivityPayloadBuilder.make(from: appModel)
        }
    }
}

/// 从当前 AppModel 推导灵动岛启动数据（启动续期与看板共用）。
enum LiveActivityPayloadBuilder {
    @MainActor
    static func make(from appModel: AppModel, now: Date = Date()) -> LiveActivityLaunchPayload? {
        guard let districtId = appModel.settings.selectedDistrictId,
              let district = appModel.calculator.district(id: districtId)
        else { return nil }

        let calc = appModel.calculator
        let today = calc.collections(on: now, districtId: districtId)
        let tomorrowDate = JapanCalendar.calendar.date(
            byAdding: .day,
            value: 1,
            to: JapanCalendar.startOfDay(for: now)
        ) ?? now
        let tomorrow = calc.collections(on: tomorrowDate, districtId: districtId)

        let focus: DayCollectionResult
        if let hm = JapanCalendar.parseHourMinute(today.dropoffDeadline) {
            var components = JapanCalendar.calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = hm.hour
            components.minute = hm.minute
            components.second = 0
            components.timeZone = JapanCalendar.timeZone
            let beforeDeadline = (JapanCalendar.calendar.date(from: components).map { now < $0 }) ?? false
            if beforeDeadline, today.hasCollection || today.isSuspended {
                focus = today
            } else {
                focus = tomorrow
            }
        } else {
            focus = tomorrow
        }

        guard !focus.isSuspended else { return nil }
        let placeTitle = appModel.settings.activePlace?.displayTitle()
            ?? appModel.settings.selectedCityLabel
        let districtLabel: String = {
            if appModel.showsDetailedDistrictPicker {
                return "\(placeTitle) · \(district.names.resolved())"
            }
            return placeTitle
        }()
        return LiveActivityLaunchPayload.from(
            focus: focus,
            districtName: districtLabel,
            now: now
        )
    }
}
