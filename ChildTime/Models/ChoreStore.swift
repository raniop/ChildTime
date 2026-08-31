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
    var createdAt: Double
    var markedDoneAt: Double?
    /// "minutes" | "coins" — the KID's pick, made when marking done.
    var chosenReward: String?
    var lastApprovedAt: Double?
    var archived: Bool

    var isPendingApproval: Bool { markedDoneAt != nil }
    var approvedToday: Bool {
        guard let t = lastApprovedAt else { return false }
        return Calendar.current.isDateInToday(Date(timeIntervalSince1970: t))
    }
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
                     createdAt: data["createdAt"] as? Double ?? 0,
                     markedDoneAt: data["markedDoneAt"] as? Double,
                     chosenReward: data["chosenReward"] as? String,
                     lastApprovedAt: data["lastApprovedAt"] as? Double,
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

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
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
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        listeningHousehold = nil
        #endif
        chores = []
    }

    func chores(forChild id: UUID) -> [Chore] {
        chores.filter { $0.childID == id.uuidString && !$0.archived }
    }

    /// Chores across the family waiting for a parent's approval.
    var pendingApproval: [Chore] {
        chores.filter { $0.isPendingApproval }
    }

    // MARK: - Parent actions

    func addChore(childID: UUID, title: String, emoji: String,
                  rewardMinutes: Int, rewardCoins: Int, isDaily: Bool) {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold ?? HouseholdManager.shared.household?.id else { return }
        db.collection("households").document(hh).collection("chores").document()
            .setData(["childID": childID.uuidString,
                      "title": title,
                      "emoji": emoji,
                      "rewardMinutes": rewardMinutes,
                      "rewardCoins": rewardCoins,
                      "isDaily": isDaily,
                      "createdAt": Date().timeIntervalSince1970])
        #endif
    }

    func deleteChore(_ chore: Chore) {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold else { return }
        db.collection("households").document(hh).collection("chores").document(chore.id).delete()
        #endif
    }

    /// Parent confirms the chore was fully done → fire the reward the KID chose
    /// as a delta command (exactly-once consumption on the child's device), then
    /// reset/archive the chore doc.
    func approve(_ chore: Chore) {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold, let cid = UUID(uuidString: chore.childID) else { return }
        if chore.chosenReward == "coins", chore.rewardCoins > 0 {
            RemoteSyncManager.shared.adjustChildMoney(childID: cid, deltaCoins: chore.rewardCoins)
        } else if chore.rewardMinutes > 0 {
            RemoteSyncManager.shared.adjustChildMinutes(childID: cid, deltaMinutes: chore.rewardMinutes)
        }
        var update: [String: Any] = ["markedDoneAt": FieldValue.delete(),
                                     "chosenReward": FieldValue.delete(),
                                     "lastApprovedAt": Date().timeIntervalSince1970]
        if !chore.isDaily { update["archived"] = true }
        db.collection("households").document(hh).collection("chores").document(chore.id)
            .updateData(update)
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
                         "returnedAt": Date().timeIntervalSince1970])
        #endif
    }

    /// Parent paid the pocket by hand → subtract what was just paid (a delta
    /// command like everything else; the child-side pocket clamps at ≥0).
    func settleMoney(childID: UUID, amount: Int) {
        guard amount > 0 else { return }
        RemoteSyncManager.shared.adjustChildMoney(childID: childID, deltaCoins: -amount)
    }

    // MARK: - Kid action

    /// The kid marks the chore done AND picks the reward they want.
    func markDone(_ chore: Chore, reward: String) {
        #if canImport(FirebaseFirestore)
        guard let hh = listeningHousehold else { return }
        db.collection("households").document(hh).collection("chores").document(chore.id)
            .updateData(["markedDoneAt": Date().timeIntervalSince1970,
                         "chosenReward": reward])
        #endif
    }
}
