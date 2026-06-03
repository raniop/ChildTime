import Foundation
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity
import os.log

/// Shared logger so the app and the monitor extension log to the SAME subsystem —
/// filter Console.app on a real device by subsystem "com.rani.ChildTime" + category
/// "ScreenTime" to watch the whole unlock → enforce → re-lock flow.
let screenTimeLog = Logger(subsystem: "com.rani.ChildTime", category: "ScreenTime")

@MainActor
final class ShieldManager: ObservableObject {
    static let shared = ShieldManager()

    private let store = ManagedSettingsStore(named: .init("childtime.shield"))
    private let center = DeviceActivityCenter()
    private let authCenter = AuthorizationCenter.shared

    static let unlockActivityName = DeviceActivityName("childtime.unlock")
    static let unlockEventName = DeviceActivityEvent.Name("childtime.unlock.usage")

    @Published var isAuthorized: Bool = false
    @Published var authorizationError: String?
    @Published var authStatusText: String = "unknown"

    private init() {
        refreshStatus()
    }

    private func refreshStatus() {
        let status = authCenter.authorizationStatus
        isAuthorized = (status == .approved)
        let text: String
        switch status {
        case .notDetermined: text = "notDetermined"
        case .denied: text = "denied"
        case .approved: text = "approved"
        @unknown default: text = "unknown"
        }
        authStatusText = text
    }

    func requestAuthorizationIfNeeded() async {
        refreshStatus()
        print("[ShieldManager] Status before request: \(authStatusText)")
        guard authCenter.authorizationStatus != .approved else {
            isAuthorized = true
            return
        }
        do {
            try await authCenter.requestAuthorization(for: .individual)
            refreshStatus()
            authorizationError = nil
            print("[ShieldManager] Status after request: \(authStatusText)")
        } catch {
            refreshStatus()
            let nsErr = error as NSError
            authorizationError = "\(nsErr.domain) #\(nsErr.code): \(error.localizedDescription)"
            print("[ShieldManager] Auth FAILED: \(authorizationError ?? "?")")
        }
    }

    // MARK: - Shield (block) management

    func applyShield(from selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? ShieldSettings.ActivityCategoryPolicy<Application>.none
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        // Never the all-web restriction here — that's Kid Mode only. Clear it so a
        // previous Kid Mode session can't leave Safari blocked.
        store.shield.webDomainCategories = ShieldSettings.ActivityCategoryPolicy<WebDomain>.none
    }

    func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy<Application>.none
        store.shield.webDomains = nil
        // CRITICAL: also drop the all-web category restriction set by Kid Mode,
        // otherwise the browser stays blocked after exiting.
        store.shield.webDomainCategories = ShieldSettings.ActivityCategoryPolicy<WebDomain>.none
    }

    /// Kid Mode (parent's own phone): lock EVERY app except the `allowed` set —
    /// the inverse of the normal block-list. Everything the parent didn't approve
    /// is shielded; ChildTime + the approved apps stay open. The kid is confined
    /// to a safe sandbox on the parent's device.
    ///
    /// NOTE: `.all(except:)` shields all categories. iOS keeps the *foreground*
    /// controlling app usable, but to guarantee the kid can always return to
    /// ChildTime, pass ChildTime's own token in `allowed` too (the entry screen
    /// nudges the parent to include it). Verify on a real device — the simulator
    /// does not enforce shields.
    func applyLockAllExcept(_ allowed: FamilyActivitySelection) {
        store.shield.applications = nil
        store.shield.applicationCategories = .all(except: allowed.applicationTokens)
        store.shield.webDomains = nil
        store.shield.webDomainCategories =
            ShieldSettings.ActivityCategoryPolicy<WebDomain>.all(except: allowed.webDomainTokens)
    }

    /// Block the full `blocked` set EXCEPT the `allowed` apps — so specific apps
    /// (e.g. YouTube) stay open while everything else remains locked.
    func applyShield(from blocked: FamilyActivitySelection, allowing allowed: FamilyActivitySelection) {
        let allowedApps = allowed.applicationTokens
        let blockedApps = blocked.applicationTokens.subtracting(allowedApps)
        store.shield.applications = blockedApps.isEmpty ? nil : blockedApps
        store.shield.applicationCategories = blocked.categoryTokens.isEmpty
            ? ShieldSettings.ActivityCategoryPolicy<Application>.none
            : .specific(blocked.categoryTokens, except: allowedApps)
        store.shield.webDomains = blocked.webDomainTokens.isEmpty ? nil : blocked.webDomainTokens
        store.shield.webDomainCategories = ShieldSettings.ActivityCategoryPolicy<WebDomain>.none
    }

    /// Start a temporary per-app allowance: open `allowed` now (rest stays
    /// locked) and re-shield after `minutes` of actual use of those apps.
    func startAllowException(allowed: FamilyActivitySelection,
                             blocked: FamilyActivitySelection,
                             minutes: Int) {
        applyShield(from: blocked, allowing: allowed)
        // The kid spends the window inside the `allowed` apps — meter THOSE.
        scheduleUsageLimit(after: minutes, monitoring: allowed)
    }

    /// Apply the device's LOCKED baseline (called whenever no play window is
    /// active). Two models:
    ///  • block-all-except-allowlist — when the parent enabled it AND picked a
    ///    non-empty allowlist (which must include ChildTime). The safe default.
    ///  • classic block-list — block only the parent-selected apps, honoring a
    ///    temporary per-app allowance.
    func applyDefaultLock() {
        let s = ParentSettings.shared
        if s.blockAllActive {
            applyLockAllExcept(SelectionStorage.decode(s.allowedAppsData))
            return
        }
        let blocked = SelectionStorage.decode(s.activitySelectionData)
        if s.allowExceptionActive, let aData = s.allowExceptionData {
            applyShield(from: blocked, allowing: SelectionStorage.decode(aData))
        } else {
            applyShield(from: blocked)
        }
    }

    // MARK: - Unlock for a duration

    func unlock(minutes: Int) {
        clearShield()
        let s = ParentSettings.shared
        screenTimeLog.notice("unlock(\(minutes, privacy: .public) min) mode=\(s.blockAllActive ? "block-all" : "block-list", privacy: .public)")
        if s.blockAllActive {
            // Block-all has no concrete blocked-token set to usage-meter, so the
            // shield returns via a wall-clock backstop (the in-app timer re-locks
            // sooner when the kid comes back to ChildTime).
            scheduleWallClockReshield(after: minutes)
        } else {
            // Everything in the blocked set is now open. Meter usage of those apps
            // so the shield comes back after `minutes` of real play — even while
            // ChildTime is in the background and the kid is inside another app
            // (e.g. YouTube). This is what makes short (<15 min) grants enforce.
            let monitored = SelectionStorage.decode(s.activitySelectionData)
            scheduleUsageLimit(after: minutes, monitoring: monitored)
        }
    }

    /// Wall-clock-only re-lock (used in block-all mode where there's no concrete
    /// set to usage-meter). Fires `intervalDidEnd` in the monitor after the
    /// window, which re-applies the block-all baseline.
    private func scheduleWallClockReshield(after minutes: Int) {
        center.stopMonitoring([Self.unlockActivityName])
        let windowMinutes = max(max(1, minutes), Self.minimumOSScheduleMinutes)
        let now = Date()
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        let endComponents = calendar.dateComponents(
            [.hour, .minute, .second],
            from: now.addingTimeInterval(TimeInterval(windowMinutes * 60))
        )
        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )
        do {
            try center.startMonitoring(Self.unlockActivityName, during: schedule)
            screenTimeLog.notice("block-all: wall-clock reshield scheduled in \(windowMinutes, privacy: .public) min")
        } catch {
            screenTimeLog.error("block-all: failed to schedule wall-clock reshield: \(String(describing: error), privacy: .public)")
        }
    }

    /// Apple's DeviceActivitySchedule requires the containing interval to be at
    /// least 15 minutes (`MonitoringError.intervalTooShort`), so a plain
    /// schedule can't enforce a shorter grant. Instead we put the real limit on
    /// a usage-based `DeviceActivityEvent` threshold — it can be any number of
    /// minutes and fires `eventDidReachThreshold` in the monitor extension even
    /// while ChildTime is backgrounded. The 15-min schedule around it is only a
    /// wall-clock backstop in case the threshold ever misfires.
    private static let minimumOSScheduleMinutes = 15

    private func scheduleUsageLimit(after minutes: Int,
                                    monitoring selection: FamilyActivitySelection) {
        center.stopMonitoring([Self.unlockActivityName])

        let safeMinutes = max(1, minutes)

        // Nothing selected to meter → there's no shield to bring back anyway.
        guard !selection.applicationTokens.isEmpty
                || !selection.categoryTokens.isEmpty
                || !selection.webDomainTokens.isEmpty else {
            screenTimeLog.error("block-list: nothing to monitor — skipping usage limit (no re-lock will fire!)")
            return
        }

        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: safeMinutes)
        )

        // Backstop window is ONLY a safety net in case the usage event misfires —
        // NOT the real limit. The usage event re-locks after `safeMinutes` of
        // ACTUAL play (it pauses while the device is locked / idle). So we make
        // the wall-clock window generous: locking the iPad mid-session no longer
        // burns the grant — the kid keeps their unused minutes for real play.
        // Time-of-day components only — mixed date+time stop `intervalDidEnd`.
        // Backstop is ONLY a safety net behind the usage event. Keep it tight
        // (grant + 5, floor 20 — above iOS's 15-min minimum) so a missed usage
        // event still re-locks within a few minutes of the intended end, not up to
        // 2 hours later. (Re-armed on each foreground so idle time isn't burned.)
        let windowMinutes = max(safeMinutes + 5, 20)
        let now = Date()
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        let endComponents = calendar.dateComponents(
            [.hour, .minute, .second],
            from: now.addingTimeInterval(TimeInterval(windowMinutes * 60))
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        do {
            try center.startMonitoring(
                Self.unlockActivityName,
                during: schedule,
                events: [Self.unlockEventName: event]
            )
            screenTimeLog.notice("block-list: metering \(safeMinutes, privacy: .public) min of usage (backstop \(windowMinutes, privacy: .public) min)")
        } catch {
            screenTimeLog.error("block-list: failed to start usage monitoring: \(String(describing: error), privacy: .public)")
        }
    }

    func cancelScheduledReshield() {
        center.stopMonitoring([Self.unlockActivityName])
    }
}
