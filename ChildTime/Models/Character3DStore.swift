import Foundation
import Combine

/// Remembers which 3D character each profile has chosen. Persisted per-profile
/// so siblings keep their own avatar. (Ownership/purchase gating arrives with
/// the paid-character phase; for now every character is selectable.)
@MainActor
final class Character3DStore: ObservableObject {
    static let shared = Character3DStore()

    private let defaults = UserDefaults(suiteName: "group.com.childtime.shared") ?? .standard
    private let key = "character3DSelection"

    /// profileID (uuidString) → characterID
    @Published private var selection: [String: String] = [:]

    private init() {
        if let data = defaults.data(forKey: key),
           let map = try? JSONDecoder().decode([String: String].self, from: data) {
            selection = map
        }
    }

    func selectedID(for profileID: UUID) -> String {
        selection[profileID.uuidString] ?? Character3DCatalog.defaultID
    }

    func selected(for profileID: UUID) -> Character3D {
        Character3DCatalog.find(selectedID(for: profileID))
    }

    func select(_ characterID: String, for profileID: UUID) {
        selection[profileID.uuidString] = characterID
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: key)
        }
    }
}
