//
//  CalendarView.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI

struct CalendarView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var visibleMonth: Date = JapanCalendar.startOfDay(for: Date())
    @State private var selectedDate: Date = JapanCalendar.startOfDay(for: Date())

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme).ignoresSafeArea()

                Group {
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 20) {
                            calendarBlock
                                .frame(maxWidth: 520)
                            detailPanel
                                .frame(maxWidth: .infinity)
                        }
                        .padding(24)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                calendarBlock
                                detailPanel
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle(L10n.t("tab_calendar"))
        }
    }

    private var calendarBlock: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInGrid, id: \.self) { date in
                    dayCell(for: date)
                }
            }
        }
        .padding(16)
        .background(AppTheme.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            Spacer()
            Text(monthTitle)
                .font(.title3.weight(.bold))
            Spacer()
            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .buttonStyle(.plain)
    }

    private var weekdayHeader: some View {
        let symbols = weekdaySymbols
        return HStack(spacing: 4) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let inMonth = JapanCalendar.calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month)
        let isSelected = JapanCalendar.calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = JapanCalendar.calendar.isDateInToday(date)
        let dayResult = dayCollections(on: date)

        return Button {
            selectedDate = JapanCalendar.startOfDay(for: date)
            if !JapanCalendar.calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month) {
                visibleMonth = JapanCalendar.startOfDay(for: date)
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(JapanCalendar.calendar.component(.day, from: date))")
                    .font(.body.weight(isToday ? .bold : .medium))
                    .foregroundStyle(inMonth ? Color.primary : Color.secondary.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                HStack(spacing: 3) {
                    ForEach(dayResult.categories.prefix(4)) { category in
                        Circle()
                            .fill(category.themeColor)
                            .frame(width: 6, height: 6)
                    }
                    if dayResult.isSuspended {
                        Circle()
                            .fill(AppTheme.danger)
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(height: 8)
                .padding(.bottom, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isToday ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: date, result: dayResult))
    }

    private var detailPanel: some View {
        let result = dayCollections(on: selectedDate)
        return VStack(alignment: .leading, spacing: 14) {
            Text(selectedDate.formatted(
                .dateTime.year().month().day().weekday(.wide)
            ))
            .font(.title3.weight(.bold))

            if result.isSuspended {
                Text(L10n.t("status_suspended"))
                    .font(.headline)
                    .foregroundStyle(AppTheme.danger)
                if let note = result.suspensionNotes?.resolved() {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else if result.categories.isEmpty {
                Text(L10n.t("no_collection_today"))
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(result.categories) { category in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(category.themeColor)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.names.resolved())
                                .font(.headline)
                            WasteCategoryBadge(category: category, compact: true)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(AppTheme.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card(for: colorScheme).opacity(sizeClass == .regular ? 1 : 0))
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.card(for: colorScheme))
                .opacity(sizeClass == .regular ? 1 : 0)
        )
    }

    // MARK: - Helpers

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.year().month(.wide))
    }

    private var weekdaySymbols: [String] {
        var cal = JapanCalendar.calendar
        let symbols = cal.shortWeekdaySymbols // Sun-first in array
        // Rotate so Monday-first matches our grid
        let first = cal.firstWeekday // 2 = Monday
        let idx = first - 1
        return Array(symbols[idx...] + symbols[..<idx])
    }

    private var daysInGrid: [Date] {
        let cal = JapanCalendar.calendar
        guard let monthInterval = cal.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let start = JapanCalendar.startOfISOWeek(for: monthInterval.start)
        return (0..<42).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: start)
        }
    }

    private func shiftMonth(by value: Int) {
        if let next = JapanCalendar.calendar.date(byAdding: .month, value: value, to: visibleMonth) {
            visibleMonth = JapanCalendar.startOfDay(for: next)
        }
    }

    private func dayCollections(on date: Date) -> DayCollectionResult {
        guard let districtId = appModel.settings.selectedDistrictId else {
            return DayCollectionResult(
                date: JapanCalendar.startOfDay(for: date),
                isSuspended: false,
                suspensionNotes: nil,
                categories: [],
                dropoffDeadline: appModel.config.defaultDropoffDeadline
            )
        }
        return appModel.calculator.collections(on: date, districtId: districtId)
    }

    private func accessibilityLabel(for date: Date, result: DayCollectionResult) -> String {
        let day = date.formatted(.dateTime.month().day())
        if result.isSuspended { return "\(day), \(L10n.t("status_suspended"))" }
        if result.categories.isEmpty { return day }
        let names = result.categories.map { $0.names.resolved() }.joined(separator: ", ")
        return "\(day), \(names)"
    }
}
