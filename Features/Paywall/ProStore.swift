//
//  ProStore.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import Foundation
import Observation
import StoreKit
import WidgetKit

/// StoreKit 2：唯一终身买断 `com.kitsparkstudio.gomicalendar.pro.lifetime`（¥480）。
/// 本地测试：Scheme → StoreKit Configuration → `GomiCalendar/GomiCalendar.storekit`。
@Observable
@MainActor
final class ProStore {
    static let shared = ProStore()

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var purchasingProductID: String?
    private(set) var didStart = false
    /// 最近一次购买 / 恢复结果提示（付费墙展示后可清空）
    var lastErrorMessage: String?
    var lastSuccessMessage: String?

    nonisolated(unsafe) private var updatesTask: Task<Void, Never>?

    private init() {
        isPro = ProAccess.isPro
    }

    deinit {
        updatesTask?.cancel()
    }

    var lifetime: Product? { products.first { $0.id == ProductID.lifetime } }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        isPro = ProAccess.isPro
        updatesTask = Task { await listenForTransactions() }
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: ProductID.all)
            if lifetime != nil {
                lastErrorMessage = nil
            } else {
                lastErrorMessage = L10n.t("paywall_products_unavailable")
            }
            await updateEntitlements()
        } catch {
            products = []
            lastErrorMessage = error.localizedDescription
            await updateEntitlements()
        }
    }

    /// 唤起系统内购弹窗；验证成功后写入 App Group 并刷新小组件。
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchasingProductID = product.id
        isLoading = true
        lastErrorMessage = nil
        lastSuccessMessage = nil
        defer {
            isLoading = false
            purchasingProductID = nil
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateEntitlements()
                if isPro {
                    lastSuccessMessage = L10n.t("paywall_purchase_success")
                    return true
                }
                lastErrorMessage = L10n.t("paywall_products_unavailable")
                return false
            case .userCancelled:
                return false
            case .pending:
                lastErrorMessage = L10n.t("paywall_purchase_pending")
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func purchaseLifetime() async -> Bool {
        if let product = lifetime {
            return await purchase(product)
        }
        await refresh()
        if let product = lifetime {
            return await purchase(product)
        }
        lastErrorMessage = L10n.t("paywall_products_unavailable")
        return false
    }

    /// `AppStore.sync()` + `Transaction.currentEntitlements`：支持重装恢复与退款撤销。
    @discardableResult
    func restore() async -> Bool {
        isLoading = true
        lastErrorMessage = nil
        lastSuccessMessage = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await updateEntitlements()
            if isPro {
                lastSuccessMessage = L10n.t("paywall_restore_success")
                return true
            }
            lastErrorMessage = L10n.t("paywall_restore_empty")
            return false
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            if let transaction = try? checkVerified(update) {
                await transaction.finish()
                await updateEntitlements()
            }
        }
    }

    /// 以 `Transaction.currentEntitlements` 为准（含退款 `revocationDate`）。
    private func updateEntitlements() async {
        var valid: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard ProductID.all.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil {
                valid.insert(transaction.productID)
            }
        }
        purchasedProductIDs = valid
        let unlocked = !valid.isEmpty
        ProAccess.setPro(unlocked)
        isPro = unlocked
        WidgetCenter.shared.reloadAllTimelines()
        // 退款撤销 / 未付费：立即清理灵动岛，禁止残留
        if !unlocked {
            await GomiLiveActivityManager.shared.endAll(markPreference: false)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
