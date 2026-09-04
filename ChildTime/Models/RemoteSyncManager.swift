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
    /// 💝 Parent GIFT minutes still in flight to the child's device (the
    /// `pendingGiftAdjustment` field). Shown by the dashboard on top of the
    /// synced gift pocket.
    @Published private(set) var pendingGifts: [UUID: Int] = [:]

    private var cancellables: Set<AnyCancellable> = []
    private var saveDebounce: Task<Void, Never>? = nil

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
        // Demo / screenshot / automated-test runs must never upload snapshots
        // to (or listen against) production — same kill-switch as HouseholdManager.
        guard !HouseholdManager.skipsCloudSync else {
            SyncLog.log("start: SKIPPED — demo/test run, sync stays local")
            isActive = false
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
        // Also tear down the child-DOC listeners — stop() only removed the
        // state-listeners, so a device that left a family kept listening to its
        // child docs and start() re-added a SECOND listener per child (leak +
        // double command-application attempts).
        for (_, listener) in childDocListeners { listener.remove() }
        childDocListeners.removeAll()
        #endif
        isActive = false
        remoteSnapshots = [:]
        resetPending = [:]
        pendingAdjustments = [:]
        pendingGifts = [:]
        // Command status trackers too — otherwise a stale red "לא נשלח" / gift
        // status from the previous family can bleed across a profile/account
        // switch. In-flight rollback Tasks also bail on !isActive (below).
        commandFailed = []
        giftSendTracker = [:]
        giftRevokeTracker = [:]
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
    /// Children whose last parent→child command was PERMANENTLY rejected
    /// (permission-denied even after a self-heal) — the dashboard shows an
    /// honest error instead of the command silently never landing.
    @Published var commandFailed: Set<UUID> = []

    #if canImport(FirebaseFirestore)
    /// Confirmed write to a child command doc, with the same Noa-class self-heal
    /// the chore path uses: permission-denied → re-assert this device's
    /// household membership and retry ONCE (safe — a denied write never
    /// committed, so a `FieldValue.increment` can't double-count). Returns the
    /// final outcome so the caller can honestly reconcile optimistic UI. Only
    /// `.denied` is retried; `.queued` (offline) is a genuine success (durable).
    private func sendChildCommandConfirmed(_ childID: UUID, _ fields: [String: Any]) async -> ConfirmedWriteOutcome {
        let ref = db.collection("children").document(childID.uuidString)
        var outcome = await confirmedMerge(ref, fields)
        if outcome == .denied {
            await HouseholdManager.shared.reassertMembership()
            outcome = await confirmedMerge(ref, fields)
        }
        return outcome
    }
    #endif

    func adjustChildMinutes(childID: UUID, deltaMinutes: Int) {
        #if canImport(FirebaseFirestore)
        // Optimistic local bump so the parent sees it immediately (reconciles when
        // the child device applies it and `pendingMinuteAdjustment` returns to 0).
        pendingAdjustments[childID, default: 0] += deltaMinutes
        let fields: [String: Any] = ["pendingMinuteAdjustment": FieldValue.increment(Int64(deltaMinutes))]
        Task { @MainActor in
            let outcome = await self.sendChildCommandConfirmed(childID, fields)
            guard self.isActive else { return }   // manager torn down mid-flight — don't touch published state
            // Permanent rejection → roll back the optimistic bump and tell the
            // parent, instead of leaving a +N that will never reach the child.
            if outcome == .denied || outcome == .error {
                // Roll back the exact optimistic contribution — but ONLY if the
                // key still holds it. If the child-doc listener already
                // reconciled (removed or zeroed) the key in the meantime,
                // subtracting would strand a phantom negative pending value.
                if let cur = self.pendingAdjustments[childID], cur != 0 {
                    let restored = cur - deltaMinutes
                    if restored == 0 { self.pendingAdjustments.removeValue(forKey: childID) }
                    else { self.pendingAdjustments[childID] = restored }
                }
                self.commandFailed.insert(childID)
            }
        }
        #endif
    }

    /// 💝 Parent GIVES minutes — into the child's separate GIFT pocket, never the
    /// earned wallet (so "you earned 30" and "mom gave 10" stay distinct). Same
    /// delta-command mechanics as `adjustChildMinutes`, on its own field.
    /// Live status of the last 💝 gift sent per child (same shape as the revoke
    /// tracker): reachedCloud on backend commit, applied when the child's device
    /// echoes `giftSentAt` back as `giftAppliedAt` in the consume transaction.
    @Published var giftSendTracker: [UUID: GiftRevokeTracker] = [:]

    func giftChildMinutes(childID: UUID, minutes: Int) {
        #if canImport(FirebaseFirestore)
        guard minutes != 0 else { return }
        pendingGifts[childID, default: 0] += minutes
        let stamp = Date().timeIntervalSince1970
        giftSendTracker[childID] = GiftRevokeTracker(stamp: stamp, sentAt: Date(),
                                                     reachedCloud: false, appliedAt: nil)
        var fields: [String: Any] = ["pendingGiftAdjustment": FieldValue.increment(Int64(minutes)),
                                     "giftSentAt": stamp]
        if let uid = AuthManager.shared.userID { fields["giftCommandBy"] = uid }
        Task { @MainActor in
            let outcome = await self.sendChildCommandConfirmed(childID, fields)
            guard self.isActive else { return }   // manager torn down mid-flight — don't touch published state
            switch outcome {
            case .ok:
                // Server committed → the gift is SAFE in the cloud.
                self.giftSendTracker[childID]?.reachedCloud = true
            case .queued:
                // Offline but durably queued — the existing "saved, will
                // auto-send" message is now TRUE. Leave the tracker as-is.
                break
            case .denied, .error:
                // Permanent rejection (the Noa-class uid drift, now on a PARENT
                // device) — roll back the optimistic pocket and tell the parent
                // honestly, instead of the old false "saved offline".
                self.pendingGifts[childID, default: 0] -= minutes
                if (self.pendingGifts[childID] ?? 0) <= 0 { self.pendingGifts.removeValue(forKey: childID) }
                self.giftSendTracker[childID]?.failed = true
            }
        }
        #endif
    }

    /// CHILD device: consume a parent's gift command exactly once (read + zero
    /// in a transaction), then add it to the GIFT pocket.
    private func applyPendingGift(childID: UUID) {
        #if canImport(FirebaseFirestore)
        // No in-flight guard: the transaction reads+zeroes atomically, so a second
        // event just finds 0 — whereas a guard could STRAND a fast second "+10".
        let ref = db.collection("children").document(childID.uuidString)
        db.runTransaction({ txn, _ -> Any? in
            let doc = try? txn.getDocument(ref)
            let adj = (doc?.data()?["pendingGiftAdjustment"] as? Int) ?? 0
            if adj != 0 {
                // Consume + ACK atomically: echo the send stamp back as
                // `giftAppliedAt` so the parent's "💝 נשלח" flips to "✅ הגיע"
                // (and a Cloud Function pushes them if it landed late).
                var update: [String: Any] = ["pendingGiftAdjustment": 0]
                if let sentAt = doc?.data()?["giftSentAt"] as? Double {
                    update["giftAppliedAt"] = sentAt
                }
                txn.updateData(update, forDocument: ref)
            }
            return adj
        }) { [weak self] result, _ in
            let adj = (result as? Int) ?? 0
            if adj != 0 { ProgressStore.shared.addParentGiftMinutes(adj) }
        }
        #endif
    }

    /// One-shot sweep of the child DOC's pending parent commands (gift, ±minutes,
    /// reset, gift-revoke). The doc listener consumes commands only on CHANGE
    /// events while this device is already being the child — so a command issued
    /// BEFORE that (parent gives 💝 60, then enters Kid Mode) sat pending
    /// forever. Kid Mode entry calls this to catch up; the read+zero transactions
    /// inside the apply helpers keep everything exactly-once even if the child's
    /// own device consumes concurrently.
    func consumePendingCommandsNow(for childID: UUID) async {
        #if canImport(FirebaseFirestore)
        let s = ParentSettings.shared
        let isBoundChildDevice = s.deviceRole == .child && s.joinedChildID == childID.uuidString
        let isKidModeForThis = KidModeManager.shared.active && KidModeManager.shared.childID == childID
        guard isBoundChildDevice || isKidModeForThis else { return }
        guard let doc = try? await db.collection("children").document(childID.uuidString).getDocument(),
              let d = doc.data() else { return }
        TofyLink("consumePendingCommandsNow: child=\(childID.uuidString.prefix(8)) adj=\(d["pendingMinuteAdjustment"] ?? 0) gift=\(d["pendingGiftAdjustment"] ?? 0) reset=\(d["resetRequestedAt"] != nil) revoke=\(d["revokeGiftAt"] != nil)")
        if ((d["pendingMinuteAdjustment"] as? Int) ?? 0) != 0 { applyPendingMinuteGrant(childID: childID) }
        let revokeRequested = d["revokeGiftAt"] != nil
        if ((d["pendingGiftAdjustment"] as? Int) ?? 0) != 0 && !revokeRequested {
            applyPendingGift(childID: childID)   // else: applied after the revoke
        }
        if d["resetRequestedAt"] != nil { applyPendingReset(childID: childID) }
        if revokeRequested { applyPendingGiftRevoke(childID: childID) }
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
        // 1. Command for the child's device — the AUTHORITATIVE wipe. (A direct
        //    cloud-state overwrite from here RACED the child: if the blank doc
        //    reached the kid before the command, mergeRemote ratchet-maxed stars
        //    back over it and re-uploaded them, and no later push could lower the
        //    cloud again. So: command only; the child wipes + pushes.)
        let fields: [String: Any] = ["resetRequestedAt": Date().timeIntervalSince1970,
                                     "pendingMinuteAdjustment": 0,
                                     "pendingGiftAdjustment": 0]
        // 2. Parent-side mirror: show zeros NOW and keep showing them until the
        //    child's post-reset snapshot arrives (a stale, pre-reset cloud echo
        //    must not flip the tile back). Stash the prior snapshot so a
        //    permanent command rejection can UNDO the fake zeros — the old code
        //    painted zeros for a full 24h even when the reset never went through.
        let prev = remoteSnapshots[childID]
        var blank = ProgressSnapshot.blank
        blank.revision = (prev?.revision ?? 0) + 1
        blank.lastModifiedAt = Date()
        remoteSnapshots[childID] = blank
        // Gate by REVISION (clock skew between devices is real), with a TTL so a
        // child that never comes back can't pin the parent on zeros forever.
        resetPending[childID] = (minRevision: blank.revision, until: Date().addingTimeInterval(24 * 3600))
        pendingAdjustments.removeValue(forKey: childID)
        pendingGifts.removeValue(forKey: childID)
        // 3. Confirm the AUTHORITATIVE command reached the cloud; self-heal a
        //    drifted membership and retry. On a permanent rejection, roll the
        //    optimistic zeros back and tell the parent — never leave fake zeros.
        Task { @MainActor in
            let outcome = await self.sendChildCommandConfirmed(childID, fields)
            guard self.isActive else { return }   // manager torn down mid-flight — don't touch published state
            if outcome == .denied || outcome == .error {
                // Undo the optimistic zeros — but ONLY if nothing newer landed
                // during the confirm window. If the child was actively playing
                // and uploaded a fresher snapshot (revision > blank), restoring
                // the stale `prev` would clobber real current progress.
                if self.remoteSnapshots[childID]?.revision == blank.revision {
                    self.resetPending.removeValue(forKey: childID)
                    self.remoteSnapshots[childID] = prev
                }
                self.commandFailed.insert(childID)
            }
        }
        #endif
    }

    /// Children whose reset command is out but not yet echoed back by the child
    /// device: ignore cloud snapshots BELOW `minRevision` until then (or TTL).
    private var resetPending: [UUID: (minRevision: Int, until: Date)] = [:]

    /// PARENT: "נעל ואפס דקות מתנה" — revoke ALL parent-given time on the child
    /// (gift pocket + frozen leftover + an open parent window). A command on the
    /// child doc, consumed by the device that IS this child (like reset/±). The
    /// lock itself is sent separately via HouseholdManager.lockRemoteScreenTime.
    /// Live status of the last "מחק דקות מתנה" per child, mirroring
    /// HouseholdManager.commandTracker: reachedCloud = the server committed the
    /// command; appliedAt = the child's device acked it (`revokeGiftAppliedAt`).
    struct GiftRevokeTracker: Equatable {
        var stamp: Double
        var sentAt: Date
        var reachedCloud: Bool
        var appliedAt: Double?
        /// The command was PERMANENTLY rejected (permission-denied even after a
        /// membership self-heal) — NOT merely offline. The status UI shows an
        /// honest "try again" instead of the false "saved, will auto-send".
        var failed: Bool = false
        var applied: Bool { (appliedAt ?? 0) >= stamp }
    }
    @Published var giftRevokeTracker: [UUID: GiftRevokeTracker] = [:]

    func revokeChildGift(childID: UUID) {
        #if canImport(FirebaseFirestore)
        let stamp = Date().timeIntervalSince1970
        giftRevokeTracker[childID] = GiftRevokeTracker(stamp: stamp, sentAt: Date(),
                                                       reachedCloud: false, appliedAt: nil)
        // Plain unix-seconds stamp — NOT FieldValue.serverTimestamp(): a
        // FIRTimestamp on the child doc is a known decoding hazard here (see
        // removeChildDevice), and a plain Double is enough for a one-shot command.
        var fields: [String: Any] = ["revokeGiftAt": stamp,
                                     "pendingGiftAdjustment": 0]   // cancel any in-flight "+10"
        if let uid = AuthManager.shared.userID { fields["giftCommandBy"] = uid }
        // Snapshot the pre-revoke gift so a permanent rejection can be undone.
        let prevGiftMinutes = remoteSnapshots[childID]?.parentGiftMinutes
        Task { @MainActor in
            let outcome = await self.sendChildCommandConfirmed(childID, fields)
            guard self.isActive else { return }   // manager torn down mid-flight — don't touch published state
            switch outcome {
            case .ok:
                self.giftRevokeTracker[childID]?.reachedCloud = true
            case .queued:
                break   // durable — will deliver
            case .denied, .error:
                // Undo the optimistic "dropped to 0" — the time was NOT revoked.
                self.giftRevokeTracker[childID]?.failed = true
                if let prevGiftMinutes, var snap = self.remoteSnapshots[childID] {
                    snap.parentGiftMinutes = prevGiftMinutes
                    self.remoteSnapshots[childID] = snap
                }
            }
        }
        // Optimistic local mirror so the parent's 💝 tile drops to 0 at once.
        pendingGifts.removeValue(forKey: childID)
        if var snap = remoteSnapshots[childID] {
            snap.parentGiftMinutes = 0
            remoteSnapshots[childID] = snap
        }
        #endif
    }

    /// CHILD device: consume a parent's gift-revoke exactly once, wipe all parent
    /// time locally, re-shield if a window was open, and push the new state up.
    private func applyPendingGiftRevoke(childID: UUID) {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("children").document(childID.uuidString)
        db.runTransaction({ txn, _ -> Any? in
            let doc = try? txn.getDocument(ref)
            guard let stamp = doc?.data()?["revokeGiftAt"] as? Double else { return nil }
            // Only clear the command. A non-zero pendingGiftAdjustment seen
            // alongside it is a NEWER "+10" (revokeChildGift zeroed the field
            // atomically with the stamp) — it must survive and apply after.
            // The ACK (`revokeGiftAppliedAt` = the command's own stamp) rides the
            // same transaction, so "consumed" and "confirmed to the parent" can
            // never diverge.
            txn.updateData(["revokeGiftAt": FieldValue.delete(),
                            "revokeGiftAppliedAt": stamp], forDocument: ref)
            return stamp
        }) { [weak self] result, _ in
            guard result is Double else { return }
            Task { @MainActor in
                TofyLink("applyPendingGiftRevoke: parent revoked gift for \(childID.uuidString.prefix(8))")
                let closed = ProgressStore.shared.revokeAllParentTime()
                if closed {
                    ShieldManager.shared.cancelScheduledReshield()
                    ShieldManager.shared.relockBaseline()
                }
                Haptic.warning()
                self?.pushNow()
                // Order: revoke first, THEN any gift given after it.
                self?.applyPendingGift(childID: childID)
            }
        }
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
                guard let self else { return }
                TofyLink("applyPendingReset: parent reset for \(childID.uuidString.prefix(8)) → wiping local + cloud")
                let wasOpen = ProgressStore.shared.isUnlocked
                ProgressVault.shared.resetProfile(childID)
                if wasOpen {   // resetAll ended the window — bring the shield back
                    ShieldManager.shared.cancelScheduledReshield()
                    ShieldManager.shared.relockBaseline()
                }
                // AUTHORITATIVE cloud wipe: a plain (non-ratchet) set from the child.
                // pushNow() would ratchet-merge and resurrect stars/xp from the cloud.
                self.writeBlankCloudState(childID: childID)
            }
        }
        #endif
    }

    /// CHILD device: overwrite this child's cloud state with a blank snapshot at a
    /// revision above both cloud and local (so it wins, and our echo is skipped),
    /// then adopt that revision locally.
    private func writeBlankCloudState(childID: UUID) {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("children").document(childID.uuidString)
            .collection("state").document("current")
        let localRev = ProgressStore.shared.revision
        db.runTransaction({ txn, _ -> Any? in
            let cloudSnap = (try? txn.getDocument(ref))?.data().flatMap({ Self.decode($0) })
            let cloudRev = cloudSnap?.revision ?? 0
            let cloudEpoch = cloudSnap?.resetEpoch ?? 0
            var blank = ProgressSnapshot.blank
            blank.revision = max(cloudRev, localRev) + 1
            // 🧹 higher epoch = authoritative wipe that survives the ratchet on
            // EVERY device, incl. a second device that never saw the command.
            blank.resetEpoch = max(cloudEpoch, ProgressStore.shared.resetEpoch) + 1
            blank.lastModifiedAt = Date()
            blank.deviceID = ProgressSnapshot.thisDeviceID
            if let data = Self.encode(blank) { txn.setData(data, forDocument: ref) }   // NOT merge
            return ["rev": blank.revision, "epoch": blank.resetEpoch]
        }) { result, err in
            if let err { TofyLink("writeBlankCloudState FAILED: \(err.localizedDescription)"); return }
            if let r = result as? [String: Int], let rev = r["rev"], let epoch = r["epoch"] {
                Task { @MainActor in
                    ProgressStore.shared.adoptRevision(rev)
                    // Adopt the epoch too — else this device is left behind the
                    // cloud it wrote and its post-reset progress never syncs.
                    ProgressStore.shared.adoptResetEpoch(epoch)
                }
            }
        }
        #endif
    }

    /// CHILD device: consume any parent minute grant on this child's doc exactly
    /// once. Reads + zeroes `pendingMinuteAdjustment` in a transaction (so two
    /// devices can't double-apply), then adds it to the live balance.
    private func applyPendingMinuteGrant(childID: UUID) {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("children").document(childID.uuidString)
        db.runTransaction({ txn, _ -> Any? in
            let doc = try? txn.getDocument(ref)
            let adj = (doc?.data()?["pendingMinuteAdjustment"] as? Int) ?? 0
            if adj != 0 { txn.updateData(["pendingMinuteAdjustment": 0], forDocument: ref) }
            return adj
        }) { [weak self] result, _ in
            let adj = (result as? Int) ?? 0
            guard adj != 0 else { return }
            ProgressStore.shared.addPendingMinutes(adj)
            // Publish immediately, not after the ~3s debounce. The command has
            // ALREADY been zeroed (exactly-once), so until this credit reaches the
            // cloud it exists only on this device — and any other write that lands
            // in that gap under a higher revision takes it away for good. This is
            // the reward for an approved chore; it must not be racy.
            self?.pushNow()
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
            store.$parentGiftMinutes.map { _ in () }.eraseToAnyPublisher(),
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
    /// Ratchet-upload a specific profile's snapshot (used to flush offline
    /// progress the parent-cache/vault held for a NON-active profile). Same
    /// merge-transaction contract as uploadActiveProfile — never lowers cloud.
    private func uploadSnapshot(_ local: ProgressSnapshot, for pid: UUID) {
        let ref = db.collection("children").document(pid.uuidString)
            .collection("state").document("current")
        db.runTransaction({ txn, _ -> Any? in
            guard let cloud = (try? txn.getDocument(ref))?.data().flatMap({ Self.decode($0) }) else {
                if let data = Self.encode(local) { txn.setData(data, forDocument: ref, merge: true) }
                return nil
            }
            var merged = ProgressSnapshot.ratchetMerged(local: local, remote: cloud)
            if ProgressSnapshot.sameProgressData(merged, cloud) { return nil }
            merged.revision = max(local.revision, cloud.revision) + 1
            merged.lastModifiedAt = Date()
            merged.deviceID = ProgressSnapshot.thisDeviceID
            if let data = Self.encode(merged) { txn.setData(data, forDocument: ref, merge: true) }
            return nil
        }) { _, _ in }
    }

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
                    let gift = (doc?.data()?["pendingGiftAdjustment"] as? Int) ?? 0
                    let revokeAck = doc?.data()?["revokeGiftAppliedAt"] as? Double
                    let giftAck = doc?.data()?["giftAppliedAt"] as? Double
                    Task { @MainActor in
                        if adj != 0 { self.pendingAdjustments[profile.id] = adj }
                        else { self.pendingAdjustments.removeValue(forKey: profile.id) }
                        if gift != 0 { self.pendingGifts[profile.id] = gift }
                        else { self.pendingGifts.removeValue(forKey: profile.id) }
                        // PARENT: the child's device acked our gift-revoke — flip
                        // the live status to "✅ נמחקו".
                        if let revokeAck, var t = self.giftRevokeTracker[profile.id],
                           revokeAck >= t.stamp, t.appliedAt != revokeAck {
                            t.appliedAt = revokeAck
                            self.giftRevokeTracker[profile.id] = t
                        }
                        // 💝 send ack: the child's device consumed the gift.
                        if let giftAck, var t = self.giftSendTracker[profile.id],
                           giftAck >= t.stamp, t.appliedAt != giftAck {
                            t.appliedAt = giftAck
                            self.giftSendTracker[profile.id] = t
                        }
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
                    let revokePending = doc?.data()?["revokeGiftAt"] != nil
                    if gift != 0 && !revokePending && (isBoundChildDevice || isKidModeForThis) {
                        self.applyPendingGift(childID: profile.id)   // else: applied after the revoke
                    }
                    // A parent's "reset progress" — consumed the same way, by the
                    // device that IS this child right now.
                    let resetRequested = doc?.data()?["resetRequestedAt"] != nil
                    if resetRequested && (isBoundChildDevice || isKidModeForThis) {
                        self.applyPendingReset(childID: profile.id)
                    }
                    let revokeRequested = doc?.data()?["revokeGiftAt"] != nil
                    if revokeRequested {
                        TofyLink("childDoc \(id.prefix(8)): revokeGiftAt present; bound=\(isBoundChildDevice) kidMode=\(isKidModeForThis) role=\(s.deviceRole) joined=\(s.joinedChildID?.prefix(8) ?? "nil")")
                    }
                    if revokeRequested && (isBoundChildDevice || isKidModeForThis) {
                        self.applyPendingGiftRevoke(childID: profile.id)
                    }
                }
        }
    }

    private func handleRemoteSnapshot(_ snap: ProgressSnapshot, profileID: UUID) {
        // Parent tapped reset and the child hasn't echoed the wipe yet: drop
        // pre-reset snapshots so the dashboard doesn't flip back to old numbers.
        if let gate = resetPending[profileID] {
            if Date() > gate.until { resetPending.removeValue(forKey: profileID) }
            else if snap.revision < gate.minRevision { return }          // stale, pre-reset
            else { resetPending.removeValue(forKey: profileID) }         // child echoed the wipe
        }
        let isActive = profileID == ProfileStore.shared.activeID
        let ownEcho = snap.deviceID == ProgressSnapshot.thisDeviceID
        TofyLink("remoteSnapshot in: child=\(profileID.uuidString.prefix(8)) active=\(isActive) ownEcho=\(ownEcho) stars=\(snap.stars) diamonds=\(snap.diamonds) min=\(snap.pendingMinutes) rev=\(snap.revision)")
        // Always cache for the dashboard — the parent monitor must reflect the
        // cloud even when THIS device made the last write (e.g. a +minutes
        // grant). Skipping our own writes here is what made the parent's view
        // stop updating after it edited a child.
        remoteSnapshots[profileID] = snap
        WidgetBridge.refreshFamilySoon()   // keep the parent widget live
        // If this is the ACTIVE profile and the remote snapshot is newer
        // than what we have locally, apply it (so a reset on the parent's
        // phone propagates to the kid's iPad in real time).
        guard profileID == ProfileStore.shared.activeID else {
            // Non-active profile (parent dashboard cache, or a sibling on a
            // shared device). MERGE against the existing vault copy instead of
            // blindly overwriting — a shared device can hold offline-earned
            // progress for this profile that hasn't uploaded yet, and a stale
            // cloud echo used to wipe it. ratchetMerged also lets a reset
            // (higher resetEpoch) win wholesale.
            let vaultCopy = ProgressVault.shared.snapshot(for: profileID)
            let merged = ProgressSnapshot.ratchetMerged(local: vaultCopy, remote: snap)
            ProgressVault.shared.write(merged, for: profileID)
            // If the vault led (we hold more than the cloud), push it up so the
            // peer converges — otherwise that offline progress never leaves.
            if !ProgressSnapshot.sameProgressData(merged, snap) {
                uploadSnapshot(merged, for: profileID)
            }
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
