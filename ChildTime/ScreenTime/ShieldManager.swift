import Foundation
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

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
    }

    func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy<Application>.none
        store.shield.webDomains = nil
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

    // MARK: - Unlock for a duration

    func unlock(minutes: Int) {
        clearShield()
        // Everything in the blocked set is now open. Meter usage of those apps
        // so the shield comes back after `minutes` of real play — even while
        // ChildTime is in the background and the kid is inside another app
        // (e.g. YouTube). This is what makes short (<15 min) grants enforce.
        let monitored = SelectionStorage.decode(ParentSettings.shared.activitySelectionData)
        scheduleUsageLimit(after: minutes, monitoring: monitored)
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
            print("[ShieldManager] Nothing to monitor — skipping usage limit")
            return
        }

        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: safeMinutes)
        )

        // Backstop window: at least the OS minimum, but long enough to contain
        // the grant if the kid plays straight through. Time-of-day components
        // only — mixed date+time components stop `intervalDidEnd` from firing.
        let windowMinutes = max(safeMinutes, Self.minimumOSScheduleMinutes)
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
            print("[ShieldManager] Metering \(safeMinutes) min of usage (backstop \(windowMinutes) min)")
        } catch {
            print("[ShieldManager] Failed to start usage monitoring: \(error)")
        }
    }

    func cancelScheduledReshield() {
        center.stopMonitoring([Self.unlockActivityName])
    }
}
