//
//  RootTabView.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI

struct RootTabView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    /// 与设置页共用；切换后 `.id` + `.environment(\.locale)` 强制整树刷新。
    @AppStorage(AppLanguageCode.storageKey) private var selectedLanguage: String = AppLanguageCode.auto.rawValue

    private var appLocale: Locale {
        if let code = AppLanguageCode(rawValue: selectedLanguage),
           let identifier = code.localeIdentifier {
            return Locale(identifier: identifier)
        }
        return Locale.autoupdatingCurrent
    }

    var body: some View {
        Group {
            if appModel.settings.hasCompletedOnboarding,
               appModel.settings.selectedDistrictId != nil {
                mainTabs
            } else {
                OnboardingView()
            }
        }
        .background(AppTheme.background(for: colorScheme).ignoresSafeArea())
        .environment(\.locale, appLocale)
        .id(selectedLanguage)
        .onChange(of: selectedLanguage) { _, newValue in
            AppLanguageCode(rawValue: newValue)?.persist()
        }
    }

    private var mainTabs: some View {
        TabView {
            Tab(L10n.t("tab_dashboard"), systemImage: "square.stack.3d.up.fill") {
                DashboardView()
            }
            Tab(L10n.t("tab_dictionary"), systemImage: "magnifyingglass") {
                DictionaryView()
            }
            Tab(L10n.t("tab_calendar"), systemImage: "calendar") {
                CalendarView()
            }
            Tab(L10n.t("tab_settings"), systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    RootTabView()
        .environment(AppModel())
}
