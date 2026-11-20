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

/// StoreKit 2：仅终身买断 `pro.lifetime`（¥480）。默认未解锁。
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
    var lastErrorMessage: String?

    nonisolated(unsafe) private var updatesTask: Task<Void, Never>?

    private init() {
        isPro = false
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
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: ProductID.all)
            await updateEntitlements()
        } catch {
            lastErrorMessage = error.localizedDescription
            await updateEntitlements()
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchasingProductID = product.id
        isLoading = true
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
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    /// 购买终身买断；商品未加载时先 refresh，仍失败则 Debug/模拟器解锁。
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

    #if DEBUG
    func unlockForDebugTesting() {
        ProAccess.setDebugUnlock(true)
        isPro = true
        WidgetCenter.shared.reloadAllTimelines()
        lastErrorMessage = nil
    }

    func clearDebugUnlock() {
        ProAccess.setDebugUnlock(false)
        Task { await updateEntitlements() }
    }
    #endif

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await updateEntitlements()
        } catch {
            lastErrorMessage = error.localizedDescription
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
        let storeUnlocked = !valid.isEmpty
        #if DEBUG
        let unlocked = storeUnlocked || ProAccess.isDebugUnlocked
        if storeUnlocked {
            ProAccess.setPro(true)
        } else if !ProAccess.isDebugUnlocked {
            ProAccess.setPro(false)
        }
        #else
        let unlocked = storeUnlocked
        ProAccess.setPro(storeUnlocked)
        #endif
        isPro = unlocked
        WidgetCenter.shared.reloadAllTimelines()
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
