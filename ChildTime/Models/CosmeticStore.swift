import Foundation
import Combine

/// Tracks which cosmetics each profile owns and what each one is wearing.
///
/// Ownership is family-wide (one kid buys, the family owns); equipping
/// is per-profile so each kid has their own look. Purchases burn gems
/// from the (shared, v1) ProgressStore.
@MainActor
final class CosmeticStore: ObservableObject {
    static let shared = CosmeticStore()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let owned       = "cosmetics.ownedIDs"
        static let equipped    = "cosmetics.equippedByProfile"   // [UUID: [Category: ItemID]]
        static let didSeedFree = "cosmetics.didSeedStarter"
    }

    /// All item IDs the family has unlocked (purchased or seeded).
    @Published private(set) var ownedIDs: Set<String> = [] {
        didSet {
            defaults.set(Array(ownedIDs), forKey: Key.owned)
        }
    }

    /// What each profile currently has equipped.
    /// `[profileID: [category: cosmeticItemID]]`
    @Published private(set) var equippedByProfile: [UUID: [CosmeticCategory: String]] = [:] {
        didSet { persistEquipped() }
    }

    /// Set briefly to the just-purchased item so the UI can flash a
    /// celebration. Consumers should reset it back to nil.
    @Published var lastPurchasedItem: CosmeticItem? = nil

    private init() {
        loadOwned()
        loadEquipped()
        seedStarterItemsIfNeeded()
    }

    // MARK: - Ownership queries

    func owns(_ id: String) -> Bool { ownedIDs.contains(id) }
    func owns(_ item: CosmeticItem) -> Bool { ownedIDs.contains(item.id) }

    /// Items the family owns in this category, sorted by rarity asc.
    func owned(in category: CosmeticCategory) -> [CosmeticItem] {
        CosmeticCatalog.items(in: category).filter { ownedIDs.contains($0.id) }
    }

    // MARK: - Equipping

    func equipped(for profileID: UUID, in category: CosmeticCategory) -> CosmeticItem? {
        guard let id = equippedByProfile[profileID]?[category] else { return nil }
        return CosmeticCatalog.item(id)
    }

    func equippedItems(for profileID: UUID) -> [CosmeticItem] {
        let map = equippedByProfile[profileID] ?? [:]
        return map.values.compactMap { CosmeticCatalog.item($0) }
                  .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    /// Put `item` on `profileID`. Replaces whatever was equipped in that
    /// category. Pass `nil` to remove. No-op if the family doesn't own
    /// the item.
    func equip(_ item: CosmeticItem?, in category: CosmeticCategory, for profileID: UUID) {
        var map = equippedByProfile[profileID] ?? [:]
        if let item, ownedIDs.contains(item.id) {
            map[category] = item.id
        } else {
            map.removeValue(forKey: category)
        }
        equippedByProfile[profileID] = map
    }

    // MARK: - Purchase

    enum PurchaseError: LocalizedError {
        case alreadyOwned
        case notEnoughCoins(short: Int)

        var errorDescription: String? {
            switch self {
            case .alreadyOwned:                return "כבר יש לך את הפריט הזה"
            case .notEnoughCoins(let short):   return "חסרים לך \(short) מטבעות"
            }
        }
    }

    /// Grant an item for free (e.g. Lucky Wheel prize). No-op if already owned.
    func unlockFree(_ item: CosmeticItem) {
        guard !ownedIDs.contains(item.id) else { return }
        ownedIDs.insert(item.id)
        lastPurchasedItem = item
    }

    /// Buy + auto-equip in one motion. Throws if not enough coins or
    /// already owned. Returns the bought item on success.
    @discardableResult
    func purchase(_ item: CosmeticItem, for profileID: UUID) throws -> CosmeticItem {
        guard !ownedIDs.contains(item.id) else { throw PurchaseError.alreadyOwned }
        let progress = ProgressStore.shared
        guard progress.gems >= item.price else {
            throw PurchaseError.notEnoughCoins(short: item.price - progress.gems)
        }
        // Spend gems through ProgressStore so the value stays canonical.
        progress.spendGems(item.price)
        ownedIDs.insert(item.id)
        equip(item, in: item.category, for: profileID)
        lastPurchasedItem = item
        return item
    }

    // MARK: - Persistence

    private func loadOwned() {
        let arr = defaults.stringArray(forKey: Key.owned) ?? []
        ownedIDs = Set(arr)
    }

    private func loadEquipped() {
        guard let raw = defaults.data(forKey: Key.equipped) else { return }
        guard let decoded = try? JSONDecoder().decode([UUID: [CosmeticCategory: String]].self, from: raw) else { return }
        equippedByProfile = decoded
    }

    private func persistEquipped() {
        if let data = try? JSONEncoder().encode(equippedByProfile) {
            defaults.set(data, forKey: Key.equipped)
        }
    }

    /// Give every family a small starter wardrobe so the avatar is never
    /// "naked" and the kid sees the system Just Working before buying.
    private func seedStarterItemsIfNeeded() {
        guard !defaults.bool(forKey: Key.didSeedFree) else { return }
        defaults.set(true, forKey: Key.didSeedFree)
        ownedIDs.formUnion(CosmeticCatalog.starterFreeIDs)
    }
}
