import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Diagnostic logging for the child ↔ household ↔ device binding flow. Prints via
/// NSLog so it shows in Xcode's console AND Console.app (filter: "TofyLink").
func TofyLink(_ msg: @autoclosure () -> String) {
    NSLog("[TofyLink] %@", msg())
}

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
    /// Linked parents as (uid, name) — used to target a SPECIFIC parent for a
    /// help request (the child picks which parent to ask).
    @Published private(set) var linkedParents: [(uid: String, name: String)] = []
    @Published private(set) var lastError: String?
    /// True while we're fetching the family from the cloud right after sign-in,
    /// so the UI can wait instead of prematurely showing "create a child".
    @Published private(set) var isLoading = false
    /// A pending request from a parent to absorb THIS account's child profiles
    /// into their household — surfaced on the child's device for approval.
    @Published var pendingChildLink: ChildLinkRequest?
    /// Requests THIS parent has sent (child-link by email), with live status.
    @Published private(set) var sentChildLinks: [ChildLinkRequest] = []
    /// Set to the invite code once a child device redeems it — lets the parent's
    /// QR sheet auto-close the moment the child's device joins.
    @Published var redeemedInviteCode: String?
    /// The childID carried by the last successfully-redeemed invite (from the
    /// invite doc), so a child device binds to the right child even from a typed code.
    @Published var redeemedInviteChildID: String?
    /// Devices connected per child (childID string → devices), so the parent can
    /// see which/how many devices each child plays on.
    @Published private(set) var devicesByChild: [String: [ChildDevice]] = [:]
    /// The PARENT phones in this household — who they are and when each was last
    /// seen. Without this there is no way to tell a parent's device from a child's.
    @Published private(set) var parentDevices: [ChildDevice] = []

    /// PARENT-side live tracking of the last remote command sent per child, so
    /// the dashboard can show the truth instead of an optimistic "it worked":
    /// sending → reached cloud → ⏳ waiting for the device → ✅ applied (via the
    /// device's `…AppliedAt` ack on its row). Survives only in memory — the
    /// pushed "בוצע" notification (Cloud Function) covers the parent who left.
    struct RemoteCommandTracker: Equatable {
        enum Kind: Equatable { case lock, unlock, appRemoval }
        var kind: Kind
        var stamp: Double              // the command stamp written to the device rows
        var targetDeviceIDs: [String]  // childDevices doc IDs the command was written to
        var sentAt: Date               // when the parent tapped
        var reachedCloud: Bool         // the server actually committed the write
    }
    @Published var commandTracker: [String: RemoteCommandTracker] = [:]   // childID →

    /// The ack field on a device row that matches a tracked command kind.
    static func ackField(for kind: RemoteCommandTracker.Kind) -> String {
        switch kind {
        case .lock:       return "remoteLockAppliedAt"
        case .unlock:     return "remoteUnlockAppliedAt"
        case .appRemoval: return "appRemovalAppliedAt"
        }
    }

    /// How many of a tracked command's target devices have acked it (their row
    /// carries an `…AppliedAt` >= the command stamp).
    func appliedCount(childID: String) -> (applied: Int, total: Int)? {
        guard let cmd = commandTracker[childID] else { return nil }
        let rows = devicesByChild[childID] ?? []
        let applied = cmd.targetDeviceIDs.filter { target in
            guard let row = rows.first(where: { $0.id == target }) else { return false }
            let ack: Double?
            switch cmd.kind {
            case .lock:       ack = row.remoteLockAppliedAt
            case .unlock:     ack = row.remoteUnlockAppliedAt
            case .appRemoval: ack = row.appRemovalAppliedAt
            }
            return (ack ?? 0) >= cmd.stamp
        }.count
        return (applied, cmd.targetDeviceIDs.count)
    }

    /// DEMO_SCREEN=dashboard only: fake a live iPad play window for the active
    /// child so the "playing now" banner can be seen in screenshots.
    func seedDemoLiveWindow(childID: UUID) {
        let now = Date()
        let dev = ChildDevice(id: "\(childID.uuidString)_demo", childID: childID.uuidString,
                              householdID: "demo", deviceID: "demo", name: "אייפד", kind: "ipad",
                              systemVersion: "18", joinedAt: now, lastSeenAt: now, removed: nil,
                              remoteUnlockMinutes: nil, remoteUnlockAt: nil,
                              windowEndsAt: now.timeIntervalSince1970 + 23 * 60 + 40,
                              frozenSeconds: nil, windowIsManual: false)
        devicesByChild[childID.uuidString] = [dev]
    }
    private var didReceiveChildren = false

    private func markLoaded() { isLoading = false }

    private var uid: String?
    private var email: String?
    private var displayName: String?
    private let preferredHouseholdKey = "preferredHouseholdID"

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var householdListener: ListenerRegistration?
    private var childrenListener: ListenerRegistration?
    private var childLinkListener: ListenerRegistration?
    private var sentChildLinkListener: ListenerRegistration?
    private var inviteWatchListener: ListenerRegistration?
    private var childDevicesListener: ListenerRegistration?
    private var tombstoneListener: ListenerRegistration?
    #endif

    private init() {}

    var isLinked: Bool { (household?.parentUIDs.count ?? 0) > 1 }

    // MARK: - Lifecycle

    /// Called from AuthManager after sign-in. Ensures the parent + household
    /// exist, migrates local profiles on first run, then starts listening.
    ///
    /// Builds that must NEVER write to Firestore:
    ///  • screenshot/demo runs (DEMO_SCREEN) — they seed sample profiles
    ///    (דָּנָה/יוֹאָב…) into the LOCAL stores;
    ///  • automated test runs — `xcodebuild test` launches the HOST app, which
    ///    once synced stale local profiles straight into the real production
    ///    household (that's how junk יוֹאָב/שיפי dupes leaked in).
    /// In these modes every HouseholdManager cloud write is a no-op (local only).
    static var skipsCloudSync: Bool {
        if ProcessInfo.processInfo.environment["DEMO_SCREEN"] != nil { return true }
        if NSClassFromString("XCTestCase") != nil { return true }   // running under tests
        return false
    }

    func start(uid: String, email: String?, displayName: String?) {
        self.uid = uid
        self.email = email?.lowercased()
        self.displayName = displayName
        // Demo / screenshot / test builds stay entirely local — no parent,
        // household, child, or device docs are ever written to production.
        guard !Self.skipsCloudSync else { Task { @MainActor in self.markLoaded() }; return }
        #if canImport(FirebaseFirestore)
        // start() is invoked from the auth-state listener, which can fire while
        // SwiftUI is mid-update. Defer the @Published mutations one tick so they
        // don't trigger "Publishing changes from within view updates".
        Task { @MainActor in
            self.isLoading = true
            self.didReceiveChildren = false
        }
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
        childLinkListener?.remove(); childLinkListener = nil
        sentChildLinkListener?.remove(); sentChildLinkListener = nil
        childDevicesListener?.remove(); childDevicesListener = nil
        tombstoneListener?.remove(); tombstoneListener = nil
        #endif
        devicesByChild = [:]
        household = nil
        parentAccount = nil
        linkedParentSummaries = []
        pendingChildLink = nil
        sentChildLinks = []
        isLoading = false
        didReceiveChildren = false
        uid = nil
        email = nil
    }

    #if canImport(FirebaseFirestore)
    private func bootstrap(uid: String, email: String?, displayName: String?) async {
        do {
            try await ensureParentDoc(uid: uid, email: email, displayName: displayName)
            // NOBODY gets a silently-created household anymore (Rani):
            //  • found an existing membership → load it (veterans feel nothing).
            //  • real account + a pending EMAIL INVITE → "המשפחה מחכה לך" screen.
            //  • real account, nothing found → explicit new-vs-join choice screen.
            //  • anonymous (child device / pre-signup) → nothing, joins later.
            let realAccount = (email?.isEmpty == false) || (displayName?.isEmpty == false)
            if let hh = try await ensureHousehold(uid: uid, canCreate: false) {
                TofyLink("bootstrap: household \(hh.id.prefix(8)) loaded — pin=\(hh.parentPinHash != nil) kids=\(hh.childIDs.count)")
                finishBootstrap(hh)
                return
            }
            guard realAccount else {
                TofyLink("bootstrap: anonymous uid with no household — NOT creating one (joins later)")
                markLoaded()
                return
            }
            if let email, let invite = await findEmailInvite(email: email) {
                TofyLink("bootstrap: email invite found → household \(invite.id.prefix(8))")
                pendingEmailInvite = invite
                markLoaded()
                return
            }
            TofyLink("bootstrap: real account with no household — showing the new-vs-join choice")
            needsFamilyChoice = true
            markLoaded()
        } catch {
            lastError = error.localizedDescription
            markLoaded()   // sync failed (e.g. rules not deployed) — let the UI proceed
        }
    }

    /// Shared wiring once a household is known — found at sign-in, explicitly
    /// created, or joined via an email invite.
    private func finishBootstrap(_ hh: Household) {
        self.household = hh
        needsFamilyChoice = false
        pendingEmailInvite = nil
        listenToTombstones(in: hh.id)
        Task {
            // Reconcile must not race the tombstone LISTENER (its first snapshot
            // is async): fetch the tombstones NOW, drop those kids locally, and
            // only then re-upload what's left. Otherwise a device that was closed
            // during a delete on another device re-pushed the deleted child on
            // its next launch — and every other device pulled the kid back.
            let tombstoned = await fetchTombstonedChildIDs(in: hh.id)
            await MainActor.run {
                for id in tombstoned { ProfileStore.shared.removeLocalOnly(id) }
                self.reconcileLocalChildren(into: hh, skipping: tombstoned)
                self.listenToHousehold(hh.id)
                self.listenToChildren(in: hh.id); self.listenToChildDevices(in: hh.id)
            }
        }
    }

    /// A signed-in account with NO family yet must explicitly choose (published
    /// for ContentView routing). Cleared the moment a household exists.
    @Published var needsFamilyChoice = false
    /// A household whose invitedParentEmails lists this account's email —
    /// "משפחת X מחכה לך" one-tap join.
    @Published var pendingEmailInvite: Household? = nil

    /// Find a household that pre-invited this email (see inviteParentByEmail).
    private func findEmailInvite(email: String) async -> Household? {
        #if canImport(FirebaseFirestore)
        let snap = try? await db.collection("households")
            .whereField("invitedParentEmails", arrayContains: email.lowercased())
            .limit(to: 1).getDocuments()
        guard let doc = snap?.documents.first else { return nil }
        return Self.decodeHousehold(id: doc.documentID, doc.data())
        #else
        return nil
        #endif
    }

    /// Explicit "צרו משפחה חדשה" from the choice screen — the ONLY way a new
    /// cloud household is ever minted now.
    func createOwnHousehold() async {
        #if canImport(FirebaseFirestore)
        guard let uid else { return }
        do {
            let hh = Household(parentUIDs: [uid], createdBy: uid)
            try await db.collection("households").document(hh.id).setData(Self.encode(hh))
            try await parentRef(uid).updateData(["householdIDs": FieldValue.arrayUnion([hh.id])])
            TofyLink("createOwnHousehold: \(hh.id.prefix(8))")
            finishBootstrap(hh)
        } catch { lastError = error.localizedDescription }
        #endif
    }

    /// One-tap accept of an email invite: add MY uid (the self-add the rules
    /// allow), adopt the household, then tidy my email off the invite list.
    func acceptEmailInvite() async {
        #if canImport(FirebaseFirestore)
        guard let uid, let invite = pendingEmailInvite else { return }
        do {
            try await db.collection("households").document(invite.id)
                .updateData(["parentUIDs": FieldValue.arrayUnion([uid])])
            try await parentRef(uid).updateData(["householdIDs": FieldValue.arrayUnion([invite.id])])
            UserDefaults.standard.set(invite.id, forKey: preferredHouseholdKey)
            if let mail = email {
                try? await db.collection("households").document(invite.id)
                    .updateData(["invitedParentEmails": FieldValue.arrayRemove([mail.lowercased()])])
            }
            // Re-read now that we're a member (fresh data incl. our uid).
            let doc = try await db.collection("households").document(invite.id).getDocument()
            if let data = doc.data(), let hh = Self.decodeHousehold(id: invite.id, data) {
                TofyLink("acceptEmailInvite: joined \(hh.id.prefix(8))")
                finishBootstrap(hh)
                recordMyParentName(in: hh)
            }
        } catch { lastError = error.localizedDescription }
        #endif
    }

    /// Owner-side: pre-invite the co-parent by email — when THAT email signs
    /// in, it gets the "המשפחה מחכה לך" screen instead of a lost empty account.
    func inviteParentByEmail(_ rawEmail: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard let hh = household else { return false }
        let mail = rawEmail.trimmingCharacters(in: .whitespaces).lowercased()
        guard mail.contains("@"), mail.contains(".") else { return false }
        do {
            try await db.collection("households").document(hh.id)
                .updateData(["invitedParentEmails": FieldValue.arrayUnion([mail])])
            TofyLink("inviteParentByEmail: \(mail) invited to \(hh.id.prefix(8))")
            return true
        } catch { lastError = error.localizedDescription; return false }
        #else
        return false
        #endif
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

    /// Re-assert THIS device's membership in the current (or last-adopted)
    /// household — arrayUnion its uid into `parentUIDs`. The rules let a
    /// non-member add ONLY itself, so a child device whose anonymous uid drifted
    /// out of the list (or was pruned) self-heals here instead of silently
    /// getting "permission denied" on every chore/progress write for the rest of
    /// the session. Cheap and idempotent (a no-op arrayUnion if already a
    /// member). Returns true once the re-grant write has been attempted.
    @discardableResult
    func reassertMembership() async -> Bool {
        guard let uid else { return false }
        guard let hid = household?.id
                ?? UserDefaults.standard.string(forKey: preferredHouseholdKey) else { return false }
        try? await db.collection("households").document(hid)
            .updateData(["parentUIDs": FieldValue.arrayUnion([uid])])
        return true
    }

    /// Returns the parent's household, creating one (with this uid as the sole
    /// parent) if they have none — but ONLY when `canCreate` (a real, named
    /// account). Anonymous uids find/adopt but never mint (→ nil).
    private func ensureHousehold(uid: String, canCreate: Bool = true) async throws -> Household? {
        // SELF-HEAL: if we previously adopted a household (a child device that
        // joined a parent), make sure we're STILL a member. A child device whose
        // (anonymous) uid changed would otherwise lose access — writes to the
        // child's progress/devices get "permission denied" and the parent stops
        // seeing updates. The rules allow a non-member to add ONLY their own uid,
        // so this re-grants access without a re-scan.
        if let preferred = UserDefaults.standard.string(forKey: preferredHouseholdKey) {
            // arrayUnion adds our uid (no-op if already present); allowed for
            // members AND for non-members adding just themselves.
            try? await db.collection("households").document(preferred)
                .updateData(["parentUIDs": FieldValue.arrayUnion([uid])])
            // Now that we're a member we can read it.
            if let doc = try? await db.collection("households").document(preferred).getDocument(),
               let data = doc.data(), let hh = Self.decodeHousehold(id: preferred, data) {
                try? await parentRef(uid).updateData(["householdIDs": FieldValue.arrayUnion([preferred])])
                return hh
            }
        }
        // Find a household that already lists this uid.
        let query = db.collection("households").whereField("parentUIDs", arrayContains: uid)
        let results = try await query.getDocuments()
        if let doc = results.documents.first, let hh = Self.decodeHousehold(id: doc.documentID, doc.data()) {
            return hh
        }
        // None — create a fresh household owned by this parent (real accounts
        // only; an anonymous device waits to JOIN one instead).
        guard canCreate else { return nil }
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
                self.recordMyParentName(in: hh)
                self.refreshLinkedParentSummaries(from: hh)
            }
    }

    /// Publish MY display name into the household (so co-parents can show it
    /// without reading my private `parents/{uid}` doc). Only real accounts with a
    /// name write here — anonymous child play-devices stay out of the list.
    private func recordMyParentName(in hh: Household) {
        guard let uid else { return }
        let name = (displayName?.isEmpty == false ? displayName : email) ?? ""
        guard !name.isEmpty, (hh.parentNames ?? [:])[uid] != name else { return }
        Task {
            try? await db.collection("households").document(hh.id)
                .updateData(["parentNames.\(uid)": name])
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
                let s0 = ParentSettings.shared
                let boundPresent = s0.joinedChildID.map { (j: String) in records.contains(where: { $0.id == j }) }
                TofyLink("children snapshot: \(records.count) child(ren) [\(records.map { "\($0.name):\($0.id.prefix(8))" }.joined(separator: ", "))]; bound=\(s0.joinedChildID ?? "nil") present=\(boundPresent.map(String.init) ?? "n/a")")
                TofyLink("LOCAL profiles: [\(ProfileStore.shared.profiles.map { "\($0.name):\($0.id.uuidString.prefix(8))" }.joined(separator: ", "))]")
                ProfileStore.shared.mergeRemoteChildren(records)
                // Ghost cleanup: with an authoritative SERVER snapshot (never
                // cache — a cold cache is partial), drop local profiles the
                // household no longer contains. Months of "merge but never
                // remove" left devices with phantom kids (a deleted duplicate
                // still showing, family stats counting 9 children of 4).
                if !snap.metadata.isFromCache {
                    ProfileStore.shared.pruneLocalGhosts(cloudIDs: Set(records.map { $0.id }))
                }
                // First reply from the cloud → the family has finished loading.
                if !self.didReceiveChildren {
                    self.didReceiveChildren = true
                    self.markLoaded()
                }
                // We do NOT disconnect merely because the bound child is ABSENT from
                // this snapshot — a transient partial/empty snapshot would kick BOTH a
                // child's devices at once. But a PERSISTENTLY-missing binding (child
                // deleted/replaced, so its UUID is orphaned) must not leave the device
                // stuck on an empty phantom profile. When the bound child is absent, do
                // a one-shot authoritative check: read its own doc. Only if that doc is
                // truly gone / access-denied do we disconnect to the reconnect screen.
                if self.didReceiveChildren, s0.deviceRole == .child,
                   let j = s0.joinedChildID, boundPresent == false {
                    self.verifyBoundChildOrDisconnect(j)
                }
            }
    }

    /// Watch the household's tombstones (deleted children). When one appears, drop
    /// that child from THIS device's local store too — so a deletion on one device
    /// propagates everywhere and this device stops re-uploading the deleted kid.
    private var verifyingBoundChild = false

    /// The bound child was ABSENT from the household list. Read its own doc once to
    /// tell a real orphan (deleted/replaced UUID → doc gone or access denied) apart
    /// from a transient list blip (doc still there). Disconnect ONLY on a definitive
    /// gone/denied — never on a plain network error (that would strand a fine device).
    private func verifyBoundChildOrDisconnect(_ childID: String) {
        #if canImport(FirebaseFirestore)
        guard !verifyingBoundChild else { return }
        verifyingBoundChild = true
        db.collection("children").document(childID).getDocument { [weak self] snap, err in
            Task { @MainActor in
                guard let self else { return }
                self.verifyingBoundChild = false
                let s = ParentSettings.shared
                // Bail if we re-bound to a different child meanwhile.
                guard s.deviceRole == .child, s.joinedChildID == childID else { return }
                let denied = (err as NSError?).map {
                    $0.domain == FirestoreErrorDomain && $0.code == FirestoreErrorCode.permissionDenied.rawValue
                } ?? false
                let definitelyGone = denied || (err == nil && snap?.exists == false)
                if definitelyGone {
                    TofyLink("verifyBoundChild: children/\(childID.prefix(8)) is gone/denied (denied=\(denied)) → disconnecting to reconnect screen")
                    self.resetAsRemovedDevice()
                } else {
                    TofyLink("verifyBoundChild: children/\(childID.prefix(8)) still reachable (err=\(err?.localizedDescription ?? "nil")) — treating as transient, staying")
                }
            }
        }
        #endif
    }

    private func listenToTombstones(in householdID: String) {
        tombstoneListener?.remove()
        tombstoneListener = db.collection("deletedChildren")
            .whereField("householdID", isEqualTo: householdID)
            .addSnapshotListener { [weak self] snap, _ in
                guard let snap else { return }
                let ids = snap.documents.compactMap { UUID(uuidString: $0.documentID) }
                Task { @MainActor in
                    for id in ids { ProfileStore.shared.removeLocalOnly(id) }
                    // Authoritative disconnect: a tombstone means the bound child was
                    // really DELETED (not just briefly absent from a snapshot). This is
                    // the ONLY thing that strands a child device on the reconnect screen.
                    let s = ParentSettings.shared
                    if s.deviceRole == .child, let joined = s.joinedChildID,
                       let jid = UUID(uuidString: joined), ids.contains(jid) {
                        TofyLink("tombstone for BOUND child \(joined) → disconnecting this device")
                        self?.resetAsRemovedDevice()
                    } else if !ids.isEmpty {
                        TofyLink("tombstones: \(ids.count) (none is the bound child \(s.joinedChildID ?? "nil"))")
                    }
                }
            }
    }

    /// Guards the one-shot self-heal retry below (per household binding) so a
    /// permanently-denied listener can't spin in a re-attach loop.
    private var childDevicesHealAttempted = false

    private func listenToChildDevices(in householdID: String) {
        childDevicesListener?.remove()
        childDevicesListener = db.collection("childDevices")
            .whereField("householdID", isEqualTo: householdID)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                // The error was previously discarded (`snap, _`). A permission-
                // denied listener leaves `devicesByChild` EMPTY and every feature
                // reading it silently dies — including the child's "נעלו שם
                // ופתחו כאן" window transfer, which simply never appeared.
                // Self-heal a drifted uid once, then re-attach.
                if let err = err as NSError? {
                    TofyLink("childDevices listener ERROR: \(err.localizedDescription)")
                    if err.domain == FirestoreErrorDomain, err.code == 7,
                       !self.childDevicesHealAttempted {
                        self.childDevicesHealAttempted = true
                        Task { @MainActor in
                            await self.reassertMembership()
                            self.listenToChildDevices(in: householdID)
                        }
                    }
                    return
                }
                guard let snap else { return }
                self.childDevicesHealAttempted = false   // healthy again
                let devices = snap.documents.compactMap {
                    Self.decode(ChildDevice.self, $0.data())
                }.filter { $0.removed != true }   // hide removed devices from the parent
                var grouped: [String: [ChildDevice]] = [:]
                var parents: [ChildDevice] = []
                for d in devices {
                    // Parent devices carry no childID — keep them out of the
                    // per-child lists (they are not the child's play devices and
                    // must never be counted by the cross-device window checks).
                    if d.role == "parent" || d.childID.isEmpty { parents.append(d) }
                    else { grouped[d.childID, default: []].append(d) }
                }
                self.parentDevices = parents.sorted { $0.lastSeenAt > $1.lastSeenAt }
                for key in grouped.keys {
                    grouped[key]?.sort { $0.lastSeenAt > $1.lastSeenAt }
                }
                self.devicesByChild = grouped
            }
    }

    /// Register THIS device as a PARENT device of the household.
    ///
    /// Rani: "מכשיר הורה חייב להירשם ישירות שיוצרים משפחה". It lives in the same
    /// `childDevices` collection so the existing listener and security rules pick
    /// it up unchanged — the rules gate on householdID alone — with a doc id that
    /// cannot collide with a child's (`parent_<install>` vs `<childID>_<install>`)
    /// and an empty childID so it never groups under a real child.
    func registerParentDevice() async {
        #if canImport(FirebaseFirestore)
        guard !Self.skipsCloudSync, let hh = household, uid != nil else { return }
        guard ParentSettings.shared.deviceRole != .child else { return }
        let now = Date()
        let device = ChildDevice(
            id: "parent_\(DeviceIdentity.installID)", childID: "",
            householdID: hh.id, deviceID: DeviceIdentity.installID,
            name: DeviceIdentity.friendlyName, kind: DeviceIdentity.kind,
            systemVersion: DeviceIdentity.systemVersion,
            joinedAt: now, lastSeenAt: now,
            removed: nil, remoteUnlockMinutes: nil, remoteUnlockAt: nil
        )
        var data = Self.encode(device)
        data["role"] = "parent"
        data["appVersion"] = AppInfo.versionLine
        data["kidModeChildID"] = KidModeManager.shared.active
            ? (KidModeManager.shared.childID?.uuidString ?? "") : FieldValue.delete()
        do {
            try await db.collection("childDevices")
                .document("parent_\(DeviceIdentity.installID)")
                .setData(data, merge: true)
        } catch { TofyLink("registerParentDevice failed: \(error.localizedDescription)") }
        #endif
    }

    /// Register / refresh THIS device under a child (called when a child device
    /// joins and on each launch), so the parent sees it as connected with a
    /// fresh "last seen". Idempotent — keyed by the install ID.
    func registerDevice(forChildID childID: UUID) async {
        #if canImport(FirebaseFirestore)
        guard !Self.skipsCloudSync else { return }   // demo/test: no device rows
        guard let hh = household, uid != nil else { return }
        let cid = childID.uuidString
        let docID = "\(cid)_\(DeviceIdentity.installID)"
        let now = Date()
        var device = ChildDevice(
            id: docID, childID: cid, householdID: hh.id,
            deviceID: DeviceIdentity.installID, name: DeviceIdentity.friendlyName,
            kind: DeviceIdentity.kind, systemVersion: DeviceIdentity.systemVersion,
            joinedAt: now, lastSeenAt: now
        )
        // Include the push token when it's already known, so Cloud Functions can
        // target this child's device precisely from the very first registration
        // (uploadFCMToken keeps it fresh afterwards).
        device.fcmToken = PushManager.shared.currentToken
        // Stamp this device's auth uid so admin tooling can tell which of the
        // household's anonymous accounts still owns a LIVE device.
        device.ownerUID = uid
        do {
            // Don't clobber the original joinedAt on relaunch.
            let existing = try? await db.collection("childDevices").document(docID).getDocument()
            if let data = existing?.data(), let prior = Self.decode(ChildDevice.self, data) {
                // The parent removed this device while it was closed → reset to a
                // fresh install instead of re-registering (and don't reappear).
                if prior.removed == true { resetAsRemovedDevice(); return }
                device.joinedAt = prior.joinedAt
            }
            try await db.collection("childDevices").document(docID)
                .setData(Self.encode(device), merge: true)
            // Live-disconnect if the parent removes it later this session.
            watchOwnDeviceRemoval(childID: childID)
        } catch { lastError = error.localizedDescription }
        // Report the real play-time state so the parent sees the truth AND the
        // child's other device can offer the window transfer. Deliberately
        // OUTSIDE the do/catch: it used to sit after the registration write, so
        // a single failed/denied registration meant this device never published
        // `windowEndsAt` for the rest of the session — and the "נעלו שם ופתחו
        // כאן" button silently never appeared on the sibling device.
        // Stamp the build this device runs, so "which version is this phone on?"
        // is answerable from the dashboard instead of by asking.
        try? await db.collection("childDevices").document(docID)
            .setData(["appVersion": AppInfo.versionLine], merge: true)
        startReportingTimeState(childID: childID)
        #endif
    }

    /// CHILD device: is one of THIS child's OTHER devices reporting an open play
    /// window right now? Prevents the classic double-spend — the kid opens 30
    /// minutes on the iPad, the iPhone hasn't synced the drained wallet yet, and
    /// opens the same 30 again. The window itself stays per-device (it shields
    /// apps on ONE device), but the fact that it exists is family-wide.
    /// Returns (device, secondsLeft) for the freshest open window elsewhere.
    func otherDeviceOpenWindow(forChildID childID: UUID) -> (device: ChildDevice, secondsLeft: Int)? {
        let mine = DeviceIdentity.installID
        let now = Date().timeIntervalSince1970
        let others = (devicesByChild[childID.uuidString] ?? [])
            .filter { $0.deviceID != mine }
            .compactMap { d -> (ChildDevice, Int)? in
                guard let end = d.windowEndsAt, end > now else { return nil }
                return (d, Int(end - now))
            }
        return others.max(by: { $0.1 < $1.1 })
    }

    private var timeStateCancellables = Set<AnyCancellable>()

    /// CHILD device: keep this device's `childDevices` doc updated with the ACTUAL
    /// play-window state (open window end / frozen minutes), so the parent dashboard
    /// reflects reality instead of guessing a countdown from the grant. Writes only
    /// when the window starts/ends/pauses (not per second — the parent computes the
    /// live countdown from `windowEndsAt` locally).
    func startReportingTimeState(childID: UUID) {
        #if canImport(FirebaseFirestore)
        // Kid Mode on a PARENT's phone is a real play device for this child: it
        // opens windows and spends the same wallet. It used to publish nothing, so
        // the child's own iPad was structurally blind to it — the double-spend
        // guard could never see that window, and the transfer was never offered.
        guard ParentSettings.shared.deviceRole == .child || KidModeManager.shared.active else { return }
        timeStateCancellables.removeAll()
        let p = ProgressStore.shared
        Publishers.MergeMany([
            p.$unlockEndsAt.map { _ in () }.eraseToAnyPublisher(),
            p.$manualPausedSeconds.map { _ in () }.eraseToAnyPublisher(),
        ])
        .dropFirst()
        .sink { [weak self] in self?.reportTimeState(childID: childID) }
        .store(in: &timeStateCancellables)
        reportTimeState(childID: childID)
        #endif
    }

    private func reportTimeState(childID: UUID) {
        #if canImport(FirebaseFirestore)
        guard let hh = household else { return }
        let docID = "\(childID.uuidString)_\(DeviceIdentity.installID)"
        let p = ProgressStore.shared
        // Always carry childID/householdID: a merge onto a row that doesn't exist
        // yet (registration lost the race, or was denied) would otherwise create
        // a doc with no householdID — unreadable by the family and invisible to
        // the sibling device's transfer check.
        var data: [String: Any] = ["frozenSeconds": p.manualPausedSeconds,
                                   "childID": childID.uuidString,
                                   "householdID": hh.id,
                                   "deviceID": DeviceIdentity.installID]
        if let end = p.unlockEndsAt, end > Date() {
            data["windowEndsAt"] = end.timeIntervalSince1970
            data["windowIsManual"] = p.unlockIsManual
        } else {
            data["windowEndsAt"] = FieldValue.delete()
            data["windowIsManual"] = FieldValue.delete()
        }
        // CONFIRMED + self-healing: this row is what makes the sibling device
        // offer "נעלו שם ופתחו כאן". A silently-denied fire-and-forget write here
        // meant the button never appeared and nobody knew ([[command-delivery-certainty]]).
        let ref = db.collection("childDevices").document(docID)
        Task {
            var outcome = await confirmedMerge(ref, data)
            if outcome == .denied {
                await self.reassertMembership()
                outcome = await confirmedMerge(ref, data)
            }
            if outcome == .denied || outcome == .error {
                TofyLink("reportTimeState FAILED for \(docID.prefix(12)) — window transfer may not be offered")
            }
        }
        #endif
    }

    /// Linked co-parents = the names recorded in the household, minus me. Reads
    /// only the household doc (no denied cross-parent reads), and naturally
    /// excludes anonymous child play-devices (they never record a name).
    private func refreshLinkedParentSummaries(from hh: Household) {
        linkedParentSummaries = (hh.parentNames ?? [:])
            .filter { $0.key != self.uid && !$0.value.isEmpty }
            .map { $0.value }
            .sorted()
        linkedParents = (hh.parentNames ?? [:])
            .filter { !$0.value.isEmpty }
            .map { (uid: $0.key, name: $0.value) }
            .sorted { $0.name < $1.name }
    }
    #endif

    // MARK: - Children CRUD (mirrors to Firestore)

    /// `onlyIfMissing: true` = HEAL mode (reconcile): create the cloud doc if
    /// it's gone, but never overwrite an existing one — a sign-in sweep with a
    /// stale local copy used to clobber fresher fields (the kid's character
    /// pick reverting to an old one). Explicit edits keep the default (false).
    func upsertChild(_ profile: Profile, onlyIfMissing: Bool = false) {
        #if canImport(FirebaseFirestore)
        guard !Self.skipsCloudSync else { return }   // never sync in demo/test builds
        guard let hh = household else { return }
        let record = ChildRecord(profile: profile, householdID: hh.id)
        Task {
            do {
                // Second line of defense against resurrecting a deleted child
                // (the single cloud write path for children): if a tombstone
                // exists for this id, drop it locally instead of uploading.
                let tomb = try? await db.collection("deletedChildren").document(record.id).getDocument()
                if tomb?.exists == true {
                    TofyLink("upsertChild: \(record.id.prefix(8)) is TOMBSTONED → dropping locally, not uploading")
                    await MainActor.run { ProfileStore.shared.removeLocalOnly(profile.id) }
                    return
                }
                if onlyIfMissing {
                    let existing = try? await db.collection("children").document(record.id).getDocument()
                    if existing?.exists == true {
                        TofyLink("upsertChild(heal): \(record.id.prefix(8)) already in cloud — not overwriting")
                        return
                    }
                }
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
                // Tombstone FIRST so a racing re-upload from another device is
                // blocked (the `blockTombstonedChild` function wipes any resurrection).
                try await db.collection("deletedChildren").document(id).setData([
                    "householdID": hh.id,
                    "deletedAt": Date().timeIntervalSince1970,
                ])
                try await db.collection("households").document(hh.id)
                    .updateData(["childIDs": FieldValue.arrayRemove([id])])
                // Delete the subcollection state AND the public leaderboard card
                // BEFORE the parent `children/{id}` doc — both their rules gate on
                // that doc's householdID, so deleting it first would leave the
                // progress doc orphaned and the child's name+stars lingering on
                // the public friends board (the delete would be silently denied).
                try await db.collection("children").document(id)
                    .collection("state").document("current").delete()
                try? await db.collection("friendCards").document(id).delete()
                try await db.collection("children").document(id).delete()
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
    private func reconcileLocalChildren(into hh: Household, skipping tombstoned: Set<UUID> = []) {
        // A child device binds to ONE existing child and must NEVER re-upload its
        // local profiles — that re-creates kids the parent just deleted (the dupes
        // that "kept coming back"). Only PARENT devices heal missing cloud records.
        guard ParentSettings.shared.deviceRole != .child else { return }
        for profile in ProfileStore.shared.profiles where !tombstoned.contains(profile.id) {
            // Resurrection guard: heal ONLY children the cloud household already
            // lists, or kids genuinely created on THIS device. A stale local copy
            // of any other UUID (months-old roster leftovers, legacy per-device
            // migrations) must never be pushed back up — that is the engine that
            // kept re-creating "duplicate children" in the day-one families.
            let cloudKnown = hh.childIDs.contains(profile.id.uuidString)
            let mine = ProfileStore.shared.wasCreatedHere(profile.id)
            if cloudKnown || mine {
                // HEAL mode: create a missing doc, never overwrite a live one —
                // this sweep runs with possibly weeks-stale local copies.
                upsertChild(profile, onlyIfMissing: true)
            } else {
                TofyLink("reconcile: SKIP \(profile.name):\(profile.id.uuidString.prefix(8)) — not in cloud household and not created on this device")
            }
        }
    }

    /// One-shot read of the household's tombstones (children deleted on ANY
    /// device). Used at bootstrap so reconcile can't resurrect a deleted kid.
    /// On a read error returns [] — the live tombstone listener still cleans up
    /// after the fact (and the cloud `blockTombstonedChild` guard, once deployed).
    private func fetchTombstonedChildIDs(in householdID: String) async -> Set<UUID> {
        let snap = try? await db.collection("deletedChildren")
            .whereField("householdID", isEqualTo: householdID)
            .getDocuments()
        return Set((snap?.documents ?? []).compactMap { UUID(uuidString: $0.documentID) })
    }
    #endif

    // MARK: - Invites

    /// Creates a join code valid for 7 days. Returns nil if Firebase is absent
    /// or there's no household yet.
    func createInvite(childID: String? = nil) async -> String? {
        #if canImport(FirebaseFirestore)
        guard let hh = household, let uid else { return nil }
        TofyLink("createInvite: encoding childID=\(childID ?? "nil") into QR, household=\(hh.id.prefix(8))")
        let code = Invite.makeCode()
        let invite = Invite(id: code, householdID: hh.id, createdBy: uid,
                            createdAt: .now, expiresAt: Date().addingTimeInterval(7 * 24 * 3600),
                            childID: childID)
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

    /// A per-child join code/QR payload: the household invite code + the child's
    /// id, so the child's device joins this family AND lands straight on that
    /// child. Format: "CODE|childID".
    func makeChildJoinCode(for childID: String) async -> String? {
        // Store the childID IN the invite doc (not just appended to the string) so
        // a typed bare code resolves the same child a scanned QR would.
        guard let code = await createInvite(childID: childID) else { return nil }
        return "\(code)|\(childID)"
    }

    /// Watch an invite (by full "CODE|childID" payload or bare code) and publish
    /// `redeemedInviteCode` the instant a child device redeems it — so the
    /// parent's QR sheet can auto-close. Replaces any prior watch.
    func watchInviteRedemption(payload: String) {
        #if canImport(FirebaseFirestore)
        let code = String(payload.split(separator: "|").first ?? Substring(payload))
            .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }
        inviteWatchListener?.remove()
        redeemedInviteCode = nil
        inviteWatchListener = db.collection("invites").document(code)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                if let data = snap?.data(), data["redeemedBy"] != nil {
                    Task { @MainActor in self.redeemedInviteCode = code }
                }
            }
        #endif
    }

    /// Family-wide parent code (salted hash). Any device in the household uses it.
    var householdPIN: String? { household?.parentPinHash }

    /// One-shot pull of the latest household doc — belt-and-suspenders for when the
    /// live listener may have lagged or dropped (e.g. the parent just changed the
    /// family code and we're about to verify it at the gate). Safe to call often.
    func refreshHouseholdNow() {
        #if canImport(FirebaseFirestore)
        let id = household?.id
            ?? UserDefaults.standard.string(forKey: preferredHouseholdKey)
        guard let id, !id.isEmpty else { return }
        Task { @MainActor in
            if let doc = try? await db.collection("households").document(id).getDocument(),
               let data = doc.data(),
               let hh = Self.decodeHousehold(id: id, data) {
                self.household = hh
            }
        }
        #endif
    }

    /// The dashboard's manual child order: the household's (family-wide) value
    /// when we have one, else the device-local cache — so ordering works
    /// instantly and offline, and before/without a synced household.
    @Published private(set) var localChildOrder: [String] =
        UserDefaults.standard.stringArray(forKey: "dashboard.childOrder") ?? []
    var effectiveChildOrder: [String] {
        if let hh = household?.childOrder, !hh.isEmpty { return hh }
        return localChildOrder
    }

    /// PARENT: save the dashboard's manual child order (family-wide, so a
    /// co-parent's dashboard matches). Applies locally at once for a snappy
    /// drag-and-drop; the household listener echoes the same value back.
    /// The parent names the family ("משפחת גולן"). Empty clears it.
    func setFamilyName(_ raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        household?.familyName = name.isEmpty ? nil : name
        #if canImport(FirebaseFirestore)
        guard let hh = household else { return }
        Task { try? await db.collection("households").document(hh.id)
            .updateData(["familyName": name.isEmpty ? FieldValue.delete() : name]) }
        #endif
    }

    func setChildOrder(_ ids: [UUID]) {
        let order = ids.map { $0.uuidString }
        localChildOrder = order
        UserDefaults.standard.set(order, forKey: "dashboard.childOrder")
        household?.childOrder = order
        #if canImport(FirebaseFirestore)
        guard let hh = household else { return }
        Task { try? await db.collection("households").document(hh.id)
            .updateData(["childOrder": order]) }
        #endif
    }

    /// Save the family parent code (hash) to the household so every device shares it.
    func setHouseholdPIN(_ blob: String) {
        #if canImport(FirebaseFirestore)
        guard let hh = household else { return }
        Task { try? await db.collection("households").document(hh.id)
            .updateData(["parentPinHash": blob]) }
        #endif
    }

    /// PARENT: open screen time for a child RIGHT NOW, from afar — the kid doesn't
    /// have to play or earn. Stamps a one-time command on every device row for that
    /// child; each device's live listener picks it up and opens a fixed `minutes`
    /// window. Works while the child's app is open or backgrounded with an active
    /// listener (a fully-suspended device applies it the moment it's reopened, as
    /// long as the grant is still fresh).
    func grantRemoteScreenTime(toChildID childID: UUID, minutes: Int) {
        #if canImport(FirebaseFirestore)
        guard let hh = household, minutes > 0 else { return }
        let cid = childID.uuidString
        let stamp = Date().timeIntervalSince1970
        Task {
            await sendDeviceCommand(childID: cid, householdID: hh.id, kind: .unlock, stamp: stamp,
                                    fields: ["remoteUnlockMinutes": minutes, "remoteUnlockAt": stamp])
            await MainActor.run { AppAnalytics.log("remote_screentime_granted", ["minutes": "\(minutes)"]) }
        }
        #endif
    }

    #if canImport(FirebaseFirestore)
    /// Shared send path for per-device remote commands: writes `fields` onto every
    /// device row of the child and keeps `commandTracker` honest along the way —
    /// `reachedCloud` flips only when the server COMMITS the write (Firestore's
    /// async updateData resolves on backend commit, not on local queueing), which
    /// is exactly the difference between "נשלח" and "אין אינטרנט, יישלח כשיחזור".
    private func sendDeviceCommand(childID cid: String, householdID: String,
                                   kind: RemoteCommandTracker.Kind, stamp: Double,
                                   fields: [String: Any]) async {
        // Tag the sender so Cloud Functions can skip the acting parent's own
        // devices when pushing the "בוצע" confirmation (they saw it live).
        var fields = fields
        if let uid { fields["commandBy"] = uid }
        // Target list from the LIVE listener first (works offline); fall back to a query.
        var targets = (devicesByChild[cid] ?? []).map { $0.id }
        if targets.isEmpty {
            let snap = try? await db.collection("childDevices")
                .whereField("householdID", isEqualTo: householdID)
                .whereField("childID", isEqualTo: cid)
                .getDocuments()
            targets = snap?.documents.map { $0.documentID } ?? []
        }
        await MainActor.run {
            commandTracker[cid] = RemoteCommandTracker(kind: kind, stamp: stamp,
                                                       targetDeviceIDs: targets,
                                                       sentAt: Date(), reachedCloud: false)
        }
        guard !targets.isEmpty else { return }
        // setData(merge:) not updateData: a row deleted-and-recreated mid-flight
        // must still receive the command rather than throw NOT_FOUND. The awaits
        // resolve on BACKEND commit — that's what makes `reachedCloud` honest.
        var committedAny = false
        for id in targets {
            do {
                try await db.collection("childDevices").document(id).setData(fields, merge: true)
                committedAny = true
            } catch { /* offline: stays queued locally; reachedCloud stays false */ }
        }
        if committedAny {
            await MainActor.run { commandTracker[cid]?.reachedCloud = true }
        }
    }
    #endif

    /// Parent action: RE-LOCK the child's device now, from afar. Writes a
    /// `remoteLockAt` stamp onto the child's device rows; the device applies it
    /// once (ends any open play window + re-applies the shield). Mirror of
    /// `grantRemoteScreenTime`.
    func lockRemoteScreenTime(toChildID childID: UUID) {
        #if canImport(FirebaseFirestore)
        guard let hh = household else { return }
        let cid = childID.uuidString
        let stamp = Date().timeIntervalSince1970
        Task {
            await sendDeviceCommand(childID: cid, householdID: hh.id, kind: .lock, stamp: stamp,
                                    fields: ["remoteLockAt": stamp])
            // Rani: a dead device must not strand the child. The command above
            // needs the device to wake up and obey — so we give it a short grace
            // to do exactly that, and only take the window away ourselves if it
            // never answers. Closing early would free the lease while the child's
            // device is still unshielded, which is its own double-window hole.
            await PlayWindowLeaseManager.shared.parentRelease(childID: childID)
            await MainActor.run { AppAnalytics.log("remote_screentime_locked", [:]) }
        }
        #endif
    }

    /// Parent action: open a short "allow app deletion" window on the child's
    /// device FROM AFAR (Rani: no need to hold the kid's device). Writes an
    /// `appRemovalUnlockAt` stamp onto the child's device rows; the device
    /// applies it once — 5 minutes of deletion allowed, then auto-relock.
    func allowAppRemovalRemotely(toChildID childID: UUID) {
        #if canImport(FirebaseFirestore)
        guard let hh = household else { return }
        let cid = childID.uuidString
        let stamp = Date().timeIntervalSince1970
        Task {
            await sendDeviceCommand(childID: cid, householdID: hh.id, kind: .appRemoval, stamp: stamp,
                                    fields: ["appRemovalUnlockAt": stamp])
            await MainActor.run { AppAnalytics.log("remote_app_removal_window", [:]) }
        }
        #endif
    }

    /// CHILD device: window transfer ("נעל באייפד ופתח כאן") — lock the SAME
    /// child's OTHER device by stamping remoteLockAt on THAT row only. The
    /// target stops-and-saves (nothing is lost), acks, clears its windowEndsAt,
    /// and pushes the refreshed wallet; the caller watches the row and opens
    /// here only AFTER the window there is confirmed gone.
    func lockOtherDeviceWindow(deviceRowID: String) {
        #if canImport(FirebaseFirestore)
        // Confirmed + self-healing: a silently-denied write left the child staring
        // at "נועלים שם…" until the 30s timeout with no honest failure
        // ([[command-delivery-certainty]]).
        let ref = db.collection("childDevices").document(deviceRowID)
        let fields: [String: Any] = ["remoteLockAt": Date().timeIntervalSince1970]
        Task {
            var outcome = await confirmedMerge(ref, fields)
            if outcome == .denied {
                await self.reassertMembership()
                outcome = await confirmedMerge(ref, fields)
            }
            if outcome == .denied || outcome == .error {
                TofyLink("lockOtherDeviceWindow FAILED for \(deviceRowID.prefix(12))")
            }
        }
        #endif
    }

    /// Kid Mode ending on a parent's phone → drop the temporary device row so the
    /// family doesn't keep seeing a phantom device for this child.
    func removeKidModeDeviceRow(forChildID childID: UUID) {
        #if canImport(FirebaseFirestore)
        guard !Self.skipsCloudSync else { return }
        let docID = "\(childID.uuidString)_\(DeviceIdentity.installID)"
        db.collection("childDevices").document(docID).delete()
        #endif
    }

    /// Remove a connected device from a child. TOMBSTONES the doc (`removed:true`)
    /// instead of deleting it, so the device itself notices and resets to a fresh
    /// install — otherwise it would just re-register on its next heartbeat.
    func removeChildDevice(id: String) {
        #if canImport(FirebaseFirestore)
        // NB: do NOT write FieldValue.serverTimestamp() here — childDevices docs
        // are decoded via JSONSerialization, which raises an (uncatchable) ObjC
        // exception on a FIRTimestamp and crashed both apps. The boolean tombstone
        // is all we need.
        db.collection("childDevices").document(id).setData(["removed": true], merge: true)
        #endif
    }

    // MARK: - This device was removed → reset to a fresh install

    private var ownDeviceListener: ListenerRegistration?

    /// CHILD device: watch its OWN row so a parent's "remove device" disconnects
    /// it live — and so a parent's REMOTE "open screen time now" applies live.
    /// Idempotent.
    func watchOwnDeviceRemoval(childID: UUID) {
        #if canImport(FirebaseFirestore)
        let docID = "\(childID.uuidString)_\(DeviceIdentity.installID)"
        ownDeviceListener?.remove()
        ownDeviceListener = db.collection("childDevices").document(docID)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let data = snap?.data() else { return }
                if (data["removed"] as? Bool) == true {
                    self.resetAsRemovedDevice()
                    return
                }
                // Lock vs unlock: apply in STAMP order so the NEWER command wins.
                // A device that was offline can wake up to both at once — the old
                // `unlock-then-lock` fixed order let a stale lock override a newer
                // grant (and vice versa the freshness window silently dropped locks).
                let lockAt = data["remoteLockAt"] as? Double ?? 0
                let unlockAt = data["remoteUnlockAt"] as? Double ?? 0
                if lockAt <= unlockAt {
                    self.applyRemoteLockIfNeeded(data, docID: docID)
                    self.applyRemoteUnlockIfNeeded(data, docID: docID)
                } else {
                    self.applyRemoteUnlockIfNeeded(data, docID: docID)
                    self.applyRemoteLockIfNeeded(data, docID: docID)
                }
                self.applyRemoteAppRemovalIfNeeded(data, docID: docID)
            }
        #endif
    }

    /// ACK a consumed device command: write the command's own stamp back onto our
    /// device row (`…AppliedAt`), so the parent's dashboard flips "⏳ ממתין" to
    /// "✅ בוצע" — and a Cloud Function pushes the parent if the ack came late.
    /// Also HEALS a missing ack for a command we already applied before an ack
    /// write ever made it out (offline crash, pre-ack build).
    private func ackDeviceCommand(docID: String, field: String, stamp: Double) {
        #if canImport(FirebaseFirestore)
        db.collection("childDevices").document(docID)
            .setData([field: stamp], merge: true)
        #endif
    }

    private let lastRemoteUnlockKey = "lastRemoteUnlockAt"
    private let lastRemoteLockKey = "lastRemoteLockAt"
    private let lastRemoteAppRemovalKey = "lastRemoteAppRemovalAt"

    /// A parent opened an app-deletion window from afar. Apply exactly once per
    /// command and only while fresh: 5 minutes of deletion allowed, then the
    /// lock returns by itself (the shield resync re-locks once the window
    /// passes; the timer below covers the app staying open the whole time).
    @MainActor
    private func applyRemoteAppRemovalIfNeeded(_ data: [String: Any], docID: String) {
        #if canImport(FirebaseFirestore)
        guard let at = data["appRemovalUnlockAt"] as? Double else { return }
        let last = UserDefaults.standard.double(forKey: lastRemoteAppRemovalKey)
        let now = Date().timeIntervalSince1970
        if at <= last, (data["appRemovalAppliedAt"] as? Double ?? 0) < at {
            ackDeviceCommand(docID: docID, field: "appRemovalAppliedAt", stamp: at)   // heal lost ack
        }
        guard at > last, now - at < Self.remoteUnlockFreshness else { return }   // unseen + fresh
        UserDefaults.standard.set(at, forKey: lastRemoteAppRemovalKey)
        ackDeviceCommand(docID: docID, field: "appRemovalAppliedAt", stamp: at)
        let windowSeconds: TimeInterval = 5 * 60
        ParentSettings.shared.appRemovalUnlockedUntil = Date().addingTimeInterval(windowSeconds)
        ShieldManager.shared.setAppRemovalLocked(false)
        Haptic.light()
        DispatchQueue.main.asyncAfter(deadline: .now() + windowSeconds + 1) {
            let s = ParentSettings.shared
            if (s.appRemovalUnlockedUntil ?? .distantPast) <= Date() {
                ShieldManager.shared.setAppRemovalLocked(s.deviceRole == .child)
            }
        }
        #endif
    }

    /// A parent RE-LOCKED this child's device from afar. Apply exactly once per
    /// command (`at > last`). Ends any open window + re-shields.
    ///
    /// Deliberately NO freshness window: a lock is the safe-side command, and the
    /// old 6-hour cutoff meant a device that was off/offline for half a day just
    /// never locked — the parent's #1 "it didn't work" report. Ordering against a
    /// NEWER unlock is handled by the caller (stamp-ordered application).
    @MainActor
    private func applyRemoteLockIfNeeded(_ data: [String: Any], docID: String) {
        #if canImport(FirebaseFirestore)
        guard let at = data["remoteLockAt"] as? Double else { return }
        let last = UserDefaults.standard.double(forKey: lastRemoteLockKey)
        if at <= last, (data["remoteLockAppliedAt"] as? Double ?? 0) < at {
            ackDeviceCommand(docID: docID, field: "remoteLockAppliedAt", stamp: at)   // heal lost ack
        }
        guard at > last else { return }   // unseen only — locks never expire
        UserDefaults.standard.set(at, forKey: lastRemoteLockKey)
        ackDeviceCommand(docID: docID, field: "remoteLockAppliedAt", stamp: at)
        Task { @MainActor in
            // Close the window but SAVE the leftover — a remote lock is "not
            // now", not a punishment: earned minutes bank back to the child's
            // wallet, a parent gift/grant freezes for later. (endUnlock() alone
            // silently burned whatever was left.)
            ProgressStore.shared.stopAndSaveCurrentUnlock()
            // Upload the banked/frozen leftover NOW — the child's OTHER device
            // may be waiting on it to open a transferred window ("נעל באייפד
            // ופתח באייפון"), and the ~3s debounce can outlive the wake window.
            RemoteSyncManager.shared.pushNow()
            ShieldManager.shared.cancelScheduledReshield()
            ShieldManager.shared.relockBaseline()    // re-lock now
            Haptic.warning()
        }
        #endif
    }

    /// How long a remote "open screen time now" stays applicable. The parent's
    /// confirmation promises it opens "the moment the child opens Tofy", so the
    /// window must be generous enough to cover a child who picks up the device a
    /// while later — not just the next 10 minutes (the old window silently dropped
    /// grants and was the cause of "sometimes the child doesn't get it"). Still
    /// bounded so a day-old grant doesn't surprise-unlock on a future launch.
    private static let remoteUnlockFreshness: TimeInterval = 6 * 3600   // 6 hours

    /// A parent opened screen time for this child from afar. Apply it exactly once
    /// per command (`at > last`), as long as it's still within the freshness window.
    @MainActor
    private func applyRemoteUnlockIfNeeded(_ data: [String: Any], docID: String) {
        guard let at = data["remoteUnlockAt"] as? Double,
              let minutes = data["remoteUnlockMinutes"] as? Int, minutes > 0 else { return }
        let last = UserDefaults.standard.double(forKey: lastRemoteUnlockKey)
        let now = Date().timeIntervalSince1970
        if at <= last, (data["remoteUnlockAppliedAt"] as? Double ?? 0) < at {
            ackDeviceCommand(docID: docID, field: "remoteUnlockAppliedAt", stamp: at)   // heal lost ack
        }
        guard at > last, now - at < Self.remoteUnlockFreshness else { return }   // unseen + fresh
        UserDefaults.standard.set(at, forKey: lastRemoteUnlockKey)
        ackDeviceCommand(docID: docID, field: "remoteUnlockAppliedAt", stamp: at)
        let childID = (data["childID"] as? String).flatMap(UUID.init(uuidString:))
        Task { @MainActor in
            await ShieldManager.shared.requestAuthorizationIfNeeded()
            ShieldManager.shared.cancelScheduledReshield()
            // A parent's remote grant used to open a window with NO wallet
            // interaction and NO cross-device awareness at all — so a parent
            // granting time while the child was mid-session on their other device
            // opened a SECOND concurrent window, leaking straight through the
            // invariant via the parent's own button. Route it through the lease:
            // `.grant` mints the minutes (they aren't spent from a pocket) and
            // `.parentOverride` outranks a sibling device holding the window.
            var leaseID: String? = nil
            if PlayWindowLeaseManager.isEnabled, let childID {
                let outcome = await PlayWindowLeaseManager.shared.claim(
                    childID: childID, kind: .grant,
                    requestedSeconds: minutes * 60, policy: .parentOverride)
                if case .granted(let id, _, let wallet) = outcome {
                    leaseID = id
                    if let wallet { ProgressStore.shared.applyClaimedWallet(wallet) }
                }
            }
            ShieldManager.shared.unlock(minutes: minutes)
            // Manual = fixed window, not drawn from the child's earned/banked pool.
            ProgressStore.shared.startUnlock(minutes: minutes, manual: true, leaseID: leaseID,
                                             leaseKind: "grant")
            Haptic.success()
        }
    }

    /// Disconnect THIS device and return it to a just-installed state. CRITICAL:
    /// it must NOT push anything to the cloud (no `resetAll` — that bumps the
    /// revision and would wipe the child's cloud progress that other devices still
    /// need). So: stop sync, wipe LOCAL data only, drop the binding → RolePicker.
    func resetAsRemovedDevice() {
        #if canImport(FirebaseFirestore)
        TofyLink("resetAsRemovedDevice() — wiping LOCAL cache, dropping binding \(ParentSettings.shared.joinedChildID ?? "nil"). Cloud is NOT touched.")
        RemoteSyncManager.shared.stop()          // no uploads/listeners → cloud safe
        ownDeviceListener?.remove(); ownDeviceListener = nil
        let s = ParentSettings.shared
        if let cid = s.joinedChildID {           // clean up our own (tombstoned) row
            db.collection("childDevices").document("\(cid)_\(DeviceIdentity.installID)").delete()
        }
        DataExporter.wipeLocalData()             // local cache only — never the cloud
        s.pendingJoinPayload = nil
        s.joinedChildID = nil
        // Stay a CHILD device → the reconnect (scan) screen, NEVER the role picker.
        // A removed child device must not be able to silently become a parent (which
        // would expose the parent control center on a kid's iPad). `justDisconnected`
        // also hides the "back to role choice" escape on the join screen.
        s.deviceRole = .child
        s.justDisconnected = true
        s.sessionUnlocked = false   // re-lock the parent gate after a disconnect
        #endif
    }

    /// Full reset of THIS device only: sign out, wipe the local cache + the parent
    /// code (Keychain), drop the binding → RolePicker — WITHOUT deleting the cloud
    /// family (sign back in to restore). For "start this device over" without
    /// nuking everyone, unlike `deleteEverything()`.
    /// Leave every household this device's account belongs to, and drop its
    /// device rows — while still signed in, because after signing out we have no
    /// permission to clean up after ourselves.
    ///
    /// Without this, dropping the session on reinstall only fixes THIS device:
    /// the account stays listed in the family's `parentUIDs` and its device rows
    /// linger, so the family keeps showing a member that no longer exists.
    func leaveAllHouseholdsForThisAccount() async {
        #if canImport(FirebaseFirestore)
        guard let uid else { return }
        do {
            let mine = try await db.collection("households")
                .whereField("parentUIDs", arrayContains: uid).getDocuments()
            for doc in mine.documents {
                try? await doc.reference.updateData([
                    "parentUIDs": FieldValue.arrayRemove([uid]),
                ])
                TofyLink("left household \(doc.documentID.prefix(8)) on reinstall")
            }
            // …and this install's own device rows, child and parent alike.
            let rows = try await db.collection("childDevices")
                .whereField("deviceID", isEqualTo: DeviceIdentity.installID).getDocuments()
            for r in rows.documents { try? await r.reference.delete() }
        } catch {
            TofyLink("leaveAllHouseholdsForThisAccount failed: \(error.localizedDescription)")
        }
        #endif
    }

    func resetThisDevice() {
        let s = ParentSettings.shared
        #if canImport(FirebaseFirestore)
        if let cid = s.joinedChildID {           // remove our own child-device row
            db.collection("childDevices").document("\(cid)_\(DeviceIdentity.installID)").delete()
        }
        #endif
        ownDeviceListener?.remove(); ownDeviceListener = nil
        AuthManager.shared.signOut()             // stops sync + clears the session
        DataExporter.wipeLocalData()             // local cache only — cloud untouched
        ProgressStore.shared.resetAll()          // wipe in-memory stars/diamonds/minutes (post sign-out → no cloud push)
        PINManager.shared.deletePIN()            // erase the parent code from the Keychain
        s.hasSetParentPIN = false
        s.faceIDForParentGate = false
        s.pendingJoinPayload = nil
        s.joinedChildID = nil
        s.justDisconnected = false
        // A FULL reset → the device must look brand-new on next launch: re-lock the
        // parent gate (security: it previously stayed unlocked across a reset), and
        // replay onboarding (welcome + consent) so re-signing-in starts clean.
        s.sessionUnlocked = false
        s.hasSeenWelcome = false
        s.consentVersionAccepted = 0
        s.deviceRole = .unset                    // → "who uses this device?"
    }

    func stopWatchingInviteRedemption() {
        #if canImport(FirebaseFirestore)
        inviteWatchListener?.remove()
        inviteWatchListener = nil
        #endif
        redeemedInviteCode = nil
    }

    /// Joins the household behind `code`. Returns true on success.
    ///
    /// `bringLocalChildren`: when true (a co-parent joining), this device's local
    /// child profiles are pushed into the joined household — so the co-parent
    /// brings their kids along. A CHILD play-device must pass FALSE: it only binds
    /// to ONE existing child, and uploading its local throwaway profile would
    /// create a phantom new child in the family.
    /// Look up an invite WITHOUT redeeming it — so the UI can detect whether a
    /// scanned/typed code is a CHILD-join code (`childID != nil`) or a CO-PARENT
    /// family code, and confirm the right action before changing anything.
    func inspectInvite(code: String) async -> Invite? {
        #if canImport(FirebaseFirestore)
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty,
              let doc = try? await db.collection("invites").document(trimmed).getDocument(),
              let data = doc.data() else { return nil }
        return Self.decodeInvite(id: trimmed, data)
        #else
        return nil
        #endif
    }

    func redeemInvite(code: String, bringLocalChildren: Bool = true) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard let uid else { return false }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        do {
            let doc = try await db.collection("invites").document(trimmed).getDocument()
            guard let data = doc.data(), let invite = Self.decodeInvite(id: trimmed, data) else {
                lastError = "קוד לא נמצא"; return false
            }
            guard !invite.isExpired else { lastError = "הקוד פג תוקף"; return false }
            // Surface the bound child (if this is a per-child code) so a typed code
            // binds the device to the right kid, not just a scanned QR.
            redeemedInviteChildID = invite.childID
            // Add me to the household + mark invite redeemed.
            try await db.collection("households").document(invite.householdID)
                .updateData(["parentUIDs": FieldValue.arrayUnion([uid])])
            try await parentRef(uid).updateData(["householdIDs": FieldValue.arrayUnion([invite.householdID])])
            try await db.collection("invites").document(trimmed).updateData(["redeemedBy": uid])

            // Bring MY children into the joined household, so whoever scans the
            // code brings their kids with them (works for absorbing a child who
            // registered separately, and for co-parents). setData(merge) creates
            // the doc if it was never synced before.
            //
            // SKIPPED for a child play-device (bringLocalChildren == false): it
            // only binds to one EXISTING child, so uploading its local profiles
            // would spawn phantom new kids in the family.
            if bringLocalChildren {
                var movedIDs: [String] = []
                for p in ProfileStore.shared.profiles {
                    let id = p.id.uuidString
                    // SAFETY: never hijack a child that ALREADY belongs to a
                    // DIFFERENT household. Moving such a child merges two separate
                    // families into one — the bug that tangled multiple families
                    // (parents seeing each other's kids; a child stops syncing once
                    // its householdID is rewritten out from under its own family).
                    // Only bring children that are new / unbound / already ours.
                    if let existing = try? await db.collection("children").document(id).getDocument(),
                       let existingHH = existing.data()?["householdID"] as? String,
                       !existingHH.isEmpty, existingHH != invite.householdID {
                        print("[Household] skip bringing child \(id): already bound to \(existingHH)")
                        continue
                    }
                    movedIDs.append(id)
                    let record = ChildRecord(profile: p, householdID: invite.householdID)
                    try? await db.collection("children").document(id)
                        .setData(Self.encode(record), merge: true)
                }
                if !movedIDs.isEmpty {
                    try? await db.collection("households").document(invite.householdID)
                        .updateData(["childIDs": FieldValue.arrayUnion(movedIDs)])
                }
            }

            // Adopt the joined household as my canonical one + switch listeners.
            UserDefaults.standard.set(invite.householdID, forKey: preferredHouseholdKey)
            let hhDoc = try await db.collection("households").document(invite.householdID).getDocument()
            if let hhData = hhDoc.data(), let hh = Self.decodeHousehold(id: invite.householdID, hhData) {
                self.household = hh
                listenToHousehold(hh.id)
                listenToChildren(in: hh.id); listenToChildDevices(in: hh.id)
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

    // MARK: - Child linking by email (parent claims an independently-registered child)

    #if canImport(FirebaseFirestore)
    /// Child side: watch for a parent's pending request to absorb my profiles.
    private func listenForIncomingChildLinks() {
        guard let email else { return }
        childLinkListener?.remove()
        childLinkListener = db.collection("childLinkRequests")
            .whereField("toEmail", isEqualTo: email)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                let reqs = snap.documents.compactMap {
                    Self.decodeChildLink(id: $0.documentID, $0.data())
                }
                self.pendingChildLink = reqs.first
            }
    }

    /// Parent side: watch the status of requests I've sent (pending/approved).
    private func listenForSentChildLinks() {
        guard let uid else { return }
        sentChildLinkListener?.remove()
        sentChildLinkListener = db.collection("childLinkRequests")
            .whereField("fromParentUID", isEqualTo: uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                self.sentChildLinks = snap.documents
                    .compactMap { Self.decodeChildLink(id: $0.documentID, $0.data()) }
                    .sorted { $0.createdAt > $1.createdAt }
            }
    }
    #endif

    /// Parent side: ask to link a child who registered with their own email.
    /// The child must approve on their device. Returns true if the request was
    /// created.
    @discardableResult
    func requestChildLink(childEmail: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard let hh = household, let uid else {
            lastError = "צריך להיות מחובר עם חשבון כדי לצרף ילד/ה (בדקו את הסנכרון)."
            return false
        }
        let target = childEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard target.contains("@"), target.count >= 5 else {
            lastError = "אנא הזינו כתובת אימייל תקינה"; return false
        }
        guard target != email else { lastError = "זה האימייל שלך 🙂"; return false }
        let name = parentAccount?.displayName ?? parentAccount?.email ?? email ?? "הוֹרֶה"
        do {
            // Clean up any earlier requests from me to this email so "resend"
            // doesn't pile up duplicate rows — then create one fresh request.
            let existing = try await db.collection("childLinkRequests")
                .whereField("fromParentUID", isEqualTo: uid)
                .whereField("toEmail", isEqualTo: target)
                .getDocuments()
            for doc in existing.documents { try? await doc.reference.delete() }

            let req = ChildLinkRequest(fromHouseholdID: hh.id, fromParentUID: uid,
                                       fromParentName: name, toEmail: target)
            try await db.collection("childLinkRequests").document(req.id).setData(Self.encode(req))
            return true
        } catch { lastError = error.localizedDescription; return false }
        #else
        return false
        #endif
    }

    /// Child side: approve the pending request — join the parent's household and
    /// move my profiles into it, so the parent can see & manage them.
    @discardableResult
    func approveChildLink() async -> Bool {
        #if canImport(FirebaseFirestore)
        guard let req = pendingChildLink, let uid else { return false }
        do {
            // 1) Join the parent's household (so I'm allowed to write into it).
            try await db.collection("households").document(req.fromHouseholdID)
                .updateData(["parentUIDs": FieldValue.arrayUnion([uid])])
            // 2) Move my children into the parent's household. Use setData(merge)
            // with the FULL record so it works whether the child doc already
            // exists (move it) or was never synced before (create it there) —
            // updateData would silently fail on a missing doc.
            let profiles = ProfileStore.shared.profiles
            var childIDs: [String] = []
            for p in profiles {
                let id = p.id.uuidString
                // Never move a TOMBSTONED (deleted) child into the new family —
                // the whole-roster push was the second resurrection path for
                // duplicate children. Skip and log instead.
                if let tomb = try? await db.collection("deletedChildren").document(id).getDocument(),
                   tomb.exists {
                    TofyLink("approveChildLink: SKIP tombstoned child \(id.prefix(8))")
                    continue
                }
                childIDs.append(id)
                let record = ChildRecord(profile: p, householdID: req.fromHouseholdID)
                try await db.collection("children").document(id)
                    .setData(Self.encode(record), merge: true)
            }
            if !childIDs.isEmpty {
                try await db.collection("households").document(req.fromHouseholdID)
                    .updateData(["childIDs": FieldValue.arrayUnion(childIDs)])
            }
            // 3) Mark the request approved + adopt the parent's household as mine.
            try await db.collection("childLinkRequests").document(req.id)
                .updateData(["status": "approved"])
            try await parentRef(uid).updateData(["householdIDs": FieldValue.arrayUnion([req.fromHouseholdID])])
            UserDefaults.standard.set(req.fromHouseholdID, forKey: preferredHouseholdKey)
            // 4) Re-point my listeners at the shared household.
            let hhDoc = try await db.collection("households").document(req.fromHouseholdID).getDocument()
            if let data = hhDoc.data(), let hh = Self.decodeHousehold(id: req.fromHouseholdID, data) {
                self.household = hh
                listenToHousehold(hh.id)
                listenToChildren(in: hh.id); listenToChildDevices(in: hh.id)
            }
            self.pendingChildLink = nil
            return true
        } catch { lastError = error.localizedDescription; return false }
        #else
        return false
        #endif
    }

    /// Child side: dismiss/decline the pending request.
    func declineChildLink() async {
        #if canImport(FirebaseFirestore)
        guard let req = pendingChildLink else { return }
        try? await db.collection("childLinkRequests").document(req.id)
            .updateData(["status": "declined"])
        #endif
        pendingChildLink = nil
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
                // Public leaderboard card (a CHILD's name lives here — must not
                // linger after a full account deletion, GDPR + Kids Category).
                // BEFORE the parent doc: the card's delete rule gates on the
                // child's householdID, so the `children/{id}` doc must still exist.
                try? await db.collection("friendCards").document(childID).delete()
                try? await db.collection("children").document(childID).delete()
                // This child's device rows (device names + FCM tokens).
                let devs = try? await db.collection("childDevices")
                    .whereField("childID", isEqualTo: childID).getDocuments()
                for d in devs?.documents ?? [] { try? await d.reference.delete() }
            }
            // Family chores + earnings ledger.
            try? await deleteSubcollection("households/\(hh.id)/chores")
            try? await deleteSubcollection("households/\(hh.id)/choreStats")
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
        // Sanitize FIRST: JSONSerialization raises an uncatchable ObjC exception on
        // a non-JSON value (e.g. a Firestore Timestamp / FieldValue), which crashes
        // the app. jsonSafe() converts Timestamps to epoch seconds and drops any
        // other unsupported type.
        let safe = jsonSafe(raw)
        guard let data = try? JSONSerialization.data(withJSONObject: safe),
              let value = try? JSONDecoder.firestore.decode(T.self, from: data) else { return nil }
        return value
    }

    /// Make a Firestore dictionary safe for `JSONSerialization` — Timestamps →
    /// epoch seconds (matches `JSONDecoder.firestore`), nested containers recursed,
    /// and any other non-JSON value dropped.
    private static func jsonSafe(_ value: Any) -> Any? {
        #if canImport(FirebaseFirestore)
        if let ts = value as? Timestamp { return ts.dateValue().timeIntervalSince1970 }
        #endif
        switch value {
        case let dict as [String: Any]:
            var out: [String: Any] = [:]
            for (k, v) in dict { if let s = jsonSafe(v) { out[k] = s } }
            return out
        case let arr as [Any]:
            return arr.compactMap { jsonSafe($0) }
        case is String, is NSNull, is Bool, is Int, is Double, is NSNumber:
            return value
        default:
            return nil   // drop FieldValue sentinels / unknown Firestore types
        }
    }
    /// 💎 True when the FAMILY holds premium (written by the paying device),
    /// independent of this device's own Apple ID / StoreKit.
    var householdPremiumActive: Bool {
        guard let until = household?.premiumUntil else { return false }
        return until > Date()
    }

    /// Publish premium to the family doc so every bound device unlocks it.
    /// `until` = expiry (far-future for lifetime); nil clears it. Only writes
    /// when the value actually changes, and only from a household member.
    func publishPremium(until: Date?) {
        #if canImport(FirebaseFirestore)
        guard !Self.skipsCloudSync, let hh = household?.id else { return }
        // The rules require a NON-anonymous account to change premiumUntil (a
        // child device must not grant itself paid premium). On an anonymous
        // device the write is denied and the self-heal is futile (it IS a
        // member — anonymity is the block), so skip it: a real parent device
        // holding the same entitlement republishes on its next refresh.
        guard AuthManager.shared.isRealAccount else { return }
        let current = household?.premiumUntil
        // Never DOWNGRADE from the cloud on a transient local read: only write
        // when extending/among-equal or clearing after a real lapse we detect.
        if let until {
            if let current, current >= until { return }   // cloud already >= ours
            let ref = db.collection("households").document(hh)
            Task {
                // Confirm + self-heal: a paid family whose device uid drifted out
                // of parentUIDs would otherwise silently fail to broadcast
                // premium, leaving co-parent/child devices locked after payment.
                var outcome = await confirmedMerge(ref, ["premiumUntil": until.timeIntervalSince1970])
                if outcome == .denied {
                    await self.reassertMembership()
                    outcome = await confirmedMerge(ref, ["premiumUntil": until.timeIntervalSince1970])
                }
            }
        }
        #endif
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
    private static func decodeChildLink(id: String, _ raw: [String: Any]) -> ChildLinkRequest? {
        var r = raw; r["id"] = id; return decode(ChildLinkRequest.self, r)
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
