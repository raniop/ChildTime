import Foundation
import StoreKit
import Combine

/// Central manager for in-app subscriptions via StoreKit 2.
///
/// Tracks whether the parent has an active "טופי+" subscription, exposes the
/// available products for the paywall, and forwards transaction updates so
/// the UI reacts in real time (e.g. unlocking premium content the moment a
/// purchase finishes).
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Product identifiers
    //
    // Flat family pricing — one plan covers all the family's children.
    // Configure these EXACT IDs in App Store Connect → Subscriptions:
    //   • Group:   "tofi_premium" (auto-renewable subscription group)
    //   • Monthly: com.rani.ChildTime.premium.monthly  (₪19.90)
    //   • Yearly:  com.rani.ChildTime.premium.yearly   (₪149, with 7-day intro free trial)

    static let monthlyID  = "com.rani.ChildTime.premium.monthly"
    static let yearlyID   = "com.rani.ChildTime.premium.yearly"

    static let allProductIDs: Set<String> = [monthlyID, yearlyID]

    // MARK: - Published state

    @Published private(set) var products: [Product] = []
    @Published private(set) var subscriptionState: SubscriptionState = .unknown
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var lastError: String?

    enum SubscriptionState: Equatable {
        case unknown                                    // initial — haven't checked yet
        case notSubscribed                              // user hasn't bought anything
        case inTrial(expires: Date)                     // active intro free trial
        case active(expires: Date?, willRenew: Bool)    // paid sub or lifetime (nil expires = lifetime)
        case expired                                    // sub lapsed
    }

    /// True if the user has ANY form of premium access (trial, paid, or lifetime).
    var isPremium: Bool {
        switch subscriptionState {
        case .inTrial, .active: return true
        default: return false
        }
    }

    private var transactionUpdates: Task<Void, Never>?

    private init() {
        transactionUpdates = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
        Task {
            await loadProducts()
            await refreshSubscriptionStatus()
        }
    }

    deinit {
        transactionUpdates?.cancel()
    }

    // MARK: - Product loading

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            // Sort: monthly → yearly → lifetime (matches the paywall layout)
            products = fetched.sorted { lhs, rhs in
                Self.sortKey(for: lhs.id) < Self.sortKey(for: rhs.id)
            }
            lastError = nil
        } catch {
            // Most common cause: products not yet configured in App Store Connect.
            // The paywall handles this gracefully (shows a placeholder + nudge).
            lastError = error.localizedDescription
        }
    }

    private static func sortKey(for id: String) -> Int {
        switch id {
        case monthlyID:  return 0
        case yearlyID:   return 1
        default:         return 99
        }
    }

    // MARK: - Purchase

    /// Initiates a purchase. Returns `true` if the user completed the purchase,
    /// `false` if they cancelled or it remained pending.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.verify(verification)
                await refreshSubscriptionStatus()
                await transaction.finish()
                AppAnalytics.subscribed(product.id)
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

    // MARK: - Restore

    /// Re-syncs with the App Store and refreshes entitlement state.
    /// Apple requires apps with IAP to expose a "Restore Purchases" button.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - State refresh

    /// Re-evaluates `subscriptionState` from current entitlements.
    /// Picks the *latest* / strongest entitlement among all owned products.
    func refreshSubscriptionStatus() async {
        var newState: SubscriptionState = .notSubscribed

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.allProductIDs.contains(transaction.productID) else { continue }

            // Lifetime (non-consumable) — no expiration date.
            if transaction.productType == .nonConsumable {
                newState = .active(expires: nil, willRenew: false)
                continue  // lifetime overrides everything; keep scanning anyway
            }

            // Auto-renewable subscription
            if let expirationDate = transaction.expirationDate {
                let willRenew = transaction.revocationDate == nil
                if expirationDate > Date() {
                    if transaction.offerType == .introductory {
                        // intro offer = free trial
                        newState = preferStronger(
                            current: newState,
                            candidate: .inTrial(expires: expirationDate)
                        )
                    } else {
                        newState = preferStronger(
                            current: newState,
                            candidate: .active(expires: expirationDate, willRenew: willRenew)
                        )
                    }
                } else {
                    newState = preferStronger(current: newState, candidate: .expired)
                }
            }
        }
        subscriptionState = newState
    }

    /// Lifetime > active > trial > expired > notSubscribed > unknown.
    private func preferStronger(
        current: SubscriptionState,
        candidate: SubscriptionState
    ) -> SubscriptionState {
        rank(candidate) > rank(current) ? candidate : current
    }

    private func rank(_ s: SubscriptionState) -> Int {
        switch s {
        case .active(let expires, _) where expires == nil: return 100  // lifetime
        case .active:        return 80
        case .inTrial:       return 60
        case .expired:       return 40
        case .notSubscribed: return 20
        case .unknown:       return 0
        }
    }

    // MARK: - Live transaction observer

    private func observeTransactionUpdates() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            await refreshSubscriptionStatus()
            await transaction.finish()
        }
    }

    // MARK: - Verification

    private static func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}

// MARK: - Convenience extensions

extension Product {
    /// Hebrew label for this product on the paywall.
    var hebrewName: String {
        switch id {
        case SubscriptionManager.monthlyID:  return "חודשי"
        case SubscriptionManager.yearlyID:   return "שנתי"
        default: return displayName
        }
    }

    /// e.g. "₪19.90 / חודש"
    var pricePerPeriod: String {
        switch id {
        case SubscriptionManager.monthlyID:
            return "\(displayPrice) / חודש"
        case SubscriptionManager.yearlyID:
            return "\(displayPrice) / שנה"
        default:
            return displayPrice
        }
    }

    /// e.g. "חיסכון 30%" — only meaningful for the yearly plan.
    var savingsBadge: String? {
        guard id == SubscriptionManager.yearlyID else { return nil }
        return "חסוך 30%"
    }
}
