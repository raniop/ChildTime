import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// 🧹 A house chore the parent defined for one child. The KID chooses which
/// reward they want when marking it done — play minutes (⏰, lands in the earned
/// wallet via the `pendingMinuteAdjustment` command) or money (🪙, a tracked
/// pocket the parent settles by hand; no real money ever moves in-app).
///
/// Lifecycle: available → kid taps "עשיתי" (markedDoneAt + chosenReward) →
/// parent approves (reward command fires, lastApprovedAt set; one-time chores
/// archive, daily ones come back tomorrow) or returns it (fields cleared, no
/// failure language on the kid side).
struct Chore: Identifiable, Equatable {
    var id: String
    var childID: String
    var title: String
    var emoji: String
    /// ⏰ minutes option (0 = this chore doesn't offer minutes).
    var rewardMinutes: Int
    /// 🪙 whole-₪ option (0 = this chore doesn't offer money).
    var rewardCoins: Int
    /// true → comes back every day after approval; false → one-time.
    var isDaily: Bool
    /// How many times it can be done (and rewarded) per day — e.g. clearing
    /// the plate happens every meal (Rani). Daily chores only.
    var timesPerDay: Int
    var createdAt: Double
    var markedDoneAt: Double?
    /// "minutes" | "coins" — the KID's pick, made when marking done.
    var chosenReward: String?
    var lastApprovedAt: Double?
    /// 📸 Optional proof photo the kid attached when marking done (compressed
    /// JPEG, well under the 1MB doc cap). Cleared on approve/return so chore
    /// docs stay small.
    var photoData: Data?
    /// Rolling same-day approval counter (paired with its date).
    var approvedTodayCount: Int
    var approvedTodayAt: Double?
    var archived: Bool

    var isPendingApproval: Bool { markedDoneAt != nil }
    /// How many approvals landed TODAY (0 if the counter is from another day).
    var doneToday: Int {
        guard let t = approvedTodayAt,
              Calendar.current.isDateInToday(Date(timeIntervalSince1970: t)) else { return 0 }
        return approvedTodayCount
    }
    /// Finished for today — did it as many times as the day allows.
    var approvedToday: Bool { isDaily && doneToday >= max(1, timesPerDay) }
    /// The kid can do it now.
    var isAvailable: Bool {
        !archived && !isPendingApproval && !(isDaily && approvedToday)
    }

    static func from(id: String, data: [String: Any]) -> Chore? {
        guard let childID = data["childID"] as? String,
              let title = data["title"] as? String else { return nil }
        return Chore(id: id,
                     childID: childID,
                     title: title,
                     emoji: data["emoji"] as? String ?? "🧹",
                     rewardMinutes: data["rewardMinutes"] as? Int ?? 0,
                     rewardCoins: data["rewardCoins"] as? Int ?? 0,
                     isDaily: data["isDaily"] as? Bool ?? false,
                     timesPerDay: data["timesPerDay"] as? Int ?? 1,
                     createdAt: data["createdAt"] as? Double ?? 0,
                     markedDoneAt: data["markedDoneAt"] as? Double,
                     chosenReward: data["chosenReward"] as? String,
                     lastApprovedAt: data["lastApprovedAt"] as? Double,
                     photoData: data["photoData"] as? Data,
                     approvedTodayCount: data["approvedTodayCount"] as? Int ?? 0,
                     approvedTodayAt: data["approvedTodayAt"] as? Double,
                     archived: data["archived"] as? Bool ?? false)
    }
}

/// Live mirror of `households/{id}/chores` — separate docs, NOT part of the
/// progress snapshot, so the kid writing "עשיתי" and the parent writing the
/// approval never race the revision/LWW machinery. Both sides of the family can
/// read/write (child devices' uids are on the household's parentUIDs).
@MainActor
final class ChoreStore: ObservableObject {
    static let shared = ChoreStore()

    @Published private(set) var chores: [Chore] = []
    /// Per-child chore money ledger (uuid-string → totals), mirrored from
    /// `households/{id}/choreStats/{childID}`. THE source of truth for money:
    /// balance = coinsTotal − coinsPaid. Written only with FieldValue.increment,
    /// so a device on an older build can never strip it (unlike a snapshot
    /// field, which an old build\'s full-state push silently erases — that\'s
    /// how Noni\'s first ₪7 vanished).
    @Published private(set) var stats: [String: (minutes: Int, coins: Int, paid: Int)] = [:]

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    private var statsListener: ListenerRegistration?
    private var listeningHousehold: String?
    #endif
    private var householdSub: AnyCancellable?

    private init() {}

    /// Idempotent — (re)attach the listener to the current household. Views call
    /// this on appear; it re-binds automatically if the family changed.
    ///
    /// RACE FIX (Rani, on-device): the dashboard's onAppear often fires BEFORE
    /// the household finishes loading — the guard below bailed, nothing ever
    /// re-attached, and the chores banner stayed stale until the user happened
    /// to open the chores screen. Now the first call also subscribes to
    /// household changes, so the listener attaches the moment the family loads.
    func startIfNeeded() {
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync else { return }
        if householdSub == nil {
            householdSub = HouseholdManager.shared.$household
                .compactMap { $0?.id }
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.startIfNeeded() }
        }
        guard let hh = HouseholdManager.shared.household?.id else { return }
        guard hh != listeningHousehold else { return }
        listener?.remove()
        listeningHousehold = hh
        // Proactively re-assert this device's membership the moment we bind a
        // family. A child device whose anonymous uid drifted out of parentUIDs
        // would otherwise only self-heal AFTER a write is denied — which never
        // fires while offline. Healing up front means even an offline-queued
        // chore write is made under a valid membership and delivers on reconnect.
        Task { await HouseholdManager.shared.reassertMembership() }
        listener = db.collection("households").document(hh).collection("chores")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                let parsed = snap.documents.compactMap { Chore.from(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.createdAt < $1.createdAt }
                Task { @MainActor in
                    self.chores = parsed
                    WidgetBridge.refreshFamilySoon()   // 🧹 counts live on the widget
                }
            }
        statsListener?.remove()
        statsListener = db.collection("households").document(hh).collection("choreStats")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                var parsed: [String: (minutes: Int, coins: Int, paid: Int)] = [:]
                for d in snap.documents {
                    parsed[d.documentID] = (d.data()["minutesTotal"] as? Int ?? 0,
                                            d.data()["coinsTotal"] as? Int ?? 0,
                                            d.data()["coinsPaid"] as? Int ?? 0)
                }
                Task { @MainActor in self.stats = parsed }
            }
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        statsListener?.remove()
        statsListener = nil
        listeningHousehold = nil
        #endif
        chores = []
        stats = [:]
    }

    /// 🗂 Built-in catalog — EVERY child gets these automatically, no parent
    /// setup needed (Rani). Default rewards scale with chore size: small 5דק'/₪2,
    /// medium 10/5, bigger 15-20/7-10. The kid picks the chore AND the reward —
    /// a little trade with the parent; the parent can retune or hide any of
    /// them (an override doc with the same deterministic id takes precedence).
    static let catalog: [(key: String, emoji: String, title: String, minutes: Int, coins: Int, timesPerDay: Int)] = [
        ("preset-bed",       "🛏", "לסדר את המיטה",            5,  2, 1),
        ("preset-clothes",   "👕", "לשים בגדים בסל הכביסה",     5,  2, 2),
        ("preset-plate",     "🍽", "לפנות את הצלחת מהשולחן",    5,  2, 3),
        ("preset-shoes",     "👟", "לסדר את הנעליים בכניסה",    5,  2, 1),
        ("preset-toys",      "🧸", "לאסוף את הצעצועים",        10,  5, 1),
        ("preset-table",     "🍴", "לערוך את השולחן לארוחה",   10,  5, 3),
        ("preset-bag",       "🎒", "להכין את התיק לבית הספר",  10,  5, 1),
        ("preset-plants",    "🪴", "להשקות את העציצים",        10,  5, 1),
        ("preset-pet",       "🐕", "להאכיל את חיית המחמד",     10,  5, 2),
        ("preset-trash",     "🗑", "להוריד את הזבל",           10,  5, 1),
        ("preset-desk",      "📚", "לסדר את שולחן הכתיבה",     15,  7, 1),
        ("preset-sweep",     "🧹", "לטאטא את החדר",            20, 10, 1),
        ("preset-laundry",   "🧺", "לעזור בקיפול כביסה",       20, 10, 1),
        ("preset-groceries", "🛒", "לעזור בסידור הקניות",      20, 10, 1),
        ("preset-cooking",   "🍳", "לעזור בהכנת ארוחה",        20, 10, 1),
        ("preset-sibling",   "🎲", "לשחק עם אח או אחות",       10,  5, 2),
        ("preset-outfit",    "👔", "לסדר תלבושת לבית הספר",     5,  2, 1),
        ("preset-closet",    "🧥", "לסדר את הארון",            15,  7, 1),
        ("preset-homework",  "📝", "להכין שיעורי בית",         30, 20, 1),
        ("preset-reading",   "📖", "לקרוא ספר",                60, 50, 1),
        ("preset-leaves",    "🍂", "לאסוף עלים מהגינה",        30, 20, 1),
    ]

    /// The child's full list: the built-in catalog (overridden per-child by any
    /// doc with the matching deterministic id — retuned rewards, hidden, or
    /// in-progress state) plus the family's custom chores. All daily.
    func chores(forChild id: UUID) -> [Chore] {
        let docs = chores.filter { $0.childID == id.uuidString }
        var byID = Dictionary(uniqueKeysWithValues: docs.map { ($0.id, $0) })
        var out: [Chore] = []
        for preset in Self.catalog {
            let docID = "\(preset.key)_\(id.uuidString)"
            if let doc = byID.removeValue(forKey: docID) {
                if !doc.archived { out.append(doc) }   // archived = hidden by the parent
            } else {
                out.append(Chore(id: docID, childID: id.uuidString,
                                 title: preset.title, emoji: preset.emoji,
                                 rewardMinutes: preset.minutes, rewardCoins: preset.coins,
                                 isDaily: true, timesPerDay: preset.timesPerDay, createdAt: 0,
                                 markedDoneAt: nil, chosenReward: nil,
                                 lastApprovedAt: nil, photoData: nil,
                                 approvedTodayCount: 0, approvedTodayAt: nil,
                                 archived: false))
            }
        }
        out += byID.values.filter { !$0.archived }.sorted { $0.createdAt < $1.createdAt }
        return out
    }

    /// Lifetime chore earnings for one child.
    func totals(forChild id: UUID) -> (minutes: Int, coins: Int, paid: Int) {
        stats[id.uuidString] ?? (0, 0, 0)
    }

    /// 🪙 What the parents still owe: earned − already paid by hand.
    func moneyBalance(forChild id: UUID) -> Int {
        let t = totals(forChild: id)
        return max(0, t.coins - t.paid)
    }

    /// A catalog chore (vs. a custom one the family added). "Deleting" a preset
    /// only hides it — it must be possible to bring it back.
    static func isPreset(_ chore: Chore) -> Bool { chore.id.hasPrefix("preset-") }

    /// Chores across the family waiting for a parent's approval.
    var pendingApproval: [Chore] {
        chores.filter { $0.isPendingApproval }
    }

    // MARK: - Parent actions

    func addChore(childID: UUID, title: String, emoji: String,
                  rewardMinutes: Int, rewardCoins: Int, isDaily: Bool, timesPerDay: Int = 1) {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold ?? HouseholdManager.shared.household?.id else { return }
        db.collection("households").document(hh).collection("chores").document()
            .setData(["childID": childID.uuidString,
                      "title": title,
                      "emoji": emoji,
                      "rewardMinutes": rewardMinutes,
                      "rewardCoins": rewardCoins,
                      "isDaily": isDaily,
                      "timesPerDay": max(1, timesPerDay),
                      "createdAt": Date().timeIntervalSince1970])
        #endif
    }

    func deleteChore(_ chore: Chore) {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold else { return }
        db.collection("households").document(hh).collection("chores").document(chore.id).delete()
        #endif
    }

    /// Parent retunes a chore's rewards (or renames a custom one) — for catalog
    /// chores this writes/updates the per-child override doc.
    func updateChore(_ chore: Chore, title: String, emoji: String,
                     rewardMinutes: Int, rewardCoins: Int, timesPerDay: Int) {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold else { return }
        db.collection("households").document(hh).collection("chores").document(chore.id)
            .setData(["childID": chore.childID,
                      "title": title,
                      "emoji": emoji,
                      "rewardMinutes": rewardMinutes,
                      "rewardCoins": rewardCoins,
                      "isDaily": chore.isDaily,
                      "timesPerDay": max(1, timesPerDay),
                      "createdAt": chore.createdAt > 0 ? chore.createdAt : Date().timeIntervalSince1970],
                     merge: true)
        #endif
    }

    /// Parent hides a catalog chore for this child (custom chores get deleted
    /// outright via deleteChore).
    func hideChore(_ chore: Chore) {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold else { return }
        db.collection("households").document(hh).collection("chores").document(chore.id)
            .setData(["childID": chore.childID,
                      "title": chore.title,
                      "emoji": chore.emoji,
                      "rewardMinutes": chore.rewardMinutes,
                      "rewardCoins": chore.rewardCoins,
                      "isDaily": chore.isDaily,
                      "timesPerDay": chore.timesPerDay,
                      "createdAt": chore.createdAt > 0 ? chore.createdAt : Date().timeIntervalSince1970,
                      "archived": true,
                      "markedDoneAt": FieldValue.delete(),
                      "chosenReward": FieldValue.delete(),
                      "photoData": FieldValue.delete(),
                      "photoToken": FieldValue.delete()], merge: true)
        #endif
    }

    /// Hidden catalog chores for this child — so the parent can bring one back.
    func hiddenPresets(forChild id: UUID) -> [Chore] {
        chores.filter { $0.childID == id.uuidString && $0.archived && Self.isPreset($0) }
    }

    /// Un-hide a previously hidden catalog chore.
    func restoreChore(_ chore: Chore) {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold else { return }
        db.collection("households").document(hh).collection("chores").document(chore.id)
            .updateData(["archived": false])
        #endif
    }

    /// Parent confirms the chore was fully done. ONE Firestore transaction
    /// claims the chore (fails if it's no longer pending) and grants the reward
    /// — so two approvers (second parent, the notification button, a double
    /// tap) can never pay twice, and a partial failure can never leave a
    /// paid-but-still-pending chore.
    /// Set when an approval couldn't commit (permission/offline) so the parent
    /// UI can show an honest "try again" instead of the reward silently never
    /// landing while the chore just sits pending.
    @Published var lastActionFailed = false
    /// Chores whose approval is in flight (awaiting the server transaction) — the
    /// button shows "מאשר…" instead of feeling dead for the ~2s round-trip.
    @Published var approvingIDs: Set<String> = []

    func approve(_ chore: Chore) {
        guard let hh = listeningHousehold else { return }
        guard !approvingIDs.contains(chore.id) else { return }   // ignore double-taps
        approvingIDs.insert(chore.id)
        Task {
            var r = await Self.performApproval(householdID: hh, choreID: chore.id)
            // Only a genuine FAILURE warrants a self-heal + retry. `.alreadyResolved`
            // means another approver won — the chore is done; never alert on it.
            if r == .failed {
                await HouseholdManager.shared.reassertMembership()
                r = await Self.performApproval(householdID: hh, choreID: chore.id)
            }
            if r == .failed { self.lastActionFailed = true }
            self.approvingIDs.remove(chore.id)
        }
    }

    /// Outcome of an approval attempt — the caller must tell a genuine failure
    /// (offline/permission/txn error → show "try again") apart from LOSING the
    /// claim to another approver (`.alreadyResolved` → the chore WAS approved,
    /// stay silent), otherwise a concurrent second-parent/notification approve
    /// pops a false "approval failed" on a chore that was in fact paid.
    enum ApprovalResult { case won, alreadyResolved, failed }

    /// The transactional core, shared with the notification-button path.
    @discardableResult
    static func performApproval(householdID: String, choreID: String) async -> ApprovalResult {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let choreRef = db.collection("households").document(householdID)
            .collection("chores").document(choreID)
        return await withCheckedContinuation { cont in
            db.runTransaction({ txn, errorPointer -> Any? in
                guard let doc = try? txn.getDocument(choreRef), let d = doc.data(),
                      d["markedDoneAt"] != nil else {
                    return false   // already approved/returned elsewhere — lose gracefully
                }
                let childID = d["childID"] as? String ?? ""
                let rewardMinutes = d["rewardMinutes"] as? Int ?? 0
                let rewardCoins = d["rewardCoins"] as? Int ?? 0
                let coins = (d["chosenReward"] as? String) == "coins" && rewardCoins > 0
                let isDaily = d["isDaily"] as? Bool ?? false
                // Same-day repeat counter — safe to compute here: the txn serializes.
                let now = Date().timeIntervalSince1970
                var doneToday = 0
                if let t = d["approvedTodayAt"] as? Double,
                   Calendar.current.isDateInToday(Date(timeIntervalSince1970: t)) {
                    doneToday = d["approvedTodayCount"] as? Int ?? 0
                }
                var update: [String: Any] = ["markedDoneAt": FieldValue.delete(),
                                             "chosenReward": FieldValue.delete(),
                                             "photoData": FieldValue.delete(),
                                             "photoToken": FieldValue.delete(),
                                             "lastApprovedAt": now,
                                             "approvedTodayCount": doneToday + 1,
                                             "approvedTodayAt": now]
                if !isDaily { update["archived"] = true }
                txn.updateData(update, forDocument: choreRef)
                // Reward INSIDE the same transaction: money → increment ledger;
                // minutes → earned-wallet command (consumed exactly-once by the
                // kid's device).
                let statsRef = db.collection("households").document(householdID)
                    .collection("choreStats").document(childID)
                txn.setData([coins ? "coinsTotal" : "minutesTotal":
                             FieldValue.increment(Int64(coins ? rewardCoins : rewardMinutes))],
                            forDocument: statsRef, merge: true)
                if !coins && rewardMinutes > 0 && !childID.isEmpty {
                    let childRef = db.collection("children").document(childID)
                    txn.setData(["pendingMinuteAdjustment": FieldValue.increment(Int64(rewardMinutes))],
                                forDocument: childRef, merge: true)
                }
                return true
            }) { result, error in
                // error != nil → the transaction itself couldn't commit
                // (offline — transactions don't queue — / permission / conflict).
                if error != nil { cont.resume(returning: .failed) }
                else { cont.resume(returning: (result as? Bool) == true ? .won : .alreadyResolved) }
            }
        }
        #else
        return .failed
        #endif
    }

    /// 🔔 Approve straight from the notification button — the app is awake only
    /// briefly in the background, so every write is AWAITED (a queued-but-unsent
    /// write would vanish when iOS suspends us). Self-contained: takes the
    /// household from the push payload (the store's listener may never have
    /// started in this cold background launch).
    func approveFromPush(householdID: String, choreID: String) async {
        // Same claim-transaction as the in-app path — a race between the
        // notification button and another approver pays exactly once.
        await Self.performApproval(householdID: householdID, choreID: choreID)
    }

    /// Parent says "not quite done yet" — the chore simply returns to the kid's
    /// list, no reward and no failure language.
    func returnChore(_ chore: Chore) {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold else { return }
        db.collection("households").document(hh).collection("chores").document(chore.id)
            .updateData(["markedDoneAt": FieldValue.delete(),
                         "chosenReward": FieldValue.delete(),
                         "photoData": FieldValue.delete(),
                         "photoToken": FieldValue.delete(),
                         "returnedAt": Date().timeIntervalSince1970])
        #endif
    }

    /// Parent paid the kid by hand → settle the WHOLE balance transactionally
    /// (coinsPaid = server-side coinsTotal). Two parents tapping "שילמתי"
    /// together used to double-increment and silently swallow future earnings.
    func settleMoney(childID: UUID, amount: Int) {
        #if canImport(FirebaseFirestore)
        guard amount > 0, let hh = listeningHousehold else { return }
        let ref = db.collection("households").document(hh)
            .collection("choreStats").document(childID.uuidString)
        db.runTransaction({ txn, _ -> Any? in
            let d = (try? txn.getDocument(ref))?.data() ?? [:]
            let total = d["coinsTotal"] as? Int ?? 0
            txn.setData(["coinsPaid": total], forDocument: ref, merge: true)
            return nil
        }) { _, _ in }
        #endif
    }

    // MARK: - Kid action

    /// The outcome of a kid marking a chore done. Anything but `.failed`/
    /// `.notReady` means the parent WILL be told (`.queued` = accepted into the
    /// durable offline queue, delivers the moment the network returns).
    enum SendResult { case sent, queued, notReady, failed }

    /// The kid marks the chore done AND picks the reward they want. A catalog
    /// chore may not have a doc yet — setData(merge) materializes it with its
    /// current (default or overridden) values in the same write.
    ///
    /// CERTAINTY (Rani — "I need to KNOW it reached me, like gift minutes"):
    /// this awaits the server's acknowledgement instead of firing-and-forgetting.
    /// The old version returned `true` the instant it queued the write, so a
    /// rules rejection (a child device whose anonymous uid drifted out of the
    /// household — Noa) or a too-big photo doc silently vanished and the parent
    /// got NOTHING, while the kid saw a fake "נשלח!". Now:
    ///   • permission-denied → re-assert this device's membership and retry once;
    ///   • any other error with a photo attached (most likely the 1MB doc cap) →
    ///     retry WITHOUT the photo so the done-signal still lands (the parent is
    ///     notified; only the picture is dropped);
    ///   • no ack within the window → `.queued` (Firestore's durable local queue
    ///     guarantees eventual delivery — safe to celebrate).
    /// Returns `.notReady` only when the family truly isn't loaded yet.
    @discardableResult
    func markDone(_ chore: Chore, reward: String, photo: Data? = nil) async -> SendResult {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold ?? HouseholdManager.shared.household?.id else { return .notReady }
        let ref = db.collection("households").document(hh).collection("chores").document(chore.id)
        var base: [String: Any] = ["childID": chore.childID,
                                    "title": chore.title,
                                    "emoji": chore.emoji,
                                    "rewardMinutes": chore.rewardMinutes,
                                    "rewardCoins": chore.rewardCoins,
                                    "isDaily": chore.isDaily,
                                    "timesPerDay": chore.timesPerDay,
                                    "createdAt": chore.createdAt > 0 ? chore.createdAt : Date().timeIntervalSince1970,
                                    "markedDoneAt": Date().timeIntervalSince1970,
                                    "chosenReward": reward]
        // Clear any stale photo/token from a previous round by default.
        base["photoData"] = FieldValue.delete()
        base["photoToken"] = FieldValue.delete()
        var full = base
        if let photo, !photo.isEmpty { full["photoData"] = photo }

        // 1) Try the full write (photo included so the push can carry it).
        var outcome = await confirmedMerge(ref, full)
        // 2) Membership drifted → re-grant this device and retry once.
        if outcome == .denied {
            await HouseholdManager.shared.reassertMembership()
            outcome = await confirmedMerge(ref, full)
        }
        // 3) Non-permission error with a photo → almost certainly the 1MB doc
        //    cap. Land the done-signal photo-less rather than lose it entirely.
        if outcome == .error, photo != nil {
            outcome = await confirmedMerge(ref, base)
            if outcome == .denied {
                await HouseholdManager.shared.reassertMembership()
                outcome = await confirmedMerge(ref, base)
            }
        }
        switch outcome {
        case .ok:     return .sent
        case .queued: return .queued
        default:      return .failed
        }
        #else
        return .notReady
        #endif
    }
}
