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
struct HelpRequest {
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
            "status": "pending",
            "createdAt": Date().timeIntervalSince1970,
        ]
    }
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

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    #endif

    private var activeRequestID: String?

    /// Create a help request targeting one parent. Returns the request id (nil if
    /// Firestore isn't available). `distractor` is the wrong option the parent
    /// sees alongside the correct answer.
    @discardableResult
    func requestHelp(childID: String, childName: String, parentUID: String,
                     householdID: String, topic: Topic,
                     question: String, correctAnswer: String, distractor: String) -> String? {
        #if canImport(FirebaseFirestore)
        // Randomize which slot the correct answer sits in so the parent can't just
        // always tap the same button.
        let correctFirst = Bool.random()
        var req = HelpRequest(
            id: "", childID: childID, childName: childName, parentUID: parentUID,
            householdID: householdID, topic: topic.rawValue, question: question,
            optionA: correctFirst ? correctAnswer : distractor,
            optionB: correctFirst ? distractor : correctAnswer,
            correctAnswer: correctAnswer)
        let ref = db.collection("helpRequests").document()
        req.id = ref.documentID
        ref.setData(req.firestoreData)
        activeRequestID = ref.documentID
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
            .addSnapshotListener { [weak self] snap, _ in
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
}
