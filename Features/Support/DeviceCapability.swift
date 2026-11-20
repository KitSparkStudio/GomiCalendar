//
//  DeviceCapability.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import ActivityKit
import UIKit

/// 设备硬件 / 系统能力探测（灵动岛等）。
enum DeviceCapability {
    /// 仅：iPhone + 顶部安全区 ≥ 51（灵动岛机型）+ 系统允许实时活动。
    @MainActor
    static var hasDynamicIsland: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        return keyWindowSafeAreaTop >= 51
    }

    @MainActor
    private static var keyWindowSafeAreaTop: CGFloat {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        let window = windows.first(where: \.isKeyWindow) ?? windows.first
        return window?.safeAreaInsets.top ?? 0
    }
}
