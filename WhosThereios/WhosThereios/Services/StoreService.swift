//
//  StoreService.swift
//  WhosThereios
//
//  Created by Ian McCurry on 2/21/26.
//

import Foundation
import Combine
import StoreKit
import FirebaseAuth
import FirebaseFirestore

@MainActor
class StoreService: ObservableObject {
    static let shared = StoreService()

    // MARK: - Published Properties

    @Published var isPremium: Bool = false
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingProducts: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let productId = "com.whosthere.premium"
    private var transactionListener: Task<Void, Error>?
    private let db = Firestore.firestore()

    // MARK: - Initialization

    private init() {
        transactionListener = listenForTransactions()

        Task {
            await checkCurrentEntitlement()
            await loadProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoadingProducts = true
        errorMessage = nil
        do {
            products = try await Product.products(for: [productId])
            if products.isEmpty {
                errorMessage = "Product unavailable. Please try again later."
                AppLogger.debug("[StoreService] No products returned for ID: \(productId)")
            }
        } catch {
            errorMessage = "Could not load purchase options. Check your connection and try again."
            AppLogger.debug("[StoreService] Failed to load products: \(error)")
        }
        isLoadingProducts = false
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product = products.first else {
            errorMessage = "Product not available. Please try again later."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPremium = true
                await syncPremiumToFirestore(true)
                AppLogger.debug("[StoreService] Purchase successful")

            case .userCancelled:
                AppLogger.debug("[StoreService] Purchase cancelled by user")

            case .pending:
                errorMessage = "Purchase is pending approval."
                AppLogger.debug("[StoreService] Purchase pending")

            @unknown default:
                errorMessage = "An unknown error occurred."
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
            AppLogger.debug("[StoreService] Purchase error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        var foundPremium = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productId {
                foundPremium = true
                break
            }
        }

        if foundPremium {
            isPremium = true
            await syncPremiumToFirestore(true)
            AppLogger.debug("[StoreService] Restore successful")
        } else {
            errorMessage = "No previous purchase found."
            AppLogger.debug("[StoreService] No purchase to restore")
        }

        isLoading = false
    }

    // MARK: - Check Current Entitlement

    func checkCurrentEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productId {
                isPremium = true
                await syncPremiumToFirestore(true)
                return
            }
        }

        // Also check Firestore as fallback (for cross-device badge display)
        if let user = FirestoreService.shared.currentUser {
            isPremium = user.isPremium
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result,
                   transaction.productID == self.productId {
                    await MainActor.run {
                        self.isPremium = true
                    }
                    await self.syncPremiumToFirestore(true)
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Firestore Sync

    private func syncPremiumToFirestore(_ isPremium: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("users").document(userId).setData([
                "isPremium": isPremium
            ], merge: true)
            FirestoreService.shared.currentUser?.isPremium = isPremium
        } catch {
            AppLogger.debug("[StoreService] Failed to sync premium to Firestore: \(error)")
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case verificationFailed
    }

    // MARK: - Debug Helpers

    #if DEBUG
    func debugTogglePremium() async {
        isPremium.toggle()
        await syncPremiumToFirestore(isPremium)
        AppLogger.debug("[StoreService] DEBUG: isPremium set to \(isPremium)")
    }
    #endif
}
