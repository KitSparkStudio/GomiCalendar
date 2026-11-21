//
//  PaywallView.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import StoreKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppLanguageCode.storageKey) private var selectedLanguage: String = AppLanguageCode.auto.rawValue
    @State private var store = ProStore.shared
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var dismissAfterAlert = false

    /// 仅在商品列表为空且未加载中时显示重新加载。
    private var shouldShowReloadButton: Bool {
        !store.isLoading && store.lifetime == nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        benefits
                        lifetimeCard
                        legal
                        restoreButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.t("paywall_title"))
            .navigationBarTitleDisplayMode(.inline)
            .id(selectedLanguage)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("close")) { dismiss() }
                }
            }
            .task {
                store.startIfNeeded()
                await store.refresh()
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button(L10n.t("close")) {
                    if dismissAfterAlert {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("paywall_headline"))
                .font(.largeTitle.weight(.bold))
            Text(L10n.t("paywall_subtitle"))
                .font(.body)
                .foregroundStyle(.secondary)
            if store.isPro {
                Text(L10n.t("paywall_already_pro"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x34C759))
            }
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefitRow(L10n.t("paywall_benefit_multi"))
            benefitRow(L10n.t("paywall_benefit_widgets"))
            benefitRow(L10n.t("paywall_benefit_live_activity"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func benefitRow(_ text: String) -> some View {
        Label {
            Text(text).font(.body)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: 0x34C759))
        }
    }

    private var lifetimeCard: some View {
        VStack(spacing: 12) {
            if store.isLoading && store.lifetime == nil {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L10n.t("paywall_loading_products"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(AppTheme.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if let product = store.lifetime {
                Button {
                    haptic()
                    Task { await purchase(product) }
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.t("paywall_lifetime_badge"))
                                    .font(.headline)
                                Text(L10n.t("paywall_lifetime_detail"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            // 价格仅来自 StoreKit，禁止任何硬编码金额兜底
                            Text(product.displayPrice)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color(hex: 0x34C759))
                        }

                        HStack {
                            if store.purchasingProductID == ProductID.lifetime {
                                ProgressView()
                                Spacer()
                            } else {
                                Text(String(format: L10n.t("paywall_buy_with_price"), product.displayPrice))
                                    .font(.headline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(Color(hex: 0x34C759), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                    }
                    .padding(18)
                    .background(AppTheme.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(hex: 0x34C759).opacity(0.5), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .disabled(store.isPro || store.purchasingProductID != nil)
            }

            if shouldShowReloadButton {
                Button {
                    haptic()
                    Task { await store.refresh() }
                } label: {
                    Label(L10n.t("paywall_retry_load"), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(AppTheme.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            if let error = store.lastErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
            }
        }
    }

    private var legal: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("paywall_legal_title"))
                .font(.subheadline.weight(.semibold))
            Text(L10n.t("paywall_legal_body"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Link(L10n.t("paywall_terms"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link(L10n.t("paywall_privacy"), destination: URL(string: "https://kitsparkstudio.github.io/GomiCalendar/privacy.html")!)
            }
            .font(.footnote.weight(.semibold))
        }
    }

    private var restoreButton: some View {
        Button {
            haptic()
            Task { await restorePurchases() }
        } label: {
            HStack {
                if store.isLoading && store.purchasingProductID == nil && store.lifetime != nil {
                    ProgressView()
                }
                Text(L10n.t("paywall_restore"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .disabled(store.isLoading && store.purchasingProductID != nil)
    }

    private func purchase(_ product: Product) async {
        let ok = await store.purchase(product)
        if ok {
            hapticSuccess()
            presentAlert(
                title: L10n.t("paywall_purchase_success_title"),
                message: store.lastSuccessMessage ?? L10n.t("paywall_purchase_success"),
                dismissAfter: true
            )
        } else if let error = store.lastErrorMessage {
            presentAlert(
                title: L10n.t("paywall_title"),
                message: error,
                dismissAfter: false
            )
        }
    }

    private func restorePurchases() async {
        let ok = await store.restore()
        if ok {
            hapticSuccess()
            presentAlert(
                title: L10n.t("paywall_restore_success_title"),
                message: store.lastSuccessMessage ?? L10n.t("paywall_restore_success"),
                dismissAfter: true
            )
        } else {
            presentAlert(
                title: L10n.t("paywall_restore"),
                message: store.lastErrorMessage ?? L10n.t("paywall_restore_empty"),
                dismissAfter: false
            )
        }
    }

    private func presentAlert(title: String, message: String, dismissAfter: Bool) {
        alertTitle = title
        alertMessage = message
        dismissAfterAlert = dismissAfter
        showAlert = true
    }

    private func haptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func hapticSuccess() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
