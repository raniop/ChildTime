import Foundation

/// App-side handler for the Live Activity "עֲצֹר וּשְׁמֹר" button. The interactive
/// intent (`StopAndSavePlayIntent`) runs in THIS process and records a request in
/// the shared app group + posts a Darwin notification; this bridge performs the
/// real work — freeze a manual grant / bank earned time, then re-lock the shield.
///
/// Idempotent via a handled-timestamp, and re-checked on foreground so a request
/// that raced app launch still applies.
enum StopAndSaveBridge {
    private static let handledKey = "stopAndSaveHandledAt"

    /// Register the Darwin observer once, early in app launch.
    private static var started = false
    static func start() {
        guard !started else { return }   // idempotent — registered from init AND .task
        started = true
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async { StopAndSaveBridge.applyIfRequested() }
            },
            stopAndSaveDarwinName as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// Apply a pending stop-and-save request exactly once (also safe to call on
    /// scene-active as a fallback).
    @MainActor
    static func applyIfRequested() {
        let d = AppGroup.defaults
        let at = d.double(forKey: stopAndSaveRequestedAtKey)
        let last = d.double(forKey: handledKey)
        // Unseen + fresh (guard against a stale request firing on a later launch).
        guard at > last, Date().timeIntervalSince1970 - at < 3600 else { return }
        d.set(at, forKey: handledKey)

        guard ProgressStore.shared.isUnlocked else { return }
        ProgressStore.shared.stopAndSaveCurrentUnlock()   // freeze (manual) / bank (earned)
        ShieldManager.shared.cancelScheduledReshield()
        ShieldManager.shared.relockBaseline()            // re-lock now
        PlayTimeLiveActivity.end()
    }
}
