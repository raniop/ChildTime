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
    }

    private var started = false

    func startIfNeeded() {
        guard WCSession.isSupported(), !started else { return }
        started = true
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func pushFamilyGlance(_ rows: [ChildGlance]) {
        guard WCSession.isSupported() else { return }
        startIfNeeded()
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled else { return }
        let payload: [String: Any] = [
            "sentAt": Date().timeIntervalSince1970,
            "children": rows.map { ["id": $0.id,
                                    "name": $0.name,
                                    "emoji": $0.emoji,
                                    "earnedToday": $0.earnedToday,
                                    "playingNow": $0.playingNow,
                                    "pendingChores": $0.pendingChores,
                                    "moneyBalance": $0.moneyBalance] },
        ]
        try? session.updateApplicationContext(payload)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
