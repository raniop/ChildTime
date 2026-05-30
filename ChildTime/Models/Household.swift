import Foundation

/// A family unit that owns children and links one or more parents. This is the
/// ownership boundary for data separation: a parent may only read/write a child
/// whose household lists their uid in `parentUIDs` (enforced by firestore.rules).
struct Household: Codable, Identifiable, Equatable {
    let id: String
    var parentUIDs: [String]
    var childIDs: [String]
    var createdBy: String
    var createdAt: Date
    /// Display names of REAL co-parents, keyed by uid. Child play-devices (which
    /// also appear in `parentUIDs` for access) never write here, so this is the
    /// clean source for "linked parents" — and avoids reading other parents'
    /// private docs (which the rules deny). Optional so older household docs
    /// (without this field) still decode.
    var parentNames: [String: String]?

    init(id: String = UUID().uuidString,
         parentUIDs: [String],
         childIDs: [String] = [],
         createdBy: String,
         createdAt: Date = .now,
         parentNames: [String: String]? = nil) {
        self.id = id
        self.parentUIDs = parentUIDs
        self.childIDs = childIDs
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.parentNames = parentNames
    }
}

/// A parent's account-level record. Sensitive bits (PIN hash, 2FA secret) live
/// in the Keychain via `PINManager`, not here. `fcmTokens` drives push delivery.
struct ParentAccount: Codable, Identifiable, Equatable {
    let id: String                 // == Firebase Auth uid
    var email: String?
    var displayName: String?
    var householdIDs: [String]
    var fcmTokens: [String]
    var twoFactorEnabled: Bool
    var consentVersion: Int        // 0 = not yet consented
    var consentAt: Date?

    init(id: String,
         email: String? = nil,
         displayName: String? = nil,
         householdIDs: [String] = [],
         fcmTokens: [String] = [],
         twoFactorEnabled: Bool = false,
         consentVersion: Int = 0,
         consentAt: Date? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.householdIDs = householdIDs
        self.fcmTokens = fcmTokens
        self.twoFactorEnabled = twoFactorEnabled
        self.consentVersion = consentVersion
        self.consentAt = consentAt
    }
}

/// A short-lived code a parent shares so a co-parent can join their household.
struct Invite: Codable, Identifiable, Equatable {
    let id: String                 // the human-shareable code (doc id)
    var householdID: String
    var createdBy: String
    var createdAt: Date
    var expiresAt: Date
    var redeemedBy: String?

    var isExpired: Bool { Date() > expiresAt }
    var isRedeemed: Bool { redeemedBy != nil }

    /// Generates a friendly 6-character code (no ambiguous 0/O/1/I).
    static func makeCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }
}

/// A request from a parent to absorb a child who signed up independently (with
/// their own email) into the parent's household. The parent creates it with the
/// child's email; the child approves it on their own device, which moves their
/// profiles into the parent's household.
struct ChildLinkRequest: Codable, Identifiable, Equatable {
    let id: String
    var fromHouseholdID: String
    var fromParentUID: String
    var fromParentName: String     // friendly label shown to the child
    var toEmail: String            // the child's email, lowercased
    var status: String             // "pending" | "approved" | "declined"
    var createdAt: Date

    init(id: String = UUID().uuidString,
         fromHouseholdID: String,
         fromParentUID: String,
         fromParentName: String,
         toEmail: String,
         status: String = "pending",
         createdAt: Date = .now) {
        self.id = id
        self.fromHouseholdID = fromHouseholdID
        self.fromParentUID = fromParentUID
        self.fromParentName = fromParentName
        self.toEmail = toEmail
        self.status = status
        self.createdAt = createdAt
    }
}

/// The current parental-consent version. Bump when the privacy terms change to
/// force re-consent.
enum Consent {
    static let currentVersion = 1
}
