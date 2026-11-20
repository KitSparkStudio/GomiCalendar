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

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        benefits
                        lifetimeCard
                        #if DEBUG
                        debugUnlock
                        #endif
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
            benefitRow(L10n.t("paywall_benefit_theme"))
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
            }

            Button {
                haptic()
                Task {
                    let ok = await store.purchaseLifetime()
                    if ok {
                        hapticSuccess()
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("paywall_lifetime_badge"))
                            .font(.headline)
                        Text(L10n.t("paywall_lifetime_detail"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let product = store.lifetime {
                            Text(product.displayName)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    if store.purchasingProductID == ProductID.lifetime || store.isLoading {
                        ProgressView()
                    } else {
                        Text(store.lifetime?.displayPrice ?? "¥480")
                            .font(.title2.weight(.bold))
                    }
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

            if store.lifetime == nil && !store.isLoading {
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

    #if DEBUG
    private var debugUnlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("paywall_debug_section"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Button {
                haptic()
                store.unlockForDebugTesting()
                hapticSuccess()
                dismiss()
            } label: {
                Label(L10n.t("paywall_debug_unlock"), systemImage: "hammer.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }
    #endif

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
        Button(L10n.t("paywall_restore")) {
            haptic()
            Task { await store.restore() }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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
