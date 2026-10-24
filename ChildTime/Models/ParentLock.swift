import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// 🔒 "נעל עד שאשחרר" (Rani, 2026-10-24). The old "נעל עכשיו" only closed
/// the window that was open — the child opened again with their own minutes
/// twelve minutes later (Emily, 2026-10-22: locked at 18:22, reopened 18:34).
/// This lock stays until a parent releases it: from their phone, or with the
/// parent code on the child's device. Nothing is taken away — the minutes wait.
///
/// Written ONLY through `ParentLockStore.set` as its own field on
/// `children/{id}` — never inside a roster upload, so a device holding an old
/// copy can't write it back (same rule as `FlightMode`).
struct ParentLock: Codable, Hashable, Sendable {
    var on: Bool
    var at: Double
}

enum ParentLockStore {
    /// Lock (true) or release (false). Confirms like every parent→child command.
    @discardableResult
    static func set(_ on: Bool, for childID: UUID) async -> ConfirmedWriteOutcome {
        let value = ParentLock(on: on, at: Date().timeIntervalSince1970)
        if var p = ProfileStore.shared.profiles.first(where: { $0.id == childID }) {
            p.parentLock = value
            ProfileStore.shared.update(p)   // the roster upload never carries parentLock
        }
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync else { return .ok }
        let ref = Firestore.firestore().collection("children").document(childID.uuidString)
        let fields: [String: Any] = ["parentLock": ["on": value.on, "at": value.at]]
        var outcome = await confirmedMerge(ref, fields, timeout: 6)
        if outcome == .denied {
            _ = await HouseholdManager.shared.reassertMembership()
            outcome = await confirmedMerge(ref, fields, timeout: 6)
        }
        return outcome
        #else
        return .error
        #endif
    }
}
