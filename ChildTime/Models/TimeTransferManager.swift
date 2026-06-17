import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Orchestrates sibling play-time purchases (see `TimeTransfer`). Runs on every
/// household device but acts ONLY on the side it owns:
///  • buyer device  — initiates + escrows diamonds; credits minutes on completion;
///                     refunds diamonds on a terminal failure.
///  • parent device — lists pending requests and approves / rejects them.
///  • seller device — settles an approved request (deducts minutes, takes diamonds).
///
/// All cross-device coordination is a single shared `timeTransfers` doc whose
/// idempotency flags are flipped inside Firestore transactions, so each side
/// applies exactly once. No device ever writes another child's wallet.
@MainActor
final class TimeTransferManager: ObservableObject {
    static let shared = TimeTransferManager()

    /// Requests awaiting a parent decision (drives the dashboard approvals list).
    @Published private(set) var pendingForParent: [TimeTransfer] = []
    /// Every household transfer, newest first — drives the parent's requests
    /// screen (pending + the approved/rejected/completed history).
    @Published private(set) var allTransfers: [TimeTransfer] = []
    /// Transfers involving THIS device's child (drives the kid's status view).
    @Published private(set) var myTransfers: [TimeTransfer] = []
    @Published private(set) var lastError: String?

    private var cancellables = Set<AnyCancellable>()
    /// Guards against launching the same settlement/credit twice while a
    /// transaction is in flight (the listener re-fires on every doc change).
    private var inFlight = Set<String>()

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    #endif

    private init() {}

    /// Begin watching the household's transfers. Idempotent — re-subscribes when
    /// the household changes. Call alongside `RemoteSyncManager.shared.start`.
    func start() {
        cancellables.removeAll()
        HouseholdManager.shared.$household
            .receive(on: RunLoop.main)
            .sink { [weak self] hh in self?.attach(householdID: hh?.id) }
            .store(in: &cancellables)
    }

    /// The child this device currently "is" — its bound play profile, or the
    /// child a parent's phone is in Kid Mode for. nil on a pure parent monitor.
    var currentChildID: UUID? {
        let s = ParentSettings.shared
        if s.deviceRole == .child, let j = s.joinedChildID { return UUID(uuidString: j) }
        if KidModeManager.shared.active { return KidModeManager.shared.childID }
        return nil
    }

    /// The price (💎) a purchase of `minutes` would cost at the current rate.
    func price(forMinutes minutes: Int) -> Int {
        minutes * max(1, ParentSettings.shared.diamondsPerMinute)
    }

    /// A child's last-known available play-minutes. For my own active profile that's
    /// the live wallet; for a sibling it's their last-synced snapshot in the vault.
    func availableMinutes(of childID: UUID) -> Int {
        if childID == ProfileStore.shared.activeID { return ProgressStore.shared.pendingMinutes }
        return ProgressVault.shared.snapshot(for: childID).pendingMinutes
    }

    // MARK: - Buyer

    /// BUYER initiates: validate, escrow the diamonds locally, and post the
    /// request for parent approval. Returns a Hebrew error string on failure, nil
    /// on success.
    @discardableResult
    func requestPurchase(from seller: Profile, minutes: Int) -> String? {
        guard ParentSettings.shared.siblingTransferEnabled else { return "התכונה כבויה" }
        guard minutes > 0 else { return "בחרו כמה דקות" }
        guard let myID = currentChildID else { return "אי אפשר לקנות מהמכשיר הזה" }
        guard myID != seller.id else { return "אי אפשר לקנות מעצמך" }
        #if canImport(FirebaseFirestore)
        guard let hh = HouseholdManager.shared.household else { return "אין משפחה מחוברת" }
        let cost = price(forMinutes: minutes)
        guard ProgressStore.shared.diamonds >= cost else { return "אין לך מספיק יהלומים 💎" }
        // The sibling must actually have the minutes to sell (last synced balance);
        // the seller re-checks at settle, but block here so we don't post a doomed
        // request. Read the sibling's wallet from the vault (mirrored from cloud).
        guard availableMinutes(of: seller.id) >= minutes else {
            return "לְ\(seller.name) אֵין מַסְפִּיק דַּקּוֹת לִמְכֹּר"
        }

        let buyerName = ProfileStore.shared.profiles.first { $0.id == myID }?.name ?? "אני"
        // Escrow: take the diamonds now so they can't be double-spent while pending.
        ProgressStore.shared.spendDiamonds(cost)

        let t = TimeTransfer(
            id: UUID().uuidString,
            householdID: hh.id,
            fromChildID: seller.id.uuidString,
            toChildID: myID.uuidString,
            fromName: seller.name,
            toName: buyerName,
            minutes: minutes,
            diamondPrice: cost,
            status: .pendingParent,
            createdAt: Date().timeIntervalSince1970
        )
        guard let data = Self.encode(t) else {
            ProgressStore.shared.addDiamonds(cost)   // undo escrow on encode failure
            return "שגיאה ביצירת הבקשה"
        }
        db.collection("timeTransfers").document(t.id).setData(data)
        AppAnalytics.log("sibling_transfer_requested", ["minutes": "\(minutes)"])
        return nil
        #else
        return "לא זמין"
        #endif
    }

    /// GIVER initiates a free gift: validate they have the minutes, then post the
    /// request for parent approval. No diamonds change hands (price 0), so the
    /// existing settlement just moves minutes giver → recipient. Returns a Hebrew
    /// error string on failure, nil on success.
    @discardableResult
    func requestGift(to recipient: Profile, minutes: Int) -> String? {
        guard ParentSettings.shared.siblingTransferEnabled else { return "התכונה כבויה" }
        guard minutes > 0 else { return "בחרו כמה דקות" }
        guard let myID = currentChildID else { return "אי אפשר מהמכשיר הזה" }
        guard myID != recipient.id else { return "אי אפשר לתת לעצמך" }
        #if canImport(FirebaseFirestore)
        guard let hh = HouseholdManager.shared.household else { return "אין משפחה מחוברת" }
        // The giver must actually have the minutes (checked again at settle).
        guard ProgressStore.shared.pendingMinutes >= minutes else { return "אין לך מספיק דקות 🎮" }

        let giverName = ProfileStore.shared.profiles.first { $0.id == myID }?.name ?? "אני"
        let t = TimeTransfer(
            id: UUID().uuidString,
            householdID: hh.id,
            fromChildID: myID.uuidString,        // giver — loses minutes
            toChildID: recipient.id.uuidString,  // recipient — gains minutes
            fromName: giverName,
            toName: recipient.name,
            minutes: minutes,
            diamondPrice: 0,                     // free gift
            status: .pendingParent,
            createdAt: Date().timeIntervalSince1970
        )
        guard let data = Self.encode(t) else { return "שגיאה ביצירת הבקשה" }
        db.collection("timeTransfers").document(t.id).setData(data)
        AppAnalytics.log("sibling_gift_requested", ["minutes": "\(minutes)"])
        return nil
        #else
        return "לא זמין"
        #endif
    }

    // MARK: - Parent

    func approve(_ t: TimeTransfer) {
        setStatus(t, to: .approved)
        AppAnalytics.log("sibling_transfer_approved", ["minutes": "\(t.minutes)"])
    }

    func reject(_ t: TimeTransfer) {
        setStatus(t, to: .rejected)
        AppAnalytics.log("sibling_transfer_rejected", [:])
    }

    /// Buyer (while still pending) or parent can cancel → triggers a refund.
    func cancel(_ t: TimeTransfer) {
        setStatus(t, to: .canceled)
    }

    private func setStatus(_ t: TimeTransfer, to status: TimeTransfer.Status) {
        #if canImport(FirebaseFirestore)
        db.collection("timeTransfers").document(t.id).setData([
            "status": status.rawValue,
            "decidedAt": Date().timeIntervalSince1970,
        ], merge: true)
        #endif
    }

    // MARK: - Listener + dispatch

    #if canImport(FirebaseFirestore)
    private func attach(householdID: String?) {
        listener?.remove(); listener = nil
        pendingForParent = []; myTransfers = []; allTransfers = []
        guard let hh = householdID else { return }
        listener = db.collection("timeTransfers")
            .whereField("householdID", isEqualTo: hh)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                let all = snap.documents.compactMap { Self.decode($0.data()) }
                Task { @MainActor in self.handle(all) }
            }
    }

    private func handle(_ all: [TimeTransfer]) {
        allTransfers = all.sorted { $0.createdAt > $1.createdAt }
        pendingForParent = all.filter { $0.status == .pendingParent }
            .sorted { $0.createdAt < $1.createdAt }
        if let mine = currentChildID?.uuidString {
            myTransfers = all.filter { $0.fromChildID == mine || $0.toChildID == mine }
                .sorted { $0.createdAt > $1.createdAt }
        } else {
            myTransfers = []
        }
        for t in all { dispatchSideEffects(t) }
    }

    /// Apply whatever this device owns for a transfer in its current state.
    private func dispatchSideEffects(_ t: TimeTransfer) {
        guard let myID = currentChildID?.uuidString else { return }
        guard !inFlight.contains(t.id) else { return }

        // SELLER: an approved request I sold → settle it.
        if t.fromChildID == myID, t.status == .approved, !t.sellerSettled {
            settleAsSeller(t); return
        }
        // BUYER: my purchase completed → credit the minutes I bought.
        if t.toChildID == myID, t.status == .completed, !t.buyerCredited {
            creditBuyer(t); return
        }
        // BUYER: my purchase failed/rejected/canceled → refund my diamonds.
        if t.toChildID == myID, t.isRefundable, !t.buyerRefunded {
            refundBuyer(t); return
        }
    }

    /// SELLER device: claim the settlement in a transaction (so it happens once),
    /// then move the local wallet. If the minutes are no longer available, mark
    /// the transfer failed so the buyer gets refunded.
    private func settleAsSeller(_ t: TimeTransfer) {
        // The seller must still actually have the minutes (they may have played
        // them while the request was pending). Checked against the live local store.
        guard ProgressStore.shared.pendingMinutes >= t.minutes else {
            setStatus(t, to: .failed)
            return
        }
        inFlight.insert(t.id)
        let ref = db.collection("timeTransfers").document(t.id)
        db.runTransaction({ txn, _ -> Any? in
            let doc = try? txn.getDocument(ref)
            let status = (doc?.data()?["status"] as? String) ?? ""
            let settled = (doc?.data()?["sellerSettled"] as? Bool) ?? false
            guard status == TimeTransfer.Status.approved.rawValue, !settled else { return false }
            txn.updateData([
                "sellerSettled": true,
                "status": TimeTransfer.Status.completed.rawValue,
                "settledAt": Date().timeIntervalSince1970,
            ], forDocument: ref)
            return true
        }) { [weak self] result, _ in
            Task { @MainActor in
                guard let self else { return }
                self.inFlight.remove(t.id)
                guard (result as? Bool) == true else { return }
                // Seller side of the trade: minutes out, diamonds in.
                ProgressStore.shared.addPendingMinutes(-t.minutes)
                ProgressStore.shared.addDiamonds(t.diamondPrice)
                Haptic.success()
            }
        }
    }

    /// BUYER device: claim the credit once, then add the bought minutes.
    private func creditBuyer(_ t: TimeTransfer) {
        inFlight.insert(t.id)
        let ref = db.collection("timeTransfers").document(t.id)
        db.runTransaction({ txn, _ -> Any? in
            let doc = try? txn.getDocument(ref)
            let credited = (doc?.data()?["buyerCredited"] as? Bool) ?? false
            guard !credited else { return false }
            txn.updateData(["buyerCredited": true], forDocument: ref)
            return true
        }) { [weak self] result, _ in
            Task { @MainActor in
                guard let self else { return }
                self.inFlight.remove(t.id)
                guard (result as? Bool) == true else { return }
                ProgressStore.shared.addPendingMinutes(t.minutes)
                Haptic.success()
            }
        }
    }

    /// BUYER device: claim the refund once, then return the escrowed diamonds.
    private func refundBuyer(_ t: TimeTransfer) {
        inFlight.insert(t.id)
        let ref = db.collection("timeTransfers").document(t.id)
        db.runTransaction({ txn, _ -> Any? in
            let doc = try? txn.getDocument(ref)
            let refunded = (doc?.data()?["buyerRefunded"] as? Bool) ?? false
            guard !refunded else { return false }
            txn.updateData(["buyerRefunded": true], forDocument: ref)
            return true
        }) { [weak self] result, _ in
            Task { @MainActor in
                guard let self else { return }
                self.inFlight.remove(t.id)
                guard (result as? Bool) == true else { return }
                ProgressStore.shared.addDiamonds(t.diamondPrice)
            }
        }
    }

    // MARK: - Encode / decode (Firestore-friendly, no FIRTimestamp)

    private static func encode(_ t: TimeTransfer) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(t),
              let any = try? JSONSerialization.jsonObject(with: data),
              let dict = any as? [String: Any] else { return nil }
        return dict
    }

    private static func decode(_ raw: [String: Any]) -> TimeTransfer? {
        guard let data = try? JSONSerialization.data(withJSONObject: raw),
              let t = try? JSONDecoder().decode(TimeTransfer.self, from: data) else { return nil }
        return t
    }
    #endif
}
