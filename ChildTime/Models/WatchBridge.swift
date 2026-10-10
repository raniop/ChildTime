import Combine
import Foundation
import UIKit
import WatchConnectivity

/// 📡 iPhone → Apple Watch: pushes a tiny per-child "family glance" via
/// `applicationContext` whenever the parent dashboard refreshes. The watch app
/// renders it as-is — no Firebase (or network) on the wrist for the glance.
/// applicationContext keeps only the LATEST payload and survives the watch
/// being offline, which is exactly the semantics a glance wants.
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    struct ChildGlance {
        let id: String
        let name: String
        let emoji: String
        let earnedToday: Int
        let playingNow: Bool
        let pendingChores: Int
        let moneyBalance: Int
        /// For the watch's wording ("משחקת" / "משחק").
        var girl: Bool = false
        /// A device of their own — the remote actions need one to reach.
        var hasDevice: Bool = false
        /// "🏠 בבית · לפני 3 דק׳" when location sharing is on.
        var whereText: String? = nil
    }

    private var started = false
    /// The most recent glance — held so a payload built BEFORE the session
    /// finished activating isn't lost (Rani's watch showed the empty state
    /// forever: the dashboard's one push raced activation and was dropped).
    private var lastPayload: [String: Any]?

    func startIfNeeded() {
        guard WCSession.isSupported(), !started else { return }
        started = true
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func pushFamilyGlance(_ rows: [ChildGlance]) {
        guard WCSession.isSupported() else { return }
        startIfNeeded()
        lastPayload = [
            "sentAt": Date().timeIntervalSince1970,
            "children": rows.map { ["id": $0.id,
                                    "name": $0.name,
                                    "emoji": $0.emoji,
                                    "earnedToday": $0.earnedToday,
                                    "playingNow": $0.playingNow,
                                    "pendingChores": $0.pendingChores,
                                    "moneyBalance": $0.moneyBalance,
                                    "girl": $0.girl,
                                    "hasDevice": $0.hasDevice,
                                    "where": $0.whereText ?? ""] },
        ]
        // 🌍 The watch can't read the phone's App Group — it follows the language
        // the phone sends with every snapshot.
        lastPayload?["language"] = LanguageStore.shared.current.rawValue
        if let lastActionStatus { lastPayload?["actionStatus"] = lastActionStatus }
        flush()
    }

    /// Re-send the last family snapshot (e.g. with a new language).
    func resendLastSnapshot() {
        lastPayload?["language"] = LanguageStore.shared.current.rawValue
        flush()
    }

    private func flush() {
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let payload = lastPayload else { return }
        try? session.updateApplicationContext(payload)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        // Activation is async — deliver the glance that may have raced it.
        DispatchQueue.main.async { WatchBridge.shared.flushAfterActivation() }
    }

    func flushAfterActivation() { flush() }

    // MARK: - ⚡ Actions from the watch (Rani, 2026-10-08)

    /// The watch has no Firebase: it asks the phone, and the phone does exactly
    /// what "⚡ פעולות" does — the same gift, lock and beep calls.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async { replyHandler(WatchBridge.shared.perform(message)) }
    }

    /// Queued while the phone was out of reach (transferUserInfo) — run on arrival.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async { _ = WatchBridge.shared.perform(userInfo) }
    }

    @discardableResult
    func perform(_ m: [String: Any]) -> [String: Any] {
        guard let action = m["action"] as? String,
              let cid = m["childID"] as? String, let id = UUID(uuidString: cid) else { return ["ok": false] }
        switch action {
        case "gift":
            // Each give is capped at what is left until midnight — like the phone.
            let want = m["minutes"] as? Int ?? 0
            let allowed = min(want, ProgressStore.minutesUntilMidnight())
            guard allowed > 0 else { return ["ok": false, "reason": "midnight"] }
            let actionID = beginTracking(childID: cid, kind: "gift", minutes: allowed)
            RemoteSyncManager.shared.giftChildMinutes(childID: id, minutes: allowed)
            refreshActionStatus()
            return ["ok": true, "minutes": allowed, "actionID": actionID]
        case "lock":
            let actionID = beginTracking(childID: cid, kind: "lock", minutes: 0)
            HouseholdManager.shared.lockRemoteScreenTime(toChildID: id)
            return ["ok": true, "actionID": actionID]
        case "beep":
            let fix = LocationSharing.shared.shownFix(cid)
            LocationSharing.shared.beep(childID: cid, deviceID: fix?.deviceID)
            return ["ok": true]
        default:
            return ["ok": false]
        }
    }
    // MARK: - 📶 What became of it — back to the watch (Rani, 2026-10-10)
    //
    // The watch's "נשלח ✓" only ever meant "the phone took the request". The phone
    // already knows every hop — reached the cloud, the child's device acked — so
    // it tells the watch each time that changes, and the watch shows the same
    // chain the phone's own status sheet shows.

    private struct TrackedAction {
        let id: String
        let childID: String
        let kind: String            // "gift" | "lock"
        let minutes: Int
        let startedAt: Date
        var state: String           // sending → sent → confirmed, or failed
    }
    private var trackedAction: TrackedAction?
    /// Rides along in every family snapshot (a new snapshot replaces the old one whole).
    private var lastActionStatus: [String: Any]?
    private var statusSinks: Set<AnyCancellable> = []

    private func beginTracking(childID: String, kind: String, minutes: Int) -> String {
        let action = TrackedAction(id: UUID().uuidString, childID: childID, kind: kind,
                                   minutes: minutes, startedAt: Date(), state: "sending")
        trackedAction = action
        holdAwakeForAnswer()
        if statusSinks.isEmpty {
            // `@Published` fires BEFORE the new value is stored — read it a beat later.
            let later: () -> Void = { DispatchQueue.main.async { WatchBridge.shared.refreshActionStatus() } }
            RemoteSyncManager.shared.$giftSendTracker.sink { _ in later() }.store(in: &statusSinks)
            HouseholdManager.shared.$commandTracker.sink { _ in later() }.store(in: &statusSinks)
            HouseholdManager.shared.$devicesByChild.sink { _ in later() }.store(in: &statusSinks)   // the acks land here
        }
        return action.id
    }

    /// The watch usually asks while the phone sits in a pocket: iOS wakes the app
    /// for the request and suspends it a moment later — before the child's device
    /// has answered. Ask for the short stretch the answer normally takes.
    private var answerWait: UIBackgroundTaskIdentifier = .invalid
    private func holdAwakeForAnswer() {
        releaseAnswerWait()
        answerWait = UIApplication.shared.beginBackgroundTask(withName: "watch-action-status") { [weak self] in
            self?.releaseAnswerWait()
        }
        let mine = answerWait
        DispatchQueue.main.asyncAfter(deadline: .now() + 50) { [weak self] in
            if self?.answerWait == mine { self?.releaseAnswerWait() }
        }
    }
    private func releaseAnswerWait() {
        guard answerWait != .invalid else { return }
        UIApplication.shared.endBackgroundTask(answerWait)
        answerWait = .invalid
    }

    /// Where the watch's last action stands right now; pushed on every change.
    private func refreshActionStatus() {
        guard var action = trackedAction, action.state != "confirmed", action.state != "failed" else { return }
        // Only THIS action's tracker — never the one an earlier gift or lock left behind.
        let fresh = action.startedAt.addingTimeInterval(-1)
        var state = action.state
        switch action.kind {
        case "gift":
            guard let id = UUID(uuidString: action.childID),
                  let t = RemoteSyncManager.shared.giftSendTracker[id], t.sentAt >= fresh else { return }
            state = t.failed ? "failed" : t.applied ? "confirmed" : t.reachedCloud ? "sent" : "sending"
        case "lock":
            guard let t = HouseholdManager.shared.commandTracker[action.childID],
                  t.kind == .lock, t.sentAt >= fresh else { return }
            // One device answering is the news — a second, switched-off iPad must
            // not keep "locked" from ever being confirmed on the wrist.
            let applied = HouseholdManager.shared.appliedCount(childID: action.childID)?.applied ?? 0
            state = applied > 0 ? "confirmed" : t.reachedCloud ? "sent" : "sending"
        default: return
        }
        guard state != action.state else { return }
        action.state = state
        trackedAction = action
        let status: [String: Any] = ["id": action.id, "childID": action.childID, "kind": action.kind,
                                     "minutes": action.minutes, "state": state,
                                     "at": Date().timeIntervalSince1970]
        // Live when the watch is listening; and in the snapshot, so a wrist that
        // was lowered finds the latest word when it comes back up.
        let session = WCSession.default
        if session.activationState == .activated, session.isReachable {
            session.sendMessage(["actionStatus": status], replyHandler: nil, errorHandler: nil)
        }
        lastActionStatus = status
        if lastPayload != nil { lastPayload?["actionStatus"] = status; flush() }
        if state == "confirmed" || state == "failed" { releaseAnswerWait() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
