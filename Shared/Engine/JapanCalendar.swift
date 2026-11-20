//
//  JapanCalendar.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// 强制锁定 `Asia/Tokyo` + 公历，保证任意设备时区下日期推算一致。
enum JapanCalendar: Sendable {
    static let timeZone = TimeZone(identifier: "Asia/Tokyo")!

    /// 周一为一周起始的东京公历日历（静态缓存，避免重复分配）。
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 2 // Monday
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    /// 将任意瞬间归一为东京时区当天 00:00。
    static func startOfDay(for date: Date = Date()) -> Date {
        calendar.startOfDay(for: date)
    }

    /// ISO 星期几：1 = 月曜日 … 7 = 日曜日。
    static func isoWeekday(of date: Date) -> Int {
        let apple = calendar.component(.weekday, from: date) // 1 = Sunday
        return apple == 1 ? 7 : apple - 1
    }

    /// `MM-DD` → (month, day)
    static func parseMonthDay(_ mmdd: String) -> (month: Int, day: Int)? {
        let parts = mmdd.split(separator: "-")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let day = Int(parts[1]),
              (1...12).contains(month),
              (1...31).contains(day)
        else { return nil }
        return (month, day)
    }

    /// `YYYY-MM-DD`（按东京日历）解析为当天 00:00。
    static func parseYMD(_ ymd: String) -> Date? {
        let parts = ymd.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        // 校验未溢出（如 2/30 → 3/x）
        let md = monthDay(of: date)
        guard md.month == month, md.day == day else { return nil }
        return startOfDay(for: date)
    }

    static func monthDay(of date: Date) -> (month: Int, day: Int) {
        let c = calendar.dateComponents([.month, .day], from: date)
        return (c.month ?? 1, c.day ?? 1)
    }

    /// 格式化东京日历日期 `yyyy-MM-dd`。
    static func ymdString(from date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 0
        let m = c.month ?? 0
        let d = c.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// 解析 `HH:mm` 为时、分。
    static func parseHourMinute(_ hhmm: String) -> (hour: Int, minute: Int)? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute)
        else { return nil }
        return (hour, minute)
    }

    /// 该日在本月是第几个「该星期几」（1-based）。跨月不会串到下月。
    static func nthWeekdayOccurrence(of date: Date) -> Int {
        let day = calendar.component(.day, from: date)
        return (day - 1) / 7 + 1
    }

    /// 以周一为起点的周起点（东京 00:00）。
    static func startOfISOWeek(for date: Date) -> Date {
        let day = startOfDay(for: date)
        let iso = isoWeekday(of: day)
        return calendar.date(byAdding: .day, value: -(iso - 1), to: day) ?? day
    }

    /// 非负模，避免双周计算在锚定日之前出现负数余数。
    static func nonNegativeMod(_ value: Int, _ modulus: Int) -> Int {
        let m = value % modulus
        return m >= 0 ? m : m + modulus
    }
}
