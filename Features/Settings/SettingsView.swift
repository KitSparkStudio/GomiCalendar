//
//  SettingsView.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @AppStorage(AppLanguageCode.storageKey) private var selectedLanguage: String = AppLanguageCode.auto.rawValue
    @State private var preferences = NotificationPreferences.load()
    @State private var showDistrictPicker = false
    @State private var showAddPlace = false
    @State private var showRegionPicker = false
    @State private var showPaywall = false
    @State private var showCustomSchedule = false
    @State private var authorizationHint: String?
    @State private var store = ProStore.shared
    @State private var liveActivity = GomiLiveActivityManager.shared
    @State private var supportCopyHint: String?
    @State private var selectedAccent = AccentTheme.current

    private static let supportEmail = "kitspark.support@gmail.com"

    /// 未 Pro：开关恒为关，拨动时弹出付费墙；已 Pro：正常开关。
    private var liveActivityToggleBinding: Binding<Bool> {
        Binding(
            get: { store.isPro && liveActivity.wantsLiveActivity },
            set: { enabled in
                guard store.isPro else {
                    showPaywall = true
                    return
                }
                liveActivity.wantsLiveActivity = enabled
                Task {
                    if enabled {
                        await liveActivity.syncAutomatically {
                            LiveActivityPayloadBuilder.make(from: appModel)
                        }
                    } else {
                        await liveActivity.endAll(markPreference: true)
                    }
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme).ignoresSafeArea()

                Form {
                    Section(L10n.t("settings_language_section")) {
                        Picker(L10n.t("settings_app_language"), selection: $selectedLanguage) {
                            ForEach(AppLanguageCode.allCases) { code in
                                Text(code.settingsLabel).tag(code.rawValue)
                            }
                        }
                        .onChange(of: selectedLanguage) { _, newValue in
                            AppLanguageCode(rawValue: newValue)?.persist()
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }

                    Section {
                        accentColorPicker
                    } header: {
                        Text(L10n.t("settings_appearance_section"))
                    } footer: {
                        Text(L10n.t("settings_accent_footer"))
                            .font(.footnote)
                    }

                    Section(L10n.t("settings_region_info_section")) {
                        LabeledContent(
                            L10n.t("settings_fiscal_year"),
                            value: appModel.config.displayFiscalYear
                        )
                        LabeledContent(
                            L10n.t("settings_rules_version"),
                            value: appModel.config.displayVersion
                        )
                    }

                    Section {
                        AutoLocateButton()

                        Button {
                            showRegionPicker = true
                        } label: {
                            HStack {
                                Text(L10n.t("settings_change_region"))
                                Spacer()
                                Text(regionLabel)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }

                        ForEach(appModel.settings.savedPlaces) { place in
                            placeRow(place)
                        }

                        if store.isPro || appModel.settings.savedPlaces.isEmpty {
                            Button(L10n.t("settings_add_district")) {
                                showAddPlace = true
                            }
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                Label(L10n.t("settings_unlock_multi_district"), systemImage: "lock.fill")
                            }
                        }

                        if appModel.showsDetailedDistrictPicker {
                            Button {
                                showDistrictPicker = true
                            } label: {
                                HStack {
                                    Text(L10n.t("settings_town_district"))
                                    Spacer()
                                    Text(appModel.selectedDistrict?.names.resolved() ?? "—")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        NavigationLink(L10n.t("override_title")) {
                            CustomScheduleOverrideView()
                        }

                        Toggle(L10n.t("settings_evening_reminder"), isOn: $preferences.eveningEnabled)
                        if preferences.eveningEnabled {
                            HourMinutePicker(
                                title: L10n.t("settings_evening_time"),
                                hhmm: $preferences.eveningTime
                            )
                        }
                        Toggle(L10n.t("settings_morning_reminder"), isOn: $preferences.morningEnabled)
                        if preferences.morningEnabled {
                            HourMinutePicker(
                                title: L10n.t("settings_morning_time"),
                                hhmm: $preferences.morningTime
                            )
                        }
                        Button(L10n.t("settings_reschedule_notifications")) {
                            Task { await reschedule() }
                        }
                        if let authorizationHint {
                            Text(authorizationHint)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        ScheduleAccuracyBanner(
                            onDismiss: nil,
                            onOpenCustomSchedule: { showCustomSchedule = true }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)

                        NavigationLink(L10n.t("bulky_title")) {
                            BulkyWasteToolsView()
                        }

                        if appModel.settings.usesStandardTemplate || appModel.config.isStandardTemplate {
                            NavigationLink(L10n.t("settings_edit_weekdays")) {
                                CustomWeekdaysView()
                            }
                        }
                    } header: {
                        Text(L10n.t("settings_district_section"))
                    } footer: {
                        Text(L10n.t("settings_places_footer"))
                            .font(.footnote)
                    }

                    Section(L10n.t("settings_pro_section")) {
                        if store.isPro {
                            Label(L10n.t("settings_pro_active"), systemImage: "checkmark.seal.fill")
                                .foregroundStyle(AppTheme.accent)
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                Label(L10n.t("settings_upgrade_pro"), systemImage: "star.circle.fill")
                            }
                        }
                    }

                    if DeviceCapability.hasDynamicIsland {
                        Section(L10n.t("settings_notifications_section")) {
                            Toggle(isOn: liveActivityToggleBinding) {
                                HStack(spacing: 8) {
                                    Text(L10n.t("settings_live_activity"))
                                    if !store.isPro {
                                        Text("PRO")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .foregroundStyle(.white)
                                            .background(AppTheme.accent, in: Capsule())
                                    }
                                }
                            }
                        }
                    }

                    Section(L10n.t("settings_about_section")) {
                        LabeledContent("App", value: appVersionLabel)

                        Button {
                            openSupportEmail()
                        } label: {
                            HStack {
                                Text(L10n.t("settings_support"))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(Self.supportEmail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                openSupportEmail()
                            } label: {
                                Label(L10n.t("settings_support_mail"), systemImage: "envelope")
                            }
                            Button {
                                copySupportEmail()
                            } label: {
                                Label(L10n.t("settings_support_copy"), systemImage: "doc.on.doc")
                            }
                        }
                        if let supportCopyHint {
                            Text(supportCopyHint)
                                .font(.caption)
                                .foregroundStyle(AppTheme.accent)
                        }

                        LabeledContent("Bundle", value: "com.kitsparkstudio.GomiCalendar")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n.t("tab_settings"))
            .id(selectedLanguage)
            .sheet(isPresented: $showDistrictPicker) {
                DistrictPickerSheet()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showAddPlace) {
                AddSavedPlaceSheet()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showRegionPicker) {
                RegionPickerSheet()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showPaywall, onDismiss: {
                selectedAccent = AccentTheme.current
                Task { await syncLiveActivityForProStatus() }
            }) {
                PaywallView()
            }
            .navigationDestination(isPresented: $showCustomSchedule) {
                CustomScheduleOverrideView()
            }
            .onAppear {
                selectedAccent = AccentTheme.current
            }
            .onReceive(NotificationCenter.default.publisher(for: .accentThemeDidChange)) { _ in
                selectedAccent = AccentTheme.current
            }
            .onChange(of: preferences) { _, newValue in
                newValue.save()
                Task { await reschedule() }
            }
            .onChange(of: store.isPro) { _, isPro in
                AccentTheme.clampToEntitlement(isPro: isPro)
                selectedAccent = AccentTheme.current
                Task { await syncLiveActivityForProStatus() }
            }
        }
    }

    /// 外观：横向圆形强调色选择器（选中光环；Pro 未解锁显示锁标）。
    private var accentColorPicker: some View {
        HStack(spacing: 18) {
            ForEach(AppTheme.accentOptions) { theme in
                Button {
                    selectAccent(theme)
                } label: {
                    ZStack {
                        Circle()
                            .fill(theme.color)
                            .frame(width: 36, height: 36)
                            .shadow(color: theme.color.opacity(selectedAccent == theme ? 0.45 : 0), radius: 6, y: 1)

                        if selectedAccent == theme {
                            Circle()
                                .strokeBorder(theme.color.opacity(0.95), lineWidth: 3)
                                .frame(width: 48, height: 48)
                        }

                        if theme.requiresPro && !store.isPro {
                            Image(systemName: "lock.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
                        }
                    }
                    .frame(width: 52, height: 52)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n.t(theme.displayNameKey)))
                .accessibilityAddTraits(selectedAccent == theme ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(L10n.t("settings_accent_color")))
    }

    private func selectAccent(_ theme: AccentTheme) {
        if theme.requiresPro, !store.isPro {
            showPaywall = true
            return
        }
        guard AccentTheme.select(theme, isPro: store.isPro) else {
            showPaywall = true
            return
        }
        selectedAccent = theme
    }

    private func placeRow(_ place: SavedPlace) -> some View {
        let isActive = place.id == appModel.settings.activePlaceId
            || (appModel.settings.activePlaceId == nil && place.id == appModel.settings.savedPlaces.first?.id)
        return HStack {
            Button {
                appModel.activatePlace(place)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isActive ? AppTheme.accent : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.displayTitle())
                            .font(.body.weight(isActive ? .semibold : .regular))
                            .foregroundStyle(.primary)
                        Text(place.regionLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            if appModel.settings.savedPlaces.count > 1 {
                Button(role: .destructive) {
                    appModel.removePlace(id: place.id)
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var regionLabel: String {
        if let place = appModel.settings.activePlace {
            return place.regionLine
        }
        let pref = appModel.catalog.prefecture(code: appModel.settings.selectedPrefectureCode)?.nameJa ?? ""
        let city = appModel.settings.selectedCityLabel
        if pref.isEmpty { return city }
        return "\(pref) / \(city)"
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let build, !build.isEmpty, build != version {
            return "ゴミログ \(version) (\(build))"
        }
        return "ゴミログ \(version)"
    }

    private func openSupportEmail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.supportEmail
        if let url = components.url {
            openURL(url)
        }
    }

    private func copySupportEmail() {
        #if canImport(UIKit)
        UIPasteboard.general.string = Self.supportEmail
        #endif
        supportCopyHint = L10n.t("bulky_copied")
    }

    private func reschedule() async {
        guard let districtId = appModel.settings.selectedDistrictId else { return }
        let ok = await NotificationScheduler.shared.requestAuthorizationIfNeeded()
        authorizationHint = ok ? nil : L10n.t("settings_notification_denied")
        await NotificationScheduler.shared.reschedule(
            config: appModel.effectiveConfig,
            districtId: districtId,
            preferences: preferences,
            temporaryRules: appModel.activeTemporaryRules
        )
    }

    private func syncLiveActivityForProStatus() async {
        if store.isPro {
            await liveActivity.syncAutomatically {
                LiveActivityPayloadBuilder.make(from: appModel)
            }
        } else {
            await liveActivity.endAll(markPreference: false)
        }
    }
}

struct CustomWeekdaysView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var days: Set<Int> = []

    var body: some View {
        List {
            Section(L10n.t("onboarding_combustible_days")) {
                ForEach(1...7, id: \.self) { day in
                    Button {
                        if days.contains(day), days.count > 1 {
                            days.remove(day)
                        } else {
                            days.insert(day)
                        }
                        appModel.updateCustomWeekdays(Array(days))
                    } label: {
                        HStack {
                            Text(weekdayLabel(day))
                            Spacer()
                            if days.contains(day) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                }
            }
            Section {
                Text(L10n.t("onboarding_template_note"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.t("settings_edit_weekdays"))
        .onAppear {
            days = Set(appModel.settings.customCombustibleWeekdays)
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

struct RegionPickerSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPrefecture: PrefectureEntry?
    @State private var query = ""
    @State private var showManual = false
    @State private var showSchedule = false

    var body: some View {
        NavigationStack {
            Group {
                if let selectedPrefecture {
                    List {
                        Section {
                            AutoLocateButton {
                                dismiss()
                            }
                            TextField(L10n.t("muni_search_city"), text: $query)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        ForEach(MunicipalityPickerHelpers.filteredCities(selectedPrefecture.cities, query: query)) { city in
                            Button {
                                appModel.selectCity(city, prefectureCode: selectedPrefecture.code)
                                if city.hasDetailedRules {
                                    dismiss()
                                } else {
                                    appModel.finishTemplateOnboarding(
                                        weekdays: appModel.settings.customCombustibleWeekdays
                                    )
                                    showSchedule = true
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(city.nameJa).font(.headline)
                                    if let kana = city.kana, !kana.isEmpty {
                                        Text(kana).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Text(city.hasDetailedRules
                                           ? L10n.t("onboarding_city_detailed")
                                           : L10n.t("onboarding_city_template"))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        Section {
                            Button {
                                showManual = true
                            } label: {
                                Label(L10n.t("manual_place_cta"), systemImage: "pencil.line")
                            }
                        }
                    }
                    .navigationTitle(selectedPrefecture.nameJa)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.t("onboarding_back")) {
                                self.selectedPrefecture = nil
                                query = ""
                            }
                        }
                    }
                } else {
                    List {
                        Section {
                            AutoLocateButton {
                                dismiss()
                            }
                            TextField(L10n.t("muni_search_prefecture"), text: $query)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        ForEach(MunicipalityPickerHelpers.filteredPrefectures(appModel.catalog.prefectures, query: query)) { pref in
                            Button {
                                selectedPrefecture = pref
                                query = ""
                            } label: {
                                HStack {
                                    Text(pref.nameJa).font(.headline)
                                    Spacer()
                                    Text("\(pref.cities.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle(L10n.t("settings_change_region"))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.t("close")) { dismiss() }
                        }
                    }
                }
            }
            .sheet(isPresented: $showManual) {
                ManualPlaceEntryView(prefectureCode: selectedPrefecture?.code) {
                    showSchedule = true
                }
            }
            .sheet(isPresented: $showSchedule, onDismiss: { dismiss() }) {
                NavigationStack {
                    CustomScheduleOverrideView()
                        .toolbar {
                            // Sheet 无系统返回键：关闭放 leading，避免与右上角「保存」抢 confirmation 位
                            ToolbarItem(placement: .cancellationAction) {
                                Button(L10n.t("close")) { showSchedule = false }
                            }
                        }
                }
            }
        }
    }
}
