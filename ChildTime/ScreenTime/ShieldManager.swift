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
    /// locked) and schedule a full re-shield after `minutes`.
    func startAllowException(allowed: FamilyActivitySelection,
                             blocked: FamilyActivitySelection,
                             minutes: Int) {
        applyShield(from: blocked, allowing: allowed)
        scheduleReshield(after: minutes)
    }

    // MARK: - Unlock for a duration

    func unlock(minutes: Int) {
        clearShield()
        scheduleReshield(after: minutes)
    }

    /// Apple's DeviceActivitySchedule requires a minimum interval (≥ 15 min).
    /// For shorter unlock windows we rely on the in-app scenePhase + timer logic
    /// in ChildTimeApp / UnlockedView to re-apply the shield when the kid returns.
    private static let minimumOSScheduleMinutes = 15

    private func scheduleReshield(after minutes: Int) {
        center.stopMonitoring([Self.unlockActivityName])

        // Skip OS-level scheduling for short windows — the in-app foreground
        // observer handles it.
        guard minutes >= Self.minimumOSScheduleMinutes else {
            print("[ShieldManager] Skipping OS schedule (only \(minutes) min — relying on in-app re-shield)")
            return
        }

        let now = Date()
        let endDate = now.addingTimeInterval(TimeInterval(minutes * 60))
        let calendar = Calendar.current

        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endDate)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        do {
            try center.startMonitoring(Self.unlockActivityName, during: schedule)
            print("[ShieldManager] Scheduled OS re-shield in \(minutes) min")
        } catch {
            print("[ShieldManager] Failed to schedule re-shield: \(error)")
        }
    }

    func cancelScheduledReshield() {
        center.stopMonitoring([Self.unlockActivityName])
    }
}
