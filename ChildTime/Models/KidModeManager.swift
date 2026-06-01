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
        didSet { defaults.set(active, forKey: Key.active) }
    }
    @Published private(set) var childID: UUID? {
        didSet { defaults.set(childID?.uuidString, forKey: Key.childID) }
    }
    /// Separate allow-list for kid mode (apps the kid may open on the parent's phone).
    @Published var allowedData: Data? {
        didSet { defaults.set(allowedData, forKey: Key.allowed) }
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
    }

    /// Enter kid mode for `child`: lock the phone to ChildTime + the allow-list,
    /// switch to that child's profile, and show the kid experience.
    func enter(childID id: UUID) {
        defaults.set(ProfileStore.shared.activeID?.uuidString, forKey: Key.prevID)
        childID = id
        if let p = ProfileStore.shared.profiles.first(where: { $0.id == id }) {
            ProfileStore.shared.setActive(p)
        }
        ShieldManager.shared.applyLockAllExcept(allowedSelection)
        active = true
        Haptic.success()
    }

    /// Exit kid mode (the caller must parent-gate this): unlock the phone, restore.
    func exit() {
        ShieldManager.shared.clearShield()
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
