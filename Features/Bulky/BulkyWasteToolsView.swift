//
//  BulkyWasteToolsView.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 粗大ごみ工具：随当前选中地区动态切换案内・电话；免费开放。
struct BulkyWasteToolsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @AppStorage(AppLanguageCode.storageKey) private var selectedLanguage: String = AppLanguageCode.auto.rawValue
    @Bindable private var settings = UserSettingsStore.shared

    @State private var lengthCm = ""
    @State private var widthCm = ""
    @State private var heightCm = ""
    @State private var weightKg = ""
    @State private var memoTitle = ""
    @State private var memoDate = Date()
    @State private var copyHint: String?

    private var placeName: String {
        let city = settings.selectedCityLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !city.isEmpty { return city }
        return appModel.config.names.resolved()
    }

    private var regionTitle: String {
        let pref = appModel.catalog.prefecture(code: settings.selectedPrefectureCode)?.nameJa ?? ""
        if pref.isEmpty { return placeName }
        return "\(pref) / \(placeName)"
    }

    private var guideHeader: String {
        String(format: L10n.t("bulky_guide_header_fmt"), placeName)
    }

    private var estimatedFee: Int? {
        guard let l = Double(lengthCm), let w = Double(widthCm), let h = Double(heightCm) else {
            return nil
        }
        return Self.estimateFeeYen(sumCm: l + w + h, weightKg: Double(weightKg) ?? 0)
    }

    private var phone: String {
        appModel.config.bulkyWaste.phone.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasRealPhone: Bool {
        guard !phone.isEmpty, phone != "—" else { return false }
        let lower = phone.lowercased()
        if lower.contains("xxxx") || lower.contains("xxx") { return false }
        return phone.contains(where: \.isNumber)
    }

    var body: some View {
        Form {
            Section {
                Text(regionTitle)
                    .font(.headline)
                Text(guideHeader)
                    .font(.subheadline.weight(.semibold))
                Text(appModel.config.bulkyWaste.feeNotes.resolved())
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if hasRealPhone {
                    LabeledContent(L10n.t("bulky_hours")) {
                        Text(appModel.config.bulkyWaste.receptionHours.resolved())
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent(L10n.t("bulky_phone"), value: phone)
                    HStack(spacing: 12) {
                        Button {
                            dial(phone)
                        } label: {
                            Label(L10n.t("bulky_call"), systemImage: "phone.fill")
                        }
                        Button {
                            copyPhone(phone)
                        } label: {
                            Label(L10n.t("bulky_copy"), systemImage: "doc.on.doc")
                        }
                    }
                    if let copyHint {
                        Text(copyHint)
                            .font(.caption)
                            .foregroundStyle(Color(hex: 0x34C759))
                    }
                } else {
                    Text(L10n.t("bulky_unknown_phone"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    openSafariSearch()
                } label: {
                    Text(String(format: L10n.t("bulky_search_place_fmt"), placeName))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: 0x34C759))
            } header: {
                Text(L10n.t("bulky_section_info"))
            }

            Section(L10n.t("bulky_section_calculator")) {
                TextField(L10n.t("bulky_length"), text: $lengthCm)
                    .keyboardType(.decimalPad)
                TextField(L10n.t("bulky_width"), text: $widthCm)
                    .keyboardType(.decimalPad)
                TextField(L10n.t("bulky_height"), text: $heightCm)
                    .keyboardType(.decimalPad)
                TextField(L10n.t("bulky_weight"), text: $weightKg)
                    .keyboardType(.decimalPad)

                if let estimatedFee {
                    LabeledContent(L10n.t("bulky_estimated_fee")) {
                        Text("¥\(estimatedFee)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color(hex: 0xAF52DE))
                    }
                } else {
                    Text(L10n.t("bulky_enter_size"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section(L10n.t("bulky_section_memo")) {
                TextField(L10n.t("bulky_memo_title"), text: $memoTitle)
                DatePicker(
                    L10n.t("bulky_memo_date"),
                    selection: $memoDate,
                    displayedComponents: [.date]
                )
                .environment(\.timeZone, JapanCalendar.timeZone)
                Button(L10n.t("bulky_memo_save")) {
                    guard !memoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    settings.addBulkyMemo(
                        BulkyAppointmentMemo(
                            id: UUID().uuidString,
                            title: memoTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                            date: memoDate,
                            estimatedFeeYen: estimatedFee
                        )
                    )
                    memoTitle = ""
                }
            }

            if !settings.bulkyMemos.isEmpty {
                Section(L10n.t("bulky_section_saved")) {
                    ForEach(settings.bulkyMemos) { memo in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memo.title).font(.headline)
                            Text(memo.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let fee = memo.estimatedFeeYen {
                                Text("¥\(fee)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(hex: 0xAF52DE))
                            }
                        }
                    }
                    .onDelete { indexSet in
                        settings.removeBulkyMemos(at: indexSet)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle(L10n.t("bulky_title"))
        .id("\(selectedLanguage)-\(settings.selectedCityId)-\(settings.selectedCityLabel)")
    }

    private func dial(_ raw: String) {
        let digits = raw.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
    }

    private func copyPhone(_ raw: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = raw
        #endif
        copyHint = L10n.t("bulky_copied")
    }

    private func openSafariSearch() {
        let pref = appModel.catalog.prefecture(code: settings.selectedPrefectureCode)?.nameJa ?? ""
        let query = [pref, placeName, "粗大ごみ", "予約", "受付"].filter { !$0.isEmpty }.joined(separator: " ")
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        if let url = components?.url {
            openURL(url)
        }
    }

    static func estimateFeeYen(sumCm: Double, weightKg: Double) -> Int {
        let sizeBand: Int
        switch sumCm {
        case ...200: sizeBand = 0
        case ...300: sizeBand = 1
        case ...400: sizeBand = 2
        default: sizeBand = 3
        }
        let weightBand: Int
        switch weightKg {
        case ..<15: weightBand = 0
        case ..<30: weightBand = 1
        case ..<40: weightBand = 2
        default: weightBand = 3
        }
        let table: [[Int]] = [
            [200, 500, 1000, 1500],
            [500, 500, 1000, 1500],
            [1000, 1000, 1000, 1500],
            [1500, 1500, 1500, 1500],
        ]
        return table[weightBand][sizeBand]
    }
}

struct BulkyAppointmentMemo: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var date: Date
    var estimatedFeeYen: Int?
}
