import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Owns the household ↔ children ↔ parents graph in Firestore and keeps the
/// local `ProfileStore` in sync with it. This is what makes multi-parent
/// linking and family data-separation possible: children belong to a household
/// (not a single uid), and any parent listed on the household can see them.
///
/// Degrades to a no-op when FirebaseFirestore isn't in the build, so the app
/// still runs purely locally.
@MainActor
final class HouseholdManager: ObservableObject {
    static let shared = HouseholdManager()

    @Published private(set) var household: Household?
    @Published private(set) var parentAccount: ParentAccount?
    @Published private(set) var linkedParentSummaries: [String] = []   // display names / emails
    @Published private(set) var lastError: String?
    /// True while we're fetching the family from the cloud right after sign-in,
    /// so the UI can wait instead of prematurely showing "create a child".
    @Published private(set) var isLoading = false
    private var didReceiveChildren = false

    private func markLoaded() { isLoading = false }

    private var uid: String?

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var householdListener: ListenerRegistration?
    private var childrenListener: ListenerRegistration?
    #endif

    private init() {}

    var isLinked: Bool { (household?.parentUIDs.count ?? 0) > 1 }

    // MARK: - Lifecycle

    /// Called from AuthManager after sign-in. Ensures the parent + household
    /// exist, migrates local profiles on first run, then starts listening.
    func start(uid: String, email: String?, displayName: String?) {
        self.uid = uid
        #if canImport(FirebaseFirestore)
        isLoading = true
        didReceiveChildren = false
        // Safety net: never block the UI forever if the cloud is slow/unreachable.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            self.markLoaded()
        }
        Task { await bootstrap(uid: uid, email: email, displayName: displayName) }
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        householdListener?.remove(); householdListener = nil
        childrenListener?.remove(); childrenListener = nil
        #endif
        household = nil
        parentAccount = nil
        linkedParentSummaries = []
        isLoading = false
        didReceiveChildren = false
        uid = nil
    }

    #if canImport(FirebaseFirestore)
    private func bootstrap(uid: String, email: String?, displayName: String?) async {
        do {
            try await ensureParentDoc(uid: uid, email: email, displayName: displayName)
            let hh = try await ensureHousehold(uid: uid)
            self.household = hh
            reconcileLocalChildren(into: hh)
            listenToHousehold(hh.id)
            listenToChildren(in: hh.id)
        } catch {
            lastError = error.localizedDescription
            markLoaded()   // sync failed (e.g. rules not deployed) — let the UI proceed
        }
    }

    private func parentRef(_ uid: String) -> DocumentReference {
        db.collection("parents").document(uid)
    }

    private func ensureParentDoc(uid: String, email: String?, displayName: String?) async throws {
        let ref = parentRef(uid)
        let snap = try await ref.getDocument()
        if snap.exists, let data = snap.data() {
            self.parentAccount = Self.decodeParent(id: uid, data)
        } else {
            let account = ParentAccount(id: uid, email: email, displayName: displayName)
            try await ref.setData(Self.encode(account), merge: true)
            self.parentAccount = account
        }
    }

    /// Returns the parent's household, creating one (with this uid as the sole
    /// parent) if they have none.
    private func ensureHousehold(uid: String) async throws -> Household {
        // Find a household that already lists this uid.
        let query = db.collection("households").whereField("parentUIDs", arrayContains: uid)
        let results = try await query.getDocuments()
        if let doc = results.documents.first, let hh = Self.decodeHousehold(id: doc.documentID, doc.data()) {
            return hh
        }
        // None — create a fresh household owned by this parent.
        let hh = Household(parentUIDs: [uid], createdBy: uid)
        try await db.collection("households").document(hh.id).setData(Self.encode(hh))
        try await parentRef(uid).updateData(["householdIDs": FieldValue.arrayUnion([hh.id])])
        return hh
    }

    private func listenToHousehold(_ id: String) {
        householdListener?.remove()
        householdListener = db.collection("households").document(id)
            .addSnapshotListener { [weak self] doc, _ in
                guard let self, let doc, let data = doc.data(),
                      let hh = Self.decodeHousehold(id: doc.documentID, data) else { return }
                self.household = hh
                self.refreshLinkedParentSummaries(hh.parentUIDs)
            }
    }

    private func listenToChildren(in householdID: String) {
        childrenListener?.remove()
        childrenListener = db.collection("children")
            .whereField("householdID", isEqualTo: householdID)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                let records = snap.documents.compactMap {
                    Self.decodeChild(id: $0.documentID, $0.data())
                }
                ProfileStore.shared.mergeRemoteChildren(records)
                // First reply from the cloud → the family has finished loading.
                if !self.didReceiveChildren {
                    self.didReceiveChildren = true
                    self.markLoaded()
                }
            }
    }

    private func refreshLinkedParentSummaries(_ uids: [String]) {
        Task {
            var summaries: [String] = []
            for parentUID in uids {
                if let doc = try? await parentRef(parentUID).getDocument(), let data = doc.data() {
                    let acc = Self.decodeParent(id: parentUID, data)
                    summaries.append(acc.displayName ?? acc.email ?? parentUID)
                }
            }
            self.linkedParentSummaries = summaries
        }
    }
    #endif

    // MARK: - Children CRUD (mirrors to Firestore)

    func upsertChild(_ profile: Profile) {
        #if canImport(FirebaseFirestore)
        guard let hh = household else { return }
        let record = ChildRecord(profile: profile, householdID: hh.id)
        Task {
            do {
                try await db.collection("children").document(record.id).setData(Self.encode(record), merge: true)
                try await db.collection("households").document(hh.id)
                    .updateData(["childIDs": FieldValue.arrayUnion([record.id])])
            } catch { lastError = error.localizedDescription }
        }
        #endif
    }

    func deleteChild(_ profileID: UUID) {
        #if canImport(FirebaseFirestore)
        guard let hh = household else { return }
        let id = profileID.uuidString
        Task {
            do {
                try await db.collection("households").document(hh.id)
                    .updateData(["childIDs": FieldValue.arrayRemove([id])])
                try await db.collection("children").document(id).delete()
                try await db.collection("children").document(id)
                    .collection("state").document("current").delete()
            } catch { lastError = error.localizedDescription }
        }
        #endif
    }

    // MARK: - Migration

    #if canImport(FirebaseFirestore)
    /// Push any locally-known children up to the cloud (idempotent). This makes
    /// a device that already has kids locally — e.g. the one they were created
    /// on — publish them so other devices on the household can pull them. Runs
    /// every sign-in; no-op on a fresh device (no local profiles yet).
    private func reconcileLocalChildren(into hh: Household) {
        for profile in ProfileStore.shared.profiles {
            upsertChild(profile)
        }
    }
    #endif

    // MARK: - Invites

    /// Creates a join code valid for 7 days. Returns nil if Firebase is absent
    /// or there's no household yet.
    func createInvite() async -> String? {
        #if canImport(FirebaseFirestore)
        guard let hh = household, let uid else { return nil }
        let code = Invite.makeCode()
        let invite = Invite(id: code, householdID: hh.id, createdBy: uid,
                            createdAt: .now, expiresAt: Date().addingTimeInterval(7 * 24 * 3600))
        do {
            try await db.collection("invites").document(code).setData(Self.encode(invite))
            return code
        } catch {
            lastError = error.localizedDescription
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Joins the household behind `code`. Returns true on success.
    func redeemInvite(code: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard let uid else { return false }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        do {
            let doc = try await db.collection("invites").document(trimmed).getDocument()
            guard let data = doc.data(), let invite = Self.decodeInvite(id: trimmed, data) else {
                lastError = "קוד לא נמצא"; return false
            }
            guard !invite.isExpired else { lastError = "הקוד פג תוקף"; return false }
            // Add this parent to the household + mark invite redeemed.
            try await db.collection("households").document(invite.householdID)
                .updateData(["parentUIDs": FieldValue.arrayUnion([uid])])
            try await parentRef(uid).updateData(["householdIDs": FieldValue.arrayUnion([invite.householdID])])
            try await db.collection("invites").document(trimmed).updateData(["redeemedBy": uid])
            // Switch to the joined household.
            let hhDoc = try await db.collection("households").document(invite.householdID).getDocument()
            if let hhData = hhDoc.data(), let hh = Self.decodeHousehold(id: invite.householdID, hhData) {
                self.household = hh
                listenToHousehold(hh.id)
                listenToChildren(in: hh.id)
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - Consent

    func recordConsent(version: Int) {
        #if canImport(FirebaseFirestore)
        guard let uid else { return }
        Task {
            try? await parentRef(uid).setData(
                ["consentVersion": version, "consentAt": Date().timeIntervalSince1970],
                merge: true
            )
        }
        #endif
    }

    // MARK: - Full deletion (privacy / GDPR-style)

    /// Cascade-deletes every child this parent's household owns, the household
    /// itself, and the parent record. Local state is cleared by the caller.
    func deleteAllData() async {
        #if canImport(FirebaseFirestore)
        guard let uid, let hh = household else { return }
        do {
            for childID in hh.childIDs {
                try? await db.collection("children").document(childID)
                    .collection("state").document("current").delete()
                try? await deleteSubcollection("children/\(childID)/dailyStats")
                try? await db.collection("children").document(childID).delete()
            }
            try? await db.collection("households").document(hh.id).delete()
            try? await parentRef(uid).delete()
        }
        #endif
    }

    #if canImport(FirebaseFirestore)
    private func deleteSubcollection(_ path: String) async throws {
        let snap = try await db.collection(path).getDocuments()
        for doc in snap.documents { try? await doc.reference.delete() }
    }
    #endif

    // MARK: - Encode / decode

    #if canImport(FirebaseFirestore)
    private static func encode<T: Encodable>(_ value: T) -> [String: Any] {
        guard let data = try? JSONEncoder.firestore.encode(value),
              let any = try? JSONSerialization.jsonObject(with: data),
              let dict = any as? [String: Any] else { return [:] }
        return dict
    }
    private static func decode<T: Decodable>(_ type: T.Type, _ raw: [String: Any]) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: raw),
              let value = try? JSONDecoder.firestore.decode(T.self, from: data) else { return nil }
        return value
    }
    private static func decodeHousehold(id: String, _ raw: [String: Any]) -> Household? {
        var r = raw; r["id"] = id; return decode(Household.self, r)
    }
    private static func decodeChild(id: String, _ raw: [String: Any]) -> ChildRecord? {
        var r = raw; r["id"] = id; return decode(ChildRecord.self, r)
    }
    private static func decodeParent(id: String, _ raw: [String: Any]) -> ParentAccount {
        var r = raw; r["id"] = id
        return decode(ParentAccount.self, r) ?? ParentAccount(id: id)
    }
    private static func decodeInvite(id: String, _ raw: [String: Any]) -> Invite? {
        var r = raw; r["id"] = id; return decode(Invite.self, r)
    }
    #endif
}

// JSON coders that round-trip Dates as epoch seconds — Firestore-friendly and
// stable across the JSONSerialization bridge used above.
extension JSONEncoder {
    static let firestore: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()
}
extension JSONDecoder {
    static let firestore: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}
