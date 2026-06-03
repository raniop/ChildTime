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

    private let store = ManagedSettingsStore(named: .init("childtime.shield"))
    private let appGroupID = "group.com.childtime.shared"
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

    private func reapplyShield() {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let decoder = JSONDecoder()

        // Block-all-except-allowlist mode — only when an allowlist actually exists
        // (otherwise we'd shield ChildTime itself and brick the device). Mirrors
        // ParentSettings.blockAllActive + ShieldManager.applyLockAllExcept.
        let blockAll = (defaults.object(forKey: "blockAllExceptAllowed") as? Bool) ?? true
        if blockAll,
           let allowedData = defaults.data(forKey: "allowedAppsData"),
           let allowed = try? decoder.decode(FamilyActivitySelection.self, from: allowedData),
           !(allowed.applicationTokens.isEmpty && allowed.categoryTokens.isEmpty && allowed.webDomainTokens.isEmpty) {
            store.shield.applications = nil
            store.shield.applicationCategories = .all(except: allowed.applicationTokens)
            store.shield.webDomains = nil
            store.shield.webDomainCategories = .all(except: allowed.webDomainTokens)
            monitorLog.notice("ext: re-applied block-all shield")
            return
        }

        guard let data = defaults.data(forKey: "activitySelection"),
              let selection = try? decoder.decode(FamilyActivitySelection.self, from: data) else {
            monitorLog.error("ext: no activitySelection to re-apply — shield NOT restored")
            return
        }

        // Honor an ACTIVE temporary parent exception (a per-app allowance that
        // hasn't expired) — mirrors ShieldManager.applyShield(from:allowing:).
        // Without this, a background re-lock would block the exception app too.
        var allowedApps: Set<ApplicationToken> = []
        if let endsAt = defaults.object(forKey: "allowExceptionEndsAt") as? Date, endsAt > Date(),
           let exData = defaults.data(forKey: "allowExceptionData"),
           let exSel = try? decoder.decode(FamilyActivitySelection.self, from: exData) {
            allowedApps = exSel.applicationTokens
            monitorLog.notice("ext: honoring active parent exception (\(allowedApps.count, privacy: .public) apps)")
        }

        let blockedApps = selection.applicationTokens.subtracting(allowedApps)
        store.shield.applications = blockedApps.isEmpty ? nil : blockedApps
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? .none
            : .specific(selection.categoryTokens, except: allowedApps)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = .none
        monitorLog.notice("ext: re-applied block-list shield (\(blockedApps.count, privacy: .public) apps blocked)")
    }

    private func clearUnlockEnd() {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        defaults.removeObject(forKey: "unlockEndsAt")
    }
}
