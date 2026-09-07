import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// One "ask a parent for help" round-trip, stored at `helpRequests/{id}`.
///
/// Flow: the child creates a request with the current question + the correct
/// answer + ONE distractor (the two options the parent will see). A Cloud
/// Function pushes the chosen parent an interactive notification; the parent
/// taps one option straight from the notification, which writes `keptOption` +
/// `removedOption` back here. The child listens and removes `removedOption`
/// from the on-screen choices — so the kid still answers, just with a hint.
struct HelpRequest: Identifiable {
    var id: String
    var childID: String
    var childName: String
    var parentUID: String
    var householdID: String
    var topic: String
    var question: String
    /// The two options shown to the parent: [correctAnswer, distractor], in a
    /// fixed order so action identifiers map back cleanly.
    var optionA: String
    var optionB: String
    var correctAnswer: String
    /// The device that asked (a child play-device) — may close its own request.
    var fromUID: String = ""
    var gender: String = ""
    var createdAt: TimeInterval = Date().timeIntervalSince1970
    /// Set by the parent's notification tap (the option they kept). nil = pending.
    var keptOption: String?
    /// The option to remove from the child's screen (the one the parent didn't keep).
    var removedOption: String?

    var isAnswered: Bool { keptOption != nil }

    var firestoreData: [String: Any] {
        [
            "childID": childID,
            "childName": childName,
            "parentUID": parentUID,
            "householdID": householdID,
            "topic": topic,
            "question": question,
            "optionA": optionA,
            "optionB": optionB,
            "correctAnswer": correctAnswer,
            "fromUID": fromUID,
            "gender": gender,
            "status": "pending",
            "createdAt": createdAt,
        ]
    }

    /// A pending request as read back on a PARENT device.
    init?(id: String, data: [String: Any]) {
        guard let question = data["question"] as? String,
              let a = data["optionA"] as? String, let b = data["optionB"] as? String else { return nil }
        self.id = id
        childID = data["childID"] as? String ?? ""
        childName = data["childName"] as? String ?? "הילד"
        parentUID = data["parentUID"] as? String ?? ""
        householdID = data["householdID"] as? String ?? ""
        topic = data["topic"] as? String ?? ""
        self.question = question
        optionA = a; optionB = b
        correctAnswer = data["correctAnswer"] as? String ?? ""
        fromUID = data["fromUID"] as? String ?? ""
        gender = data["gender"] as? String ?? ""
        createdAt = data["createdAt"] as? TimeInterval ?? 0
        keptOption = data["keptOption"] as? String
        removedOption = data["removedOption"] as? String
    }

    init(id: String, childID: String, childName: String, parentUID: String, householdID: String,
         topic: String, question: String, optionA: String, optionB: String, correctAnswer: String,
         fromUID: String = "", gender: String = "") {
        self.id = id; self.childID = childID; self.childName = childName; self.parentUID = parentUID
        self.householdID = householdID; self.topic = topic; self.question = question
        self.optionA = optionA; self.optionB = optionB; self.correctAnswer = correctAnswer
        self.fromUID = fromUID; self.gender = gender
    }

    var isGirl: Bool { gender == "girl" }
}

/// Creates help requests and listens for the parent's reply in real time.
@MainActor
final class ParentHelpManager: ObservableObject {
    static let shared = ParentHelpManager()
    private init() {}

    /// The most recent reply for the active request (option to remove + which the
    /// parent kept), published so the question screen can react instantly.
    @Published var lastReply: (removed: String, kept: String)? = nil
    @Published var lastError: String?
    /// The question text of the open request, so the question screen can tell a
    /// reply for THIS question from one that arrived after the kid moved on.
    @Published private(set) var activeQuestion: String?

    // ---- Parent side --------------------------------------------------------
    /// Open requests addressed to this parent (or to "all" parents), newest
    /// first — the dashboard shows a banner and an answer sheet for them.
    @Published var pendingForParent: [HelpRequest] = []
    /// A request the parent should see RIGHT NOW (tapped its notification).
    @Published var promptedRequest: HelpRequest?

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    #endif

    private var activeRequestID: String?
    var hasActiveRequest: Bool { activeRequestID != nil }

    /// Create a help request targeting one parent. Returns the request id (nil if
    /// Firestore isn't available). `distractor` is the wrong option the parent
    /// sees alongside the correct answer.
    @discardableResult
    func requestHelp(childID: String, childName: String, parentUID: String,
                     householdID: String, topic: Topic,
                     question: String, correctAnswer: String, distractor: String,
                     gender: String = "") -> String? {
        #if canImport(FirebaseFirestore)
        expireActiveRequest()
        // Randomize which slot the correct answer sits in so the parent can't just
        // always tap the same button.
        let correctFirst = Bool.random()
        var req = HelpRequest(
            id: "", childID: childID, childName: childName, parentUID: parentUID,
            householdID: householdID, topic: topic.rawValue, question: question,
            optionA: correctFirst ? correctAnswer : distractor,
            optionB: correctFirst ? distractor : correctAnswer,
            correctAnswer: correctAnswer,
            fromUID: AuthManager.shared.userID ?? "", gender: gender)
        let ref = db.collection("helpRequests").document()
        req.id = ref.documentID
        ref.setData(req.firestoreData)
        activeRequestID = ref.documentID
        activeQuestion = question
        lastReply = nil
        listenForReply(ref.documentID)
        AppAnalytics.log("parent_help_requested", ["topic": topic.rawValue])
        return ref.documentID
        #else
        return nil
        #endif
    }

    private func listenForReply(_ id: String) {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        let createdAt = Date()
        listener = db.collection("helpRequests").document(id)
            .addSnapshotListener { [weak self] snap, error in
                if let error { print("[ParentHelp] listen failed: \(error.localizedDescription)") }
                guard let self, let data = snap?.data(),
                      let kept = data["keptOption"] as? String,
                      let removed = data["removedOption"] as? String else { return }
                Task { @MainActor in
                    self.lastReply = (removed: removed, kept: kept)
                    let seconds = Int(Date().timeIntervalSince(createdAt))
                    AppAnalytics.log("parent_help_answered",
                                     ["topic": (data["topic"] as? String) ?? "",
                                      "response_seconds": "\(seconds)"])
                    self.stopListening()
                }
            }
        #endif
    }

    func stopListening() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
        activeRequestID = nil
    }

    /// The kid moved on (next question / left the session) while the request was
    /// still open: close it so it leaves the parent's banner. A parent who still
    /// taps the notification gets a gentle "already solved" instead of a hint
    /// that lands on the wrong question.
    func expireActiveRequest() {
        guard let id = activeRequestID else { return }
        #if canImport(FirebaseFirestore)
        db.collection("helpRequests").document(id)
            .setData(["status": "expired", "expiredAt": Date().timeIntervalSince1970], merge: true)
        #endif
        stopListening()
        activeQuestion = nil
    }

    // MARK: - Parent side

    #if canImport(FirebaseFirestore)
    private var parentListener: ListenerRegistration?
    private var parentListenerHousehold: String?
    #endif

    /// Watch the household's open help requests (parent devices only). Safe to
    /// call repeatedly; re-subscribes when the household changes.
    func startParentListener(householdID: String?) {
        #if canImport(FirebaseFirestore)
        guard let householdID, !householdID.isEmpty else { return }
        if parentListenerHousehold == householdID, parentListener != nil { return }
        parentListener?.remove()
        parentListenerHousehold = householdID
        parentListener = db.collection("helpRequests")
            .whereField("householdID", isEqualTo: householdID)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snap, error in
                if let error { print("[ParentHelp] parent listen failed: \(error.localizedDescription)"); return }
                guard let self, let docs = snap?.documents else { return }
                let me = AuthManager.shared.userID ?? ""
                let cutoff = Date().timeIntervalSince1970 - 2 * 3600   // an hour-old request is stale
                let mine = docs.compactMap { HelpRequest(id: $0.documentID, data: $0.data()) }
                    .filter { ($0.parentUID == me || $0.parentUID == "all") && $0.fromUID != me && $0.createdAt > cutoff }
                    .sorted { $0.createdAt > $1.createdAt }
                Task { @MainActor in
                    self.pendingForParent = mine
                    // The prompted sheet closes itself once its request is gone.
                    if let p = self.promptedRequest, !mine.contains(where: { $0.id == p.id }),
                       p.parentUID != "demo" { self.promptedRequest = nil }
                }
            }
        #endif
    }

    /// The parent kept `kept`; the other option leaves the child's screen. Shared
    /// by the notification button and the in-app sheet. Awaitable so the
    /// background notification path can hold the app alive until it lands.
    func answer(requestID: String, kept: String, removed: String) async -> Bool {
        guard !kept.isEmpty, !removed.isEmpty else { return false }
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("helpRequests").document(requestID).setData([
                "keptOption": kept,
                "removedOption": removed,
                "status": "answered",
                "respondedByUID": AuthManager.shared.userID ?? "",
                "respondedAt": Date().timeIntervalSince1970,
            ], merge: true)
        } catch {
            print("[ParentHelp] write-back failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return false
        }
        #endif
        pendingForParent.removeAll { $0.id == requestID }
        if promptedRequest?.id == requestID { promptedRequest = nil }
        return true
    }

    /// "לא עכשיו" — hide the request on every parent device without answering.
    func dismiss(requestID: String) {
        #if canImport(FirebaseFirestore)
        db.collection("helpRequests").document(requestID)
            .setData(["status": "dismissed", "dismissedAt": Date().timeIntervalSince1970], merge: true)
        #endif
        pendingForParent.removeAll { $0.id == requestID }
        if promptedRequest?.id == requestID { promptedRequest = nil }
    }

    /// A tapped help notification (not one of its buttons): open the answer
    /// sheet straight away, built from the push payload so it works before the
    /// listener has caught up.
    func prompt(fromPush info: [AnyHashable: Any]) {
        guard let id = info["helpRequestID"] as? String else { return }
        let data: [String: Any] = [
            "question": info["question"] as? String ?? "",
            "optionA": info["optionA"] as? String ?? "",
            "optionB": info["optionB"] as? String ?? "",
            "correctAnswer": info["correctAnswer"] as? String ?? "",
            "childName": info["childName"] as? String ?? "הילד",
            "topic": info["topic"] as? String ?? "",
            "gender": info["gender"] as? String ?? "",
            "createdAt": Date().timeIntervalSince1970,
        ]
        if let req = HelpRequest(id: id, data: data) { promptedRequest = req }
    }

    /// A sample request for DEMO_SCREEN=parenthelp screenshots.
    static var demoRequest: HelpRequest {
        HelpRequest(id: "demo", childID: "", childName: "נועה", parentUID: "demo", householdID: "",
                    topic: Topic.math.rawValue, question: "כמה זה 7 + 8?",
                    optionA: "15", optionB: "13", correctAnswer: "15", gender: "girl")
    }
}
