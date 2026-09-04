import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// 🔐 ONE authoritative play window per child, owned by exactly ONE device.
///
/// Rani's model, and the right one: *"the child has 60 gift minutes, opens on the
/// iPhone; the iPad is locked and says 'you're open on the iPhone' with an option
/// to close it there and open here — and the remaining minutes move across."*
///
/// Before this, the app asked THREE different places whether the child was
/// playing somewhere else — a device row that could be stale/denied/absent, a
/// device-local `unlockEndsAt` that never synced, and a wallet scalar both
/// devices edited — and none of them was authoritative. That is why a spend on
/// one device could be resurrected by the other and opened twice.
///
/// Now it is one document and one atomic question, and **the minutes ride inside
/// the answer**: the wallet debit and the lease write are the SAME transaction,
/// so there is no instant in which minutes are spent-but-unclaimed or
/// claimed-but-unspent.
///
/// THE INVARIANT: never open a window whose minutes are still spent somewhere
/// else. Note what this is *not* — it is not "the peer must confirm". A powered
/// off iPhone never confirms, and a child who cannot open minutes they earned
/// because a sibling's iPad is in a drawer is a worse trust failure than a
/// bounded overlap. The lease document holds the time, so the peer's ack is an
/// optimization; after an unanswered release request the claimant may take over,
/// and the takeover SETTLES the remainder at the server's clock — a takeover can
/// never mint time, only ever spend it once.
struct PlayWindowLease: Equatable {
    enum State: String { case open, releasing, idle }
    /// Which pocket funded the window — decides where a refund goes.
    enum Kind: String { case earned, gift, grant }

    var state: State = .idle
    var leaseID: String?
    var ownerDeviceID: String?
    var ownerKind: String?
    var ownerName: String?
    var kind: Kind = .earned
    var grantedSeconds: Int = 0
    /// Server-stamped. The ONLY clock that counts — a child moving the device
    /// clock cannot move the start, so `expiresAt` can't be inflated.
    var startedAt: Date?
    var releaseRequestedBy: String?
    var lastReleasedLeaseID: String?

    var isMine: Bool { ownerDeviceID == DeviceIdentity.installID }
    var isHeld: Bool { state != .idle && leaseID != nil }

    /// Derived, never stored: a stored `remainingSeconds` is a field a lying
    /// device can lie into, and a crash between decrement and commit leaves it
    /// wrong. Derived-from-`startedAt` is monotone and self-correcting.
    func remainingSeconds(now: Date = Date()) -> Int {
        guard let startedAt else { return 0 }
        return max(0, grantedSeconds - Int(now.timeIntervalSince(startedAt)))
    }

    /// A generous grace absorbs clock skew between the two devices. A wrong
    /// steal costs nothing anyway — the remainder is settled back to the wallet,
    /// never duplicated.
    static let expiryGraceSeconds = 120

    func isExpired(now: Date = Date()) -> Bool {
        guard isHeld, let startedAt else { return true }
        return now.timeIntervalSince(startedAt) > Double(grantedSeconds + Self.expiryGraceSeconds)
    }

    /// Someone ELSE is genuinely playing right now.
    func isHeldElsewhere(now: Date = Date()) -> Bool {
        isHeld && !isMine && !isExpired(now: now)
    }

    static func from(_ d: [String: Any]) -> PlayWindowLease {
        var l = PlayWindowLease()
        l.state = State(rawValue: d["state"] as? String ?? "") ?? .idle
        l.leaseID = d["leaseID"] as? String
        l.ownerDeviceID = d["ownerDeviceID"] as? String
        l.ownerKind = d["ownerKind"] as? String
        l.ownerName = d["ownerName"] as? String
        l.kind = Kind(rawValue: d["kind"] as? String ?? "") ?? .earned
        l.grantedSeconds = d["grantedSeconds"] as? Int ?? 0
        #if canImport(FirebaseFirestore)
        l.startedAt = (d["startedAt"] as? Timestamp)?.dateValue() ?? d["startedAt"] as? Date
        #endif
        l.releaseRequestedBy = d["releaseRequestedBy"] as? String
        l.lastReleasedLeaseID = d["lastReleasedLeaseID"] as? String
        return l
    }
}

/// What a claim attempt produced.
enum ClaimOutcome: Equatable {
    case granted(leaseID: String, seconds: Int)
    /// Another device holds a live window — offer the transfer.
    case heldElsewhere(ownerKind: String, secondsLeft: Int)
    case insufficient
    /// The transaction could not run (Firestore transactions do NOT queue
    /// offline). The caller decides whether a bounded local window is allowed.
    case offline
}

enum ClaimPolicy {
    case normal           // the child tapping "open my minutes"
    case parentOverride   // a parent's remote grant outranks a sibling device
    case force            // takeover after an unanswered release request
    /// Retro-claim for a window this device ALREADY opened offline. The wallet
    /// was debited locally and that debit rides up with the snapshot, so the
    /// transaction must NOT debit a second time — it only publishes the fact
    /// that this device owns the window, and still refuses if a sibling
    /// legitimately holds one.
    case adoptLocal
}

@MainActor
final class PlayWindowLeaseManager: ObservableObject {
    static let shared = PlayWindowLeaseManager()

    /// The live lease for the child this device is currently being.
    @Published private(set) var lease = PlayWindowLease()

    /// Kill switch — the whole lease path can be disabled without a build, and
    /// the app falls back to the previous behaviour verbatim. ON by default from
    /// build 138: every failure mode degrades to exactly the old behaviour (a
    /// claim that cannot run returns `.offline` and the caller takes the legacy
    /// path), so the worst case of leaving it on is what shipped before it.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "playWindowLease.enabled") as? Bool ?? true
    }

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    #endif
    private var listeningChild: String?
    private var reconciling = false

    private init() {}

    // MARK: - Live view of the lease

    func startIfNeeded(childID: UUID) {
        #if canImport(FirebaseFirestore)
        guard Self.isEnabled, !HouseholdManager.skipsCloudSync else { return }
        let cid = childID.uuidString
        guard cid != listeningChild else { return }
        listener?.remove()
        listeningChild = cid
        listener = windowRef(cid).addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err { TofyLink("lease listener error: \(err.localizedDescription)"); return }
            let parsed = PlayWindowLease.from(snap?.data() ?? [:])
            Task { @MainActor in
                self.lease = parsed
                self.honorReleaseRequestIfNeeded(parsed)
            }
        }
        #endif
    }

    /// OWNER SIDE of the transfer: the child's other device asked for the window.
    /// Let go immediately — re-lock, then stop-and-save, which fires the release
    /// transaction that publishes the refund and the "it's closed" fact together.
    private func honorReleaseRequestIfNeeded(_ l: PlayWindowLease) {
        guard l.isMine, l.state == .releasing,
              l.releaseRequestedBy != DeviceIdentity.installID else { return }
        ShieldManager.shared.relockBaseline()
        ProgressStore.shared.stopAndSaveCurrentUnlock()
    }

    /// CLAIMANT SIDE of Rani's flow: ask the owner to let go, ring its doorbell,
    /// wait for the ONE atomic fact that proves it closed (the lease reaching
    /// `idle`), then claim — the refunded minutes are already in the wallet the
    /// claim reads, so there is no separate fetch-and-merge step.
    func transferHere(childID: UUID, ownerDeviceRowID: String?,
                      kind: PlayWindowLease.Kind, requestedSeconds: Int) async -> ClaimOutcome {
        guard await requestRelease(childID: childID) else {
            return await claim(childID: childID, kind: kind, requestedSeconds: requestedSeconds)
        }
        // Wake the owner (push). Purely a doorbell — correctness lives in the lease.
        if let row = ownerDeviceRowID { HouseholdManager.shared.lockOtherDeviceWindow(deviceRowID: row) }
        // Wait for the honest confirmation, bounded.
        for _ in 0..<60 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !lease.isHeld || lease.isMine || lease.isExpired() { break }
        }
        guard !lease.isHeldElsewhere() else {
            return .heldElsewhere(ownerKind: lease.ownerKind ?? "other",
                                  secondsLeft: lease.remainingSeconds())
        }
        return await claim(childID: childID, kind: kind, requestedSeconds: requestedSeconds)
    }

    /// RECONNECT SWEEP. A window opened while Firestore was unreachable has no
    /// lease (transactions never queue offline), so the sibling device sees an
    /// idle lease and could legitimately open a second window — the exact
    /// double-spend this whole design exists to kill. On every wake, if we are
    /// playing WITHOUT a lease, retro-claim one for the time we have left.
    ///
    /// `.adoptLocal` does not debit: the minutes were already taken out of the
    /// local wallet and that debit rides up with the snapshot. If a sibling
    /// genuinely holds the window we simply do not get the lease — we let this
    /// window run out rather than confiscating time from a child who did nothing
    /// wrong, and the invariant in `enforceShieldStateIfNeeded` only ever locks a
    /// device that DOES hold a lease, so nothing is yanked mid-play.
    func reconcileOfflineWindowIfNeeded(childID: UUID) {
        #if canImport(FirebaseFirestore)
        guard Self.isEnabled, !HouseholdManager.skipsCloudSync else { return }
        let progress = ProgressStore.shared
        guard progress.isUnlocked, progress.activeLeaseID == nil else { return }
        let left = progress.unlockSecondsRemaining
        guard left > 30 else { return }   // about to end anyway — not worth a write
        let kind = PlayWindowLease.Kind(rawValue: progress.unlockKind) ?? .earned
        guard !reconciling else { return }
        reconciling = true
        Task { @MainActor in
            defer { self.reconciling = false }
            let out = await self.claim(childID: childID, kind: kind,
                                       requestedSeconds: left, policy: .adoptLocal)
            if case .granted(let lid, _) = out {
                progress.adoptLeaseID(lid)
                TofyLink("lease: adopted offline window \(lid) (\(left)s left)")
            }
        }
        #endif
    }

    /// Settle a lease the MONITOR EXTENSION closed. The extension has no Firebase,
    /// so a window that ran out in the background leaves the lease open; this
    /// drains that hand-off on the next app wake. Refund 0 — the window genuinely
    /// ran to its end, there is nothing left to give back.
    func drainExtensionReleaseIfNeeded(childID: UUID) {
        #if canImport(FirebaseFirestore)
        guard Self.isEnabled else { return }
        let d = AppGroup.defaults
        guard let leaseID = d.string(forKey: "leaseNeedsRelease") else { return }
        d.removeObject(forKey: "leaseNeedsRelease")
        Task { await self.release(childID: childID, leaseID: leaseID, localRemainingSeconds: 0) }
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        listener?.remove(); listener = nil
        #endif
        listeningChild = nil
        lease = PlayWindowLease()
    }

    #if canImport(FirebaseFirestore)
    private func windowRef(_ cid: String) -> DocumentReference {
        db.collection("children").document(cid).collection("state").document("window")
    }
    private func stateRef(_ cid: String) -> DocumentReference {
        db.collection("children").document(cid).collection("state").document("current")
    }

    // MARK: - CLAIM (open)

    /// Atomically: verify nobody else holds a live window, settle any dead lease,
    /// DEBIT the wallet, and write the lease — all in one transaction. The caller
    /// opens the shield only on `.granted`.
    func claim(childID: UUID, kind: PlayWindowLease.Kind, requestedSeconds: Int,
               policy: ClaimPolicy = .normal) async -> ClaimOutcome {
        let cid = childID.uuidString
        let me = DeviceIdentity.installID
        let candidate = UUID().uuidString
        // Captured BEFORE the transaction — the block may re-run.
        let local = ProgressStore.shared.captureSnapshot()
        let minSeconds = ProgressStore.shared.minimumUnlockMinutes * 60
        let wRef = windowRef(cid), sRef = stateRef(cid)
        let kindRaw = kind.rawValue
        let ownerKind = DeviceIdentity.kind, ownerName = DeviceIdentity.friendlyName

        return await withCheckedContinuation { (cont: CheckedContinuation<ClaimOutcome, Never>) in
            db.runTransaction({ txn, _ -> Any? in
                let wData = (try? txn.getDocument(wRef))?.data() ?? [:]
                let held = PlayWindowLease.from(wData)
                let now = Date()

                // 1. We already hold it → same answer, NO second debit (a retried
                //    claim must be idempotent).
                if held.isHeld, held.isMine, !held.isExpired(now: now) {
                    return ["ok": true, "leaseID": held.leaseID ?? "", "seconds": held.remainingSeconds(now: now)]
                }
                // 2. Someone else is genuinely playing → refuse. THE invariant.
                if held.isHeldElsewhere(now: now), policy == .normal || policy == .adoptLocal {
                    return ["held": true, "kind": held.ownerKind ?? "other",
                            "seconds": held.remainingSeconds(now: now)]
                }

                var cloud = (try? txn.getDocument(sRef))?.data().flatMap(ProgressSnapshot.fromFirestore) ?? .blank
                // 3. Taking over an expired/force-taken lease → SETTLE it first, so
                //    the sibling's remainder is never silently burned. Guarded by
                //    lastReleasedLeaseID so two racing stealers can't both refund.
                if held.isHeld, let hid = held.leaseID, held.lastReleasedLeaseID != hid {
                    let refundMin = held.remainingSeconds(now: now) / 60
                    if refundMin > 0 {
                        switch held.kind {
                        case .earned:
                            cloud.pendingMinutes += refundMin
                            cloud.minutesUnlockedToday = max(0, cloud.minutesUnlockedToday - refundMin)
                        case .gift:
                            cloud.parentGiftMinutes = (cloud.parentGiftMinutes ?? 0) + refundMin
                        case .grant: break
                        }
                    }
                }

                // 4. Merge our local state up (never lowers the cloud), then debit.
                var merged = ProgressSnapshot.ratchetMerged(local: local, remote: cloud)
                var grant = 0
                if policy == .adoptLocal {
                    // Already paid for locally — publish ownership, touch no pocket.
                    grant = requestedSeconds
                } else {
                    switch kind {
                    case .earned:
                        let capLeft = max(0, merged.pendingMinutes)
                        grant = min(requestedSeconds / 60, capLeft) * 60
                        guard grant >= minSeconds else { return ["insufficient": true] }
                        merged.pendingMinutes -= grant / 60
                        merged.minutesUnlockedToday += grant / 60
                    case .gift:
                        let pocket = merged.parentGiftMinutes ?? 0
                        grant = min(requestedSeconds / 60, pocket) * 60
                        guard grant > 0 else { return ["insufficient": true] }
                        merged.parentGiftMinutes = max(0, pocket - grant / 60)
                    case .grant:
                        // A parent's remote grant is MINTED, not spent from a pocket.
                        grant = requestedSeconds
                    }
                }
                merged.revision = max(local.revision, cloud.revision) + 1
                merged.lastModifiedAt = Date()
                merged.deviceID = ProgressSnapshot.thisDeviceID
                if let enc = ProgressSnapshot.toFirestore(merged) {
                    txn.setData(enc, forDocument: sRef, merge: true)
                }

                // 5. Write the lease. setData (NOT merge) so a stale
                //    releaseRequestedBy can't survive into the new lease.
                txn.setData([
                    "schemaVersion": 1, "state": "open",
                    "leaseID": candidate, "ownerDeviceID": me,
                    "ownerKind": ownerKind, "ownerName": ownerName,
                    "kind": kindRaw, "grantedSeconds": grant,
                    "startedAt": FieldValue.serverTimestamp(),
                    "lastReleasedLeaseID": held.leaseID ?? wData["lastReleasedLeaseID"] as Any,
                ], forDocument: wRef)
                return ["ok": true, "leaseID": candidate, "seconds": grant]
            }) { result, err in
                if err != nil { cont.resume(returning: .offline); return }
                guard let r = result as? [String: Any] else { cont.resume(returning: .offline); return }
                if r["insufficient"] != nil { cont.resume(returning: .insufficient); return }
                if r["held"] != nil {
                    cont.resume(returning: .heldElsewhere(ownerKind: r["kind"] as? String ?? "other",
                                                          secondsLeft: r["seconds"] as? Int ?? 0))
                    return
                }
                cont.resume(returning: .granted(leaseID: r["leaseID"] as? String ?? "",
                                                seconds: r["seconds"] as? Int ?? 0))
            }
        }
    }

    // MARK: - RELEASE (close)

    /// Return the unused remainder to the wallet and clear the lease — idempotent.
    /// The refund is clamped to `granted − elapsed` by the SERVER's start stamp, so
    /// a rolled-back device clock cannot mint minutes even in principle.
    @discardableResult
    func release(childID: UUID, leaseID: String, localRemainingSeconds: Int) async -> Bool {
        let cid = childID.uuidString
        let wRef = windowRef(cid), sRef = stateRef(cid)
        let localRevision = ProgressStore.shared.revision

        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            db.runTransaction({ txn, _ -> Any? in
                let wData = (try? txn.getDocument(wRef))?.data() ?? [:]
                // Idempotency, two total guards.
                if (wData["lastReleasedLeaseID"] as? String) == leaseID { return true }
                guard (wData["leaseID"] as? String) == leaseID else { return true }

                let held = PlayWindowLease.from(wData)
                let elapsed = held.startedAt.map { max(0, Int(Date().timeIntervalSince($0))) } ?? 0
                let refund = max(0, min(localRemainingSeconds, held.grantedSeconds - elapsed))
                let refundMin = refund / 60

                // Credit the CLOUD's own value (not a merge of our local copy —
                // which may already carry the optimistic credit, which would double).
                var cloud = (try? txn.getDocument(sRef))?.data().flatMap(ProgressSnapshot.fromFirestore) ?? .blank
                if refundMin > 0 {
                    switch held.kind {
                    case .earned:
                        cloud.pendingMinutes += refundMin
                        cloud.minutesUnlockedToday = max(0, cloud.minutesUnlockedToday - refundMin)
                    case .gift:
                        cloud.parentGiftMinutes = (cloud.parentGiftMinutes ?? 0) + refundMin
                    case .grant: break   // a parent's fixed grant refunds nothing
                    }
                }
                cloud.revision = max(localRevision, cloud.revision) + 1
                cloud.lastModifiedAt = Date()
                cloud.deviceID = ProgressSnapshot.thisDeviceID
                if let enc = ProgressSnapshot.toFirestore(cloud) {
                    txn.setData(enc, forDocument: sRef, merge: true)
                }

                txn.setData([
                    "state": "idle",
                    "leaseID": FieldValue.delete(), "ownerDeviceID": FieldValue.delete(),
                    "ownerKind": FieldValue.delete(), "ownerName": FieldValue.delete(),
                    "grantedSeconds": FieldValue.delete(), "startedAt": FieldValue.delete(),
                    "releaseRequestedBy": FieldValue.delete(),
                    "releaseRequestedAt": FieldValue.delete(),
                    "lastReleasedLeaseID": leaseID,
                    "lastReleasedAt": FieldValue.serverTimestamp(),
                    "refundedSeconds": refund,
                ], forDocument: wRef, merge: true)
                return true
            }) { _, err in cont.resume(returning: err == nil) }
        }
    }

    // MARK: - TRANSFER (ask the owner to let go)

    /// Step 1 of Rani's flow: mark the lease "releasing" and ring the owner's
    /// doorbell. "We KNOW it locked" is later established by the lease reaching
    /// `state == .idle` with `lastReleasedLeaseID == thatLeaseID` — one atomic
    /// fact, published in the same write as the refund.
    func requestRelease(childID: UUID) async -> Bool {
        let cid = childID.uuidString
        let me = DeviceIdentity.installID
        let wRef = windowRef(cid)
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            db.runTransaction({ txn, _ -> Any? in
                let wData = (try? txn.getDocument(wRef))?.data() ?? [:]
                let held = PlayWindowLease.from(wData)
                guard held.isHeld, !held.isMine else { return false }
                txn.setData(["state": "releasing",
                             "releaseRequestedBy": me,
                             "releaseRequestedAt": FieldValue.serverTimestamp()],
                            forDocument: wRef, merge: true)
                return true
            }) { result, err in cont.resume(returning: err == nil && (result as? Bool ?? false)) }
        }
    }
    #endif
}
