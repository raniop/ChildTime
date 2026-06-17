import Foundation

/// A request for one child to BUY play-minutes from a sibling using 💎 diamonds.
/// The buyer (`toChildID`) initiates and escrows the diamonds locally; a parent
/// approves; then the seller (`fromChildID`) settles on their own device. Lives
/// in the top-level `timeTransfers` Firestore collection, scoped by `householdID`.
///
/// Money flow (all conserved):
///  • buyer:  −diamonds (escrowed at request)  +minutes (credited on `completed`)
///  • seller: −minutes  (deducted at settle)   +diamonds (credited at settle)
///
/// Each device only ever mutates ITS OWN child's wallet, so the proven per-child
/// LWW sync carries the change — no cross-child writes.
struct TimeTransfer: Codable, Identifiable, Equatable {
    enum Status: String, Codable {
        case pendingParent   // waiting for a parent to approve
        case approved        // parent approved → seller will settle
        case rejected        // parent declined → refund the buyer
        case canceled        // buyer (or parent) canceled before completion → refund
        case completed       // settled on both sides
        case failed          // seller no longer had the minutes → refund the buyer
    }

    var id: String
    var householdID: String

    /// Seller — loses minutes, gains diamonds.
    var fromChildID: String
    /// Buyer — gains minutes, loses diamonds. Always the initiator.
    var toChildID: String
    /// Denormalized display names so the parent UI needs no extra lookups.
    var fromName: String
    var toName: String

    var minutes: Int
    var diamondPrice: Int
    var status: Status

    var createdAt: Double
    var decidedAt: Double?
    var settledAt: Double?

    // Idempotency flags (flipped inside Firestore transactions so a side applies
    // exactly once even across app relaunches / multiple devices for one child).
    var sellerSettled: Bool = false
    var buyerCredited: Bool = false
    var buyerRefunded: Bool = false

    /// A terminal state that should refund the buyer's escrowed diamonds.
    var isRefundable: Bool {
        status == .rejected || status == .canceled || status == .failed
    }
}
