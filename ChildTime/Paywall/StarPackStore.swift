import Foundation
import StoreKit
import Combine

/// Sells consumable "star packs" for real money. Stars are the in-app currency
/// kids spend on characters; buying them is ALWAYS behind the parent gate
/// (the UI wraps `StarShopView` in `ParentGateView`).
///
/// Configure these EXACT consumable IDs in App Store Connect → In-App Purchases.
@MainActor
final class StarPackStore: ObservableObject {
    static let shared = StarPackStore()

    static let smallID  = "com.rani.ChildTime.stars.small"   // 300
    static let mediumID = "com.rani.ChildTime.stars.medium"  // 1000
    static let largeID  = "com.rani.ChildTime.stars.large"   // 2500
    static let allIDs: Set<String> = [smallID, mediumID, largeID]

    /// How many stars each pack grants.
    static func stars(for productID: String) -> Int {
        switch productID {
        case smallID:  return 300
        case mediumID: return 1000
        case largeID:  return 2500
        default:       return 0
        }
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    /// True once a load attempt has finished (success or failure) — so the UI can
    /// tell "still loading" apart from "loaded, but no packs available".
    @Published private(set) var didAttemptLoad = false
    @Published var isPurchasing = false
    @Published var lastError: String?
    /// Set to the number of stars just granted so the UI can celebrate; reset to nil.
    @Published var lastGrantedStars: Int? = nil

    /// Transaction IDs already credited — guards against double-granting across
    /// the purchase path and the `Transaction.updates` stream (and relaunches).
    private let grantedKey = "starpack.grantedTxIDs"
    private var grantedTxIDs: Set<String>

    private var updates: Task<Void, Never>?

    private init() {
        grantedTxIDs = Set(UserDefaults.standard.stringArray(forKey: grantedKey) ?? [])
        updates = Task { [weak self] in await self?.observeTransactionUpdates() }
        Task { await loadProducts() }
    }

    deinit { updates?.cancel() }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false; didAttemptLoad = true }
        do {
            let fetched = try await Product.products(for: Self.allIDs)
            products = fetched.sorted { Self.stars(for: $0.id) < Self.stars(for: $1.id) }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Retry loading (e.g. a "try again" button after a failed/empty load).
    func reload() async { await loadProducts() }

    /// Best-value badge for the middle pack.
    func isBestValue(_ product: Product) -> Bool { product.id == Self.mediumID }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.verify(verification)
                grant(transaction)
                await transaction.finish()
                lastError = nil
                return true
            case .userCancelled:
                return false
            case .pending:
                lastError = "ההזמנה ממתינה לאישור (Ask to Buy)"
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Credit a verified consumable exactly once.
    private func grant(_ transaction: Transaction) {
        let txKey = String(transaction.id)
        guard !grantedTxIDs.contains(txKey) else { return }
        let amount = Self.stars(for: transaction.productID)
        guard amount > 0 else { return }
        grantedTxIDs.insert(txKey)
        UserDefaults.standard.set(Array(grantedTxIDs), forKey: grantedKey)
        ProgressStore.shared.addStars(amount)
        lastGrantedStars = amount
        AppAnalytics.purchasedStars(transaction.productID, stars: amount)
    }

    /// Catches purchases finished outside the app or interrupted mid-flow.
    private func observeTransactionUpdates() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            if Self.allIDs.contains(transaction.productID) { grant(transaction) }
            await transaction.finish()
        }
    }

    private static func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):       return value
        case .unverified(_, let error):  throw error
        }
    }
}

extension Product {
    /// "300 ⭐" style label for a star pack.
    var starPackLabel: String {
        "\(StarPackStore.stars(for: id)) ⭐"
    }
}
