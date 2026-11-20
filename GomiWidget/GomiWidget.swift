//
//  GomiWidget.swift
//  GomiWidget
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Entry

struct WidgetDaySlot: Identifiable, Hashable {
    var id: String
    var weekdayLabel: String
    var dayNumber: Int
    var isToday: Bool
    /// 彩色语义圆点（分类主题色）
    var dotColors: [String]
    var isSuspended: Bool
}

struct GomiEntry: TimelineEntry {
    var date: Date
    /// 地区标签，如 `🏠 自宅・鎌倉市`
    var placeTitle: String
    var focusLabel: String
    var focusIsToday: Bool
    var focusYMD: String
    var focusCategories: [WidgetCategory]
    var todayCategories: [WidgetCategory]
    var tomorrowCategories: [WidgetCategory]
    var weekDays: [WidgetDaySlot]
    var isSuspended: Bool
    var suspensionNote: String
    var deadline: String
    /// 无收集时的下次预告（已本地化）
    var nextPickupLabel: String?
    /// 特殊 / 资源垃圾倒计时
    var nextSpecialLabel: String?
    /// 焦点日是否已「已投放」打卡
    var isMarkedDone: Bool
    var isPro: Bool
}

struct WidgetCategory: Identifiable, Hashable {
    var id: String
    var name: String
    var bagLabel: String
    var colorHex: String
    var symbolName: String
}

// MARK: - Provider

struct GomiProvider: TimelineProvider {
    func placeholder(in context: Context) -> GomiEntry {
        sampleEntry(date: Date(), isPro: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (GomiEntry) -> Void) {
        completion(makeEntry(at: Date()) ?? sampleEntry(date: Date(), isPro: ProAccess.isPro))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GomiEntry>) -> Void) {
        let now = Date()
        var entries: [GomiEntry] = []

        if let current = makeEntry(at: now) {
            entries.append(current)
        }

        for refresh in upcomingRefreshDates(from: now, dayCount: 7) {
            if let entry = makeEntry(at: refresh) {
                entries.append(entry)
            }
        }

        if entries.isEmpty {
            entries = [sampleEntry(date: now, isPro: ProAccess.isPro)]
        }

        let next = upcomingRefreshDates(from: now, dayCount: 2).first ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(next)))
    }

    /// 东京时区：每天 00:00 与 08:00（截止后切到明日提醒）。
    private func upcomingRefreshDates(from now: Date, dayCount: Int) -> [Date] {
        let cal = JapanCalendar.calendar
        let start = JapanCalendar.startOfDay(for: now)
        var dates: [Date] = []

        for dayOffset in 0..<dayCount {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: start) else { continue }
            for hour in [0, 8] {
                var components = cal.dateComponents([.year, .month, .day], from: day)
                components.hour = hour
                components.minute = 0
                components.second = 0
                components.timeZone = JapanCalendar.timeZone
                if let date = cal.date(from: components), date > now {
                    dates.append(date)
                }
            }
        }
        return dates
    }

    private func makeEntry(at date: Date) -> GomiEntry? {
        let defaults = UserDefaults(suiteName: ProAccess.appGroupID) ?? .standard
        let cityId = defaults.string(forKey: "selectedCityId") ?? "jp_05201_akita"
        let cityLabel = defaults.string(forKey: "selectedCityLabel")
        guard var config = try? CityWasteConfig.loadCity(cityId: cityId, displayNameJa: cityLabel) else {
            return nil
        }
        if defaults.bool(forKey: "usesCustomWeekdays")
            || defaults.bool(forKey: "usesStandardTemplate")
            || config.isStandardTemplate {
            let days = (defaults.array(forKey: "customCombustibleWeekdays") as? [Int]) ?? [1, 4]
            config.districts = config.districts.map { district in
                var d = district
                d.schedules = d.schedules.map { schedule in
                    var s = schedule
                    if s.categoryId == .combustible, s.kind == .weekly {
                        s.weekdays = days.sorted()
                    }
                    return s
                }
                return d
            }
        }

        let districtId = defaults.string(forKey: "selectedDistrictId")
            ?? config.districts.first?.id
        config = ScheduleOverrideStore.applyScheduleOverrides(
            to: config,
            cityId: cityId,
            districtId: districtId
        )
        let temporaryRules: [TemporaryDayRule] = {
            guard let districtId else { return [] }
            return ScheduleOverrideStore.override(cityId: cityId, districtId: districtId)?.temporaryDays ?? []
        }()

        guard let districtId,
              let district = config.districts.first(where: { $0.id == districtId })
        else {
            return nil
        }

        let calc = ScheduleCalculator(config: config, temporaryRules: temporaryRules)
        let deadline = {
            let custom = defaults.string(forKey: "customDropoffDeadline")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return custom.isEmpty ? config.defaultDropoffDeadline : custom
        }()
        let todayStart = JapanCalendar.startOfDay(for: date)
        let today = calc.collections(on: date, districtId: districtId)
        let tomorrowDate = JapanCalendar.calendar.date(byAdding: .day, value: 1, to: todayStart) ?? date
        let tomorrow = calc.collections(on: tomorrowDate, districtId: districtId)

        let focusToday = isBeforeDeadline(date, deadline: deadline)
        let focus = focusToday ? today : tomorrow
        let focusDate = focusToday ? todayStart : tomorrowDate
        let focusYMD = JapanCalendar.ymdString(from: focusDate)

        let placeTitle = loadPlaceTitle(
            defaults: defaults,
            fallbackCity: cityLabel ?? config.names.resolved(),
            fallbackDistrict: district.names.resolved()
        )

        let weekDays = buildWeekDays(
            from: todayStart,
            districtId: districtId,
            calculator: calc
        )

        let nextPickupLabel: String? = {
            guard focus.categories.isEmpty, !focus.isSuspended else { return nil }
            return specialCountdownLabel(
                preferred: [.combustible, .recyclable, .nonCombustible, .hazardous, .oversized],
                calc: calc,
                config: config,
                districtId: districtId,
                from: date
            )
        }()

        let nextSpecialLabel = specialCountdownLabel(
            preferred: [.recyclable, .nonCombustible, .hazardous, .oversized],
            calc: calc,
            config: config,
            districtId: districtId,
            from: date
        )

        let completedKey = defaults.string(forKey: GomiLiveActivityKeys.widgetDropCompletedKey)
        let expectedKey = "\(cityId)|\(districtId)|\(focusYMD)"
        let isMarkedDone = completedKey == expectedKey

        return GomiEntry(
            date: date,
            placeTitle: placeTitle,
            focusLabel: focusToday ? L10n.t("widget_today") : L10n.t("widget_tomorrow"),
            focusIsToday: focusToday,
            focusYMD: focusYMD,
            focusCategories: focus.categories.map(mapCategory),
            todayCategories: today.categories.map(mapCategory),
            tomorrowCategories: tomorrow.categories.map(mapCategory),
            weekDays: weekDays,
            isSuspended: focus.isSuspended,
            suspensionNote: focus.suspensionNotes?.resolved() ?? "",
            deadline: deadline,
            nextPickupLabel: nextPickupLabel,
            nextSpecialLabel: nextSpecialLabel,
            isMarkedDone: isMarkedDone,
            isPro: ProAccess.isPro
        )
    }

    private func buildWeekDays(
        from todayStart: Date,
        districtId: String,
        calculator: ScheduleCalculator
    ) -> [WidgetDaySlot] {
        (0..<7).compactMap { offset -> WidgetDaySlot? in
            guard let day = JapanCalendar.calendar.date(byAdding: .day, value: offset, to: todayStart)
            else { return nil }
            let result = calculator.collections(on: day, districtId: districtId)
            let ymd = JapanCalendar.ymdString(from: day)
            let dayNumber = JapanCalendar.calendar.component(.day, from: day)
            return WidgetDaySlot(
                id: ymd,
                weekdayLabel: weekdayLabel(for: day),
                dayNumber: dayNumber,
                isToday: offset == 0,
                dotColors: result.isSuspended
                    ? []
                    : result.categories.prefix(3).map(\.themeColorHex),
                isSuspended: result.isSuspended
            )
        }
    }

    private func specialCountdownLabel(
        preferred: [WasteCategoryID],
        calc: ScheduleCalculator,
        config: CityWasteConfig,
        districtId: String,
        from date: Date
    ) -> String? {
        let infos = calc.daysUntilNextCollections(districtId: districtId, from: date)
        let ranked = preferred.compactMap { id -> (WasteCategory, Int)? in
            guard let info = infos.first(where: { $0.categoryId == id }),
                  let days = info.daysUntil,
                  let category = config.categories.first(where: { $0.id == id && $0.isActive })
            else { return nil }
            return (category, days)
        }
        .sorted { $0.1 < $1.1 }

        guard let best = ranked.first else { return nil }
        let name = best.0.names.resolved()
        if best.1 == 0 {
            return String(format: L10n.t("widget_special_today_fmt"), name)
        }
        return String(format: L10n.t("widget_special_days_fmt"), name, best.1)
    }

    private func loadPlaceTitle(
        defaults: UserDefaults,
        fallbackCity: String,
        fallbackDistrict: String
    ) -> String {
        guard let data = defaults.data(forKey: "savedPlaces"),
              let places = try? JSONDecoder().decode([SavedPlace].self, from: data),
              !places.isEmpty
        else {
            if fallbackDistrict.contains("自宅") || fallbackDistrict.localizedCaseInsensitiveContains("home") {
                return fallbackCity
            }
            return "\(fallbackCity) · \(fallbackDistrict)"
        }
        let activeId = defaults.string(forKey: "activePlaceId")
        let place = places.first { $0.id == activeId } ?? places.first!
        return place.displayTitle()
    }

    private func isBeforeDeadline(_ date: Date, deadline: String) -> Bool {
        guard let hm = JapanCalendar.parseHourMinute(deadline) else { return true }
        var components = JapanCalendar.calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hm.hour
        components.minute = hm.minute
        components.second = 0
        components.timeZone = JapanCalendar.timeZone
        guard let deadlineDate = JapanCalendar.calendar.date(from: components) else { return true }
        return date < deadlineDate
    }

    private func mapCategory(_ category: WasteCategory) -> WidgetCategory {
        WidgetCategory(
            id: category.id.rawValue,
            name: category.names.resolved(),
            bagLabel: category.bagBadge.label.resolved(),
            colorHex: category.themeColorHex,
            symbolName: GomiActivityAttributes.symbolName(for: category.id.rawValue)
        )
    }

    private func weekdayLabel(for date: Date) -> String {
        let weekday = JapanCalendar.calendar.component(.weekday, from: date)
        switch weekday {
        case 2: return L10n.t("weekday_mon")
        case 3: return L10n.t("weekday_tue")
        case 4: return L10n.t("weekday_wed")
        case 5: return L10n.t("weekday_thu")
        case 6: return L10n.t("weekday_fri")
        case 7: return L10n.t("weekday_sat")
        default: return L10n.t("weekday_sun")
        }
    }

    private func sampleEntry(date: Date, isPro: Bool) -> GomiEntry {
        let sample = WidgetCategory(
            id: "combustible",
            name: "家庭ごみ",
            bagLabel: "黄色指定袋",
            colorHex: "#FF6B4A",
            symbolName: "flame.fill"
        )
        let start = JapanCalendar.startOfDay(for: date)
        let week: [WidgetDaySlot] = (0..<7).compactMap { offset in
            guard let day = JapanCalendar.calendar.date(byAdding: .day, value: offset, to: start)
            else { return nil }
            return WidgetDaySlot(
                id: JapanCalendar.ymdString(from: day),
                weekdayLabel: weekdayLabel(for: day),
                dayNumber: JapanCalendar.calendar.component(.day, from: day),
                isToday: offset == 0,
                dotColors: offset == 0 || offset == 3 ? ["#FF6B4A"] : (offset == 2 ? ["#00D2FF"] : []),
                isSuspended: false
            )
        }
        return GomiEntry(
            date: date,
            placeTitle: "🏠 自宅・秋田市",
            focusLabel: L10n.t("widget_today"),
            focusIsToday: true,
            focusYMD: JapanCalendar.ymdString(from: start),
            focusCategories: [sample],
            todayCategories: [sample],
            tomorrowCategories: [],
            weekDays: week,
            isSuspended: false,
            suspensionNote: "",
            deadline: "08:00",
            nextPickupLabel: nil,
            nextSpecialLabel: String(format: L10n.t("widget_special_days_fmt"), "資源ごみ", 2),
            isMarkedDone: false,
            isPro: isPro
        )
    }
}

// MARK: - Views

struct GomiWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: GomiEntry

    var body: some View {
        switch family {
        case .systemMedium:
            if entry.isPro {
                MediumWidgetView(entry: entry)
            } else {
                ProLockedWidgetView(message: L10n.t("widget_pro_medium"))
            }
        case .accessoryRectangular:
            if entry.isPro {
                LockScreenWidgetView(entry: entry)
            } else {
                ProLockedWidgetView(message: L10n.t("widget_pro_lock"))
            }
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: Small

private struct SmallWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    var entry: GomiEntry

    private var primary: WidgetCategory? { entry.focusCategories.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(entry.placeTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                focusBadge
            }

            if entry.isSuspended {
                restBlock(
                    icon: "exclamationmark.triangle.fill",
                    title: L10n.t("widget_suspended"),
                    subtitle: entry.suspensionNote.isEmpty ? nil : entry.suspensionNote
                )
            } else if let primary {
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    categoryOrb(primary, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primary.name)
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if entry.focusCategories.count > 1 {
                            Text(entry.focusCategories.dropFirst().map(\.name).joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
                Spacer(minLength: 0)
                bagChip(primary.bagLabel, color: Color(hexString: primary.colorHex))
            } else {
                Spacer(minLength: 0)
                restBlock(
                    icon: "moon.zzz.fill",
                    title: L10n.t("widget_rest"),
                    subtitle: entry.nextPickupLabel
                )
                Spacer(minLength: 0)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            WidgetCardBackground()
        }
    }

    private var focusBadge: some View {
        Text(entry.focusLabel)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color(hex: 0x0A84FF).opacity(colorScheme == .dark ? 0.35 : 0.18))
            )
            .foregroundStyle(Color(hex: 0x0A84FF))
    }

    private func restBlock(icon: String, title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
    }
}

// MARK: Medium — 焦点 + 7 日全览 + 打卡

private struct MediumWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    var entry: GomiEntry

    private var primary: WidgetCategory? { entry.focusCategories.first }

    var body: some View {
        GeometryReader { geo in
            let divider: CGFloat = 1
            let gap: CGFloat = 0
            let leftW = (geo.size.width - divider - gap) * 0.42
            let rightW = geo.size.width - divider - gap - leftW
            HStack(spacing: gap) {
                focusPane
                    .frame(width: leftW, alignment: .topLeading)

                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: divider)
                    .padding(.vertical, 4)

                weekPane
                    .frame(width: rightW, alignment: .topLeading)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            WidgetCardBackground()
        }
    }

    // MARK: Left ~42%

    private var focusPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(entry.placeTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text(entry.focusLabel)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color(hex: 0x0A84FF).opacity(colorScheme == .dark ? 0.32 : 0.16))
                    )
                    .foregroundStyle(Color(hex: 0x0A84FF))
                    .lineLimit(1)
            }

            if entry.isSuspended {
                Label(L10n.t("widget_suspended"), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: 0xFF9F0A))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            } else if let primary {
                HStack(spacing: 8) {
                    categoryOrb(primary, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primary.name)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(String(format: L10n.t("widget_deadline_before"), entry.deadline))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                bagChip(primary.bagLabel, color: Color(hexString: primary.colorHex))
                Spacer(minLength: 0)
                markDoneButton
            } else {
                Label(L10n.t("widget_rest"), systemImage: "moon.zzz.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let next = entry.nextPickupLabel {
                    Text(next)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.trailing, 8)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var markDoneButton: some View {
        if entry.isMarkedDone {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text(L10n.t("widget_marked_done"))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(AccentTheme.current.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(AccentTheme.current.color.opacity(0.16), in: Capsule())
        } else if !entry.focusCategories.isEmpty, !entry.isSuspended {
            Button(intent: CompleteGomiDropIntent()) {
                Text(L10n.t("widget_mark_done"))
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(AccentTheme.current.color.opacity(0.22), in: Capsule())
                    .foregroundStyle(AccentTheme.current.color)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Right ~58%

    private var weekPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("widget_week_title"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 3) {
                ForEach(entry.weekDays) { day in
                    weekColumn(day)
                }
            }
            .frame(maxWidth: .infinity)

            if let special = entry.nextSpecialLabel, !special.isEmpty {
                Text(special)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x00D2FF))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, 8)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func weekColumn(_ day: WidgetDaySlot) -> some View {
        VStack(spacing: 3) {
            Text(day.weekdayLabel)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(day.isToday ? Color(hex: 0x0A84FF) : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(day.dayNumber)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 2) {
                if day.isSuspended {
                    Circle()
                        .fill(Color(hex: 0xFF9F0A).opacity(0.7))
                        .frame(width: 5, height: 5)
                } else if day.dotColors.isEmpty {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 5, height: 5)
                } else {
                    ForEach(Array(day.dotColors.prefix(2).enumerated()), id: \.offset) { _, hex in
                        Circle()
                            .fill(Color(hexString: hex))
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .padding(.horizontal, 1)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(day.isToday ? Color(hex: 0x0A84FF).opacity(colorScheme == .dark ? 0.18 : 0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    day.isToday ? Color(hex: 0x0A84FF).opacity(0.85) : Color.clear,
                    lineWidth: 1.2
                )
        )
    }
}

// MARK: Lock screen

private struct LockScreenWidgetView: View {
    var entry: GomiEntry

    var body: some View {
        let names = entry.focusCategories.map(\.name).joined(separator: " · ")
        let line: String = {
            if entry.isSuspended {
                return "\(entry.focusLabel) · \(L10n.t("widget_suspended"))"
            }
            if names.isEmpty {
                return "\(entry.focusLabel) · \(L10n.t("widget_rest"))"
            }
            return String(
                format: L10n.t("widget_lock_fmt"),
                entry.focusLabel,
                entry.deadline,
                names
            )
        }()

        HStack(spacing: 8) {
            if let primary = entry.focusCategories.first {
                Image(systemName: primary.symbolName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color(hexString: primary.colorHex))
            } else {
                Image(systemName: entry.isSuspended ? "exclamationmark.triangle.fill" : "moon.zzz.fill")
                    .font(.body.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(line)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(entry.placeTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProLockedWidgetView: View {
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pro")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AccentTheme.current.color.opacity(0.2), in: Capsule())
                .foregroundStyle(AccentTheme.current.color)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            WidgetCardBackground()
        }
    }
}

// MARK: Shared chrome

private struct WidgetCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ContainerRelativeShape()
            .fill(colorScheme == .dark ? Color(hex: 0x161A1E) : Color(hex: 0xF7F8FA))
    }
}

private func categoryOrb(_ category: WidgetCategory, size: CGFloat) -> some View {
    let color = Color(hexString: category.colorHex)
    return ZStack {
        Circle()
            .fill(color.opacity(0.35))
            .frame(width: size + 8, height: size + 8)
            .blur(radius: 5)
        Circle()
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.55), radius: 6, y: 2)
        Image(systemName: category.symbolName)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.white)
    }
}

private func bagChip(_ label: String, color: Color) -> some View {
    Text(label)
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.18), in: Capsule())
        .foregroundStyle(color)
}

// MARK: - Widget

struct GomiWidget: Widget {
    let kind = "GomiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GomiProvider()) { entry in
            GomiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(L10n.t("widget_display_name"))
        .description(L10n.t("widget_description"))
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
        ])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemMedium) {
    GomiWidget()
} timeline: {
    GomiEntry(
        date: .now,
        placeTitle: "🏠 自宅・秋田市",
        focusLabel: "明日",
        focusIsToday: false,
        focusYMD: "2026-11-21",
        focusCategories: [
            WidgetCategory(
                id: "combustible",
                name: "家庭ごみ",
                bagLabel: "黄色指定袋",
                colorHex: "#FF6B4A",
                symbolName: "flame.fill"
            )
        ],
        todayCategories: [],
        tomorrowCategories: [
            WidgetCategory(
                id: "combustible",
                name: "家庭ごみ",
                bagLabel: "黄色指定袋",
                colorHex: "#FF6B4A",
                symbolName: "flame.fill"
            )
        ],
        weekDays: (0..<7).map { i in
            WidgetDaySlot(
                id: "d\(i)",
                weekdayLabel: ["月", "火", "水", "木", "金", "土", "日"][i],
                dayNumber: 20 + i,
                isToday: i == 0,
                dotColors: i == 0 || i == 3 ? ["#FF6B4A"] : (i == 2 ? ["#00D2FF"] : []),
                isSuspended: false
            )
        },
        isSuspended: false,
        suspensionNote: "",
        deadline: "08:00",
        nextPickupLabel: nil,
        nextSpecialLabel: "資源ごみまであと2日",
        isMarkedDone: false,
        isPro: true
    )
}
