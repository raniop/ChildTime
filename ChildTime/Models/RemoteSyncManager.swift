import Foundation
import Combine
import os

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Lightweight, always-on logging for the cross-device sync path. Visible in
/// Console.app / Xcode by filtering the "ChildTime" subsystem, "sync" category —
/// the fastest way to confirm on a real device whether sync is actually running
/// (e.g. "no signed-in user" means Anonymous Auth is off in the Firebase console).
enum SyncLog {
    private static let logger = Logger(subsystem: "ChildTime", category: "sync")
    static func log(_ message: String) { logger.notice("\(message, privacy: .public)") }
    static func error(_ message: String) { logger.error("\(message, privacy: .public)") }
}

/// Cross-device sync layer for per-profile progress snapshots.
///
/// Topology (when the parent is signed in via Firebase Auth):
///   `users/{uid}/profiles/{profileID}/state` ← live document
///
/// Each device:
///   • Uploads its captured `ProgressSnapshot` whenever it changes
///     (debounced through the same path the Vault uses for local saves).
///   • Listens to *all* of the user's profile docs and merges newer
///     remote snapshots back into local state.
///
/// 'Newer' is decided by `revision`, then `lastModifiedAt`. The
/// `deviceID` field lets us skip echoes of our own writes.
///
/// Without FirebaseFirestore in the build (e.g. SDK not added yet),
/// every method is a no-op so the app still compiles and runs.
@MainActor
final class RemoteSyncManager: ObservableObject {
    static let shared = RemoteSyncManager()

    @Published private(set) var isActive = false
    @Published private(set) var lastUploadAt: Date? = nil
    @Published private(set) var lastError: String? = nil
    /// Snapshots pulled from Firestore for non-active profiles, keyed by
    /// profile UUID. The dashboard merges these in.
    @Published private(set) var remoteSnapshots: [UUID: ProgressSnapshot] = [:]
    /// Parent minute grants still WAITING to be applied on the child's device,
    /// keyed by child UUID (the `pendingMinuteAdjustment` field on the child doc).
    /// The dashboard adds this to the shown balance so a +10/-5 reflects instantly
    /// and doesn't "revert" while it's in flight.
    @Published private(set) var pendingAdjustments: [UUID: Int] = [:]

    private var cancellables: Set<AnyCancellable> = []
    private var saveDebounce: Task<Void, Never>? = nil
    private var applyingGrant = false

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listeners: [String: ListenerRegistration] = [:]   // keyed by profileID
    private var childDocListeners: [String: ListenerRegistration] = [:]   // child doc (for minute grants)
    #endif

    private init() {}

    // MARK: - Public lifecycle

    /// Start syncing for the currently-signed-in parent. Idempotent.
    ///
    /// Pass `explicitUID` when calling from inside `AuthManager` so we
    /// don't reach back into `AuthManager.shared` while *that* singleton
    /// is still inside its own dispatch_once init. Without the explicit
    /// uid we deadlock the launcher with EXC_BREAKPOINT.
    func start(uid explicitUID: String? = nil) {
        #if canImport(FirebaseFirestore)
        let resolvedUID: String
        if let explicitUID, !explicitUID.isEmpty {
            resolvedUID = explicitUID
        } else if let cached = AuthManager.shared.userID, !cached.isEmpty {
            resolvedUID = cached
        } else {
            lastError = "אין משתמש מחובר — סנכרון לא פעיל"
            isActive = false
            SyncLog.error("start: NO signed-in user — sync inactive. If this is a child device, enable Anonymous Auth in the Firebase console.")
            return
        }
        isActive = true
        lastError = nil
        SyncLog.log("start: active uid=\(resolvedUID.prefix(6))… role=\(ParentSettings.shared.deviceRole) device=\(ProgressSnapshot.thisDeviceID.prefix(8))")
        observeLocalChanges()
        subscribeToAllProfiles(uid: resolvedUID)
        // First push of the active profile's current state so the cloud
        // mirrors what's on disk.
        uploadActiveProfileSoon()
        #else
        lastError = "Firebase Firestore לא הותקן"
        isActive = false
        #endif
    }

    /// Tear down on sign-out.
    func stop() {
        cancellables.removeAll()
        saveDebounce?.cancel()
        saveDebounce = nil
        #if canImport(FirebaseFirestore)
        for (_, listener) in listeners { listener.remove() }
        listeners.removeAll()
        #endif
        isActive = false
        remoteSnapshots = [:]
    }

    /// Force-write the current active profile's snapshot now (used after
    /// the parent taps reset, so the kid's other device sees it fast).
    func pushNow() {
        #if canImport(FirebaseFirestore)
        uploadActiveProfile()
        #endif
    }

    /// One-shot fetch of a child's current cloud snapshot — used by Kid Mode to
    /// force-load the child's real progress before handing them the phone, even
    /// if the live listeners never ran or the cache is stale.
    func fetchSnapshot(for childID: UUID) async -> ProgressSnapshot? {
        #if canImport(FirebaseFirestore)
        guard AuthManager.shared.isSignedIn else {
            TofyLink("fetchSnapshot(\(childID.uuidString.prefix(8))): NOT signed in → nil")
            return nil
        }
        let doc = try? await db.collection("children").document(childID.uuidString)
            .collection("state").document("current").getDocument()
        guard let raw = doc?.data() else {
            TofyLink("fetchSnapshot(\(childID.uuidString.prefix(8))): NO cloud state/current doc (empty/deleted) → nil")
            return nil
        }
        let snap = Self.decode(raw)
        TofyLink("fetchSnapshot(\(childID.uuidString.prefix(8))): cloud has stars=\(snap?.stars ?? -1) diamonds=\(snap?.diamonds ?? -1) min=\(snap?.pendingMinutes ?? -1) rev=\(snap?.revision ?? -1)")
        if let snap { handleRemoteSnapshot(snap, profileID: childID) }
        return snap
        #else
        return nil
        #endif
    }

    /// Parent action: grant/spend a child's play-minutes by editing the CLOUD
    /// snapshot directly, in a transaction that BUMPS the revision so the child's
    /// device accepts it (a stale local push from the parent would otherwise lose
    /// the revision race and be ignored). Works for ANY child, active or not.
    /// A parent's +10 / −5 minute control. Writes a DELTA COMMAND
    /// (`pendingMinuteAdjustment += delta`, atomic) onto the child doc rather than
    /// editing the live `state/current` snapshot. Editing the snapshot raced the
    /// child device's fast-churning `revision` (it bumps on every play tick), so
    /// the child's next upload reverted the parent's change — the adjustment
    /// "didn't work". The child's device consumes this command additively
    /// (`applyPendingMinuteGrant`), so grants always land and even compose, and
    /// nothing else (stars / diamonds) is touched.
    func adjustChildMinutes(childID: UUID, deltaMinutes: Int) {
        #if canImport(FirebaseFirestore)
        // Optimistic local bump so the parent sees it immediately (reconciles when
        // the child device applies it and `pendingMinuteAdjustment` returns to 0).
        pendingAdjustments[childID, default: 0] += deltaMinutes
        db.collection("children").document(childID.uuidString)
            .setData(["pendingMinuteAdjustment": FieldValue.increment(Int64(deltaMinutes))], merge: true)
        #endif
    }

    /// PARENT: reset a child's progress everywhere.
    ///
    /// Why not just push a blank snapshot? Uploads are RATCHET-merged (they can
    /// only ever raise accumulators — the guard against stale pushes wiping
    /// real progress), so a blank push from the parent is silently discarded,
    /// and the parent's dashboard (which prefers the cloud) never changes.
    /// That's exactly the "reset does nothing" symptom.
    ///
    /// So a reset is a COMMAND on the child doc (like ±minutes): the child's own
    /// device consumes `resetRequestedAt`, wipes its live store (revision-bumped)
    /// and pushes the blank up — the one writer allowed to lower the cloud. And
    /// so the parent isn't left staring at stale numbers meanwhile, we ALSO
    /// overwrite the cloud `state/current` doc directly here (a plain set, not a
    /// ratchet), stamped as a fresh higher revision. Together: instant on the
    /// parent, durable on the child even if it was offline when the reset ran.
    func resetChildProgress(childID: UUID) {
        #if canImport(FirebaseFirestore)
        let id = childID.uuidString
        // 1. Command for the child's device (works even if it's offline now).
        db.collection("children").document(id)
            .setData(["resetRequestedAt": FieldValue.serverTimestamp()], merge: true)
        // 2. Immediate cloud state overwrite so every monitor shows zeros now.
        let ref = db.collection("children").document(id)
            .collection("state").document("current")
        db.runTransaction({ txn, _ -> Any? in
            let cloudRev = (try? txn.getDocument(ref))?.data()
                .flatMap({ Self.decode($0) })?.revision ?? 0
            var blank = ProgressSnapshot.blank
            blank.revision = cloudRev + 1
            blank.lastModifiedAt = Date()
            blank.deviceID = ProgressSnapshot.thisDeviceID
            if let data = Self.encode(blank) { txn.setData(data, forDocument: ref) }   // NOT merge — a real wipe
            return nil
        }) { _, err in
            if let err { TofyLink("resetChildProgress cloud wipe FAILED: \(err.localizedDescription)") }
        }
        // 3. Local mirror so the dashboard row flips instantly (before the
        //    listener echoes the wipe back).
        var blank = ProgressSnapshot.blank
        blank.revision = (remoteSnapshots[childID]?.revision ?? 0) + 1
        blank.lastModifiedAt = Date()
        remoteSnapshots[childID] = blank
        pendingAdjustments.removeValue(forKey: childID)
        #endif
    }

    /// CHILD device: a parent asked to reset THIS child. Consume the command
    /// exactly once (read + clear in a transaction), then wipe the live store
    /// and push the blank state up.
    private func applyPendingReset(childID: UUID) {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("children").document(childID.uuidString)
        db.runTransaction({ txn, _ -> Any? in
            let doc = try? txn.getDocument(ref)
            let requested = doc?.data()?["resetRequestedAt"] != nil
            if requested { txn.updateData(["resetRequestedAt": FieldValue.delete()], forDocument: ref) }
            return requested
        }) { [weak self] result, _ in
            guard (result as? Bool) == true else { return }
            Task { @MainActor in
                TofyLink("applyPendingReset: parent reset for \(childID.uuidString.prefix(8)) → wiping local + pushing")
                ProgressVault.shared.resetProfile(childID)
                self?.pushNow()
            }
        }
        #endif
    }

    /// CHILD device: consume any parent minute grant on this child's doc exactly
    /// once. Reads + zeroes `pendingMinuteAdjustment` in a transaction (so two
    /// devices can't double-apply), then adds it to the live balance.
    private func applyPendingMinuteGrant(childID: UUID) {
        #if canImport(FirebaseFirestore)
        guard !applyingGrant else { return }
        applyingGrant = true
        let ref = db.collection("children").document(childID.uuidString)
        db.runTransaction({ txn, _ -> Any? in
            let doc = try? txn.getDocument(ref)
            let adj = (doc?.data()?["pendingMinuteAdjustment"] as? Int) ?? 0
            if adj != 0 { txn.updateData(["pendingMinuteAdjustment": 0], forDocument: ref) }
            return adj
        }) { [weak self] result, _ in
            self?.applyingGrant = false
            let adj = (result as? Int) ?? 0
            if adj != 0 { ProgressStore.shared.addPendingMinutes(adj) }
        }
        #endif
    }

    /// Force an immediate re-fetch of every child's cloud state (used by the
    /// parent's "refresh" button). Also re-ensures the live listeners are
    /// attached, in case they were dropped.
    func refreshNow() {
        #if canImport(FirebaseFirestore)
        refreshProfileSubscriptions()
        for profile in ProfileStore.shared.profiles {
            let id = profile.id.uuidString
            db.collection("children").document(id)
              .collection("state").document("current")
              .getDocument { [weak self] doc, _ in
                  guard let raw = doc?.data(), let snap = Self.decode(raw) else { return }
                  self?.handleRemoteSnapshot(snap, profileID: profile.id)
              }
        }
        #endif
    }

    // MARK: - Local change observation

    private func observeLocalChanges() {
        cancellables.removeAll()
        let store = ProgressStore.shared
        let triggers: [AnyPublisher<Void, Never>] = [
            store.$pendingMinutes.map { _ in () }.eraseToAnyPublisher(),
            store.$totalScore.map { _ in () }.eraseToAnyPublisher(),
            store.$stars.map { _ in () }.eraseToAnyPublisher(),
            store.$diamonds.map { _ in () }.eraseToAnyPublisher(),
            store.$unlockEndsAt.map { _ in () }.eraseToAnyPublisher(),
            store.$minutesEarnedToday.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(triggers)
            .dropFirst()
            .sink { [weak self] _ in self?.uploadActiveProfileSoon() }
            .store(in: &cancellables)
    }

    // MARK: - Upload (debounced ~3s)

    private func uploadActiveProfileSoon() {
        // The parent control-center device is a MONITOR — it must never push its
        // own (empty) local state, or it clobbers the child's real cloud data
        // with zeros. Explicit parent actions (reset / ±minutes) still go through
        // pushNow() → uploadActiveProfile().
        // EXCEPTION: in Kid Mode the parent's phone IS the child's session, so it
        // must upload the child's real play (otherwise it never syncs back).
        guard ParentSettings.shared.deviceRole != .parent || KidModeManager.shared.active else { return }
        saveDebounce?.cancel()
        saveDebounce = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.uploadActiveProfile()
        }
    }

    #if canImport(FirebaseFirestore)
    private func uploadActiveProfile() {
        guard let pid = ProfileStore.shared.activeID else { return }
        // Capture local state on the calling (main) thread, then MERGE it into the
        // cloud doc inside a transaction. A plain setData(merge:) was a BLIND
        // overwrite — a stale local push (e.g. the `pushNow()` on launch, before
        // the listener delivered the cloud state) could clobber a HIGHER cloud
        // value with a lower local one (this is how a restored 4100★ could drop
        // back to a device's local 153★). Ratchet-merging with the cloud means an
        // upload can only ever raise accumulators, never lower them.
        let local = ProgressStore.shared.captureSnapshot()
        let ref = db.collection("children").document(pid.uuidString)
            .collection("state").document("current")
        db.runTransaction({ txn, _ -> Any? in
            guard let cloud = (try? txn.getDocument(ref))?.data().flatMap({ Self.decode($0) }) else {
                // No cloud doc yet → first write is just our local state.
                if let data = Self.encode(local) { txn.setData(data, forDocument: ref, merge: true) }
                return nil
            }
            var merged = ProgressSnapshot.ratchetMerged(local: local, remote: cloud)
            // Cloud already holds everything we have → don't write (no churn, and
            // never lowers the cloud with a stale push).
            if ProgressSnapshot.sameProgressData(merged, cloud) { return nil }
            merged.revision = max(local.revision, cloud.revision) + 1
            merged.lastModifiedAt = Date()
            merged.deviceID = ProgressSnapshot.thisDeviceID
            if let data = Self.encode(merged) { txn.setData(data, forDocument: ref, merge: true) }
            return nil
        }) { [weak self] _, err in
            if let err {
                self?.lastError = err.localizedDescription
                SyncLog.error("upload FAILED for \(pid.uuidString.prefix(8)): \(err.localizedDescription)")
            } else {
                self?.lastUploadAt = .now
                self?.lastError = nil
                SyncLog.log("upload OK (merge) for \(pid.uuidString.prefix(8)) stars=\(local.stars) min=\(local.pendingMinutes)")
            }
        }
    }
    #endif

    // MARK: - Listeners (per profile)

    #if canImport(FirebaseFirestore)
    private func subscribeToAllProfiles(uid: String) {
        // React when the local roster of children changes (e.g. a co-parent's
        // child arrives via the household listener) by re-subscribing.
        ProfileStore.shared.$profiles
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshProfileSubscriptions() }
            .store(in: &cancellables)
        refreshProfileSubscriptions()
    }

    private func refreshProfileSubscriptions() {
        // Drop listeners for children we no longer have locally.
        let localIDs = Set(ProfileStore.shared.profiles.map { $0.id.uuidString })
        for (id, listener) in listeners where !localIDs.contains(id) {
            listener.remove()
            listeners.removeValue(forKey: id)
            childDocListeners[id]?.remove()
            childDocListeners.removeValue(forKey: id)
            if let uuid = UUID(uuidString: id) {
                remoteSnapshots.removeValue(forKey: uuid)
                pendingAdjustments.removeValue(forKey: uuid)
            }
        }
        // Add listeners for new ones — household-owned `children` docs.
        for profile in ProfileStore.shared.profiles {
            let id = profile.id.uuidString
            if listeners[id] != nil { continue }
            let listener = db.collection("children").document(id)
                .collection("state").document("current")
                .addSnapshotListener { [weak self] doc, _ in
                    guard let self, let doc, let raw = doc.data() else { return }
                    guard let snap = Self.decode(raw) else { return }
                    self.handleRemoteSnapshot(snap, profileID: profile.id)
                }
            listeners[id] = listener

            // Watch the child DOC for parent minute grants (pendingMinuteAdjustment):
            // surface it for the parent's display, and — on THIS child's own play
            // device — consume it additively.
            childDocListeners[id] = db.collection("children").document(id)
                .addSnapshotListener { [weak self] doc, _ in
                    guard let self else { return }
                    let adj = (doc?.data()?["pendingMinuteAdjustment"] as? Int) ?? 0
                    Task { @MainActor in
                        if adj != 0 { self.pendingAdjustments[profile.id] = adj }
                        else { self.pendingAdjustments.removeValue(forKey: profile.id) }
                    }
                    // Consume the grant on whatever device is currently BEING this
                    // child: its own bound play device, or the parent's phone while
                    // it's in Kid Mode for this child. The read+zero transaction
                    // guarantees it's applied exactly once even if both are open.
                    let s = ParentSettings.shared
                    let isBoundChildDevice = s.deviceRole == .child && s.joinedChildID == id
                    let isKidModeForThis = KidModeManager.shared.active
                        && KidModeManager.shared.childID?.uuidString == id
                    if adj != 0 && (isBoundChildDevice || isKidModeForThis) {
                        self.applyPendingMinuteGrant(childID: profile.id)
                    }
                    // A parent's "reset progress" — consumed the same way, by the
                    // device that IS this child right now.
                    let resetRequested = doc?.data()?["resetRequestedAt"] != nil
                    if resetRequested && (isBoundChildDevice || isKidModeForThis) {
                        self.applyPendingReset(childID: profile.id)
                    }
                }
        }
    }

    private func handleRemoteSnapshot(_ snap: ProgressSnapshot, profileID: UUID) {
        let isActive = profileID == ProfileStore.shared.activeID
        let ownEcho = snap.deviceID == ProgressSnapshot.thisDeviceID
        TofyLink("remoteSnapshot in: child=\(profileID.uuidString.prefix(8)) active=\(isActive) ownEcho=\(ownEcho) stars=\(snap.stars) diamonds=\(snap.diamonds) min=\(snap.pendingMinutes) rev=\(snap.revision)")
        // Always cache for the dashboard — the parent monitor must reflect the
        // cloud even when THIS device made the last write (e.g. a +minutes
        // grant). Skipping our own writes here is what made the parent's view
        // stop updating after it edited a child.
        remoteSnapshots[profileID] = snap
        // If this is the ACTIVE profile and the remote snapshot is newer
        // than what we have locally, apply it (so a reset on the parent's
        // phone propagates to the kid's iPad in real time).
        guard profileID == ProfileStore.shared.activeID else {
            // For non-active profiles, mirror into the vault so the
            // dashboard reflects the latest cloud state immediately.
            ProgressVault.shared.write(snap, for: profileID)
            return
        }
        // Don't re-apply our OWN echo to the live in-memory store (it would fight
        // local play). Display caching above already happened.
        if snap.deviceID == ProgressSnapshot.thisDeviceID { return }
        // Merge instead of clobber: a plain revision race would discard the
        // losing device's earnings wholesale (the symptom: one device showing
        // 129⭐, the other 75⭐). `mergeRemote` ratchets accumulators up over
        // both, so stars/score/characters converge to the combined best and
        // neither device loses progress. It returns true when WE still held
        // something the remote lacked — push it so the peer converges too.
        let needsUpload = ProgressStore.shared.mergeRemote(snap)
        if needsUpload {
            SyncLog.log("merge: local was ahead — re-uploading merged snapshot for \(profileID.uuidString.prefix(8))")
            uploadActiveProfile()
        }
    }
    #endif

    // MARK: - Encode / decode (Firestore-friendly)

    private static func encode(_ snap: ProgressSnapshot) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(snap),
              let any = try? JSONSerialization.jsonObject(with: data),
              let dict = any as? [String: Any]
        else { return nil }
        return dict
    }

    private static func decode(_ raw: [String: Any]) -> ProgressSnapshot? {
        guard let data = try? JSONSerialization.data(withJSONObject: raw),
              let snap = try? JSONDecoder().decode(ProgressSnapshot.self, from: data)
        else { return nil }
        return snap
    }
}
