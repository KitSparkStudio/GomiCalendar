//
//  NotificationScheduler.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation
import UserNotifications

/// 用户可独立开关的提醒偏好（存 App Group，主 App / Widget 共享）。
struct NotificationPreferences: Codable, Equatable, Sendable {
    /// 前一天晚上提醒
    var eveningEnabled: Bool
    /// 默认 21:00
    var eveningTime: String
    /// 当天早晨提醒
    var morningEnabled: Bool
    /// 默认 07:00
    var morningTime: String

    static let `default` = NotificationPreferences(
        eveningEnabled: true,
        eveningTime: "21:00",
        morningEnabled: true,
        morningTime: "07:00"
    )

    private static let storageKey = "notificationPreferences"
    private static let appGroupID = "group.com.kitsparkstudio.gomicalendar"

    nonisolated private static var suite: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    nonisolated static func load() -> NotificationPreferences {
        guard let data = suite.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    nonisolated func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.suite.set(data, forKey: Self.storageKey)
    }
}

/// 智能本地通知调度器：仅在真正有收运的日期排期，扫描未来 14 天。
@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    /// 本应用通知 identifier 前缀，便于整体取消/重建。
    static let identifierPrefix = "com.kitsparkstudio.gomicalendar.pickup."

    private let center: UNUserNotificationCenter
    /// 向前扫描的天数（含今天）
    var horizonDays: Int

    init(
        center: UNUserNotificationCenter = .current(),
        horizonDays: Int = 14
    ) {
        self.center = center
        self.horizonDays = horizonDays
    }

    // MARK: - Authorization

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        default:
            return false
        }
    }

    // MARK: - Reschedule

    /// 按町名与偏好重建未来通知。无收运日绝不排空提醒。
    func reschedule(
        config: CityWasteConfig,
        districtId: String,
        preferences: NotificationPreferences = .load(),
        temporaryRules: [TemporaryDayRule] = [],
        now: Date = Date()
    ) async {
        await cancelAllManagedNotifications()

        guard preferences.eveningEnabled || preferences.morningEnabled else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let calculator = ScheduleCalculator(config: config, temporaryRules: temporaryRules)
        guard calculator.district(id: districtId) != nil else { return }

        let locale = Locale.autoupdatingCurrent
        let today = JapanCalendar.startOfDay(for: now)
        var requests: [UNNotificationRequest] = []

        for offset in 0..<horizonDays {
            guard let collectionDate = JapanCalendar.calendar.date(byAdding: .day, value: offset, to: today) else {
                continue
            }

            let dayResult = calculator.collections(
                on: collectionDate,
                districtId: districtId,
                includeAppointmentRequired: false
            )

            // 停收日或无任何收运 → 不发通知
            guard dayResult.hasCollection else { continue }

            if preferences.eveningEnabled,
               let evening = JapanCalendar.parseHourMinute(preferences.eveningTime) {
                // 前一天晚上提醒 → 触发日 = 收运日前一天
                if let triggerDate = JapanCalendar.calendar.date(byAdding: .day, value: -1, to: collectionDate) {
                    // 仅当触发时刻仍在「现在」之后才排期（避免补发过期通知）
                    if let request = makeRequest(
                        kind: .evening,
                        triggerDay: triggerDate,
                        hour: evening.hour,
                        minute: evening.minute,
                        collectionDay: dayResult,
                        now: now,
                        locale: locale
                    ) {
                        requests.append(request)
                    }
                }
            }

            if preferences.morningEnabled,
               let morning = JapanCalendar.parseHourMinute(preferences.morningTime) {
                if let request = makeRequest(
                    kind: .morning,
                    triggerDay: collectionDate,
                    hour: morning.hour,
                    minute: morning.minute,
                    collectionDay: dayResult,
                    now: now,
                    locale: locale
                ) {
                    requests.append(request)
                }
            }
        }

        for request in requests {
            do {
                try await center.add(request)
            } catch {
                // 单条失败不阻断其余排期
                continue
            }
        }
    }

    /// 取消本应用管理的全部待发送通知。
    func cancelAllManagedNotifications() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Private

    private enum ReminderKind: String {
        case evening
        case morning
    }

    private func makeRequest(
        kind: ReminderKind,
        triggerDay: Date,
        hour: Int,
        minute: Int,
        collectionDay: DayCollectionResult,
        now: Date,
        locale: Locale
    ) -> UNNotificationRequest? {
        let dayStart = JapanCalendar.startOfDay(for: triggerDay)
        var components = JapanCalendar.calendar.dateComponents(
            [.year, .month, .day],
            from: dayStart
        )
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = JapanCalendar.timeZone

        guard let fireDate = JapanCalendar.calendar.date(from: components),
              fireDate > now
        else { return nil }

        let ymd = JapanCalendar.ymdString(from: collectionDay.date)
        let identifier = "\(Self.identifierPrefix)\(kind.rawValue).\(ymd)"

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = title(for: kind, locale: locale)
        content.body = body(for: collectionDay, locale: locale)
        content.userInfo = [
            "kind": kind.rawValue,
            "collectionDate": ymd,
            "categoryIds": collectionDay.categories.map(\.id.rawValue),
        ]

        var triggerComponents = DateComponents()
        triggerComponents.calendar = JapanCalendar.calendar
        triggerComponents.timeZone = JapanCalendar.timeZone
        triggerComponents.year = components.year
        triggerComponents.month = components.month
        triggerComponents.day = components.day
        triggerComponents.hour = hour
        triggerComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func title(for kind: ReminderKind, locale: Locale) -> String {
        let code = LocalizedText.preferredLanguageCode(from: locale)
        switch (kind, code) {
        case (.evening, "ja"): return "明日のごみ出し"
        case (.evening, "zh-Hans"): return "明天要扔的垃圾"
        case (.evening, "vi"): return "Rác ngày mai"
        case (.evening, "ko"): return "내일 버릴 쓰레기"
        case (.evening, _): return "Tomorrow's collection"

        case (.morning, "ja"): return "今日のごみ出し"
        case (.morning, "zh-Hans"): return "今天要扔的垃圾"
        case (.morning, "vi"): return "Rác hôm nay"
        case (.morning, "ko"): return "오늘 버릴 쓰레기"
        case (.morning, _): return "Today's collection"
        }
    }

    private func body(for day: DayCollectionResult, locale: Locale) -> String {
        let code = LocalizedText.preferredLanguageCode(from: locale)
        let names = day.categories.map { $0.names.resolved(locale: locale) }
        let bags = day.categories.map { $0.bagBadge.label.resolved(locale: locale) }
        let joinedNames = names.joined(separator: separator(for: code))
        let joinedBags = bags.joined(separator: separator(for: code))
        let deadline = day.dropoffDeadline

        switch code {
        case "ja":
            return "\(joinedNames)（\(joinedBags)）。\(deadline)までに出してください。"
        case "zh-Hans":
            return "\(joinedNames)（\(joinedBags)）。请在 \(deadline) 前投放。"
        case "vi":
            return "\(joinedNames) (\(joinedBags)). Để trước \(deadline)."
        case "ko":
            return "\(joinedNames)(\(joinedBags)). \(deadline)까지 배출하세요."
        default:
            return "\(joinedNames) (\(joinedBags)). Put out by \(deadline)."
        }
    }

    private func separator(for languageCode: String) -> String {
        switch languageCode {
        case "ja", "zh-Hans": return "、"
        case "ko": return ", "
        default: return ", "
        }
    }
}
