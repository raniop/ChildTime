import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// What actually happened to a Firestore write — the difference the app cares
/// about is `queued` (durable, WILL deliver) vs `denied`/`error` (permanently
/// rejected, will NOT deliver without intervention). Conflating the two is what
/// let a rejected gift show the parent a false "saved offline, will auto-send"
/// (and let Noa's chores vanish with a fake "נשלח!").
enum ConfirmedWriteOutcome { case ok, queued, denied, error }

#if canImport(FirebaseFirestore)
/// One `setData(merge:)` that reports whether the SERVER accepted it.
///
/// Firestore's completion handler fires only when the write reaches the server;
/// while OFFLINE it never fires (the write sits in the durable local queue and
/// delivers when the network returns). So "no ack within `timeout`" is reported
/// as `.queued` — guaranteed eventual delivery, safe to treat as success — and
/// only a real server error is a problem to react to. permission-denied
/// (`NSError` code 7) is surfaced as `.denied` so callers can self-heal
/// household membership and retry.
func confirmedMerge(_ ref: DocumentReference,
                    _ fields: [String: Any],
                    timeout: TimeInterval = 3.0) async -> ConfirmedWriteOutcome {
    await withCheckedContinuation { (cont: CheckedContinuation<ConfirmedWriteOutcome, Never>) in
        let latch = WriteLatch()
        let assumeQueued = DispatchWorkItem {
            if latch.fire() { cont.resume(returning: .queued) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: assumeQueued)
        ref.setData(fields, merge: true) { err in
            assumeQueued.cancel()
            guard latch.fire() else { return }
            if let err = err as NSError? {
                cont.resume(returning: err.code == 7 /* permissionDenied */ ? .denied : .error)
            } else {
                cont.resume(returning: .ok)
            }
        }
    }
}
#endif

/// One-shot latch so the ack callback and the timeout can never both resume the
/// same continuation.
final class WriteLatch {
    private var fired = false
    private let lock = NSLock()
    /// Returns true for the FIRST caller only.
    func fire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if fired { return false }
        fired = true; return true
    }
}
