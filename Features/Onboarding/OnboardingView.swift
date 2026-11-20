//
//  OnboardingView.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var step: Step = .prefecture
    @State private var selectedPrefecture: PrefectureEntry?
    @State private var selectedCity: CatalogCityEntry?
    @State private var query = ""
    @State private var combustibleDays: Set<Int> = [1, 4]
    @State private var showManualPlace = false
    @State private var showCustomSchedule = false

    private enum Step {
        case prefecture
        case city
        case district
        case templateWeekdays
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    switch step {
                    case .prefecture:
                        prefectureList
                    case .city:
                        cityList
                    case .district:
                        districtList
                    case .templateWeekdays:
                        templateEditor
                    }
                }
            }
            .navigationTitle(L10n.t("onboarding_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .prefecture {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.t("onboarding_back")) {
                            goBack()
                        }
                    }
                }
            }
            .sheet(isPresented: $showManualPlace) {
                ManualPlaceEntryView(prefectureCode: selectedPrefecture?.code) {
                    showCustomSchedule = true
                }
            }
            .sheet(isPresented: $showCustomSchedule) {
                NavigationStack {
                    CustomScheduleOverrideView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.t("onboarding_finish")) {
                                    showCustomSchedule = false
                                }
                            }
                        }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headerTitle)
                .font(.largeTitle.weight(.bold))
            Text(headerSubtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerTitle: String {
        switch step {
        case .prefecture:
            return L10n.t("onboarding_pick_prefecture")
        case .city:
            return selectedPrefecture?.nameJa ?? L10n.t("onboarding_pick_city")
        case .district:
            return selectedCity?.nameJa ?? appModel.config.names.resolved()
        case .templateWeekdays:
            return L10n.t("onboarding_template_title")
        }
    }

    private var headerSubtitle: String {
        switch step {
        case .prefecture:
            return L10n.t("onboarding_subtitle")
        case .city:
            return L10n.t("onboarding_pick_city_hint")
        case .district:
            return L10n.t("onboarding_pick_district_hint")
        case .templateWeekdays:
            return L10n.t("onboarding_template_hint")
        }
    }

    private var prefectureList: some View {
        VStack(spacing: 0) {
            AutoLocateButton()
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            SearchField(text: $query, prompt: L10n.t("muni_search_prefecture"))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            List(MunicipalityPickerHelpers.filteredPrefectures(appModel.catalog.prefectures, query: query)) { pref in
                Button {
                    selectedPrefecture = pref
                    appModel.settings.selectedPrefectureCode = pref.code
                    step = .city
                    query = ""
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pref.nameJa).font(.headline).foregroundStyle(.primary)
                            Text(String(format: L10n.t("muni_count_fmt"), pref.cities.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .listRowBackground(AppTheme.card(for: colorScheme))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var cityList: some View {
        let cities = MunicipalityPickerHelpers.filteredCities(
            selectedPrefecture?.cities ?? [],
            query: query
        )
        return VStack(spacing: 0) {
            AutoLocateButton()
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            SearchField(text: $query, prompt: L10n.t("muni_search_city"))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            List {
                ForEach(cities) { city in
                    Button {
                        selectedCity = city
                        appModel.selectCity(city, prefectureCode: selectedPrefecture?.code ?? "01")
                        query = ""
                        if city.hasDetailedRules {
                            step = .district
                        } else {
                            combustibleDays = Set(appModel.settings.customCombustibleWeekdays)
                            step = .templateWeekdays
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(city.nameJa).font(.headline).foregroundStyle(.primary)
                                HStack(spacing: 6) {
                                    if let kana = city.kana, !kana.isEmpty {
                                        Text(kana)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(city.hasDetailedRules
                                           ? L10n.t("onboarding_city_detailed")
                                           : L10n.t("onboarding_city_template"))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(AppTheme.card(for: colorScheme))
                }
                Section {
                    Button {
                        showManualPlace = true
                    } label: {
                        Label(L10n.t("manual_place_cta"), systemImage: "pencil.line")
                            .font(.subheadline.weight(.semibold))
                    }
                    .listRowBackground(AppTheme.card(for: colorScheme))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var districtList: some View {
        VStack(spacing: 0) {
            SearchField(
                text: $query,
                prompt: L10n.t("onboarding_search_prompt")
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            List(filteredDistricts) { district in
                Button {
                    appModel.selectDistrict(district)
                } label: {
                    DistrictRow(district: district)
                }
                .listRowBackground(AppTheme.card(for: colorScheme))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var templateEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.t("onboarding_combustible_days"))
                .font(.headline)
                .padding(.horizontal, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(1...7, id: \.self) { day in
                    let selected = combustibleDays.contains(day)
                    Button {
                        if selected, combustibleDays.count > 1 {
                            combustibleDays.remove(day)
                        } else {
                            combustibleDays.insert(day)
                        }
                    } label: {
                        Text(weekdayLabel(day))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selected ? Color(hex: 0x34C759).opacity(0.25) : AppTheme.card(for: colorScheme),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(selected ? Color(hex: 0x34C759) : .clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Text(L10n.t("onboarding_template_note"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            Spacer()

            Button {
                appModel.finishTemplateOnboarding(weekdays: Array(combustibleDays))
            } label: {
                Text(L10n.t("onboarding_finish"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(hex: 0x34C759), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .disabled(combustibleDays.isEmpty)
        }
    }

    private var filteredDistricts: [DistrictRule] {
        let all = appModel.config.districts
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter { district in
            SearchNormalizer.matches(q, in: searchTokens(for: district))
        }
    }

    private func goBack() {
        query = ""
        switch step {
        case .city:
            step = .prefecture
            selectedCity = nil
        case .district, .templateWeekdays:
            step = .city
        case .prefecture:
            break
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

    private func searchTokens(for district: DistrictRule) -> [String] {
        var tokens = district.aliases
        tokens.append(district.names.resolved())
        if let kana = district.names.kana { tokens.append(kana) }
        tokens.append(district.names.en)
        tokens.append(district.names.zhHans)
        tokens.append(district.names.vi)
        tokens.append(district.names.ko)
        tokens.append(district.id)
        return tokens
    }
}

private struct DistrictRow: View {
    let district: DistrictRule

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(district.names.resolved())
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        let kana = district.names.kana.map { "（\($0)）" } ?? ""
        return "\(district.names.en)\(kana)"
    }
}

struct SearchField: View {
    @Binding var text: String
    var prompt: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
