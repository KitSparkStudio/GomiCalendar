//
//  AddSavedPlaceSheet.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI

/// 全量 47 都道府县 → 1,741 市町村选择器 + 地址标签，写入常用地区列表。
struct AddSavedPlaceSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPrefecture: PrefectureEntry?
    @State private var query = ""
    @State private var pendingCity: CatalogCityEntry?
    @State private var pendingPrefecture: PrefectureEntry?
    @State private var labelKind: PlaceLabelKind = .work
    @State private var customLabel = ""
    @State private var showPaywall = false
    @State private var store = ProStore.shared
    @State private var step: Step = .region

    private enum Step {
        case region
        case label
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .region:
                    regionPicker
                case .label:
                    labelPicker
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var regionPicker: some View {
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
                            pendingCity = city
                            pendingPrefecture = selectedPrefecture
                            step = .label
                        } label: {
                            cityRow(city)
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
                .navigationTitle(L10n.t("settings_add_district"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.t("close")) { dismiss() }
                    }
                }
            }
        }
    }

    private var labelPicker: some View {
        Form {
            if let city = pendingCity, let pref = pendingPrefecture {
                Section(L10n.t("place_selected_region")) {
                    Text("\(pref.nameJa) / \(city.nameJa)")
                        .font(.headline)
                }
            }
            Section(L10n.t("place_label_section")) {
                ForEach(PlaceLabelKind.allCases) { kind in
                    Button {
                        labelKind = kind
                    } label: {
                        HStack {
                            Text("\(kind.emoji) \(L10n.t(kind.l10nKey))")
                            Spacer()
                            if labelKind == kind {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(hex: 0x34C759))
                            }
                        }
                    }
                }
                if labelKind == .other {
                    TextField(L10n.t("place_custom_label_placeholder"), text: $customLabel)
                        .textInputAutocapitalization(.never)
                }
            }
            Section {
                Button {
                    save()
                } label: {
                    Text(L10n.t("place_save"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .disabled(pendingCity == nil || pendingPrefecture == nil)
            }
        }
        .navigationTitle(L10n.t("place_label_section"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.t("onboarding_back")) {
                    step = .region
                }
            }
        }
    }

    private func cityRow(_ city: CatalogCityEntry) -> some View {
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

    private func save() {
        guard let city = pendingCity, let pref = pendingPrefecture else { return }
        if !store.isPro, !appModel.settings.savedPlaces.isEmpty {
            showPaywall = true
            return
        }
        let custom = labelKind == .other
            ? customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        let ok = appModel.addSavedPlace(
            city: city,
            prefecture: pref,
            labelKind: labelKind,
            customLabel: (custom?.isEmpty == false) ? custom : nil,
            isPro: store.isPro
        )
        if ok {
            dismiss()
        } else {
            showPaywall = true
        }
    }
}
