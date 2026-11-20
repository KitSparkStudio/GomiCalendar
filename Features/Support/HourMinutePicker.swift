//
//  HourMinutePicker.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/21.
//

import SwiftUI

/// 原生时分滚轮；对外仍用 `HH:mm` 字符串与现有存储兼容。
struct HourMinutePicker: View {
    var title: String
    @Binding var hhmm: String

    @State private var date: Date = HourMinutePicker.date(from: "08:00")

    var body: some View {
        DatePicker(title, selection: $date, displayedComponents: .hourAndMinute)
            .environment(\.timeZone, JapanCalendar.timeZone)
            .onAppear {
                date = Self.date(from: hhmm)
            }
            .onChange(of: date) { _, newValue in
                let formatted = Self.hhmm(from: newValue)
                if formatted != hhmm {
                    hhmm = formatted
                }
            }
            .onChange(of: hhmm) { _, newValue in
                let next = Self.date(from: newValue)
                if JapanCalendar.calendar.dateComponents([.hour, .minute], from: date)
                    != JapanCalendar.calendar.dateComponents([.hour, .minute], from: next) {
                    date = next
                }
            }
    }

    static func hhmm(from date: Date) -> String {
        let parts = JapanCalendar.calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }

    static func date(from hhmm: String, reference: Date = Date()) -> Date {
        let parsed = JapanCalendar.parseHourMinute(hhmm) ?? (8, 0)
        var components = JapanCalendar.calendar.dateComponents(
            [.year, .month, .day],
            from: JapanCalendar.startOfDay(for: reference)
        )
        components.hour = parsed.hour
        components.minute = parsed.minute
        components.second = 0
        components.timeZone = JapanCalendar.timeZone
        return JapanCalendar.calendar.date(from: components) ?? reference
    }
}

/// 原生日期滚轮；对外仍用 `yyyy-MM-dd`。
struct YMDDatePicker: View {
    var title: String
    @Binding var ymd: String

    @State private var date: Date = Date()

    var body: some View {
        DatePicker(title, selection: $date, displayedComponents: .date)
            .environment(\.timeZone, JapanCalendar.timeZone)
            .onAppear {
                date = Self.date(from: ymd)
            }
            .onChange(of: date) { _, newValue in
                let formatted = JapanCalendar.ymdString(from: newValue)
                if formatted != ymd {
                    ymd = formatted
                }
            }
            .onChange(of: ymd) { _, newValue in
                let next = Self.date(from: newValue)
                if JapanCalendar.ymdString(from: date) != JapanCalendar.ymdString(from: next) {
                    date = next
                }
            }
    }

    static func date(from ymd: String) -> Date {
        let parts = ymd.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            return JapanCalendar.startOfDay(for: Date())
        }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = JapanCalendar.timeZone
        return JapanCalendar.calendar.date(from: components)
            ?? JapanCalendar.startOfDay(for: Date())
    }
}
