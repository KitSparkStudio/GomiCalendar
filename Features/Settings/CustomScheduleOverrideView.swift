//
//  CustomScheduleOverrideView.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 免费：在自治体模板上覆盖收集周期、投放截止时间，并添加临时停收 / 临时收集日。
struct CustomScheduleOverrideView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguageCode.storageKey) private var selectedLanguage: String = AppLanguageCode.auto.rawValue

    @State private var draft: DistrictScheduleOverride
    @State private var baselineDraft: DistrictScheduleOverride
    @State private var deadlineText = "08:00"
    @State private var baselineDeadline = "08:00"
    @State private var showAddTemporary = false
    @State private var tempDate = Date()
    @State private var tempEffect: TemporaryDayEffect = .suspend
    @State private var tempCategory: WasteCategoryID? = nil
    @State private var didSaveBanner = false
    @State private var didLoad = false

    init() {
        let empty = DistrictScheduleOverride(cityId: "", districtId: "")
        _draft = State(initialValue: empty)
        _baselineDraft = State(initialValue: empty)
    }

    private var isDirty: Bool {
        guard didLoad else { return false }
        return draft != baselineDraft || deadlineText != baselineDeadline
    }

    var body: some View {
        List {
            Section {
                Text(L10n.t("override_intro"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.t("override_deadline_section")) {
                HourMinutePicker(
                    title: L10n.t("override_deadline_section"),
                    hhmm: $deadlineText
                )
            }

            Section(L10n.t("override_schedules_section")) {
                ForEach(activeCategories, id: \.id) { category in
                    NavigationLink {
                        CategoryScheduleEditor(
                            category: category,
                            initial: draft.categorySchedules[category.id.rawValue]
                                ?? defaultSchedule(for: category.id),
                            onSave: { saved in
                                commitCategorySchedule(saved, for: category.id)
                            }
                        )
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hexString: category.themeColorHex))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.names.resolved())
                                    .font(.headline)
                                Text(scheduleSummary(for: category.id))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section(L10n.t("override_temporary_section")) {
                if draft.temporaryDays.isEmpty {
                    Text(L10n.t("override_temporary_empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(draft.temporaryDays) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.ymd).font(.headline)
                                Text(temporaryLabel(rule))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete { offsets in
                        var next = draft
                        next.temporaryDays.remove(atOffsets: offsets)
                        draft = next
                    }
                }
                Button {
                    showAddTemporary = true
                } label: {
                    Label(L10n.t("override_add_temporary"), systemImage: "calendar.badge.plus")
                }
            }

            Section {
                Button(L10n.t("override_reset"), role: .destructive) {
                    reset()
                }
            }

            if didSaveBanner {
                Section {
                    Text(L10n.t("override_saved"))
                        .font(.footnote)
                        .foregroundStyle(Color(hex: 0x34C759))
                }
            }
        }
        .navigationTitle(L10n.t("override_title"))
        .navigationBarTitleDisplayMode(.inline)
        .id(selectedLanguage)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                OverrideSaveToolbarButton(isDirty: isDirty) {
                    persistAndSync(dismissAfter: false)
                }
            }
        }
        .onAppear { loadDraft() }
        .sheet(isPresented: $showAddTemporary) {
            NavigationStack {
                Form {
                    DatePicker(
                        L10n.t("override_temp_date"),
                        selection: $tempDate,
                        displayedComponents: .date
                    )
                    .environment(\.timeZone, JapanCalendar.timeZone)

                    Picker(L10n.t("override_temp_effect"), selection: $tempEffect) {
                        Text(L10n.t("override_effect_suspend")).tag(TemporaryDayEffect.suspend)
                        Text(L10n.t("override_effect_collect")).tag(TemporaryDayEffect.collect)
                    }

                    Picker(L10n.t("override_temp_category"), selection: $tempCategory) {
                        Text(L10n.t("override_all_categories")).tag(Optional<WasteCategoryID>.none)
                        ForEach(activeCategories, id: \.id) { cat in
                            Text(cat.names.resolved()).tag(Optional(cat.id))
                        }
                    }
                }
                .navigationTitle(L10n.t("override_add_temporary"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.t("close")) { showAddTemporary = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.t("override_add")) {
                            let ymd = JapanCalendar.ymdString(from: tempDate)
                            var next = draft
                            next.temporaryDays.append(
                                TemporaryDayRule(ymd: ymd, effect: tempEffect, categoryId: tempCategory)
                            )
                            next.temporaryDays.sort { $0.ymd < $1.ymd }
                            draft = next
                            showAddTemporary = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var activeCategories: [WasteCategory] {
        appModel.config.categories.filter { $0.isActive && !$0.requiresAppointment }
    }

    private func loadDraft() {
        let cityId = appModel.settings.selectedCityId
        let districtId = appModel.settings.selectedDistrictId
            ?? appModel.config.districts.first?.id
            ?? "home"
        let savedDeadline = appModel.settings.customDropoffDeadline
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let deadline = savedDeadline.isEmpty
            ? appModel.config.defaultDropoffDeadline
            : savedDeadline

        let loaded: DistrictScheduleOverride
        if var existing = ScheduleOverrideStore.override(cityId: cityId, districtId: districtId) {
            existing.cityId = cityId
            existing.districtId = districtId
            loaded = existing
        } else {
            var schedules: [String: CollectionSchedule] = [:]
            if let district = appModel.effectiveConfig.districts.first(where: { $0.id == districtId }) {
                for schedule in district.schedules {
                    schedules[schedule.categoryId.rawValue] = schedule
                }
            }
            loaded = DistrictScheduleOverride(
                cityId: cityId,
                districtId: districtId,
                categorySchedules: schedules,
                temporaryDays: []
            )
        }

        draft = loaded
        baselineDraft = loaded
        deadlineText = deadline
        baselineDeadline = deadline
        didLoad = true
        didSaveBanner = false
    }

    private func defaultSchedule(for categoryId: WasteCategoryID) -> CollectionSchedule {
        if let district = appModel.effectiveConfig.districts.first(where: { $0.id == draft.districtId }),
           let existing = district.schedules.first(where: { $0.categoryId == categoryId }) {
            return existing
        }
        return CollectionSchedule(
            categoryId: categoryId,
            kind: .weekly,
            weekdays: [2, 5],
            weekday: nil,
            weeksOfMonth: nil,
            biweeklyAnchor: nil,
            biweeklyParity: nil
        )
    }

    private func scheduleSummary(for categoryId: WasteCategoryID) -> String {
        guard let schedule = draft.categorySchedules[categoryId.rawValue] else {
            return L10n.t("override_using_city_default")
        }
        switch schedule.kind {
        case .weekly:
            let days = (schedule.weekdays ?? []).map(shortWeekday).joined(separator: "・")
            return "\(L10n.t("override_kind_weekly")): \(days)"
        case .monthlyNthWeekday:
            let weeks = (schedule.weeksOfMonth ?? []).map(String.init).joined(separator: ",")
            let wd = shortWeekday(schedule.weekday ?? 1)
            return "\(L10n.t("override_kind_monthly")): \(weeks) / \(wd)"
        case .biweekly:
            return "\(L10n.t("override_kind_biweekly")): \(shortWeekday(schedule.weekday ?? 1))"
        }
    }

    private func temporaryLabel(_ rule: TemporaryDayRule) -> String {
        let effect = rule.effect == .suspend
            ? L10n.t("override_effect_suspend")
            : L10n.t("override_effect_collect")
        if let categoryId = rule.categoryId,
           let cat = appModel.config.categories.first(where: { $0.id == categoryId }) {
            return "\(effect) · \(cat.names.resolved())"
        }
        return "\(effect) · \(L10n.t("override_all_categories"))"
    }

    private func shortWeekday(_ day: Int) -> String {
        switch day {
        case 1: return L10n.t("weekday_mon")
        case 2: return L10n.t("weekday_tue")
        case 3: return L10n.t("weekday_wed")
        case 4: return L10n.t("weekday_thu")
        case 5: return L10n.t("weekday_fri")
        case 6: return L10n.t("weekday_sat")
        default: return L10n.t("weekday_sun")
        }
    }

    /// 分类编辑页点保存：写入 draft 并立即强制落盘 + 全局同步，再由子页 dismiss。
    private func commitCategorySchedule(_ schedule: CollectionSchedule, for categoryId: WasteCategoryID) {
        var next = draft
        var saved = schedule
        saved.categoryId = categoryId
        next.categorySchedules[categoryId.rawValue] = saved
        if next.cityId.isEmpty {
            next.cityId = appModel.settings.selectedCityId
        }
        if next.districtId.isEmpty {
            next.districtId = appModel.settings.selectedDistrictId
                ?? appModel.config.districts.first?.id
                ?? "home"
        }
        draft = next
        persistAndSync(dismissAfter: false)
    }

    private func persistAndSync(dismissAfter: Bool) {
        guard didLoad else { return }
        var toSave = draft
        if toSave.cityId.isEmpty {
            toSave.cityId = appModel.settings.selectedCityId
        }
        if toSave.districtId.isEmpty {
            toSave.districtId = appModel.settings.selectedDistrictId
                ?? appModel.config.districts.first?.id
                ?? "home"
        }

        let trimmed = deadlineText.trimmingCharacters(in: .whitespacesAndNewlines)
        if JapanCalendar.parseHourMinute(trimmed) != nil {
            appModel.settings.customDropoffDeadline = trimmed
            deadlineText = trimmed
        }

        // 1) App Group 强制写入
        ScheduleOverrideStore.upsert(toSave)
        // 2–3) 刷新日历 / 看板 / 通知 / 小组件
        appModel.saveScheduleOverride(toSave, rescheduleNotifications: true)

        draft = toSave
        baselineDraft = toSave
        baselineDeadline = deadlineText
        didSaveBanner = true

        // 4) 轻触觉
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        if dismissAfter {
            dismiss()
        }
    }

    private func reset() {
        appModel.settings.customDropoffDeadline = ""
        appModel.clearScheduleOverride(districtId: draft.districtId)
        loadDraft()
        didSaveBanner = true
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

// MARK: - 单分类收集周期编辑（本地草稿 + 显式保存）

private struct CategoryScheduleEditor: View {
    let category: WasteCategory
    let onSave: (CollectionSchedule) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var schedule: CollectionSchedule
    @State private var baseline: CollectionSchedule

    init(
        category: WasteCategory,
        initial: CollectionSchedule,
        onSave: @escaping (CollectionSchedule) -> Void
    ) {
        self.category = category
        self.onSave = onSave
        _schedule = State(initialValue: initial)
        _baseline = State(initialValue: initial)
    }

    private var isDirty: Bool {
        schedule != baseline
    }

    var body: some View {
        Form {
            Section(L10n.t("override_kind_section")) {
                Picker(L10n.t("override_kind"), selection: $schedule.kind) {
                    Text(L10n.t("override_kind_weekly")).tag(CollectionScheduleKind.weekly)
                    Text(L10n.t("override_kind_monthly")).tag(CollectionScheduleKind.monthlyNthWeekday)
                    Text(L10n.t("override_kind_biweekly")).tag(CollectionScheduleKind.biweekly)
                }
                .onChange(of: schedule.kind) { _, newKind in
                    normalize(for: newKind)
                }
            }

            if schedule.kind == .weekly {
                Section(L10n.t("onboarding_combustible_days")) {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(isOn: weekdayBinding(day)) {
                            Text(weekdayLabel(day))
                        }
                    }
                }
            }

            if schedule.kind == .monthlyNthWeekday {
                Section {
                    Picker(L10n.t("override_weekday"), selection: Binding(
                        get: { schedule.weekday ?? 2 },
                        set: {
                            var next = schedule
                            next.weekday = $0
                            next.categoryId = category.id
                            schedule = next
                        }
                    )) {
                        ForEach(1...7, id: \.self) { day in
                            Text(weekdayLabel(day)).tag(day)
                        }
                    }
                    ForEach([1, 2, 3, 4, 5], id: \.self) { nth in
                        Toggle(isOn: weekOfMonthBinding(nth)) {
                            Text("\(L10n.t("override_nth_week_prefix")) \(nth)")
                        }
                    }
                }
            }

            if schedule.kind == .biweekly {
                Section {
                    Picker(L10n.t("override_weekday"), selection: Binding(
                        get: { schedule.weekday ?? 3 },
                        set: {
                            var next = schedule
                            next.weekday = $0
                            next.categoryId = category.id
                            schedule = next
                        }
                    )) {
                        ForEach(1...7, id: \.self) { day in
                            Text(weekdayLabel(day)).tag(day)
                        }
                    }
                    Picker(L10n.t("override_biweekly_parity"), selection: Binding(
                        get: { schedule.biweeklyParity ?? .odd },
                        set: {
                            var next = schedule
                            next.biweeklyParity = $0
                            next.categoryId = category.id
                            schedule = next
                        }
                    )) {
                        Text(L10n.t("override_parity_odd")).tag(BiweeklyParity.odd)
                        Text(L10n.t("override_parity_even")).tag(BiweeklyParity.even)
                    }
                    YMDDatePicker(
                        title: L10n.t("override_biweekly_anchor"),
                        ymd: Binding(
                            get: {
                                schedule.biweeklyAnchor
                                    ?? JapanCalendar.ymdString(from: Date())
                            },
                            set: {
                                var next = schedule
                                next.biweeklyAnchor = $0
                                next.categoryId = category.id
                                schedule = next
                            }
                        )
                    )
                }
            }
        }
        .navigationTitle(category.names.resolved())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                OverrideSaveToolbarButton(isDirty: isDirty) {
                    commitSave()
                }
            }
        }
        .onAppear {
            if schedule.kind == .weekly, (schedule.weekdays ?? []).isEmpty {
                var next = schedule
                next.weekdays = [2, 5]
                next.categoryId = category.id
                schedule = next
                baseline = next
            }
        }
    }

    private func commitSave() {
        var next = schedule
        next.categoryId = category.id
        // 规范化空数组，避免无效规则写入
        switch next.kind {
        case .weekly:
            if (next.weekdays ?? []).isEmpty { next.weekdays = [2, 5] }
        case .monthlyNthWeekday:
            if next.weekday == nil { next.weekday = 2 }
            if (next.weeksOfMonth ?? []).isEmpty { next.weeksOfMonth = [1, 3] }
        case .biweekly:
            if next.weekday == nil { next.weekday = 3 }
            if next.biweeklyParity == nil { next.biweeklyParity = .odd }
            if next.biweeklyAnchor == nil {
                next.biweeklyAnchor = JapanCalendar.ymdString(from: Date())
            }
        }
        schedule = next
        baseline = next
        onSave(next) // 父页强制写入 App Group + 刷新日历/通知/小组件 + 触觉
        dismiss()
    }

    private func weekdayBinding(_ day: Int) -> Binding<Bool> {
        Binding(
            get: { (schedule.weekdays ?? []).contains(day) },
            set: { on in
                var days = Set(schedule.weekdays ?? [])
                if on { days.insert(day) } else { days.remove(day) }
                if days.isEmpty { days = [day] }
                var next = schedule
                next.weekdays = days.sorted()
                next.categoryId = category.id
                next.kind = .weekly
                schedule = next
            }
        )
    }

    private func weekOfMonthBinding(_ nth: Int) -> Binding<Bool> {
        Binding(
            get: { (schedule.weeksOfMonth ?? []).contains(nth) },
            set: { on in
                var weeks = Set(schedule.weeksOfMonth ?? [])
                if on { weeks.insert(nth) } else { weeks.remove(nth) }
                if weeks.isEmpty { weeks = [nth] }
                var next = schedule
                next.weeksOfMonth = weeks.sorted()
                next.categoryId = category.id
                next.kind = .monthlyNthWeekday
                schedule = next
            }
        )
    }

    private func normalize(for kind: CollectionScheduleKind) {
        var next = schedule
        next.categoryId = category.id
        next.kind = kind
        switch kind {
        case .weekly:
            next.weekdays = next.weekdays ?? [2, 5]
            next.weekday = nil
            next.weeksOfMonth = nil
            next.biweeklyAnchor = nil
            next.biweeklyParity = nil
        case .monthlyNthWeekday:
            next.weekday = next.weekday ?? 2
            next.weeksOfMonth = next.weeksOfMonth ?? [1, 3]
            next.weekdays = nil
            next.biweeklyAnchor = nil
            next.biweeklyParity = nil
        case .biweekly:
            next.weekday = next.weekday ?? 3
            next.biweeklyParity = next.biweeklyParity ?? .odd
            next.biweeklyAnchor = next.biweeklyAnchor ?? JapanCalendar.ymdString(from: Date())
            next.weekdays = nil
            next.weeksOfMonth = nil
        }
        schedule = next
    }

    private func weekdayLabel(_ day: Int) -> String {
        switch day {
        case 1: return L10n.t("weekday_mon")
        case 2: return L10n.t("weekday_tue")
        case 3: return L10n.t("weekday_wed")
        case 4: return L10n.t("weekday_thu")
        case 5: return L10n.t("weekday_fri")
        case 6: return L10n.t("weekday_sat")
        default: return L10n.t("weekday_sun")
        }
    }
}

// MARK: - 右上角唯一「保存」按钮

private struct OverrideSaveToolbarButton: View {
    let isDirty: Bool
    let action: () -> Void

    private let accent = Color(hex: 0x34C759)

    var body: some View {
        Button {
            guard isDirty else { return }
            action()
        } label: {
            Text(L10n.t("override_save"))
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, isDirty ? 12 : 4)
                .padding(.vertical, isDirty ? 6 : 4)
                .foregroundStyle(isDirty ? Color.white : accent)
                .background {
                    if isDirty {
                        Capsule().fill(accent)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("override_save"))
        .accessibilityAddTraits(isDirty ? .isButton : [.isButton, .isStaticText])
    }
}
