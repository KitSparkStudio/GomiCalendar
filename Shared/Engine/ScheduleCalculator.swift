//
//  ScheduleCalculator.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// 某一东京日历日的收集结果。
struct DayCollectionResult: Sendable, Hashable {
    /// 东京时区当天 00:00
    var date: Date
    var isSuspended: Bool
    var suspensionNotes: LocalizedText?
    /// 当日应投放的分类（已排除停收、未启用分类）
    var categories: [WasteCategory]
    /// 默认投放截止 `HH:mm`
    var dropoffDeadline: String

    var hasCollection: Bool { !isSuspended && !categories.isEmpty }
}

/// 「距下次回收」查询结果。
struct NextCollectionInfo: Sendable, Hashable {
    var categoryId: WasteCategoryID
    /// 距下次回收的整天数；`0` = 今天；找不到则为 `nil`
    var daysUntil: Int?
    var nextDate: Date?
}

/// 今天 / 明天汇总。
struct TodayTomorrowResult: Sendable, Hashable {
    var today: DayCollectionResult
    var tomorrow: DayCollectionResult
}

/// 日期推算引擎：锁定东京时区与公历，按町名推算收集日。
///
/// `temporaryRules`（用户自定义临时停收/收集）优先于市政 `yearEndSuspensions` 与周期表。
struct ScheduleCalculator: Sendable {
    var config: CityWasteConfig
    /// 向前搜索「下次回收」的最大天数
    var nextSearchLimitDays: Int
    /// 当前町名的临时日覆盖（来自 Pro 自定义微调）
    var temporaryRules: [TemporaryDayRule]

    init(
        config: CityWasteConfig,
        temporaryRules: [TemporaryDayRule] = [],
        nextSearchLimitDays: Int = 90
    ) {
        self.config = config
        self.temporaryRules = temporaryRules
        self.nextSearchLimitDays = nextSearchLimitDays
    }

    // MARK: - District lookup

    func district(id: String) -> DistrictRule? {
        config.districts.first { $0.id == id }
    }

    /// 按正式名或别名匹配町名。
    func district(matching name: String) -> DistrictRule? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return config.districts.first { district in
            if district.id.caseInsensitiveCompare(trimmed) == .orderedSame { return true }
            if district.names.ja == trimmed { return true }
            if district.names.en.caseInsensitiveCompare(trimmed) == .orderedSame { return true }
            return district.aliases.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        }
    }

    // MARK: - Today / Tomorrow

    func todayAndTomorrow(
        districtId: String,
        now: Date = Date(),
        includeAppointmentRequired: Bool = false
    ) -> TodayTomorrowResult? {
        guard district(id: districtId) != nil else { return nil }
        let today = JapanCalendar.startOfDay(for: now)
        let tomorrow = JapanCalendar.calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return TodayTomorrowResult(
            today: collections(
                on: today,
                districtId: districtId,
                includeAppointmentRequired: includeAppointmentRequired
            ),
            tomorrow: collections(
                on: tomorrow,
                districtId: districtId,
                includeAppointmentRequired: includeAppointmentRequired
            )
        )
    }

    // MARK: - Day query

    func collections(
        on date: Date,
        districtId: String,
        includeAppointmentRequired: Bool = false
    ) -> DayCollectionResult {
        let day = JapanCalendar.startOfDay(for: date)
        let deadline = config.defaultDropoffDeadline
        let ymd = JapanCalendar.ymdString(from: day)

        // 1) 用户强制全天停收（优先）
        if temporaryRules.contains(where: { $0.ymd == ymd && $0.effect == .suspend && $0.categoryId == nil }) {
            return DayCollectionResult(
                date: day,
                isSuspended: true,
                suspensionNotes: Self.userSuspendNotes,
                categories: [],
                dropoffDeadline: deadline
            )
        }

        // 2) 市政全市停收（年末年始等）
        if let suspension = activeSuspension(on: day, categoryId: nil) {
            return DayCollectionResult(
                date: day,
                isSuspended: true,
                suspensionNotes: suspension.notes,
                categories: [],
                dropoffDeadline: deadline
            )
        }

        guard let district = district(id: districtId) else {
            return DayCollectionResult(
                date: day,
                isSuspended: false,
                suspensionNotes: nil,
                categories: [],
                dropoffDeadline: deadline
            )
        }

        var matchedIDs = scheduledCategoryIDs(on: day, district: district)

        // 3) 临时强制收集
        for rule in temporaryRules where rule.ymd == ymd && rule.effect == .collect {
            if let categoryId = rule.categoryId {
                matchedIDs.insert(categoryId)
            }
        }

        // 4) 临时分类停收
        for rule in temporaryRules where rule.ymd == ymd && rule.effect == .suspend {
            if let categoryId = rule.categoryId {
                matchedIDs.remove(categoryId)
            }
        }

        let categories = config.categories.filter { category in
            guard category.isActive else { return false }
            guard matchedIDs.contains(category.id) else { return false }
            if category.requiresAppointment && !includeAppointmentRequired { return false }
            if activeSuspension(on: day, categoryId: category.id) != nil { return false }
            return true
        }

        return DayCollectionResult(
            date: day,
            isSuspended: false,
            suspensionNotes: nil,
            categories: categories,
            dropoffDeadline: deadline
        )
    }

    // MARK: - Days until next

    /// 查询各类垃圾距离下次回收还有几天（含今天 = 0）。
    func daysUntilNextCollections(
        districtId: String,
        from date: Date = Date(),
        includeAppointmentRequired: Bool = false
    ) -> [NextCollectionInfo] {
        let activeIDs: [WasteCategoryID] = config.categories.compactMap { category in
            guard category.isActive else { return nil }
            if category.requiresAppointment && !includeAppointmentRequired { return nil }
            return category.id
        }

        return activeIDs.map { categoryId in
            daysUntilNext(
                categoryId: categoryId,
                districtId: districtId,
                from: date
            )
        }
    }

    func daysUntilNext(
        categoryId: WasteCategoryID,
        districtId: String,
        from date: Date = Date()
    ) -> NextCollectionInfo {
        let start = JapanCalendar.startOfDay(for: date)
        guard district(id: districtId) != nil else {
            return NextCollectionInfo(categoryId: categoryId, daysUntil: nil, nextDate: nil)
        }

        for offset in 0...nextSearchLimitDays {
            guard let candidate = JapanCalendar.calendar.date(byAdding: .day, value: offset, to: start) else {
                continue
            }
            let result = collections(
                on: candidate,
                districtId: districtId,
                includeAppointmentRequired: true
            )
            if result.isSuspended { continue }
            if result.categories.contains(where: { $0.id == categoryId }) {
                return NextCollectionInfo(
                    categoryId: categoryId,
                    daysUntil: offset,
                    nextDate: JapanCalendar.startOfDay(for: candidate)
                )
            }
            // 分类级停收时 collections 已过滤；若仅该分类停收而其它仍收，上面已处理。
            // 若整天因全市停收被跳过，同样 continue。
        }

        return NextCollectionInfo(categoryId: categoryId, daysUntil: nil, nextDate: nil)
    }

    // MARK: - Suspension

    /// `categoryId == nil` 时仅匹配全市（`all`）停收。
    func activeSuspension(
        on date: Date,
        categoryId: WasteCategoryID?
    ) -> YearEndSuspension? {
        let day = JapanCalendar.startOfDay(for: date)
        let md = JapanCalendar.monthDay(of: day)

        return config.yearEndSuspensions.first { suspension in
            guard monthDay(md, isInInclusiveRangeStart: suspension.start, end: suspension.end) else {
                return false
            }
            let applies = suspension.appliesTo
            let citywide = applies.isEmpty || applies.contains("all")
            if let categoryId {
                return citywide || applies.contains(categoryId.rawValue)
            }
            return citywide
        }
    }

    // MARK: - Schedule matching

    func isCollectionDay(
        _ date: Date,
        schedule: CollectionSchedule
    ) -> Bool {
        let day = JapanCalendar.startOfDay(for: date)
        let iso = JapanCalendar.isoWeekday(of: day)

        switch schedule.kind {
        case .weekly:
            let days = schedule.weekdays ?? []
            return days.contains(iso)

        case .monthlyNthWeekday:
            guard let targetWeekday = schedule.weekday,
                  let weeks = schedule.weeksOfMonth,
                  iso == targetWeekday
            else { return false }
            let nth = JapanCalendar.nthWeekdayOccurrence(of: day)
            return weeks.contains(nth)

        case .biweekly:
            guard let targetWeekday = schedule.weekday,
                  iso == targetWeekday,
                  let anchorString = schedule.biweeklyAnchor,
                  let anchor = JapanCalendar.parseYMD(anchorString),
                  let parity = schedule.biweeklyParity
            else { return false }

            let weekStart = JapanCalendar.startOfISOWeek(for: day)
            let anchorWeek = JapanCalendar.startOfISOWeek(for: anchor)
            let dayDiff = JapanCalendar.calendar.dateComponents([.day], from: anchorWeek, to: weekStart).day ?? 0
            // 跨月/跨年、锚定日之前均用非负模，保证奇偶周稳定
            let weekDiff = dayDiff / 7
            let parityBit = JapanCalendar.nonNegativeMod(weekDiff, 2)
            switch parity {
            case .odd:
                return parityBit == 0 // 锚定周及其后每隔一周
            case .even:
                return parityBit == 1
            }
        }
    }

    // MARK: - Private

    private static let userSuspendNotes = LocalizedText(
        ja: "ユーザー設定の臨時休止日",
        kana: "りんじきゅうし",
        en: "User temporary suspension",
        zhHans: "用户设置的临时停收日",
        vi: "Ngày tạm dừng do người dùng",
        ko: "사용자 임시 휴지일"
    )

    private func scheduledCategoryIDs(on day: Date, district: DistrictRule) -> Set<WasteCategoryID> {
        var ids = Set<WasteCategoryID>()
        for schedule in district.schedules where isCollectionDay(day, schedule: schedule) {
            ids.insert(schedule.categoryId)
        }
        return ids
    }

    /// `MM-DD` 闭区间；支持跨年（如 `12-30`…`01-03`）。
    private func monthDay(
        _ md: (month: Int, day: Int),
        isInInclusiveRangeStart start: String,
        end: String
    ) -> Bool {
        guard let s = JapanCalendar.parseMonthDay(start),
              let e = JapanCalendar.parseMonthDay(end)
        else { return false }

        let value = md.month * 100 + md.day
        let startValue = s.month * 100 + s.day
        let endValue = e.month * 100 + e.day

        if startValue <= endValue {
            return value >= startValue && value <= endValue
        }
        // 跨年：落在 start…12-31 或 01-01…end
        return value >= startValue || value <= endValue
    }
}

#if DEBUG
extension ScheduleCalculator {
    /// 开发期自检：三种周期 + 跨年停收。
    static func debugAssertInvariants(config: CityWasteConfig) {
        let calc = ScheduleCalculator(config: config)
        guard let district = config.districts.first else { return }

        // 每周
        if let weekly = district.schedules.first(where: { $0.kind == .weekly }),
           let weekdays = weekly.weekdays,
           let sample = JapanCalendar.parseYMD("2026-01-05") { // Monday
            let iso = JapanCalendar.isoWeekday(of: sample)
            assert((1...7).contains(iso))
            _ = weekdays.contains(iso)
        }

        // 每月第 N 个星期几：2026-01-07 是第 1 个水曜
        if let d = JapanCalendar.parseYMD("2026-01-07") {
            assert(JapanCalendar.nthWeekdayOccurrence(of: d) == 1)
            assert(JapanCalendar.isoWeekday(of: d) == 3)
        }
        // 跨月：2026-01-28 是第 4 个水曜，不会算成下月第 0 周
        if let d = JapanCalendar.parseYMD("2026-01-28") {
            assert(JapanCalendar.nthWeekdayOccurrence(of: d) == 4)
        }

        // 双周：锚定周 odd，隔周 even
        if let d0 = JapanCalendar.parseYMD("2026-01-06"),
           let d1 = JapanCalendar.parseYMD("2026-01-13") {
            let s = CollectionSchedule(
                categoryId: .recyclable,
                kind: .biweekly,
                weekdays: nil,
                weekday: 2,
                weeksOfMonth: nil,
                biweeklyAnchor: "2026-01-06",
                biweeklyParity: .odd
            )
            assert(calc.isCollectionDay(d0, schedule: s))
            assert(!calc.isCollectionDay(d1, schedule: s))
        }

        // 跨年停收 12-31…01-03
        if let nye = JapanCalendar.parseYMD("2026-12-31"),
           let jan2 = JapanCalendar.parseYMD("2027-01-02"),
           let jan4 = JapanCalendar.parseYMD("2027-01-04") {
            assert(calc.activeSuspension(on: nye, categoryId: nil) != nil)
            assert(calc.activeSuspension(on: jan2, categoryId: nil) != nil)
            assert(calc.activeSuspension(on: jan4, categoryId: nil) == nil)
        }
    }
}
#endif
