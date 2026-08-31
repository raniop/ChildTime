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

    private init() {}

    /// Idempotent — (re)attach the listener to the current household. Views call
    /// this on appear; it re-binds automatically if the family changed.
    func startIfNeeded() {
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync else { return }
        guard let hh = HouseholdManager.shared.household?.id else { return }
        guard hh != listeningHousehold else { return }
        listener?.remove()
        listeningHousehold = hh
        listener = db.collection("households").document(hh).collection("chores")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                let parsed = snap.documents.compactMap { Chore.from(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.createdAt < $1.createdAt }
                Task { @MainActor in self.chores = parsed }
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
        ("preset-sibling",   "👫", "לשחק עם אח או אחות",       10,  5, 2),
        ("preset-outfit",    "🎽", "לסדר תלבושת לבית הספר",     5,  2, 1),
        ("preset-closet",    "🧥", "לסדר את הארון",            15,  7, 1),
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
                      "chosenReward": FieldValue.delete()], merge: true)
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

    /// Parent confirms the chore was fully done → fire the reward the KID chose
    /// as a delta command (exactly-once consumption on the child's device), then
    /// reset/archive the chore doc.
    func approve(_ chore: Chore) {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold, let cid = UUID(uuidString: chore.childID) else { return }
        let coins = chore.chosenReward == "coins" && chore.rewardCoins > 0
        // Minutes ride the proven earned-wallet command; money lives ONLY in
        // the increment-based ledger below (see `stats` — snapshot fields die
        // under old-build pushes).
        if !coins && chore.rewardMinutes > 0 {
            RemoteSyncManager.shared.adjustChildMinutes(childID: cid, deltaMinutes: chore.rewardMinutes)
        }
        let now = Date().timeIntervalSince1970
        var update: [String: Any] = ["markedDoneAt": FieldValue.delete(),
                                     "chosenReward": FieldValue.delete(),
                                     "photoData": FieldValue.delete(),
                                     "lastApprovedAt": now,
                                     // same-day repeat counter ("לפנות את הצלחת"
                                     // can legitimately happen every meal — Rani)
                                     "approvedTodayCount": chore.doneToday + 1,
                                     "approvedTodayAt": now]
        if !chore.isDaily { update["archived"] = true }
        db.collection("households").document(hh).collection("chores").document(chore.id)
            .updateData(update)
        // Money + lifetime-earnings ledger — what the kid sees as "הרווחתי".
        db.collection("households").document(hh).collection("choreStats").document(chore.childID)
            .setData([coins ? "coinsTotal" : "minutesTotal":
                      FieldValue.increment(Int64(coins ? chore.rewardCoins : chore.rewardMinutes))],
                     merge: true)
        #endif
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
                         "returnedAt": Date().timeIntervalSince1970])
        #endif
    }

    /// Parent paid the kid by hand → record it in the ledger (increment-only,
    /// old-build-proof). Balance shown everywhere = coinsTotal − coinsPaid.
    func settleMoney(childID: UUID, amount: Int) {
        #if canImport(FirebaseFirestore)
        guard amount > 0, let hh = listeningHousehold else { return }
        db.collection("households").document(hh).collection("choreStats").document(childID.uuidString)
            .setData(["coinsPaid": FieldValue.increment(Int64(amount))], merge: true)
        #endif
    }

    // MARK: - Kid action

    /// The kid marks the chore done AND picks the reward they want. A catalog
    /// chore may not have a doc yet — setData(merge) materializes it with its
    /// current (default or overridden) values in the same write.
    func markDone(_ chore: Chore, reward: String, photo: Data? = nil) {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold else { return }
        var fields: [String: Any] = ["childID": chore.childID,
                                     "title": chore.title,
                                     "emoji": chore.emoji,
                                     "rewardMinutes": chore.rewardMinutes,
                                     "rewardCoins": chore.rewardCoins,
                                     "isDaily": chore.isDaily,
                                     "timesPerDay": chore.timesPerDay,
                                     "createdAt": chore.createdAt > 0 ? chore.createdAt : Date().timeIntervalSince1970,
                                     "markedDoneAt": Date().timeIntervalSince1970,
                                     "chosenReward": reward]
        // 📸 proof photo — replace or clear any stale one from a previous round.
        fields["photoData"] = photo ?? FieldValue.delete()
        db.collection("households").document(hh).collection("chores").document(chore.id)
            .setData(fields, merge: true)
        #endif
    }
}
