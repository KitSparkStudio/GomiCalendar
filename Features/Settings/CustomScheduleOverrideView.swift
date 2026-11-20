//
//  CustomScheduleOverrideView.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI

/// 免费：在自治体模板上覆盖收集周期、投放截止时间，并添加临时停收 / 临时收集日。
struct CustomScheduleOverrideView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppLanguageCode.storageKey) private var selectedLanguage: String = AppLanguageCode.auto.rawValue
    @State private var draft: DistrictScheduleOverride
    @State private var deadlineText = "08:00"
    @State private var showAddTemporary = false
    @State private var tempDate = Date()
    @State private var tempEffect: TemporaryDayEffect = .suspend
    @State private var tempCategory: WasteCategoryID? = nil
    @State private var didSave = false

    init() {
        // 占位；onAppear 用真实 district 填充
        _draft = State(initialValue: DistrictScheduleOverride(cityId: "", districtId: ""))
    }

    var body: some View {
        List {
            Section {
                Text(L10n.t("override_intro"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.t("override_deadline_section")) {
                TextField(L10n.t("override_deadline_hint"), text: $deadlineText)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
            }

            Section(L10n.t("override_schedules_section")) {
                ForEach(activeCategories, id: \.id) { category in
                    NavigationLink {
                        CategoryScheduleEditor(
                            category: category,
                            schedule: bindingSchedule(for: category.id)
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
                        draft.temporaryDays.remove(atOffsets: offsets)
                    }
                }
                Button {
                    showAddTemporary = true
                } label: {
                    Label(L10n.t("override_add_temporary"), systemImage: "calendar.badge.plus")
                }
            }

            Section {
                Button(L10n.t("override_save")) {
                    save()
                }
                .font(.headline)

                Button(L10n.t("override_reset"), role: .destructive) {
                    reset()
                }
            }

            if didSave {
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
                            draft.temporaryDays.append(
                                TemporaryDayRule(ymd: ymd, effect: tempEffect, categoryId: tempCategory)
                            )
                            draft.temporaryDays.sort { $0.ymd < $1.ymd }
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
        let savedDeadline = appModel.settings.customDropoffDeadline.trimmingCharacters(in: .whitespacesAndNewlines)
        deadlineText = savedDeadline.isEmpty ? appModel.config.defaultDropoffDeadline : savedDeadline
        if let existing = ScheduleOverrideStore.override(cityId: cityId, districtId: districtId) {
            draft = existing
        } else {
            var schedules: [String: CollectionSchedule] = [:]
            if let district = appModel.effectiveConfig.districts.first(where: { $0.id == districtId }) {
                for schedule in district.schedules {
                    schedules[schedule.categoryId.rawValue] = schedule
                }
            }
            draft = DistrictScheduleOverride(
                cityId: cityId,
                districtId: districtId,
                categorySchedules: schedules,
                temporaryDays: []
            )
        }
    }

    private func bindingSchedule(for categoryId: WasteCategoryID) -> Binding<CollectionSchedule> {
        Binding {
            if let existing = draft.categorySchedules[categoryId.rawValue] {
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
        } set: { newValue in
            draft.categorySchedules[categoryId.rawValue] = newValue
        }
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

    private func save() {
        let trimmed = deadlineText.trimmingCharacters(in: .whitespacesAndNewlines)
        appModel.settings.customDropoffDeadline = trimmed
        appModel.saveScheduleOverride(draft)
        didSave = true
    }

    private func reset() {
        appModel.settings.customDropoffDeadline = ""
        appModel.clearScheduleOverride(districtId: draft.districtId)
        loadDraft()
        didSave = true
    }
}

private struct CategoryScheduleEditor: View {
    let category: WasteCategory
    @Binding var schedule: CollectionSchedule
    @State private var selectedWeekdays: Set<Int> = []

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
                        set: { schedule.weekday = $0 }
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
                        set: { schedule.weekday = $0 }
                    )) {
                        ForEach(1...7, id: \.self) { day in
                            Text(weekdayLabel(day)).tag(day)
                        }
                    }
                    Picker(L10n.t("override_biweekly_parity"), selection: Binding(
                        get: { schedule.biweeklyParity ?? .odd },
                        set: { schedule.biweeklyParity = $0 }
                    )) {
                        Text(L10n.t("override_parity_odd")).tag(BiweeklyParity.odd)
                        Text(L10n.t("override_parity_even")).tag(BiweeklyParity.even)
                    }
                    TextField(
                        L10n.t("override_biweekly_anchor"),
                        text: Binding(
                            get: { schedule.biweeklyAnchor ?? JapanCalendar.ymdString(from: Date()) },
                            set: { schedule.biweeklyAnchor = $0 }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numbersAndPunctuation)
                }
            }
        }
        .navigationTitle(category.names.resolved())
        .onAppear {
            selectedWeekdays = Set(schedule.weekdays ?? [])
            if schedule.kind == .weekly, selectedWeekdays.isEmpty {
                selectedWeekdays = [2, 5]
                schedule.weekdays = [2, 5]
            }
        }
    }

    private func weekdayBinding(_ day: Int) -> Binding<Bool> {
        Binding(
            get: { (schedule.weekdays ?? []).contains(day) },
            set: { on in
                var days = Set(schedule.weekdays ?? [])
                if on { days.insert(day) } else { days.remove(day) }
                if days.isEmpty { days = [day] }
                schedule.weekdays = days.sorted()
                schedule.categoryId = category.id
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
                schedule.weeksOfMonth = weeks.sorted()
                schedule.categoryId = category.id
            }
        )
    }

    private func normalize(for kind: CollectionScheduleKind) {
        schedule.categoryId = category.id
        switch kind {
        case .weekly:
            schedule.weekdays = schedule.weekdays ?? [2, 5]
            schedule.weekday = nil
            schedule.weeksOfMonth = nil
            schedule.biweeklyAnchor = nil
            schedule.biweeklyParity = nil
        case .monthlyNthWeekday:
            schedule.weekday = schedule.weekday ?? 2
            schedule.weeksOfMonth = schedule.weeksOfMonth ?? [1, 3]
            schedule.weekdays = nil
            schedule.biweeklyAnchor = nil
            schedule.biweeklyParity = nil
        case .biweekly:
            schedule.weekday = schedule.weekday ?? 3
            schedule.biweeklyParity = schedule.biweeklyParity ?? .odd
            schedule.biweeklyAnchor = schedule.biweeklyAnchor ?? JapanCalendar.ymdString(from: Date())
            schedule.weekdays = nil
            schedule.weeksOfMonth = nil
        }
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
