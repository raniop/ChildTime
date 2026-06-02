import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(named: .init("childtime.shield"))
    private let appGroupID = "group.com.childtime.shared"
    private static let unlockName = DeviceActivityName("childtime.unlock")

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == Self.unlockName else { return }
        reapplyShield()
        clearUnlockEnd()
    }

    /// Fires when the kid has actually *used* the unlocked apps for the granted
    /// number of minutes — even while ChildTime itself is in the background.
    /// This is what re-locks short (<15 min) grants when the kid wanders off to
    /// another app instead of returning to ChildTime.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == Self.unlockName else { return }
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
            return
        }

        guard let data = defaults.data(forKey: "activitySelection") else { return }
        guard let selection = try? decoder.decode(FamilyActivitySelection.self, from: data) else { return }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? .none
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = .none
    }

    private func clearUnlockEnd() {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        defaults.removeObject(forKey: "unlockEndsAt")
    }
}
