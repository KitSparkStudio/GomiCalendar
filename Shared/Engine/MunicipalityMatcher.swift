//
//  MunicipalityMatcher.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

enum MunicipalityMatcher {
    /// 用 CLGeocoder（ja_JP）结果在全量目录中匹配市町村。
    static func match(
        in catalog: RegionCatalog,
        administrativeArea: String?,
        locality: String?,
        subLocality: String?,
        thoroughfare: String? = nil
    ) -> (PrefectureEntry, CatalogCityEntry)? {
        let pref = matchPrefecture(in: catalog, administrativeArea: administrativeArea)
            ?? inferPrefecture(in: catalog, locality: locality, subLocality: subLocality)
        guard let pref else { return nil }

        let candidates = [
            subLocality,
            locality,
            thoroughfare,
            administrativeArea,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        for name in candidates {
            if let city = bestCity(named: name, in: pref.cities) {
                return (pref, city)
            }
        }

        for name in candidates {
            let stripped = stripMunicipalitySuffix(name)
            if stripped != name, let city = bestCity(named: stripped, in: pref.cities) {
                return (pref, city)
            }
        }

        return nil
    }

    static func matchPrefecture(
        in catalog: RegionCatalog,
        administrativeArea: String?
    ) -> PrefectureEntry? {
        guard let area = administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines),
              !area.isEmpty
        else { return nil }

        if let exact = catalog.prefectures.first(where: { $0.nameJa == area }) {
            return exact
        }
        let foldedArea = fold(area)
        return catalog.prefectures.first { pref in
            let foldedPref = fold(pref.nameJa)
            return foldedPref.contains(foldedArea)
                || foldedArea.contains(foldedPref)
                || fold(stripPrefSuffix(pref.nameJa)) == fold(stripPrefSuffix(area))
        }
    }

    private static func inferPrefecture(
        in catalog: RegionCatalog,
        locality: String?,
        subLocality: String?
    ) -> PrefectureEntry? {
        let names = [subLocality, locality].compactMap { $0 }
        for name in names {
            for pref in catalog.prefectures {
                if bestCity(named: name, in: pref.cities) != nil {
                    return pref
                }
            }
        }
        return nil
    }

    private static func bestCity(named name: String, in cities: [CatalogCityEntry]) -> CatalogCityEntry? {
        let foldedName = fold(name)
        if let exact = cities.first(where: { fold($0.nameJa) == foldedName }) {
            return exact
        }
        let partial = cities
            .filter {
                let n = fold($0.nameJa)
                return n.contains(foldedName) || foldedName.contains(n)
            }
            .sorted { $0.nameJa.count > $1.nameJa.count }
        return partial.first
    }

    private static func stripMunicipalitySuffix(_ name: String) -> String {
        var result = name
        for suffix in ["特別区", "市", "区", "町", "村"] {
            if result.hasSuffix(suffix), result.count > suffix.count {
                result = String(result.dropLast(suffix.count))
                break
            }
        }
        return result
    }

    private static func stripPrefSuffix(_ name: String) -> String {
        var result = name
        for suffix in ["都", "道", "府", "県"] {
            if result.hasSuffix(suffix), result.count > suffix.count {
                result = String(result.dropLast(suffix.count))
                break
            }
        }
        return result
    }

    private static func fold(_ string: String) -> String {
        string
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                locale: Locale(identifier: "ja_JP")
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
