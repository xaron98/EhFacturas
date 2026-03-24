// SubscriptionManager.swift
// FacturaApp — StoreKit 2 subscription management for Pro features

import Foundation
import StoreKit

@MainActor
@Observable
final class SubscriptionManager {

    static let shared = SubscriptionManager()

    private(set) var isProSubscriber = false
    private(set) var products: [Product] = []
    private(set) var purchaseError: String?

    static let proMonthlyID = "es.facturaapp.pro.monthly"
    static let proYearlyID = "es.facturaapp.pro.yearly"

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
    }

    // MARK: - Load products

    func loadProducts() async {
        do {
            products = try await Product.products(for: [
                Self.proMonthlyID,
                Self.proYearlyID
            ])
        } catch {
            purchaseError = "Error cargando productos: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()

            // Authenticate with backend proxy
            if let receiptData = await getReceiptData() {
                await APIKeyManager.shared.authenticate(receiptData: receiptData)
            }

            return true

        case .userCancelled:
            return false

        case .pending:
            purchaseError = "Compra pendiente de aprobación."
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Check subscription status

    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.proMonthlyID ||
                   transaction.productID == Self.proYearlyID {
                    hasActiveSubscription = true
                }
            }
        }

        isProSubscriber = hasActiveSubscription
    }

    // MARK: - Restore purchases

    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()

        if isProSubscriber {
            if let receiptData = await getReceiptData() {
                await APIKeyManager.shared.authenticate(receiptData: receiptData)
            }
        }
    }

    // MARK: - Listen for transactions

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let value):
            return value
        }
    }

    private func getReceiptData() async -> Data? {
        // StoreKit 2 doesn't have a traditional receipt file.
        // For backend validation, we'd use the transaction JWS.
        // For now, return nil — backend auth will be implemented with the proxy.
        return nil
    }

    // MARK: - Display helpers

    var monthlyProduct: Product? {
        products.first(where: { $0.id == Self.proMonthlyID })
    }

    var yearlyProduct: Product? {
        products.first(where: { $0.id == Self.proYearlyID })
    }

    var statusText: String {
        isProSubscriber ? "Pro activo" : "Gratuito"
    }

    enum SubscriptionError: LocalizedError {
        case verificationFailed

        var errorDescription: String? {
            "No se pudo verificar la compra."
        }
    }
}
