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

/// Seconds-exact wallet arithmetic, extracted from the lease transactions so the
/// conservation invariant can be tested without Firestore.
///
/// The wallets hold whole minutes; the odd seconds live in a 0…59 carry. The one
/// rule both directions must obey: **time is neither minted nor lost**. Spending
/// rounds the pocket withdrawal UP and hands the unspent part back to the carry,
/// so repeated hand-offs cannot shave (or grow) a child's balance.
enum WalletSeconds {
    /// Spend up to `want` seconds from `minutes` whole minutes plus `carry`.
    static func spend(want: Int, minutes: Int, carry: Int) -> (granted: Int, minutesOut: Int, carryLeft: Int) {
        let carry = max(0, min(59, carry))
        let minutes = max(0, minutes)
        let granted = max(0, min(want, minutes * 60 + carry))
        let minutesOut = (max(0, granted - carry) + 59) / 60
        return (granted, minutesOut, minutesOut * 60 + carry - granted)
    }

    /// Give `seconds` back, folding them into `carry` and overflowing to minutes.
    static func refund(seconds: Int, carry: Int) -> (minutesIn: Int, carryLeft: Int) {
        let total = max(0, seconds) + max(0, min(59, carry))
        return (total / 60, total % 60)
    }
}

/// The wallet EXACTLY as the claim transaction left it in the cloud. The caller
/// adopts this verbatim instead of guessing at a local debit: the claimant's own
/// copy is stale by construction (the refund it is spending was published by the
/// OTHER device moments earlier), and a stale pocket pushed back up under a newer
/// revision silently un-does the debit — which is how a 60-minute gift grew to 228
/// across a few transfers.
struct ClaimedWallet: Equatable {
    let pendingMinutes: Int
    let parentGiftMinutes: Int
    let minutesUnlockedToday: Int
    /// Sub-minute remainder left after the transaction spent/refunded (0…59).
    let secondsCarry: Int
    /// Which pocket that remainder belongs to.
    var carryIsGift: Bool = false
    let revision: Int
    /// The local edit count this result was computed on. If the store has moved
    /// past it, the absolute numbers above are a photograph of the past. NOT the
    /// revision — that is a generation and deliberately does not move per edit.
    var basedOnEditSeq: Int = 0
    /// What the transaction actually moved, in seconds: negative spent, positive
    /// refunded. Lets a stale result still be applied RELATIVELY, so it neither
    /// erases what landed meanwhile nor loses the child's time.
    var deltaSeconds: Int = 0
    /// Which pocket that delta belongs to.
    var deltaIsGift: Bool = false
}

/// What a claim attempt produced.
enum ClaimOutcome: Equatable {
    case granted(leaseID: String, seconds: Int, wallet: ClaimedWallet?)
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
    // NOTE: there is deliberately no `force` takeover. Rani: an "open anyway"
    // override re-opens the very hole this design closes. A stuck window now
    // resolves honestly — the owner hands the lease back when it stops, the
    // wake-up sweep hands it back if it already stopped, and a truly dead lease
    // expires on the server's clock.
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
        if ProgressStore.shared.isUnlocked {
            ProgressStore.shared.stopAndSaveCurrentUnlock()
            return
        }
        // We hold the lease but are NOT playing — the window was closed by a path
        // that missed the release (an older build, a crash, a revoke). Without
        // this branch stopAndSaveCurrentUnlock returns at its `guard isUnlocked`
        // and NOBODY ever lets go: this device holds the child's only window
        // hostage until it expires and the sibling can never open. Refund 0 —
        // whatever was owed was already banked locally when it closed.
        #if canImport(FirebaseFirestore)
        if let lid = l.leaseID, let cid = ProfileStore.shared.activeID {
            Task { await self.release(childID: cid, leaseID: lid, localRemainingSeconds: 0) }
        }
        #endif
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
        // MIRROR IMAGE, and the one that self-heals a stuck family: we hold the
        // lease but are not playing. Let go without waiting to be asked — the
        // sibling's "פתוח במכשיר השני" card is driven by this lease, so until it
        // clears the child simply cannot open anywhere.
        if lease.isMine, lease.isHeld, !progress.isUnlocked, let lid = lease.leaseID {
            Task { await self.release(childID: childID, leaseID: lid, localRemainingSeconds: 0) }
            return
        }
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
            if case .granted(let lid, _, _) = out {
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
        let baseSeq = ProgressStore.shared.localEditSeq
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
                    let cur = (try? txn.getDocument(sRef))?.data().flatMap(ProgressSnapshot.fromFirestore) ?? .blank
                    return ["ok": true, "leaseID": held.leaseID ?? "",
                            "seconds": held.remainingSeconds(now: now),
                            "wPending": cur.pendingMinutes, "wGiftPocket": cur.parentGiftMinutes ?? 0,
                            "wToday": cur.minutesUnlockedToday, "wCarry": cur.secondsCarry ?? 0, "wCarryGift": cur.carryIsGift ?? false,
                            "wRev": cur.revision, "wBase": baseSeq, "wDelta": 0,
                            "wGift": false]
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
                    let same = (cloud.carryIsGift ?? false) == (held.kind == .gift)
                    let r = WalletSeconds.refund(seconds: held.remainingSeconds(now: now),
                                                 carry: same ? (cloud.secondsCarry ?? 0) : 0)
                    let refundMin = r.minutesIn
                    if held.kind != .grant {
                        cloud.secondsCarry = r.carryLeft
                        cloud.carryIsGift = held.kind == .gift
                    }
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
                    // Seconds-exact (Rani: a hand-off at 38:50 resumes at 38:50,
                    // not 38:00). The pockets are whole minutes, so the odd
                    // seconds live in `secondsCarry` and are spent FIRST.
                    // Only spend the carry if it came out of THIS pocket.
                    let carry = (merged.carryIsGift ?? false) == (kind == .gift)
                        ? max(0, min(59, merged.secondsCarry ?? 0)) : 0
                    switch kind {
                    case .earned:
                        let r = WalletSeconds.spend(want: requestedSeconds,
                                                    minutes: merged.pendingMinutes, carry: carry)
                        grant = r.granted
                        guard grant >= minSeconds else { return ["insufficient": true] }
                        merged.pendingMinutes = max(0, merged.pendingMinutes - r.minutesOut)
                        merged.minutesUnlockedToday += r.minutesOut
                        merged.secondsCarry = r.carryLeft
                        merged.carryIsGift = false
                    case .gift:
                        let pocket = merged.parentGiftMinutes ?? 0
                        let r = WalletSeconds.spend(want: requestedSeconds, minutes: pocket, carry: carry)
                        grant = r.granted
                        guard grant > 0 else { return ["insufficient": true] }
                        merged.parentGiftMinutes = max(0, pocket - r.minutesOut)
                        merged.secondsCarry = r.carryLeft
                        merged.carryIsGift = true
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
                return ["ok": true, "leaseID": candidate, "seconds": grant,
                        "wPending": merged.pendingMinutes, "wGiftPocket": merged.parentGiftMinutes ?? 0,
                        "wToday": merged.minutesUnlockedToday, "wCarry": merged.secondsCarry ?? 0, "wCarryGift": merged.carryIsGift ?? false,
                        "wRev": merged.revision, "wBase": baseSeq,
                        "wDelta": (policy == .adoptLocal || kind == .grant) ? 0 : -grant,
                        "wGift": kind == .gift]
            }) { result, err in
                if err != nil { cont.resume(returning: .offline); return }
                guard let r = result as? [String: Any] else { cont.resume(returning: .offline); return }
                if r["insufficient"] != nil { cont.resume(returning: .insufficient); return }
                if r["held"] != nil {
                    cont.resume(returning: .heldElsewhere(ownerKind: r["kind"] as? String ?? "other",
                                                          secondsLeft: r["seconds"] as? Int ?? 0))
                    return
                }
                var wallet: ClaimedWallet?
                if let rev = r["wRev"] as? Int {
                    wallet = ClaimedWallet(pendingMinutes: r["wPending"] as? Int ?? 0,
                                           parentGiftMinutes: r["wGiftPocket"] as? Int ?? 0,
                                           minutesUnlockedToday: r["wToday"] as? Int ?? 0,
                                           secondsCarry: r["wCarry"] as? Int ?? 0,
                                           carryIsGift: r["wCarryGift"] as? Bool ?? false,
                                           revision: rev,
                                           basedOnEditSeq: r["wBase"] as? Int ?? 0,
                                           deltaSeconds: r["wDelta"] as? Int ?? 0,
                                           deltaIsGift: r["wGift"] as? Bool ?? false)
                }
                cont.resume(returning: .granted(leaseID: r["leaseID"] as? String ?? "",
                                                seconds: r["seconds"] as? Int ?? 0,
                                                wallet: wallet))
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
        // Captured BEFORE the transaction — the block may re-run.
        let local = ProgressStore.shared.captureSnapshot()
        let baseSeq = ProgressStore.shared.localEditSeq

        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            db.runTransaction({ txn, _ -> Any? in
                let wData = (try? txn.getDocument(wRef))?.data() ?? [:]
                // Idempotency, two total guards.
                if (wData["lastReleasedLeaseID"] as? String) == leaseID { return true }
                guard (wData["leaseID"] as? String) == leaseID else { return true }

                let held = PlayWindowLease.from(wData)
                let elapsed = held.startedAt.map { max(0, Int(Date().timeIntervalSince($0))) } ?? 0
                let refund = max(0, min(localRemainingSeconds, held.grantedSeconds - elapsed))
                // Merge our local state up, THEN add the refund.
                //
                // This used to read the cloud alone, to stop the local optimistic
                // credit being counted twice. That credit is gone now (the stop
                // path no longer pays — see stopAndSaveCurrentUnlock), so merging
                // is safe again — and NOT merging is a hazard in its own right:
                // the transaction would write a snapshot from before anything that
                // had just landed locally (a 💝 gift consumed from a command,
                // minutes earned mid-window, an approved chore), and adopting that
                // result would erase it.
                let remote = (try? txn.getDocument(sRef))?.data().flatMap(ProgressSnapshot.fromFirestore) ?? .blank
                var cloud = ProgressSnapshot.ratchetMerged(local: local, remote: remote)
                // Seconds-exact: give back every second, whole minutes to the
                // pocket and the remainder to the carry. Flooring here is what
                // used to shave up to 59 seconds off every hand-off.
                if refund > 0, held.kind != .grant {
                    let samePocket = (cloud.carryIsGift ?? false) == (held.kind == .gift)
                    let r = WalletSeconds.refund(seconds: refund,
                                                 carry: samePocket ? (cloud.secondsCarry ?? 0) : 0)
                    let refundMin = r.minutesIn
                    cloud.secondsCarry = r.carryLeft
                    cloud.carryIsGift = held.kind == .gift
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
                return ["wPending": cloud.pendingMinutes, "wGiftPocket": cloud.parentGiftMinutes ?? 0,
                        "wToday": cloud.minutesUnlockedToday, "wCarry": cloud.secondsCarry ?? 0, "wCarryGift": cloud.carryIsGift ?? false,
                        "wRev": cloud.revision, "wBase": baseSeq,
                        "wDelta": held.kind == .grant ? 0 : refund,
                        "wGift": held.kind == .gift]
            }) { result, err in
                // Same rule as a claim: the SERVER-clamped refund is the truth.
                //
                // `err == nil` is NOT optional here. The block's return value can
                // come back alongside an error for an attempt that never committed,
                // and adopting it would also adopt its REVISION — putting this
                // device at a generation the cloud never reached. Every genuine
                // cloud snapshot then carries a lower revision, loses the merge,
                // and the device is frozen on stale numbers for good: one iPad
                // showing 15 minutes and no gift while the iPhone correctly shows
                // 20 and 30.
                if err == nil, let r = result as? [String: Any], let rev = r["wRev"] as? Int {
                    let w = ClaimedWallet(pendingMinutes: r["wPending"] as? Int ?? 0,
                                          parentGiftMinutes: r["wGiftPocket"] as? Int ?? 0,
                                          minutesUnlockedToday: r["wToday"] as? Int ?? 0,
                                          secondsCarry: r["wCarry"] as? Int ?? 0,
                                          carryIsGift: r["wCarryGift"] as? Bool ?? false,
                                          revision: rev,
                                          basedOnEditSeq: r["wBase"] as? Int ?? 0,
                                          deltaSeconds: r["wDelta"] as? Int ?? 0,
                                          deltaIsGift: r["wGift"] as? Bool ?? false)
                    Task { @MainActor in
                        // ONLY when this device is currently being that child. A
                        // parent closing a child's window remotely runs the very
                        // same transaction — writing that child's wallet into the
                        // parent's ProgressStore would corrupt whoever is active.
                        guard ProfileStore.shared.activeID == childID else { return }
                        ProgressStore.shared.applyClaimedWallet(w)
                    }
                }
                cont.resume(returning: err == nil)
            }
        }
    }

    /// PARENT closes the child's window from afar, with no cooperation from the
    /// device that holds it. The remote-lock command already in place asks the
    /// child's device to stop — useless when that device is dead or off, which is
    /// exactly when a child is stranded: the lease stays held and they cannot
    /// open on their other device. This settles it directly instead, refunding
    /// the remainder at the SERVER's clock so nothing is burned.
    /// Grace before the parent stops asking and starts telling. A live device
    /// answers the remote-lock push in a second or two; this only ever elapses
    /// when the device genuinely cannot answer.
    static let parentReleaseGraceSeconds = 15

    func parentRelease(childID: UUID, afterGrace: Bool = true) async {
        #if canImport(FirebaseFirestore)
        guard Self.isEnabled else { return }
        let ref = windowRef(childID.uuidString)

        // GIVE THE DEVICE THE FIRST WORD (Rani). Settling the lease the instant
        // the parent taps would open a gap: the lease is free again while the
        // child's device is still unshielded and has not yet noticed — long
        // enough for them to walk to the other device and open a SECOND window.
        // A device that is alive releases the lease itself as part of obeying the
        // remote lock, and that release is the honest proof it has re-locked.
        if afterGrace {
            for _ in 0..<(Self.parentReleaseGraceSeconds / 3) {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                let snap = try? await ref.getDocument()
                if !PlayWindowLease.from(snap?.data() ?? [:]).isHeld { return }   // it obeyed
            }
        }

        // It never answered — it is off, offline, or stuck. Settle it ourselves
        // so the child is not stranded behind a device that cannot let go.
        let snap = try? await ref.getDocument()
        let l = PlayWindowLease.from(snap?.data() ?? [:])
        guard l.isHeld, let lid = l.leaseID else { return }
        // Int.max: the parent has no view of the device's local clock, so let the
        // transaction's own `granted − elapsed` clamp decide the refund.
        await release(childID: childID, leaseID: lid, localRemainingSeconds: .max)
        TofyLink("lease: parent force-closed \(lid.prefix(8)) — device never answered")
        #endif
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
