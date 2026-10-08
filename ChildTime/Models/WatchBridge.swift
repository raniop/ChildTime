import Foundation
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
            RemoteSyncManager.shared.giftChildMinutes(childID: id, minutes: allowed)
            return ["ok": true, "minutes": allowed]
        case "lock":
            HouseholdManager.shared.lockRemoteScreenTime(toChildID: id)
            return ["ok": true]
        case "beep":
            let fix = LocationSharing.shared.shownFix(cid)
            LocationSharing.shared.beep(childID: cid, deviceID: fix?.deviceID)
            return ["ok": true]
        default:
            return ["ok": false]
        }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
