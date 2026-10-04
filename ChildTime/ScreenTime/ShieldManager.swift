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

    func refreshStatus() {
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

    /// Has an automatic (not user-initiated) request already been shown and not
    /// approved? Apple's sheet re-presents on every call, so the launch-time
    /// request put a full-screen system dialog in front of the child on EVERY
    /// single open once it had been declined once. Ask automatically ONCE; after
    /// that only an explicit tap ("בקש" / "נסו שוב" / "בחרו אפליקציות") asks again.
    private static let autoAsksKey = "shield.autoAuthAsks"
    private static let autoAskLimit = 1
    var automaticRequestExhausted: Bool {
        UserDefaults.standard.integer(forKey: Self.autoAsksKey) >= Self.autoAskLimit
    }

    /// `userInitiated` — a person tapped a button asking for it: those always ask.
    /// Everything else (launch, onAppear, a remote command) is throttled by
    /// `automaticRequestExhausted`. The default is the SAFE one: a new caller that
    /// forgets the argument cannot put Apple's sheet in front of a child again.
    func requestAuthorizationIfNeeded(userInitiated: Bool = false) async {
        refreshStatus()
        print("[ShieldManager] Status before request: \(authStatusText)")
        guard authCenter.authorizationStatus != .approved else {
            isAuthorized = true
            UserDefaults.standard.set(0, forKey: Self.autoAsksKey)   // granted — forget the throttle
            return
        }
        if !userInitiated {
            guard !automaticRequestExhausted else { return }
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: Self.autoAsksKey) + 1,
                                      forKey: Self.autoAsksKey)
        }
        do {
            try await authCenter.requestAuthorization(for: .individual)
            refreshStatus()
            authorizationError = nil
            print("[ShieldManager] Status after request: \(authStatusText)")
        } catch {
            refreshStatus()
            let nsErr = error as NSError
            authorizationError = Self.friendlyAuthError(nsErr)
            // A child device that cannot shield is not a working child device.
            // Publish the failure so the kid's home can say "a grown-up needs to
            // finish this" and the parent's dashboard can show it from afar.
            if let cid = ProfileStore.shared.activeID, ParentSettings.shared.deviceRole == .child {
                Task { await HouseholdManager.shared.registerDevice(forChildID: cid) }
            }
            print("[ShieldManager] Auth FAILED: \(nsErr.domain) #\(nsErr.code): \(error.localizedDescription)")
        }
    }

    /// Turn Apple's raw FamilyControls errors into something a parent can act on.
    /// The raw text ("FamilyControls.FamilyControlsError #4: ... only one
    /// application at a time") is meaningless to a parent — and the fix is
    /// usually in iOS Settings, not in Tofy.
    static func friendlyAuthError(_ err: NSError) -> String {
        guard err.domain.contains("FamilyControls") else {
            return tr("לא הצלחנו לקבל את ההרשאה (\(err.localizedDescription)).")
        }
        switch err.code {
        case 4:   // authorizationConflict — another app already holds Family Controls
            return tr("אפליקציה אחרת במכשיר כבר משתמשת ב-Screen Time (אפל מאפשרת אחת בלבד). הסירו אותה מ״הגדרות ← זמן מסך ← אפליקציות עם גישה״, ונסו שוב.")
        case 2:   // authorizationCanceled
            return tr("האישור בוטל. נסו שוב ואשרו בחלון של אפל.")
        case 3:   // networkError
            return tr("אין חיבור לאינטרנט. התחברו ונסו שוב.")
        case 5:   // invalidAccountType — child/Family Sharing account limits
            return tr("החשבון במכשיר לא מאפשר את זה. ודאו שמחוברים עם Apple ID של הורה (לא של ילד).")
        case 6:   // restricted — MDM / Screen Time restrictions
            return tr("המכשיר מוגבל (זמן מסך / ניהול ארגוני). בטלו את ההגבלה ונסו שוב.")
        default:
            return tr("אפל לא אישרה את ההרשאה (\(err.localizedDescription)).")
        }
    }

    // MARK: - Shield (block) management

    /// Prevent DELETING apps (iOS Screen Time restriction). Deleting ChildTime
    /// would wipe the shield and unlock every app, so a managed device keeps this
    /// ON — even during a temporary play-time window. Device-wide (iOS can't
    /// target a single app). Cleared only when management truly ends (Kid Mode
    /// exit on a parent's phone).
    func setAppRemovalLocked(_ locked: Bool) {
        store.application.denyAppRemoval = locked ? true : nil
    }

    func clearShield() {
        // NOTE: intentionally does NOT touch denyAppRemoval — a temporary unlock
        // must not let the kid delete ChildTime and escape the lock.
        store.shield.applications = nil
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy<Application>.none
        store.shield.webDomains = nil
        // CRITICAL: also drop the all-web category restriction set by Kid Mode,
        // otherwise the browser stays blocked after exiting.
        store.shield.webDomainCategories = ShieldSettings.ActivityCategoryPolicy<WebDomain>.none
        TofyShield.defaults.set("cleared", forKey: TofyShield.Key.lastPlan)
        TofyShield.defaults.set(Date().timeIntervalSince1970, forKey: TofyShield.Key.lastPlanAt)
    }

    /// Kid Mode (parent's own phone): lock EVERY app except the `allowed` set.
    ///
    /// NOTE: `.all(except:)` shields all categories. To guarantee the kid can
    /// always return to ChildTime, the parent must include ChildTime's own token
    /// in `allowed` (the entry screen nudges them to). Verify on a real device —
    /// the simulator does not enforce shields.
    func applyLockAllExcept(_ allowed: FamilyActivitySelection) {
        var inputs = TofyShieldInputs()
        inputs.kidModeActive = true
        inputs.kidModeAllowedApps = allowed.applicationTokens
        inputs.kidModeAllowedWebDomains = allowed.webDomainTokens
        TofyShield.apply(inputs.plan(), to: store, reason: "kid-mode", log: screenTimeLog)
        // Kid Mode: also block app deletion (can't sneak out by removing ChildTime).
        store.application.denyAppRemoval = true
    }

    /// Start a temporary per-app allowance: open `allowed` now (rest stays
    /// locked) and re-shield after `minutes` of actual use of those apps.
    ///
    /// The caller has already persisted `allowExceptionData` / `allowExceptionEndsAt`,
    /// so re-applying the baseline picks the allowance up in BOTH models — the
    /// allow-list (`.all(except: … union allowed)`) and the classic block-list.
    func startAllowException(allowed: FamilyActivitySelection,
                             blocked _: FamilyActivitySelection,
                             minutes: Int) {
        applyDefaultLock()
        // The kid spends the window inside the `allowed` apps — meter THOSE.
        scheduleUsageLimit(after: minutes, monitoring: allowed)
    }

    /// The single "re-lock the baseline NOW" entry point, for the app, the
    /// monitor extension and the push service alike. Kid-Mode-aware, allow-list
    /// aware, allowance-aware — because all three now ask the same brain
    /// (`ShieldPolicy.swift`) instead of each re-deriving the policy by hand.
    func relockBaseline() { applyDefaultLock() }

    /// Apply the device's LOCKED baseline (called whenever no play window is
    /// active). The shape is decided in one place — see `ShieldPolicy.swift`:
    ///  - Kid Mode on a parent phone  -> everything except the kid-mode list
    ///  - allow-list armed            -> everything, INCLUDING apps installed
    ///                                   later, except what stays open
    ///  - otherwise                   -> the classic enumerated block-list
    func applyDefaultLock() {
        TofyShield.relock(reason: "app", log: screenTimeLog)
    }

    /// What the last shield write actually did — the breadcrumb a real-device run
    /// can be checked against in Console.app, and what the tests assert.
    var lastAppliedPlanSummary: String {
        TofyShield.defaults.string(forKey: TofyShield.Key.lastPlan) ?? "none"
    }

    // MARK: - Unlock for a duration

    func unlock(minutes: Int) {
        let plan = TofyShield.inputs().plan()
        clearShield()
        screenTimeLog.notice("unlock(\(minutes, privacy: .public) min) baseline=\(plan.kind.rawValue, privacy: .public)")
        // Everything that was shielded is now open. Meter usage of the parent's
        // block-list so the shield comes back after `minutes` of REAL play — even
        // while ChildTime is backgrounded and the kid is inside another app. This
        // is what makes short (<15 min) grants enforce.
        //
        // In the allow-list model there is no enumerated blocked set covering the
        // whole device, so when the parent has no block-list left we fall back to
        // the wall-clock backstop (floor: iOS's 15-minute schedule minimum).
        let monitored = SelectionStorage.decode(ParentSettings.shared.activitySelectionData)
        let meterable = !monitored.applicationTokens.isEmpty
            || !monitored.categoryTokens.isEmpty
            || !monitored.webDomainTokens.isEmpty
        if meterable {
            scheduleUsageLimit(after: minutes, monitoring: monitored)
        } else {
            scheduleWallClockReshield(after: minutes)
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
