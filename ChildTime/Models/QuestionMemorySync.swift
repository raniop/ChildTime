import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// 🔁 Shares `QuestionMemory` between a child's devices (Rani, 2026-10-17): a
/// question asked on the iPad isn't asked again on the phone.
///
/// One document per child, `children/{id}/memory/questions`:
///
///     t: { <topic>: { <fingerprint>: <seconds since 1970>, … }, … }
///     coverage: { <topic>: { seen, pool, at } }   — for the founder dashboard's
///                                                  "running out of questions"
///
/// Each device adds the questions it asked as a merge, field by field, so two
/// devices writing at once never erase each other; reading takes the later
/// time per question. Writes are gathered for a few seconds and sent together.
/// Never in the demo tour, a DEMO_SCREEN run or tests (`skipsCloudSync`).
enum QuestionMemorySync {
    #if canImport(FirebaseFirestore)
    private static let lock = NSLock()
    private static var pending: [String: [String: Double]] = [:]
    private static var pendingCoverage: [String: [String: Any]] = [:]
    private static var pendingChild: String?
    private static var flushScheduled = false
    /// A denied read/write (a profile that isn't a cloud child) — stop trying
    /// for this child until the app restarts.
    private static var refused: Set<String> = []

    private static var childID: String? {
        guard !HouseholdManager.skipsCloudSync, AuthManager.shared.isSignedIn,
              let id = ProfileStore.shared.activeID?.uuidString else { return nil }
        return id
    }

    private static func ref(_ child: String) -> DocumentReference {
        Firestore.firestore().collection("children").document(child)
            .collection("memory").document("questions")
    }
    #endif

    /// Fetch what the child's other devices asked and fold it in.
    static func pull() {
        #if canImport(FirebaseFirestore)
        guard let child = childID, !lock.withLock({ refused.contains(child) }) else { return }
        ref(child).getDocument { snap, error in
            if let error {
                if (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue {
                    lock.withLock { _ = refused.insert(child) }
                }
                return
            }
            guard let t = snap?.data()?["t"] as? [String: Any] else { return }
            var remote: [String: [String: Double]] = [:]
            for (topic, value) in t {
                guard let entries = value as? [String: Any] else { continue }
                remote[topic] = entries.compactMapValues { ($0 as? Double) ?? ($0 as? NSNumber)?.doubleValue }
            }
            DispatchQueue.main.async { QuestionMemory.shared.merge(remote: remote, forProfile: child) }
        }
        #endif
    }

    /// Queue one asked question; sent with the others a few seconds later.
    static func push(topic: String, fingerprint: String, at: Double) {
        #if canImport(FirebaseFirestore)
        guard let child = childID else { return }
        let schedule: Bool = lock.withLock {
            guard !refused.contains(child) else { return false }
            if pendingChild != child { pending = [:]; pendingCoverage = [:]; pendingChild = child }
            pending[topic, default: [:]][fingerprint] = at
            defer { flushScheduled = true }
            return !flushScheduled
        }
        if schedule {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { flush() }
        }
        #endif
    }

    /// How much of a world's pool this child has been asked — sent with the
    /// next batch (the dashboard warns from 80%).
    static func coverage(topic: String, seen: Int, pool: Int) {
        #if canImport(FirebaseFirestore)
        guard let child = childID else { return }
        lock.withLock {
            guard pendingChild == child || pendingChild == nil else { return }
            pendingChild = child
            pendingCoverage[topic] = ["seen": seen, "pool": pool, "at": Date().timeIntervalSince1970]
        }
        #endif
    }

    #if canImport(FirebaseFirestore)
    private static func flush() {
        let (child, batch, cover): (String?, [String: [String: Double]], [String: [String: Any]]) = lock.withLock {
            defer { pending = [:]; pendingCoverage = [:]; flushScheduled = false }
            return (pendingChild, pending, pendingCoverage)
        }
        guard let child, !batch.isEmpty else { return }
        var fields: [String: Any] = ["t": batch]
        if !cover.isEmpty { fields["coverage"] = cover }
        ref(child).setData(fields, merge: true) { error in
            if let error, (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue {
                lock.withLock { _ = refused.insert(child) }
            }
        }
    }
    #endif
}
