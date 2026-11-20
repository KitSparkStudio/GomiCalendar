//
//  RuleUpdateService.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// 远端规则索引与热更新入口（RemoteConfig）。
/// 无网络时静默失败，不打断冷启动。
enum RuleRemoteEndpoints {
    /// GitHub raw 静态索引（可配置）。
    static let githubIndexURL = URL(
        string: "https://raw.githubusercontent.com/kitsparkstudio/gomicalendar-rules/main/index.json"
    )!

    /// Cloudflare / 自建 CDN 备用索引。
    static let cloudflareIndexURL = URL(
        string: "https://rules.gomicalendar.kitspark.studio/index.json"
    )!

    /// 当前启用的索引地址；正式环境可切换为 Cloudflare。
    static var activeIndexURL: URL { githubIndexURL }
}

struct RulesRemoteIndex: Codable, Sendable {
    var schemaVersion: Int
    var generatedAt: String?
    var cities: [RulesRemoteCityEntry]
}

struct RulesRemoteCityEntry: Codable, Sendable, Identifiable {
    var cityId: String
    var fiscalYear: String?
    var version: String
    var lastUpdated: String?
    /// 绝对或相对（相对索引目录）JSON URL
    var url: String
    var id: String { cityId }
}

enum RuleUpdateOutcome: Sendable, Equatable {
    case upToDate
    case updated(cityId: String, version: String)
    case noEntry
    case skippedOfflineOrError
}

/// App Group 规则缓存 + 远端热更新。
actor RuleUpdateService {
    static let shared = RuleUpdateService()

    static let appGroupID = "group.com.kitsparkstudio.gomicalendar"
    private static let cacheFolderName = "RulesCache"

    private var lastIndex: RulesRemoteIndex?
    private var lastCheckDate: Date?

    // MARK: - Cache paths

    nonisolated static func appGroupContainer() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    nonisolated static func cacheDirectory() -> URL? {
        guard let root = appGroupContainer() else { return nil }
        let dir = root.appendingPathComponent(cacheFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated static func cachedCityURL(cityId: String) -> URL? {
        cacheDirectory()?.appendingPathComponent("\(cityId).json", isDirectory: false)
    }

    /// 读取 App Group 中已下载的城市规则（若有）。
    nonisolated static func loadCachedCity(cityId: String) -> CityWasteConfig? {
        guard let url = cachedCityURL(cityId: cityId),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(CityWasteConfig.self, from: data)
        else { return nil }
        return config
    }

    nonisolated static func saveCachedCity(cityId: String, data: Data) throws {
        guard let url = cachedCityURL(cityId: cityId) else {
            throw CityWasteConfigError.resourceNotFound(cityId)
        }
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Check / download

    /// 启动或回到前台时调用：检查当前城市是否有更高版本。
    @discardableResult
    func checkAndUpdateIfNeeded(
        cityId: String,
        currentVersion: String?
    ) async -> RuleUpdateOutcome {
        do {
            let index = try await fetchIndex()
            lastIndex = index
            lastCheckDate = Date()
            guard let entry = index.cities.first(where: { $0.cityId == cityId }) else {
                return .noEntry
            }
            let local = currentVersion
                ?? Self.loadCachedCity(cityId: cityId)?.version
                ?? "0"
            guard CityWasteConfig.isVersion(entry.version, newerThan: local) else {
                return .upToDate
            }
            try await downloadAndCache(entry: entry, indexURL: RuleRemoteEndpoints.activeIndexURL)
            return .updated(cityId: cityId, version: entry.version)
        } catch {
            return .skippedOfflineOrError
        }
    }

    func fetchIndex(force: Bool = false) async throws -> RulesRemoteIndex {
        if !force, let lastIndex, let lastCheckDate,
           Date().timeIntervalSince(lastCheckDate) < 60 {
            return lastIndex
        }
        var request = URLRequest(url: RuleRemoteEndpoints.activeIndexURL)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let index = try JSONDecoder().decode(RulesRemoteIndex.self, from: data)
        lastIndex = index
        lastCheckDate = Date()
        return index
    }

    private func downloadAndCache(entry: RulesRemoteCityEntry, indexURL: URL) async throws {
        let fileURL: URL
        if let absolute = URL(string: entry.url), absolute.scheme != nil {
            fileURL = absolute
        } else {
            fileURL = indexURL.deletingLastPathComponent().appendingPathComponent(entry.url)
        }
        var request = URLRequest(url: fileURL)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        // 校验可解码后再落盘
        _ = try JSONDecoder().decode(CityWasteConfig.self, from: data)
        try Self.saveCachedCity(cityId: entry.cityId, data: data)
    }
}
