//
//  GomiCalendarApp.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI
import UIKit

@main
struct GomiCalendarApp: App {
    @State private var appModel = AppModel()

    init() {
        // 冷启动：窗口底色跟主题走，消除系统默认白屏闪烁。禁止在此触发 StoreKit / iCloud / Widget。
        let light = UIColor(red: 0xF7 / 255, green: 0xF8 / 255, blue: 0xFA / 255, alpha: 1)
        let dark = UIColor(red: 0x0B / 255, green: 0x0E / 255, blue: 0x11 / 255, alpha: 1)
        UIWindow.appearance().backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }

    var body: some Scene {
        WindowGroup {
            LaunchRootView(appModel: appModel)
        }
    }
}

/// 首屏容器：立刻铺主题底色，重任务延后到 `.task`；前台时再检查规则热更新。
private struct LaunchRootView: View {
    @Bindable var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RootTabView()
            .environment(appModel)
            .background(AppTheme.background(for: colorScheme).ignoresSafeArea())
            .task {
                await StartupTasks.runAfterFirstFrame(appModel: appModel)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await appModel.checkRuleUpdates(userInitiated: false)
                    await GomiLiveActivityManager.shared.syncAutomatically {
                        LiveActivityPayloadBuilder.make(from: appModel)
                    }
                }
            }
    }
}
