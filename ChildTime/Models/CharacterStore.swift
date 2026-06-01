import Foundation
import Combine

/// Tracks which characters the family owns. Free characters (priceStars == 0)
/// are always owned; the rest are bought with earned stars.
///
/// Like `CosmeticStore`, ownership is family-wide (one kid buys, the family
/// owns) and burns stars from the shared `ProgressStore`. Which character each
/// kid *equips* lives on `Profile.character3DID` (synced per-profile), so this
/// store only answers "do we own it" and "buy it".
@MainActor
final class CharacterStore: ObservableObject {
    static let shared = CharacterStore()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let owned = "characters.ownedIDs"
    }

    /// IDs of paid characters the family has unlocked. Free ones are implicit.
    @Published private(set) var ownedIDs: Set<String> = [] {
        didSet { defaults.set(Array(ownedIDs), forKey: Key.owned) }
    }

    /// Set briefly to the just-purchased character so the UI can celebrate.
    @Published var lastPurchased: Character3D? = nil

    private init() {
        ownedIDs = Set(defaults.stringArray(forKey: Key.owned) ?? [])
    }

    // MARK: - Queries

    func owns(_ character: Character3D) -> Bool {
        character.isFree || ownedIDs.contains(character.id)
    }

    func owns(_ id: String) -> Bool { owns(Character3DCatalog.find(id)) }

    // MARK: - Purchase

    enum PurchaseError: LocalizedError {
        case alreadyOwned
        case notEnoughStars(short: Int)

        var errorDescription: String? {
            switch self {
            case .alreadyOwned:               return "הדמות כבר שלך"
            case .notEnoughStars(let short):  return "חסרים \(short) כוכבים"
            }
        }
    }

    /// Buy a character with stars. Throws if already owned or too few stars.
    @discardableResult
    func purchase(_ character: Character3D) throws -> Character3D {
        guard !owns(character) else { throw PurchaseError.alreadyOwned }
        let progress = ProgressStore.shared
        guard progress.stars >= character.priceStars else {
            throw PurchaseError.notEnoughStars(short: character.priceStars - progress.stars)
        }
        progress.spendStars(character.priceStars)
        ownedIDs.insert(character.id)
        lastPurchased = character
        return character
    }

    /// Grant a character for free (e.g. a prize). No-op if already owned.
    func unlockFree(_ character: Character3D) {
        guard !owns(character) else { return }
        ownedIDs.insert(character.id)
        lastPurchased = character
    }
}
