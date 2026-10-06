import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation
import os.log

/// Same subsystem/category as the app's `screenTimeLog`, so Console.app on a real
/// device shows the app AND this extension together (filter: subsystem
/// "com.rani.ChildTime", category "ScreenTime") — the only way to verify the
/// background re-lock actually fires (it never runs in the Simulator).
private let monitorLog = Logger(subsystem: "com.rani.ChildTime", category: "ScreenTime")

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let appGroupID = TofyShield.appGroupID
    private static let unlockName = DeviceActivityName("childtime.unlock")

    private static let quietNames: Set<String> = ["childtime.quiet.school", "childtime.quiet.bedtime"]

    /// 🏫🌙 A school time / bedtime begins (iOS wakes us daily at its start; we
    /// decide here whether today counts). An EARNED or GIFT window still open
    /// is closed now: the shield comes back and the unlock metering stops. The
    /// refund needs the wallet and the cloud lease, which live in the app — so
    /// we leave the window's record in place and mark the moment; the app
    /// gives back what was left as of THIS instant when it next wakes. The
    /// parent's own manual open ("grant") is left running.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard Self.quietNames.contains(activity.rawValue) else { return }
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let now = Date()
        guard QuietHoursStore.load(defaults).active(at: now) != nil else {
            monitorLog.notice("ext: \(activity.rawValue, privacy: .public) woke — not a quiet day")
            return
        }
        let open = (defaults.object(forKey: "unlockEndsAt") as? Date).map { $0 > now } ?? false
        if open, defaults.string(forKey: "unlockKind") == "grant" {
            monitorLog.notice("ext: quiet time began during a parent's open — left running")
            return
        }
        if open, defaults.object(forKey: QuietHoursStore.cutAtKey) == nil {
            defaults.set(now, forKey: QuietHoursStore.cutAtKey)
        }
        monitorLog.notice("ext: quiet time began (\(activity.rawValue, privacy: .public)) → locking")
        reapplyShield()
        DeviceActivityCenter().stopMonitoring([Self.unlockName])
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == Self.unlockName else { return }
        monitorLog.notice("ext: intervalDidEnd (backstop window ended) → re-locking")
        reapplyShield()
        clearUnlockEnd()
    }

    /// Fires when the kid has actually *used* the unlocked apps for the granted
    /// number of minutes — even while ChildTime itself is in the background.
    /// This is what re-locks short grants when the kid wanders off to another app.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == Self.unlockName else { return }
        monitorLog.notice("ext: eventDidReachThreshold (usage limit hit) → re-locking")
        reapplyShield()
        clearUnlockEnd()
        // The grant is spent — free the monitoring slot for the next unlock.
        DeviceActivityCenter().stopMonitoring([activity])
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    /// Re-apply the locked baseline.
    ///
    /// This used to be a hand-written copy of the app's logic and it drifted
    /// from it: the block-list branch here shielded only the parent's enumerated
    /// apps and categories, so an app the child installed after setup was never
    /// covered. It now asks the SAME brain the app asks (`ShieldPolicy.swift`),
    /// which means a background re-lock writes byte-for-byte the policy the app
    /// would have written — including `.all(except:)` once the allow-list is
    /// armed, so a newly installed app is shielded even though this process has
    /// no network and no idea the app exists.
    ///
    /// `TofyShield.relock` also owns `denyAppRemoval`, honoring the parent's
    /// short "you may delete Tofy" window.
    private func reapplyShield() {
        TofyShield.relock(reason: "monitor-ext", log: monitorLog)
    }

    private func clearUnlockEnd() {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        defaults.removeObject(forKey: "unlockEndsAt")
        // This process has no Firebase, so it cannot release the cloud play-window
        // lease. Hand the app the leaseID to settle on its next wake — otherwise a
        // window that simply RAN OUT (the most common ending of all) would leave
        // the lease "open" and block the child's other device until it expires.
        if let lease = defaults.string(forKey: "activeLeaseID") {
            defaults.set(lease, forKey: "leaseNeedsRelease")
        }
    }
}
