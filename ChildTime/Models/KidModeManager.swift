import Foundation
import Combine
import FamilyControls

/// Kid Mode on the PARENT's phone: a button temporarily turns this device into
/// the chosen child's device — every app locked except ChildTime + a separate
/// approved allow-list — and shows the full kid experience. Exiting requires the
/// parent PIN (the caller gates it). The shield + this flag persist, so killing
/// the app does NOT escape kid mode.
@MainActor
final class KidModeManager: ObservableObject {
    static let shared = KidModeManager()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let active   = "kidmode.active"
        static let childID  = "kidmode.childID"
        static let allowed  = "kidmode.allowedSelection"
        static let prevID   = "kidmode.prevActiveID"
    }

    @Published private(set) var active: Bool {
        didSet {
            defaults.set(active, forKey: Key.active)
            AppGroup.defaults.set(active, forKey: "kidModeActive")   // extension reads this
        }
    }
    @Published private(set) var childID: UUID? {
        didSet { defaults.set(childID?.uuidString, forKey: Key.childID) }
    }
    /// Separate allow-list for kid mode (apps the kid may open on the parent's phone).
    @Published var allowedData: Data? {
        didSet {
            defaults.set(allowedData, forKey: Key.allowed)
            AppGroup.defaults.set(allowedData, forKey: "kidModeAllowedData")   // extension reads this
        }
    }
    /// Flipped by the home-screen Quick Action so the UI presents the entry flow.
    @Published var pendingEntry = false

    /// The Quick Action / shortcut item type.
    static let shortcutType = "com.rani.ChildTime.kidmode"

    var allowedSelection: FamilyActivitySelection { SelectionStorage.decode(allowedData) }
    var hasAllowList: Bool { !SelectionStorage.isEmpty(allowedData) }

    private init() {
        active = defaults.bool(forKey: Key.active)
        if let s = defaults.string(forKey: Key.childID) { childID = UUID(uuidString: s) }
        allowedData = defaults.data(forKey: Key.allowed)
        // Re-mirror to the app group in case it drifted (first launch after update).
        AppGroup.defaults.set(active, forKey: "kidModeActive")
        AppGroup.defaults.set(allowedData, forKey: "kidModeAllowedData")
    }

    /// Enter kid mode for `child`: pull the child's full progress from the cloud,
    /// lock the phone to ChildTime + the allow-list, switch to that child's
    /// profile, and show the kid experience with THEIR real data.
    func enter(childID id: UUID) async {
        // A fresh session-unlock must not survive into Kid Mode, or leaving it
        // would skip the gate. Leaving Kid Mode must always re-authenticate.
        ParentSettings.shared.sessionUnlocked = false
        defaults.set(ProfileStore.shared.activeID?.uuidString, forKey: Key.prevID)
        childID = id

        // Force-pull the child's CURRENT cloud snapshot directly (don't rely on a
        // possibly-empty cache or revision races); fetchSnapshot also mirrors it
        // into the vault.
        let cloud = await RemoteSyncManager.shared.fetchSnapshot(for: id)
        // Pull the child's day-by-day learning history too.
        await LearningHistoryStore.shared.fetchRemoteHistory(for: id)

        // Switch to the child — loads the (now-fresh) vault snapshot into
        // ProgressStore and binds their history.
        if let p = ProfileStore.shared.profiles.first(where: { $0.id == id }) {
            ProfileStore.shared.setActive(p)
        }
        // Bring in the cloud truth — MERGE (LWW by revision + ratchet), not a
        // blind apply: switchTo above may have just migrated device-local frozen
        // parent time into the gift pocket (revision bumped), and a blind
        // apply(cloud) overwrote it. mergeRemote keeps the newer local pocket
        // and still ratchets accumulators up to the cloud.
        if let cloud { _ = ProgressStore.shared.mergeRemote(cloud) }
        // This phone may hold the kid's frozen parent-time from a previous Kid
        // Mode session (device-local, stashed on exit) — bring it back.
        ProgressStore.shared.restoreDeviceLocalPlayState(for: id)

        ShieldManager.shared.applyLockAllExcept(allowedSelection)
        active = true
        // Commands issued BEFORE this moment (💝 gift, ± minutes, reset) were
        // skipped by the doc listener — it only consumes while the device is
        // already being this child. Sweep them now that Kid Mode is on.
        await RemoteSyncManager.shared.consumePendingCommandsNow(for: id)
        Haptic.success()
    }

    /// Exit kid mode (the caller must parent-gate this): unlock the phone, restore.
    func exit() {
        // Close/save the kid's window BEFORE restoring the parent's profile —
        // otherwise a window or frozen parent time (device-local, not in the
        // snapshot) would leak onto whichever profile is active next.
        ProgressStore.shared.stopAndSaveCurrentUnlock()
        // The kid's banked earned leftover (and the last seconds of play) live
        // only in the LIVE store right now — push them under the KID's id before
        // the profile switches to the parent (the debounced upload would fire
        // 3s later against the wrong active profile and never upload them).
        RemoteSyncManager.shared.pushNow()
        // A frozen parent leftover belongs to the KID — park it under their id.
        // (Non-destructive stash; switchTo below may stash again with 0 → no-op.)
        if let kid = childID { ProgressStore.shared.stashDeviceLocalPlayState(for: kid) }
        ProgressStore.shared.clearDeviceLocalPlayState()
        ShieldManager.shared.clearShield()
        // Parent's phone returns to normal → allow deleting apps again.
        ShieldManager.shared.setAppRemovalLocked(false)
        ShieldManager.shared.cancelScheduledReshield()
        active = false
        // Restore whoever the parent had selected before (best effort).
        if let s = defaults.string(forKey: Key.prevID), let id = UUID(uuidString: s) {
            ProfileStore.shared.setActiveID(id)
        }
        Haptic.light()
    }

    /// Re-assert the lock on launch/foreground while still in kid mode (the app
    /// may have been killed). The ManagedSettings shield persists on its own, but
    /// re-applying is cheap insurance against any drift.
    func reassertIfActive() {
        guard active else { return }
        ShieldManager.shared.applyLockAllExcept(allowedSelection)
    }
}
