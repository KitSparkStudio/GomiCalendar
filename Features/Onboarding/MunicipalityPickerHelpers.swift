//
//  MunicipalityPickerHelpers.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

enum MunicipalityPickerHelpers {
    static func filteredCities(_ cities: [CatalogCityEntry], query: String) -> [CatalogCityEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return cities }
        return cities.filter { city in
            SearchNormalizer.matches(q, in: city.searchTokens)
        }
    }

    static func filteredPrefectures(_ prefs: [PrefectureEntry], query: String) -> [PrefectureEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return prefs }
        return prefs.filter { pref in
            var tokens = [pref.nameJa, pref.code]
            if let kana = pref.kana { tokens.append(kana) }
            return SearchNormalizer.matches(q, in: tokens)
        }
    }
}
