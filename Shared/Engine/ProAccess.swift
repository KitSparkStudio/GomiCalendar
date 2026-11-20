//
//  ProAccess.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation

/// App / Widget 共享的 Pro 解锁状态（StoreKit 终身买断写入 App Group）。
/// 正式包默认未解锁。仅支持一次性买断，无订阅。
enum ProAccess: Sendable {
    nonisolated static let appGroupID = "group.com.kitsparkstudio.gomicalendar"
    nonisolated static let isProKey = "isProUnlocked"

    nonisolated static var isPro: Bool {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        return defaults.bool(forKey: isProKey)
    }

    /// 写入 App Group，供主 App 与小组件读取。
    nonisolated static func setPro(_ value: Bool) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        defaults.set(value, forKey: isProKey)
        defaults.synchronize()
    }
}

enum ProductID {
    /// 唯一付费商品：¥480 终身买断
    nonisolated static let lifetime = "com.kitsparkstudio.gomicalendar.pro.lifetime"
    nonisolated static let all: [String] = [lifetime]
}
