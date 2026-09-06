import Foundation
import StoreKit
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Sells question packs (⚽ עולם הכדורגל …) — ADD-ONS on top of Tofy+, bought
/// per child. Consumable products so a family can buy the same pack for a
/// second child ("הוסיפו גם ל…" at half price); the entitlement lives in OUR
/// data (the child's `packs` + the household's `ownedPacks`), like diamonds.
///
/// Always behind the parent gate; never reachable from a child's device.
@MainActor
final class PackStore: ObservableObject {
    static let shared = PackStore()

    @Published private(set) var products: [String: Product] = [:]
    /// Packs switched ON in the cloud (`packs/{id}.enabled == true`). The
    /// questions ship with the build; this is the launch switch. Debug builds
    /// (and the demo harness) show every bundled pack.
    @Published private(set) var liveIDs: Set<String> = []
    #if canImport(FirebaseFirestore)
    private var liveListener: ListenerRegistration?
    #endif
    @Published private(set) var didAttemptLoad = false
    @Published var isPurchasing = false
    @Published var lastError: String?

    /// Transaction ids already credited — the purchase path and the
    /// `Transaction.updates` stream can both deliver the same one.
    private let grantedKey = "packstore.grantedTxIDs"
    private var grantedTxIDs: Set<String>
    /// The purchase in flight ("soccer" → [childIDs]) so a transaction that
    /// finishes out-of-band (interrupted app, Ask to Buy approval) still knows
    /// which children it was for.
    private let pendingKey = "packstore.pending"
    private var updates: Task<Void, Never>?

    private init() {
        grantedTxIDs = Set(UserDefaults.standard.stringArray(forKey: grantedKey) ?? [])
        updates = Task { [weak self] in await self?.observeTransactionUpdates() }
        Task { await loadProducts() }
        listenForLivePacks()
    }
    deinit { updates?.cancel() }

    /// Packs the parent can see and buy right now, in catalog order.
    var visiblePacks: [QuestionPack] {
        #if DEBUG
        return QuestionPacks.all
        #else
        return QuestionPacks.all.filter { liveIDs.contains($0.id) }
        #endif
    }

    private func listenForLivePacks() {
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync else { return }
        liveListener = Firestore.firestore().collection("packs").whereField("enabled", isEqualTo: true)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let docs = snap?.documents else { return }
                Task { @MainActor in self.liveIDs = Set(docs.map(\.documentID)) }
            }
        #endif
    }

    func loadProducts() async {
        defer { didAttemptLoad = true }
        do {
            let fetched = try await Product.products(for: QuestionPacks.allProductIDs)
            products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Pricing

    /// Every pack/pass product came back from StoreKit. Prices are shown only
    /// as ONE set — all from the store, or (DEBUG demo) all planned in ₪ —
    /// never a mix of currencies on one screen (Rani).
    var allLoaded: Bool { QuestionPacks.allProductIDs.allSatisfy { products[$0] != nil } }

    /// The price to show on a card: the store's, or the planned ₪ in a DEBUG
    /// demo without products, or nothing.
    func displayPrice(for pack: QuestionPack) -> String? {
        if allLoaded { return products[pack.productID]?.displayPrice }
        #if DEBUG
        return pack.plannedPriceLabel
        #else
        return nil
        #endif
    }

    /// What this family pays for `pack` for `childIDs`: the first child in the
    /// family at full price, every further child (now or later) at the sibling
    /// price. Returns the products to buy, in order, with quantities.
    func priceLines(for pack: QuestionPack, childIDs: [String]) -> [(product: Product, quantity: Int)] {
        // A pass can always be bought again (renewal); a permanent pack only for
        // children who don't have it.
        let newKids = pack.isPass ? childIDs : childIDs.filter { !HouseholdManager.shared.childOwnsPack(pack.id, childID: $0) }
        guard !newKids.isEmpty else { return [] }
        // Pass: full price per child-month, the sibling price only for extra
        // children in the same purchase. Pack: the family pays full once.
        let familyOwns = pack.isPass ? false : HouseholdManager.shared.householdOwnsPack(pack.id)
        var lines: [(Product, Int)] = []
        var remaining = newKids.count
        if !familyOwns, let full = products[pack.productID] {
            lines.append((full, 1)); remaining -= 1
        }
        if remaining > 0, let sib = products[pack.siblingProductID] {
            lines.append((sib, remaining))
        }
        return lines
    }

    /// "₪14.90" — the total the parent will be charged.
    func priceLabel(for pack: QuestionPack, childIDs: [String]) -> String? {
        let lines = priceLines(for: pack, childIDs: childIDs)
        #if DEBUG
        // The demo harness runs without Xcode's StoreKit test config — show the
        // planned price so the screen can be reviewed (never in release).
        if !childIDs.isEmpty, !allLoaded { return pack.plannedPriceLabel }
        #endif
        guard !lines.isEmpty else { return nil }
        let total = lines.reduce(Decimal(0)) { $0 + $1.product.price * Decimal($1.quantity) }
        return lines.first?.product.priceFormatStyle.format(total)
    }

    // MARK: - Purchase

    /// Buys `pack` for `childIDs` (one StoreKit sheet per price line) and grants
    /// it the moment Apple verifies each transaction. Returns true when every
    /// child got the pack.
    @discardableResult
    func purchase(_ pack: QuestionPack, for childIDs: [String]) async -> Bool {
        let lines = priceLines(for: pack, childIDs: childIDs)
        guard !lines.isEmpty else { return true }   // already owned — nothing to charge
        isPurchasing = true
        defer { isPurchasing = false; UserDefaults.standard.removeObject(forKey: pendingKey) }
        UserDefaults.standard.set(["pack": pack.id, "children": childIDs], forKey: pendingKey)
        var granted = false
        for line in lines {
            do {
                var options: Set<Product.PurchaseOption> = []
                if line.quantity > 1 { options.insert(.quantity(line.quantity)) }
                let result = try await line.product.purchase(options: options)
                switch result {
                case .success(let verification):
                    let tx = try Self.verify(verification)
                    grant(tx, pack: pack, childIDs: childIDs)
                    await tx.finish()
                    granted = true
                case .userCancelled:
                    return granted
                case .pending:
                    lastError = "הָהַזְמָנָה מַמְתִּינָה לְאִשּׁוּר (Ask to Buy)"
                    return granted
                @unknown default:
                    return granted
                }
            } catch {
                lastError = error.localizedDescription
                return granted
            }
        }
        lastError = nil
        return true
    }

    /// Credit a verified transaction exactly once: the pack lands on every
    /// child it was bought for (local + cloud), and the sale is logged for the
    /// founder dashboard (first-party only).
    private func grant(_ tx: StoreKit.Transaction, pack: QuestionPack, childIDs: [String]) {
        let key = String(tx.id)
        guard !grantedTxIDs.contains(key) else { return }
        grantedTxIDs.insert(key)
        UserDefaults.standard.set(Array(grantedTxIDs), forKey: grantedKey)
        HouseholdManager.shared.grantPack(pack, childIDs: childIDs, productID: tx.productID,
                                          price: products[tx.productID]?.price, transactionID: key)
        AppAnalytics.log("pack_purchased", ["pack": pack.id, "children": childIDs.count])
    }

    /// Purchases finished outside the normal flow (Ask to Buy approved later,
    /// app killed mid-purchase) — credited to the children of the pending
    /// purchase, or to the household's unassigned credits when unknown.
    private func observeTransactionUpdates() async {
        for await update in Transaction.updates {
            guard case .verified(let tx) = update else { continue }
            if let pack = QuestionPacks.all.first(where: { $0.productID == tx.productID || $0.siblingProductID == tx.productID }) {
                let pending = UserDefaults.standard.dictionary(forKey: pendingKey)
                let kids = (pending?["pack"] as? String) == pack.id ? (pending?["children"] as? [String]) ?? [] : []
                grant(tx, pack: pack, childIDs: kids)
            }
            await tx.finish()
        }
    }

    private static func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):      return value
        case .unverified(_, let error): throw error
        }
    }
}
