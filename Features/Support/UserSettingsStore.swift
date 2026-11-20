//
//  UserSettingsStore.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation
import Observation

/// 地区选择：App Group 本地共享 + `NSUbiquitousKeyValueStore` 免登录跨设备同步。
@Observable
@MainActor
final class UserSettingsStore {
    static let shared = UserSettingsStore()

    static let appGroupID = "group.com.kitsparkstudio.gomicalendar"

    private enum Key {
        static let districtId = "selectedDistrictId"
        static let cityId = "selectedCityId"
        static let prefectureCode = "selectedPrefectureCode"
        static let onboardingComplete = "onboardingComplete"
        static let bulkyMemos = "bulkyAppointmentMemos"
        static let customCombustibleWeekdays = "customCombustibleWeekdays"
        static let usesCustomWeekdays = "usesCustomWeekdays"
        static let selectedCityLabel = "selectedCityLabel"
        static let usesStandardTemplate = "usesStandardTemplate"
        static let customDropoffDeadline = "customDropoffDeadline"
        static let savedPlaces = "savedPlaces"
        static let activePlaceId = "activePlaceId"
    }

    /// 兼容：当前激活地区的町名 ID（与 `activePlace` 同步）。
    var selectedDistrictId: String? {
        didSet { persist() }
    }

    var selectedCityId: String {
        didSet { persist() }
    }

    var selectedPrefectureCode: String {
        didSet { persist() }
    }

    var customCombustibleWeekdays: [Int] = [1, 4] {
        didSet { persist() }
    }

    var usesCustomWeekdays: Bool {
        didSet { persist() }
    }

    var selectedCityLabel: String {
        didSet { persist() }
    }

    var usesStandardTemplate: Bool {
        didSet { persist() }
    }

    var customDropoffDeadline: String {
        didSet { persist() }
    }

    var hasCompletedOnboarding: Bool {
        didSet { persist() }
    }

    /// 常用地区列表（免费 1 个，Pro 可多个）。
    var savedPlaces: [SavedPlace] = [] {
        didSet { persist() }
    }

    var activePlaceId: String? {
        didSet { persist() }
    }

    var bulkyMemos: [BulkyAppointmentMemo] = [] {
        didSet { persistMemos() }
    }

    var activePlace: SavedPlace? {
        guard let activePlaceId else { return savedPlaces.first }
        return savedPlaces.first { $0.id == activePlaceId } ?? savedPlaces.first
    }

    private let defaults: UserDefaults
    private let cloud = NSUbiquitousKeyValueStore.default
    nonisolated(unsafe) private var cloudObserver: NSObjectProtocol?

    private init() {
        defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        selectedCityId = defaults.string(forKey: Key.cityId)
            ?? cloud.string(forKey: Key.cityId)
            ?? "jp_05201_akita"
        selectedPrefectureCode = defaults.string(forKey: Key.prefectureCode)
            ?? cloud.string(forKey: Key.prefectureCode)
            ?? "05"
        selectedDistrictId = defaults.string(forKey: Key.districtId)
            ?? cloud.string(forKey: Key.districtId)
        hasCompletedOnboarding = defaults.object(forKey: Key.onboardingComplete) as? Bool
            ?? cloud.bool(forKey: Key.onboardingComplete)
        customCombustibleWeekdays = (defaults.array(forKey: Key.customCombustibleWeekdays) as? [Int])
            ?? (cloud.array(forKey: Key.customCombustibleWeekdays) as? [Int])
            ?? [1, 4]
        usesCustomWeekdays = defaults.object(forKey: Key.usesCustomWeekdays) as? Bool
            ?? cloud.bool(forKey: Key.usesCustomWeekdays)
        selectedCityLabel = defaults.string(forKey: Key.selectedCityLabel)
            ?? cloud.string(forKey: Key.selectedCityLabel)
            ?? "秋田市"
        usesStandardTemplate = defaults.object(forKey: Key.usesStandardTemplate) as? Bool
            ?? cloud.bool(forKey: Key.usesStandardTemplate)
        customDropoffDeadline = defaults.string(forKey: Key.customDropoffDeadline)
            ?? cloud.string(forKey: Key.customDropoffDeadline)
            ?? ""
        bulkyMemos = Self.decodeMemos(defaults.data(forKey: Key.bulkyMemos))
            ?? Self.decodeMemos(cloud.data(forKey: Key.bulkyMemos))
            ?? []
        savedPlaces = Self.decodePlaces(defaults.data(forKey: Key.savedPlaces))
            ?? Self.decodePlaces(cloud.data(forKey: Key.savedPlaces))
            ?? []
        activePlaceId = defaults.string(forKey: Key.activePlaceId)
            ?? cloud.string(forKey: Key.activePlaceId)

        migrateLegacyPlacesIfNeeded()

        if let cloudDistrict = cloud.string(forKey: Key.districtId), !cloudDistrict.isEmpty {
            selectedDistrictId = cloudDistrict
            hasCompletedOnboarding = true
        }

        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pullFromCloud()
            }
        }
    }

    deinit {
        if let cloudObserver {
            NotificationCenter.default.removeObserver(cloudObserver)
        }
    }

    /// 从旧版单城市字段迁移出首个自宅地点。
    private func migrateLegacyPlacesIfNeeded() {
        guard savedPlaces.isEmpty, hasCompletedOnboarding || selectedDistrictId != nil else { return }
        let prefName: String = {
            switch selectedPrefectureCode {
            case "13": return "東京都"
            case "05": return "秋田県"
            default: return ""
            }
        }()
        let place = SavedPlace(
            labelKind: .home,
            prefectureCode: selectedPrefectureCode,
            prefectureNameJa: prefName.isEmpty ? selectedCityLabel : prefName,
            cityId: selectedCityId,
            cityNameJa: selectedCityLabel,
            jisCode: String(selectedCityId.split(separator: "_").dropFirst().first ?? Substring(selectedCityId)),
            districtId: selectedDistrictId,
            hasDetailedRules: !usesStandardTemplate
        )
        savedPlaces = [place]
        activePlaceId = place.id
        // 修正 jis：优先从 cityId `jp_05201_akita` 提取
        if let jis = extractJIS(from: selectedCityId) {
            var fixed = place
            fixed.jisCode = jis
            savedPlaces = [fixed]
            activePlaceId = fixed.id
        }
    }

    private func extractJIS(from cityId: String) -> String? {
        let parts = cityId.split(separator: "_")
        guard parts.count >= 2 else { return nil }
        let candidate = String(parts[1])
        return candidate.count == 5 && candidate.allSatisfy(\.isNumber) ? candidate : nil
    }

    func selectDistrict(id: String, cityId: String = "jp_05201_akita") {
        selectedCityId = cityId
        selectedDistrictId = id
        hasCompletedOnboarding = true
        if var place = activePlace {
            place.districtId = id
            place.cityId = cityId
            upsertPlace(place, activate: true)
        }
        persist()
    }

    @discardableResult
    func upsertPlace(_ place: SavedPlace, activate: Bool, isPro: Bool = true) -> Bool {
        if let idx = savedPlaces.firstIndex(where: { $0.id == place.id }) {
            savedPlaces[idx] = place
        } else {
            // 免费仅允许第一个；Pro 可多个
            if !isPro && !savedPlaces.isEmpty {
                return false
            }
            savedPlaces.append(place)
        }
        if activate {
            applyPlaceFields(place)
        }
        persist()
        return true
    }

    func activatePlace(_ place: SavedPlace) {
        applyPlaceFields(place)
        persist()
    }

    func removePlace(id: String) {
        savedPlaces.removeAll { $0.id == id }
        if activePlaceId == id {
            if let first = savedPlaces.first {
                applyPlaceFields(first)
            } else {
                activePlaceId = nil
                hasCompletedOnboarding = false
                selectedDistrictId = nil
            }
        }
        persist()
    }

    private func applyPlaceFields(_ place: SavedPlace) {
        activePlaceId = place.id
        selectedCityId = place.cityId
        selectedCityLabel = place.cityNameJa
        selectedPrefectureCode = place.prefectureCode
        selectedDistrictId = place.districtId
        usesStandardTemplate = !place.hasDetailedRules
        hasCompletedOnboarding = true
    }

    func clearDistrict() {
        selectedDistrictId = nil
        savedPlaces = []
        activePlaceId = nil
        hasCompletedOnboarding = false
        persist()
    }

    func addBulkyMemo(_ memo: BulkyAppointmentMemo) {
        bulkyMemos.insert(memo, at: 0)
    }

    func removeBulkyMemos(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            guard bulkyMemos.indices.contains(index) else { continue }
            bulkyMemos.remove(at: index)
        }
    }

    private func persist() {
        defaults.set(selectedDistrictId, forKey: Key.districtId)
        defaults.set(selectedCityId, forKey: Key.cityId)
        defaults.set(selectedPrefectureCode, forKey: Key.prefectureCode)
        defaults.set(hasCompletedOnboarding, forKey: Key.onboardingComplete)
        defaults.set(customCombustibleWeekdays, forKey: Key.customCombustibleWeekdays)
        defaults.set(usesCustomWeekdays, forKey: Key.usesCustomWeekdays)
        defaults.set(selectedCityLabel, forKey: Key.selectedCityLabel)
        defaults.set(usesStandardTemplate, forKey: Key.usesStandardTemplate)
        defaults.set(customDropoffDeadline, forKey: Key.customDropoffDeadline)
        defaults.set(activePlaceId, forKey: Key.activePlaceId)
        if let data = try? JSONEncoder().encode(savedPlaces) {
            defaults.set(data, forKey: Key.savedPlaces)
            cloud.set(data, forKey: Key.savedPlaces)
        }

        if let selectedDistrictId {
            cloud.set(selectedDistrictId, forKey: Key.districtId)
        } else {
            cloud.removeObject(forKey: Key.districtId)
        }
        cloud.set(selectedCityId, forKey: Key.cityId)
        cloud.set(selectedPrefectureCode, forKey: Key.prefectureCode)
        cloud.set(hasCompletedOnboarding, forKey: Key.onboardingComplete)
        cloud.set(customCombustibleWeekdays, forKey: Key.customCombustibleWeekdays)
        cloud.set(usesCustomWeekdays, forKey: Key.usesCustomWeekdays)
        cloud.set(selectedCityLabel, forKey: Key.selectedCityLabel)
        cloud.set(usesStandardTemplate, forKey: Key.usesStandardTemplate)
        cloud.set(customDropoffDeadline, forKey: Key.customDropoffDeadline)
        if let activePlaceId {
            cloud.set(activePlaceId, forKey: Key.activePlaceId)
        }
        cloud.synchronize()
    }

    private func persistMemos() {
        if let data = try? JSONEncoder().encode(bulkyMemos) {
            defaults.set(data, forKey: Key.bulkyMemos)
            cloud.set(data, forKey: Key.bulkyMemos)
            cloud.synchronize()
        }
    }

    private func pullFromCloud() {
        if let district = cloud.string(forKey: Key.districtId), !district.isEmpty {
            selectedDistrictId = district
            hasCompletedOnboarding = true
        }
        if let city = cloud.string(forKey: Key.cityId), !city.isEmpty {
            selectedCityId = city
        }
        if let places = Self.decodePlaces(cloud.data(forKey: Key.savedPlaces)) {
            savedPlaces = places
        }
        if let active = cloud.string(forKey: Key.activePlaceId) {
            activePlaceId = active
        }
        if let memos = Self.decodeMemos(cloud.data(forKey: Key.bulkyMemos)) {
            bulkyMemos = memos
        }
    }

    private static func decodeMemos(_ data: Data?) -> [BulkyAppointmentMemo]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([BulkyAppointmentMemo].self, from: data)
    }

    private static func decodePlaces(_ data: Data?) -> [SavedPlace]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([SavedPlace].self, from: data)
    }
}
