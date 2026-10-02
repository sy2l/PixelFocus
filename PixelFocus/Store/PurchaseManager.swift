/*
 * PurchaseManager.swift
 * PixelFocus
 *
 * Achats intégrés avec StoreKit 2.
 *
 * - Charge les produits, lance les achats, écoute les transactions (renouvellements, remboursements, achats hors app)
 * - Chaque achat porte l'identifiant du compte serveur (appAccountToken): le serveur refuse qu'un autre compte le réclame
 * - Droits (Premium, images du mois) calculés depuis Transaction.currentEntitlements -> EntitlementStore
 * - Boosters (consommables): crédités une seule fois par transaction, puis validés par le serveur
 *
 * Tests en local: sélectionner PixelFocus.storekit dans le schéma Xcode (voir README).
 */

import Foundation
import StoreKit

// MARK: - PurchaseManager
@MainActor
final class PurchaseManager: ObservableObject {

    enum PurchaseOutcome {
        case purchased
        case cancelled
        case pending
    }

    private enum Keys {
        static let creditedTransactions = "store.creditedBoosterTransactions"
        static let pendingValidation = "store.pendingBoosterValidation"
    }

    // MARK: - Published State
    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var hasActiveSubscription = false
    @Published private(set) var isLoadingProducts = false

    // MARK: - Dependencies
    private let entitlements: EntitlementStore
    private let syncService: SyncService?
    private let creditBoosters: @MainActor (Int) -> Void
    private let defaults: UserDefaults

    private var updatesTask: Task<Void, Never>?

    // MARK: - Init
    init(
        entitlements: EntitlementStore,
        syncService: SyncService?,
        defaults: UserDefaults = .standard,
        creditBoosters: @escaping @MainActor (Int) -> Void
    ) {
        self.entitlements = entitlements
        self.syncService = syncService
        self.defaults = defaults
        self.creditBoosters = creditBoosters

        // Tant qu'un achat de boosters n'est pas validé par le serveur, on garde le crédit local
        syncService?.canReconcilePurchasedBoosters = { [weak self] in
            self?.pendingValidation.isEmpty ?? true
        }
    }

    // MARK: - Démarrage

    /// À appeler au lancement: écoute des transactions, produits, droits, transactions non terminées
    func start(monthISOs: [String]) {
        guard updatesTask == nil else { return }

        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }

        Task {
            await loadProducts(monthISOs: monthISOs)
            for await result in Transaction.unfinished {
                await handle(result)
            }
            await refreshEntitlements()
            await retryPendingValidations()
        }
    }

    func loadProducts(monthISOs: [String]) async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: StoreProducts.allIdentifiers(monthISOs: monthISOs))
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            // Hors ligne ou produits non configurés: la boutique affichera "indisponible"
        }
    }

    func product(_ id: String) -> Product? {
        products[id]
    }

    // MARK: - Achat

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        var options: Set<Product.PurchaseOption> = []
        if let userId = syncService?.userId {
            options.insert(.appAccountToken(userId))
        }

        let result = try await product.purchase(options: options)
        switch result {
        case .success(let verification):
            await handle(verification)
            return .purchased
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    /// Restaurer les achats (bouton obligatoire sur l'App Store)
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
        await syncService?.syncNow()
    }

    // MARK: - Transactions

    private func handle(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else {
            // Transaction non vérifiée par StoreKit: ignorée
            return
        }

        if let amount = StoreProducts.boosters[transaction.productID], transaction.revocationDate == nil {
            let id = String(transaction.id)
            if !creditedTransactions.contains(id) {
                creditBoosters(amount * transaction.purchasedQuantity)
                creditedTransactions.insert(id)
                pendingValidation.insert(id)
            }
        }

        await validateWithServer(transactionId: transaction.id)
        await transaction.finish()
        await refreshEntitlements()
    }

    /// Envoie la transaction au serveur (droits multi-appareils). Sans réseau: réessayé au prochain lancement.
    private func validateWithServer(transactionId: UInt64) async {
        guard let syncService, AppConfig.isSyncConfigured else { return }
        let id = String(transactionId)
        // Retiré avant l'appel pour que le serveur puisse recalculer le stock de boosters
        let wasPending = pendingValidation.remove(id) != nil
        do {
            try await syncService.validateApplePurchase(transactionId: transactionId)
        } catch {
            // Sans réseau: réessayé au prochain lancement (retryPendingValidations)
            if wasPending {
                pendingValidation.insert(id)
            }
        }
    }

    private func retryPendingValidations() async {
        for id in pendingValidation {
            if let transactionId = UInt64(id) {
                await validateWithServer(transactionId: transactionId)
            }
        }
    }

    /// Droits actuels selon StoreKit -> EntitlementStore
    func refreshEntitlements() async {
        var subscriptionActive = false
        var monthlyIds = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            let productId = transaction.productID

            if StoreProducts.subscriptions.contains(productId) {
                if let expiration = transaction.expirationDate, expiration < Date() { continue }
                subscriptionActive = true
            } else if let artworkId = StoreProducts.monthlyArtworkId(productId: productId) {
                monthlyIds.insert(artworkId)
            }
        }

        hasActiveSubscription = subscriptionActive
        entitlements.applyStore(isPremium: subscriptionActive, monthlyArtworkIds: monthlyIds)
    }

    // MARK: - Persistance

    private var creditedTransactions: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.creditedTransactions) ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.creditedTransactions) }
    }

    private var pendingValidation: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.pendingValidation) ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.pendingValidation) }
    }
}
