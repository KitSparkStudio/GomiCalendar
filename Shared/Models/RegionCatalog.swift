//
//  RegionCatalog.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

struct RegionCatalog: Codable, Sendable {
    var schemaVersion: Int
    var source: String?
    var prefectureCount: Int?
    var municipalityCount: Int?
    var prefectures: [PrefectureEntry]
}

struct PrefectureEntry: Codable, Identifiable, Hashable, Sendable {
    var code: String
    var nameJa: String
    var kana: String?
    var cities: [CatalogCityEntry]
    var id: String { code }
}

struct CatalogCityEntry: Codable, Identifiable, Hashable, Sendable {
    var jisCode: String
    var cityId: String
    var nameJa: String
    var kana: String?
    var hasDetailedRules: Bool
    var id: String { "\(jisCode)-\(nameJa)" }

    /// 搜索用 token（汉字・假名・罗马字近似）。
    var searchTokens: [String] {
        var tokens = [nameJa, jisCode, cityId]
        if let kana, !kana.isEmpty {
            tokens.append(kana)
        }
        return tokens
    }
}

extension RegionCatalog {
    /// 优先加载全量 `japan_all_municipalities.json`，回退旧版精简目录。
    static func load(bundle: Bundle = .main) throws -> RegionCatalog {
        if let url = bundle.url(forResource: "japan_all_municipalities", withExtension: "json") {
            return try JSONDecoder().decode(RegionCatalog.self, from: Data(contentsOf: url))
        }
        guard let url = bundle.url(forResource: "jp_region_catalog", withExtension: "json") else {
            throw CityWasteConfigError.resourceNotFound("japan_all_municipalities")
        }
        return try JSONDecoder().decode(RegionCatalog.self, from: Data(contentsOf: url))
    }

    func prefecture(code: String) -> PrefectureEntry? {
        prefectures.first { $0.code == code }
    }

    func city(cityId: String) -> (PrefectureEntry, CatalogCityEntry)? {
        for pref in prefectures {
            if let city = pref.cities.first(where: { $0.cityId == cityId }) {
                return (pref, city)
            }
        }
        return nil
    }

    func city(jisCode: String) -> (PrefectureEntry, CatalogCityEntry)? {
        for pref in prefectures {
            if let city = pref.cities.first(where: { $0.jisCode == jisCode }) {
                return (pref, city)
            }
        }
        return nil
    }
}

struct NationalDictionaryFile: Codable, Sendable {
    var schemaVersion: Int
    var itemDictionary: [WasteItemEntry]
}

extension CityWasteConfig {
    /// 是否为「日本标准家庭垃圾模板」派生（无预置町名日历）。
    var isStandardTemplate: Bool {
        cityId == "jp_standard_household"
            || cityId.hasSuffix("_template")
            || cityId.hasPrefix("jp_custom_")
    }

    /// 优先 App Group 热更新缓存，再 Bundle；无独立 JSON 时回退标准模板并合并全国词典。
    static func loadCity(
        cityId: String,
        displayNameJa: String? = nil,
        bundle: Bundle = .main
    ) throws -> CityWasteConfig {
        var config: CityWasteConfig
        var usedFallback = false

        if let cached = RuleUpdateService.loadCachedCity(cityId: cityId) {
            config = cached
        } else if let url = bundle.url(forResource: cityId, withExtension: "json") {
            config = try JSONDecoder().decode(CityWasteConfig.self, from: Data(contentsOf: url))
        } else if let url = bundle.url(forResource: "jp_standard_household", withExtension: "json") {
            config = try JSONDecoder().decode(CityWasteConfig.self, from: Data(contentsOf: url))
            usedFallback = true
        } else {
            throw CityWasteConfigError.resourceNotFound(cityId)
        }

        if usedFallback {
            config.cityId = cityId
            if let displayNameJa, !displayNameJa.isEmpty {
                config.names = LocalizedText(
                    ja: displayNameJa,
                    kana: nil,
                    en: displayNameJa,
                    zhHans: displayNameJa,
                    vi: displayNameJa,
                    ko: displayNameJa
                )
                // 未知市町村：粗大电话置空，交给 Safari 查询
                if config.bulkyWaste.phone == "—" || config.bulkyWaste.phone.isEmpty {
                    config.bulkyWaste.phone = "—"
                }
            }
        }
        config.itemDictionary = mergeNationalDictionary(into: config.itemDictionary, bundle: bundle)
        return config
    }

    private static func mergeNationalDictionary(
        into existing: [WasteItemEntry],
        bundle: Bundle
    ) -> [WasteItemEntry] {
        guard let dictURL = bundle.url(forResource: "jp_national_dictionary", withExtension: "json"),
              let dictData = try? Data(contentsOf: dictURL),
              let national = try? JSONDecoder().decode(NationalDictionaryFile.self, from: dictData)
        else {
            return existing
        }
        var merged = existing
        let known = Set(merged.map(\.id))
        for item in national.itemDictionary where !known.contains(item.id) {
            merged.append(item)
        }
        return merged
    }
}
