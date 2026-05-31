import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Lets a parent flag a question they think is bad. The question is hidden on
/// this device immediately (won't be shown again) and a report is sent to us so
/// we can fix or remove it from the banks for everyone.
@MainActor
final class QuestionReporter {
    static let shared = QuestionReporter()

    private let key = "reportedHiddenPrompts"
    private let defaults = UserDefaults.standard

    /// Prompts the parent reported — hidden from this device's question pool.
    private(set) var hidden: Set<String>

    private init() {
        hidden = Set(defaults.stringArray(forKey: key) ?? [])
    }

    func isHidden(_ prompt: String) -> Bool { hidden.contains(prompt) }

    /// Hide the question locally and send a report to the backend.
    func report(_ question: Question, reason: String? = nil) {
        hidden.insert(question.prompt)
        defaults.set(Array(hidden), forKey: key)
        AppAnalytics.log("question_reported", ["topic": question.topic.rawValue])

        #if canImport(FirebaseFirestore)
        var payload: [String: Any] = [
            "prompt": question.prompt,
            "correctAnswer": question.correctAnswer,
            "topic": question.topic.rawValue,
            "createdAt": Date().timeIntervalSince1970,
        ]
        payload["reportedBy"] = AuthManager.shared.userID ?? "anonymous"
        if let reason, !reason.isEmpty { payload["reason"] = reason }
        Firestore.firestore().collection("questionReports").addDocument(data: payload)
        #endif
    }
}
