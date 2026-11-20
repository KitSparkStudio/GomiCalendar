//
//  ScheduleOverrideStore.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// 临时日效果：强制停收 / 强制收集。
enum TemporaryDayEffect: String, Codable, Sendable {
    case suspend
    case collect
}

/// 单日临时调休 / 临时收集。
struct TemporaryDayRule: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    /// `YYYY-MM-DD`（东京日历）
    var ymd: String
    var effect: TemporaryDayEffect
    /// `nil` = 全部分类（通常用于停收）；收集日建议指定分类
    var categoryId: WasteCategoryID?

    init(
        id: UUID = UUID(),
        ymd: String,
        effect: TemporaryDayEffect,
        categoryId: WasteCategoryID? = nil
    ) {
        self.id = id
        self.ymd = ymd
        self.effect = effect
        self.categoryId = categoryId
    }
}

/// 某一町名的自定义覆盖：周期替换 + 临时日。
struct DistrictScheduleOverride: Codable, Hashable, Sendable {
    var cityId: String
    var districtId: String
    /// categoryId.rawValue → 替换后的收集周期（覆盖市政模板）
    var categorySchedules: [String: CollectionSchedule]
    var temporaryDays: [TemporaryDayRule]

    init(
        cityId: String,
        districtId: String,
        categorySchedules: [String: CollectionSchedule] = [:],
        temporaryDays: [TemporaryDayRule] = []
    ) {
        self.cityId = cityId
        self.districtId = districtId
        self.categorySchedules = categorySchedules
        self.temporaryDays = temporaryDays
    }

    static func storageKey(cityId: String, districtId: String) -> String {
        "\(cityId)|\(districtId)"
    }
}

/// App Group 持久化的用户自定义收集规则（Pro）。
enum ScheduleOverrideStore: Sendable {
    static let appGroupID = "group.com.kitsparkstudio.gomicalendar"
    private static let defaultsKey = "districtScheduleOverrides"

    nonisolated private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    nonisolated static func loadAll() -> [String: DistrictScheduleOverride] {
        guard let data = defaults.data(forKey: defaultsKey),
              let map = try? JSONDecoder().decode([String: DistrictScheduleOverride].self, from: data)
        else { return [:] }
        return map
    }

    nonisolated static func saveAll(_ map: [String: DistrictScheduleOverride]) {
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    nonisolated static func override(cityId: String, districtId: String) -> DistrictScheduleOverride? {
        let key = DistrictScheduleOverride.storageKey(cityId: cityId, districtId: districtId)
        return loadAll()[key]
    }

    /// 是否已有实际自定义内容（周期覆盖或临时日）。
    nonisolated static func hasMeaningfulOverride(cityId: String, districtId: String) -> Bool {
        guard let value = override(cityId: cityId, districtId: districtId) else { return false }
        return !value.categorySchedules.isEmpty || !value.temporaryDays.isEmpty
    }

    nonisolated static func upsert(_ value: DistrictScheduleOverride) {
        var map = loadAll()
        let key = DistrictScheduleOverride.storageKey(cityId: value.cityId, districtId: value.districtId)
        map[key] = value
        saveAll(map)
    }

    nonisolated static func remove(cityId: String, districtId: String) {
        var map = loadAll()
        map.removeValue(forKey: DistrictScheduleOverride.storageKey(cityId: cityId, districtId: districtId))
        saveAll(map)
    }

    /// 将周期覆盖应用到配置副本（临时日仍由 ScheduleCalculator 处理）。
    /// 自定义收集日为免费核心能力，不依赖 Pro。
    nonisolated static func applyScheduleOverrides(
        to config: CityWasteConfig,
        cityId: String,
        districtId: String?
    ) -> CityWasteConfig {
        guard let districtId,
              let override = override(cityId: cityId, districtId: districtId),
              !override.categorySchedules.isEmpty
        else { return config }

        var cfg = config
        cfg.districts = cfg.districts.map { district in
            guard district.id == districtId else { return district }
            var d = district
            var schedules = d.schedules
            for (raw, replacement) in override.categorySchedules {
                guard let categoryId = WasteCategoryID(rawValue: raw) else { continue }
                if let idx = schedules.firstIndex(where: { $0.categoryId == categoryId }) {
                    schedules[idx] = replacement
                } else {
                    schedules.append(replacement)
                }
            }
            d.schedules = schedules
            return d
        }
        return cfg
    }
}
