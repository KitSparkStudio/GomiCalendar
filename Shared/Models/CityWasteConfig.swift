//
//  CityWasteConfig.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// 年末年始等按日期区间的全市停收配置。`start`/`end` 为 `MM-DD`（可跨年）。
struct YearEndSuspension: Codable, Hashable, Sendable {
    var start: String
    var end: String
    /// 适用分类；空或含 `"all"` 表示全市全部分类停收
    var appliesTo: [String]
    var notes: LocalizedText
}

/// 粗大ごみ预约与收费说明。
struct BulkyWasteInfo: Codable, Hashable, Sendable {
    var phone: String
    var receptionHours: LocalizedText
    var feeNotes: LocalizedText
    var onlineBookingURL: String?
}

/// 单一自治体完整垃圾分类配置（文件名约定：`jp_{JIS}_{slug}.json`）。
///
/// 亦称 `MunicipalityConfig`；含年度版本元数据，供远程热更新比对。
struct CityWasteConfig: Codable, Identifiable, Hashable, Sendable {
    var schemaVersion: Int
    /// 适用年度（日本财政年度常用起始年），如 `"2026"`
    var fiscalYear: String?
    /// 数据版本号，如 `"2026.11.1"`（语义化，越大越新）
    var version: String?
    /// ISO 日期或时间戳字符串，如 `"2026-11-20"`
    var lastUpdated: String?
    /// JIS 地方公共团体コード，如 `05201`
    var jisCode: String
    /// 稳定城市 ID，如 `jp_05201_akita`
    var cityId: String
    var names: LocalizedText
    /// 默认投放截止时间 `HH:mm`（秋田市为 `08:00`）
    var defaultDropoffDeadline: String
    var bulkyWaste: BulkyWasteInfo
    var yearEndSuspensions: [YearEndSuspension]
    var categories: [WasteCategory]
    var districts: [DistrictRule]
    var itemDictionary: [WasteItemEntry]

    var id: String { cityId }

    var displayFiscalYear: String { fiscalYear ?? "—" }
    var displayVersion: String { version ?? "—" }
    var displayLastUpdated: String { lastUpdated ?? "—" }
}

/// 与产品文档一致的别名。
typealias MunicipalityConfig = CityWasteConfig

extension CityWasteConfig {
    /// 从主 App / Widget 共享 Bundle 加载城市 JSON。
    static func load(resourceName: String, bundle: Bundle = .main) throws -> CityWasteConfig {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CityWasteConfigError.resourceNotFound(resourceName)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CityWasteConfig.self, from: data)
    }

    /// 比较版本字符串：`"2026.11.2" > "2026.11.1"`。无法解析时按字典序。
    static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        if !left.isEmpty || !right.isEmpty {
            let count = max(left.count, right.count)
            for i in 0..<count {
                let a = i < left.count ? left[i] : 0
                let b = i < right.count ? right[i] : 0
                if a != b { return a > b }
            }
            return false
        }
        return lhs > rhs
    }
}

enum CityWasteConfigError: Error, LocalizedError, Sendable {
    case resourceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "City waste config JSON not found: \(name).json"
        }
    }
}
