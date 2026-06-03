import Foundation
import Combine

/// Tracks which characters the family owns. Free characters (priceStars == 0)
/// are always owned; the rest are bought with earned 💎 diamonds.
///
/// Like `CosmeticStore`, ownership is family-wide (one kid buys, the family
/// owns) and burns diamonds from the shared `ProgressStore`. Which character each
/// kid *equips* lives on `Profile.character3DID` (synced per-profile), so this
/// store only answers "do we own it" and "buy it".
@MainActor
final class CharacterStore: ObservableObject {
    static let shared = CharacterStore()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let legacyOwned = "characters.ownedIDs"   // pre-sync, family-wide
        static let didMigrate  = "characters.didMigrateToProfile"
    }

    /// Set briefly to the just-purchased character so the UI can celebrate.
    @Published var lastPurchased: Character3D? = nil

    private init() {
        migrateLegacyOwnershipIfNeeded()
    }

    /// Ownership now lives per-profile on the synced ProgressSnapshot. Carry any
    /// previously-bought (family-wide, local) characters onto the active profile
    /// once, so nobody loses what they already unlocked.
    private func migrateLegacyOwnershipIfNeeded() {
        guard !defaults.bool(forKey: Key.didMigrate) else { return }
        let legacy = defaults.stringArray(forKey: Key.legacyOwned) ?? []
        for id in legacy { ProgressStore.shared.addOwnedCharacter(id) }
        defaults.set(true, forKey: Key.didMigrate)
    }

    // MARK: - Queries

    func owns(_ character: Character3D) -> Bool {
        character.isFree || ProgressStore.shared.ownedCharacterIDs.contains(character.id)
    }

    func owns(_ id: String) -> Bool { owns(Character3DCatalog.find(id)) }

    // MARK: - Purchase

    enum PurchaseError: LocalizedError {
        case alreadyOwned
        case notEnoughDiamonds(short: Int)

        var errorDescription: String? {
            switch self {
            case .alreadyOwned:                  return "הדמות כבר שלך"
            case .notEnoughDiamonds(let short):  return "חסרים \(short) יהלומים"
            }
        }
    }

    /// Buy a character with 💎 diamonds. Throws if already owned or too few.
    @discardableResult
    func purchase(_ character: Character3D) throws -> Character3D {
        guard !owns(character) else { throw PurchaseError.alreadyOwned }
        let progress = ProgressStore.shared
        guard progress.diamonds >= character.priceDiamonds else {
            throw PurchaseError.notEnoughDiamonds(short: character.priceDiamonds - progress.diamonds)
        }
        progress.spendDiamonds(character.priceDiamonds)
        progress.addOwnedCharacter(character.id)
        lastPurchased = character
        return character
    }

    /// Grant a character for free (e.g. a prize). No-op if already owned.
    func unlockFree(_ character: Character3D) {
        guard !owns(character) else { return }
        ProgressStore.shared.addOwnedCharacter(character.id)
        lastPurchased = character
    }
}
