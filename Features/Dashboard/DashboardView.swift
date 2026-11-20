//
//  DashboardView.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Combine
import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showDistrictPicker = false
    @State private var showCustomSchedule = false
    @State private var now = Date()
    @AppStorage("scheduleAccuracyBannerDismissedKey") private var dismissedHintKey = ""

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        heroSection
                        nextDaysSection
                        if shouldShowScheduleHint {
                            ScheduleAccuracyBanner(
                                onDismiss: { dismissedHintKey = currentHintKey },
                                onOpenCustomSchedule: { showCustomSchedule = true }
                            )
                        }
                    }
                    .padding(.horizontal, sizeClass == .regular ? 28 : 16)
                    .padding(.vertical, 16)
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDistrictPicker) {
                DistrictPickerSheet()
                    .presentationDetents([.medium, .large])
            }
            .navigationDestination(isPresented: $showCustomSchedule) {
                CustomScheduleOverrideView()
            }
            .onReceive(timer) { value in
                now = value
            }
            .id(appModel.scheduleEpoch)
        }
    }

    private var currentHintKey: String {
        let city = appModel.settings.selectedCityId
        let district = appModel.settings.selectedDistrictId ?? "home"
        return "\(city)|\(district)"
    }

    private var shouldShowScheduleHint: Bool {
        dismissedHintKey != currentHintKey
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    if appModel.showsDetailedDistrictPicker {
                        showDistrictPicker = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(appModel.activePlaceTitle)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.leading)
                        if appModel.showsDetailedDistrictPicker {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!appModel.showsDetailedDistrictPicker)

                if appModel.showsDetailedDistrictPicker,
                   let town = appModel.selectedDistrict?.names.resolved() {
                    Text(town)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(dateLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                if appModel.settings.savedPlaces.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(appModel.settings.savedPlaces) { place in
                                placeChip(place)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            Spacer()
        }
    }

    private func placeChip(_ place: SavedPlace) -> some View {
        let isActive = place.id == appModel.settings.activePlaceId
            || (appModel.settings.activePlaceId == nil
                && place.id == appModel.settings.savedPlaces.first?.id)
        return Button {
            guard !isActive else { return }
            appModel.activatePlace(place)
        } label: {
            Text(place.displayTitle())
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isActive ? Color.accentColor : AppTheme.card(for: colorScheme),
                    in: Capsule()
                )
                .foregroundStyle(isActive ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var heroSection: some View {
        let focus = focusDay
        let hasPickup = !focus.result.categories.isEmpty && !focus.result.isSuspended
        return HeroWasteCard(
            title: focus.isTodayFocus
                ? L10n.t("hero_title_today")
                : L10n.t("hero_title_tomorrow"),
            subtitle: focus.isTodayFocus
                ? L10n.t("hero_subtitle_before_deadline")
                : L10n.t("hero_subtitle_prepare"),
            categories: focus.result.categories,
            isSuspended: focus.result.isSuspended,
            suspensionNote: focus.result.suspensionNotes?.resolved(),
            countdownText: hasPickup
                ? countdownText(for: focus.result.date, deadline: focus.result.dropoffDeadline)
                : nil,
            deadline: focus.result.dropoffDeadline
        )
    }

    private var nextDaysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("next_pickups_section"))
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(nextInfos, id: \.categoryId) { info in
                        if let category = appModel.config.categories.first(where: { $0.id == info.categoryId && $0.isActive && !$0.requiresAppointment }) {
                            DaysUntilCapsule(category: category, daysUntil: info.daysUntil)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Logic

    private var dateLabel: String {
        let day = JapanCalendar.startOfDay(for: now)
        return day.formatted(
            .dateTime
                .year()
                .month().day()
                .weekday(.wide)
                .locale(Locale.autoupdatingCurrent)
        )
    }

    private struct FocusDay {
        var result: DayCollectionResult
        var isTodayFocus: Bool
    }

    private var focusDay: FocusDay {
        guard let districtId = appModel.settings.selectedDistrictId else {
            let empty = DayCollectionResult(
                date: JapanCalendar.startOfDay(for: now),
                isSuspended: false,
                suspensionNotes: nil,
                categories: [],
                dropoffDeadline: appModel.config.defaultDropoffDeadline
            )
            return FocusDay(result: empty, isTodayFocus: true)
        }

        let calc = appModel.calculator
        let today = calc.collections(on: now, districtId: districtId)
        let tomorrowDate = JapanCalendar.calendar.date(byAdding: .day, value: 1, to: JapanCalendar.startOfDay(for: now)) ?? now
        let tomorrow = calc.collections(on: tomorrowDate, districtId: districtId)

        if shouldFocusToday(deadline: today.dropoffDeadline), today.hasCollection || today.isSuspended {
            return FocusDay(result: today, isTodayFocus: true)
        }
        return FocusDay(result: tomorrow, isTodayFocus: false)
    }

    private func shouldFocusToday(deadline: String) -> Bool {
        guard let hm = JapanCalendar.parseHourMinute(deadline) else { return false }
        var components = JapanCalendar.calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hm.hour
        components.minute = hm.minute
        components.second = 0
        components.timeZone = JapanCalendar.timeZone
        guard let deadlineDate = JapanCalendar.calendar.date(from: components) else { return false }
        return now < deadlineDate
    }

    private func countdownText(for collectionDay: Date, deadline: String) -> String {
        guard let hm = JapanCalendar.parseHourMinute(deadline) else { return L10n.t("countdown_passed") }
        var components = JapanCalendar.calendar.dateComponents([.year, .month, .day], from: collectionDay)
        components.hour = hm.hour
        components.minute = hm.minute
        components.second = 0
        components.timeZone = JapanCalendar.timeZone
        guard let target = JapanCalendar.calendar.date(from: components) else {
            return L10n.t("countdown_passed")
        }

        let remaining = target.timeIntervalSince(now)
        if remaining <= 0 {
            return L10n.t("countdown_passed")
        }
        let totalSeconds = Int(remaining)
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        if days >= 1 {
            return String(format: L10n.t("countdown_dh_left"), days, hours)
        }
        return String(format: L10n.t("countdown_hm_left"), hours, minutes)
    }

    private var nextInfos: [NextCollectionInfo] {
        guard let districtId = appModel.settings.selectedDistrictId else { return [] }
        return appModel.calculator.daysUntilNextCollections(districtId: districtId, from: now)
    }
}

struct DistrictPickerSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var districts: [DistrictRule] {
        let all = appModel.config.districts
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter { district in
            var tokens = district.aliases
            tokens.append(contentsOf: [
                district.names.resolved(), district.names.en, district.names.zhHans,
                district.names.vi, district.names.ko, district.id,
            ])
            if let kana = district.names.kana { tokens.append(kana) }
            return SearchNormalizer.matches(q, in: tokens)
        }
    }

    var body: some View {
        NavigationStack {
            List(districts) { district in
                Button {
                    appModel.selectDistrict(district)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(district.names.resolved()).font(.headline)
                            Text(district.names.en).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if district.id == appModel.settings.selectedDistrictId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: L10n.t("onboarding_search_prompt"))
            .navigationTitle(L10n.t("switch_district"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("close")) { dismiss() }
                }
            }
        }
    }
}
