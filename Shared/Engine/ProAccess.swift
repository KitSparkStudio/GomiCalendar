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
    #if DEBUG
    nonisolated static let debugUnlockKey = "debugProUnlock"
    #endif

    nonisolated static var isPro: Bool {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        #if DEBUG
        return defaults.bool(forKey: isProKey) || defaults.bool(forKey: debugUnlockKey)
        #else
        return defaults.bool(forKey: isProKey)
        #endif
    }

    nonisolated static func setPro(_ value: Bool) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        defaults.set(value, forKey: isProKey)
    }

    #if DEBUG
    nonisolated static func setDebugUnlock(_ value: Bool) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        defaults.set(value, forKey: debugUnlockKey)
    }

    nonisolated static var isDebugUnlocked: Bool {
        (UserDefaults(suiteName: appGroupID) ?? .standard).bool(forKey: debugUnlockKey)
    }
    #endif
}

enum ProductID {
    /// 唯一付费商品：¥480 终身买断
    nonisolated static let lifetime = "com.kitsparkstudio.gomicalendar.pro.lifetime"
    nonisolated static let all: [String] = [lifetime]
}
