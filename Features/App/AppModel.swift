//
//  AppModel.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation
import Observation
import WidgetKit

@Observable
@MainActor
final class AppModel {
    var config: CityWasteConfig
    var catalog: RegionCatalog
    var settings: UserSettingsStore
    var loadError: String?
    var ruleUpdateMessage: String?
    var isCheckingRules = false
    /// 触发看板刷新的世代号（热更新 / 覆盖保存后递增）
    var scheduleEpoch: Int = 0

    var calculator: ScheduleCalculator {
        ScheduleCalculator(
            config: effectiveConfig,
            temporaryRules: activeTemporaryRules
        )
    }

    var activeTemporaryRules: [TemporaryDayRule] {
        guard let districtId = settings.selectedDistrictId,
              let override = ScheduleOverrideStore.override(
                cityId: settings.selectedCityId,
                districtId: districtId
              )
        else { return [] }
        return override.temporaryDays
    }

    /// 标准模板可燃日 + Pro 自定义周期覆盖。
    var effectiveConfig: CityWasteConfig {
        var cfg = config
        if cfg.isStandardTemplate || settings.usesStandardTemplate || settings.usesCustomWeekdays {
            cfg = applyCustomWeekdays(to: cfg)
        }
        cfg = ScheduleOverrideStore.applyScheduleOverrides(
            to: cfg,
            cityId: settings.selectedCityId,
            districtId: settings.selectedDistrictId
        )
        let deadline = settings.customDropoffDeadline.trimmingCharacters(in: .whitespacesAndNewlines)
        if !deadline.isEmpty {
            cfg.defaultDropoffDeadline = deadline
        }
        return cfg
    }

    var selectedDistrict: DistrictRule? {
        guard let id = settings.selectedDistrictId else { return nil }
        return calculator.district(id: id)
    }

    /// 看板/设置顶部展示用：优先 SavedPlace 标题，避免模板「自宅区域」。
    var activePlaceTitle: String {
        if let place = settings.activePlace {
            return place.displayTitle()
        }
        let pref = catalog.prefecture(code: settings.selectedPrefectureCode)?.nameJa ?? ""
        let city = settings.selectedCityLabel
        if pref.isEmpty { return city }
        return "\(pref) / \(city)"
    }

    var showsDetailedDistrictPicker: Bool {
        !config.isStandardTemplate
            && !settings.usesStandardTemplate
            && config.districts.count > 1
    }

    /// 当前地区是否已保存自定义收集日覆盖（用于提示条安心态）。
    var hasCustomScheduleOverride: Bool {
        guard let districtId = settings.selectedDistrictId else { return false }
        return ScheduleOverrideStore.hasMeaningfulOverride(
            cityId: settings.selectedCityId,
            districtId: districtId
        )
    }

    init(settings: UserSettingsStore? = nil) {
        let resolved = settings ?? .shared
        self.settings = resolved
        self.catalog = (try? RegionCatalog.load()) ?? RegionCatalog(schemaVersion: 1, prefectures: [])
        do {
            self.config = try CityWasteConfig.loadCity(
                cityId: resolved.selectedCityId,
                displayNameJa: resolved.selectedCityLabel
            )
        } catch {
            self.loadError = error.localizedDescription
            self.config = (try? CityWasteConfig.loadCity(
                cityId: "jp_standard_household",
                displayNameJa: resolved.selectedCityLabel
            )) ?? Self.placeholderConfig
        }
    }

    /// 选择/切换主要市区町村（引导页・更换地区）。更新当前激活 SavedPlace。
    func selectCity(_ entry: CatalogCityEntry, prefectureCode: String) {
        let prefName = catalog.prefecture(code: prefectureCode)?.nameJa ?? ""
        reloadCity(entry.cityId, displayNameJa: entry.nameJa)

        var place = settings.activePlace ?? SavedPlace(
            labelKind: .home,
            prefectureCode: prefectureCode,
            prefectureNameJa: prefName,
            cityId: entry.cityId,
            cityNameJa: entry.nameJa,
            jisCode: entry.jisCode,
            districtId: config.districts.first?.id,
            hasDetailedRules: entry.hasDetailedRules
        )
        place.prefectureCode = prefectureCode
        place.prefectureNameJa = prefName
        place.cityId = entry.cityId
        place.cityNameJa = entry.nameJa
        place.jisCode = entry.jisCode
        place.hasDetailedRules = entry.hasDetailedRules
        place.districtId = config.districts.first?.id
        place.districtNote = nil

        settings.selectedPrefectureCode = prefectureCode
        settings.selectedCityLabel = entry.nameJa
        settings.usesStandardTemplate = !entry.hasDetailedRules
        settings.usesCustomWeekdays = !entry.hasDetailedRules
        settings.upsertPlace(place, activate: true, isPro: true)
        bumpSchedule()
    }

    /// Pro：新增常用地区并激活。
    @discardableResult
    func addSavedPlace(
        city: CatalogCityEntry,
        prefecture: PrefectureEntry,
        labelKind: PlaceLabelKind,
        customLabel: String?,
        isPro: Bool
    ) -> Bool {
        let place = SavedPlace(
            labelKind: labelKind,
            customLabel: customLabel,
            prefectureCode: prefecture.code,
            prefectureNameJa: prefecture.nameJa,
            cityId: city.cityId,
            cityNameJa: city.nameJa,
            jisCode: city.jisCode,
            districtId: nil,
            hasDetailedRules: city.hasDetailedRules
        )
        let ok = settings.upsertPlace(place, activate: false, isPro: isPro)
        guard ok else { return false }

        activatePlace(place)
        if !city.hasDetailedRules {
            finishTemplateOnboarding(weekdays: settings.customCombustibleWeekdays)
        }
        return true
    }

    func activatePlace(_ place: SavedPlace) {
        settings.activatePlace(place)
        reloadCity(place.cityId, displayNameJa: place.cityNameJa)
        if settings.selectedDistrictId == nil, let first = config.districts.first {
            settings.selectDistrict(id: first.id, cityId: place.cityId)
        }
        bumpSchedule()
        Task { await rescheduleNotifications() }
    }

    func removePlace(id: String) {
        let wasActive = settings.activePlaceId == id
        settings.removePlace(id: id)
        if wasActive, let next = settings.activePlace {
            reloadCity(next.cityId, displayNameJa: next.cityNameJa)
        }
        bumpSchedule()
        Task { await rescheduleNotifications() }
    }

    /// CoreLocation + CLGeocoder(ja_JP) → 匹配 1,741 库并设为当前地区。
    func autoLocateCurrentMunicipality() async throws {
        let (pref, city) = try await LocationPlaceResolver.shared.resolveMunicipality(in: catalog)
        selectCity(city, prefectureCode: pref.code)
        if city.hasDetailedRules {
            if let first = config.districts.first {
                selectDistrict(first)
            }
        } else {
            finishTemplateOnboarding(weekdays: settings.customCombustibleWeekdays)
        }
    }

    /// 手动输入任意地名：创建专属模板档案并进入可自定义收集日状态。
    @discardableResult
    func adoptCustomPlace(displayName: String, prefectureCode: String?) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Custom" : trimmed
        let slug = name
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }
            .joined()
        let stamp = Int(Date().timeIntervalSince1970)
        let cityId = "jp_custom_\(stamp)_\(slug.prefix(24))"
        let code = prefectureCode ?? settings.selectedPrefectureCode
        let prefName = catalog.prefecture(code: code)?.nameJa ?? ""

        settings.selectedPrefectureCode = code
        settings.selectedCityLabel = name
        settings.usesStandardTemplate = true
        settings.usesCustomWeekdays = true
        settings.customDropoffDeadline = settings.customDropoffDeadline.isEmpty
            ? "08:00"
            : settings.customDropoffDeadline
        reloadCity(cityId, displayNameJa: name)

        let districtId = config.districts.first?.id
        let place = SavedPlace(
            id: settings.activePlace?.id ?? UUID().uuidString,
            labelKind: settings.activePlace?.labelKind ?? .home,
            customLabel: settings.activePlace?.customLabel,
            prefectureCode: code,
            prefectureNameJa: prefName,
            cityId: cityId,
            cityNameJa: name,
            jisCode: "00000",
            districtId: districtId,
            districtNote: name,
            hasDetailedRules: false
        )
        settings.upsertPlace(place, activate: true, isPro: true)
        if let districtId {
            settings.selectDistrict(id: districtId, cityId: cityId)
        }
        bumpSchedule()
        Task { await rescheduleNotifications() }
        return cityId
    }

    func selectDistrict(_ district: DistrictRule) {
        settings.selectDistrict(id: district.id, cityId: config.cityId)
        bumpSchedule()
        Task { await rescheduleNotifications() }
    }

    func finishTemplateOnboarding(weekdays: [Int]) {
        settings.customCombustibleWeekdays = weekdays.sorted()
        settings.usesCustomWeekdays = true
        settings.usesStandardTemplate = true
        let district = effectiveConfig.districts.first ?? config.districts.first
        if let district {
            settings.selectDistrict(id: district.id, cityId: config.cityId)
            bumpSchedule()
            Task { await rescheduleNotifications() }
        }
    }

    func updateCustomWeekdays(_ weekdays: [Int]) {
        settings.customCombustibleWeekdays = weekdays.sorted()
        settings.usesCustomWeekdays = true
        bumpSchedule()
        Task { await rescheduleNotifications() }
    }

    func reloadCity(_ cityId: String, displayNameJa: String? = nil) {
        do {
            let label = displayNameJa ?? settings.selectedCityLabel
            config = try CityWasteConfig.loadCity(cityId: cityId, displayNameJa: label)
            settings.selectedCityId = cityId
            settings.selectedCityLabel = label
            settings.usesStandardTemplate = config.isStandardTemplate

            if settings.selectedDistrictId == nil
                || calculator.district(id: settings.selectedDistrictId ?? "") == nil {
                if config.isStandardTemplate {
                    settings.selectedDistrictId = config.districts.first?.id
                } else if let first = config.districts.first {
                    settings.selectedDistrictId = first.id
                }
            }

            bumpSchedule()
            if settings.hasCompletedOnboarding {
                Task { await rescheduleNotifications() }
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// 从 App Group 缓存重新装载当前城市（热更新后）。
    func reloadFromCacheOrBundle() {
        reloadCity(settings.selectedCityId, displayNameJa: settings.selectedCityLabel)
    }

    func saveScheduleOverride(_ override: DistrictScheduleOverride) {
        ScheduleOverrideStore.upsert(override)
        bumpSchedule()
        Task { await rescheduleNotifications() }
    }

    func clearScheduleOverride(districtId: String) {
        ScheduleOverrideStore.remove(cityId: settings.selectedCityId, districtId: districtId)
        bumpSchedule()
        Task { await rescheduleNotifications() }
    }

    /// 启动 / 前台 / 设置页手动检查。
    @discardableResult
    func checkRuleUpdates(userInitiated: Bool = false) async -> RuleUpdateOutcome {
        if userInitiated { isCheckingRules = true }
        defer { if userInitiated { isCheckingRules = false } }

        let outcome = await RuleUpdateService.shared.checkAndUpdateIfNeeded(
            cityId: settings.selectedCityId,
            currentVersion: config.version
        )
        switch outcome {
        case .updated(_, let version):
            reloadFromCacheOrBundle()
            ruleUpdateMessage = "\(L10n.t("settings_rules_updated")) \(version)"
            WidgetCenter.shared.reloadAllTimelines()
            await GomiLiveActivityManager.shared.renewIfNeeded {
                LiveActivityPayloadBuilder.make(from: self)
            }
        case .upToDate:
            if userInitiated {
                ruleUpdateMessage = L10n.t("settings_rules_uptodate")
            }
        case .noEntry:
            if userInitiated {
                ruleUpdateMessage = L10n.t("settings_rules_no_remote")
            }
        case .skippedOfflineOrError:
            if userInitiated {
                ruleUpdateMessage = L10n.t("settings_rules_check_failed")
            }
        }
        return outcome
    }

    func applyCustomWeekdays(to config: CityWasteConfig) -> CityWasteConfig {
        var cfg = config
        let days = settings.customCombustibleWeekdays
        guard !days.isEmpty else { return cfg }
        cfg.districts = cfg.districts.map { district in
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
        return cfg
    }

    private func bumpSchedule() {
        scheduleEpoch &+= 1
        WidgetCenter.shared.reloadAllTimelines()
        Task {
            await GomiLiveActivityManager.shared.syncAutomatically {
                LiveActivityPayloadBuilder.make(from: self)
            }
        }
    }

    private func rescheduleNotifications() async {
        guard let districtId = settings.selectedDistrictId else { return }
        await NotificationScheduler.shared.reschedule(
            config: effectiveConfig,
            districtId: districtId,
            preferences: NotificationPreferences.load(),
            temporaryRules: activeTemporaryRules
        )
    }

    private static let placeholderConfig = CityWasteConfig(
        schemaVersion: 1,
        fiscalYear: "2026",
        version: "2026.11.1",
        lastUpdated: "2026-11-20",
        jisCode: "00000",
        cityId: "jp_standard_household",
        names: LocalizedText(ja: "標準", kana: "ひょうじゅん", en: "Standard", zhHans: "标准", vi: "Chuẩn", ko: "표준"),
        defaultDropoffDeadline: "08:00",
        bulkyWaste: BulkyWasteInfo(
            phone: "—",
            receptionHours: LocalizedText(ja: "", kana: nil, en: "", zhHans: "", vi: "", ko: ""),
            feeNotes: LocalizedText(ja: "", kana: nil, en: "", zhHans: "", vi: "", ko: ""),
            onlineBookingURL: nil
        ),
        yearEndSuspensions: [],
        categories: [],
        districts: [],
        itemDictionary: []
    )
}
