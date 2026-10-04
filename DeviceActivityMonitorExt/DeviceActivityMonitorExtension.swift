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
