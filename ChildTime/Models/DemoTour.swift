import Foundation
import Combine
import UserNotifications
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// 🎬 סיור הדגמה — a made-up family to look around in BEFORE signing up.
///
/// Rani, 2026-10-12: parents hear about Tofy, say "show us an example", and
/// then face install → sign-up → create children just to see one. The tour
/// opens from the first screen, with no account, and everything in it stays
/// on this device.
///
/// A demo was tried before and removed (2026-08-30) because it was not local:
/// the guest opened an anonymous account and a real household. This one holds
/// three lines of defence, each enough on its own:
///
///  1. **No account.** The tour never signs in — not even anonymously — and
///     every Firestore rule requires a signed-in user, so the server itself
///     refuses anything that tries to leave the device.
///  2. **The kill switch.** `HouseholdManager.skipsCloudSync` (the one the
///     test runs and the screenshot runs already stand behind) is on for the
///     whole tour: no sync starts, no child, device or token is written.
///  3. **Nothing survives it.** The tour starts only on a device that holds
///     no family at all, and leaving it — to sign up or just out — runs the
///     same local wipe as "reset this device", so no made-up child is left
///     for a later sign-in to upload (the exact way sample children once
///     reached a real family).
final class DemoTour: ObservableObject {
    static let shared = DemoTour()

    private static let activeKey = "demoTour.active"
    private static let childIDsKey = "demoTour.childIDs"
    private static let signUpKey = "demoTour.signUpNext"

    /// Read from every thread and from other singletons' `init` (through
    /// `AppInfo.isDemoRun` and `HouseholdManager.skipsCloudSync`), so it is a
    /// plain stored flag with no dependencies.
    private(set) static var isOn: Bool = UserDefaults.standard.bool(forKey: activeKey)

    @Published private(set) var active: Bool = DemoTour.isOn
    /// The child whose own screen is showing ("לראות כמו הילד"); nil = the parent's home.
    @Published var kidID: UUID?
    /// The invitation to sign up, and what brought it up.
    @Published var invite: Invite?

    enum Invite: String, Identifiable {
        /// The band's own button.
        case band
        /// Something that only works in a real family was tapped.
        case closed
        var id: String { rawValue }
    }

    private init() {}

    // MARK: - Starting

    /// The tour may start only where there is nothing to mix with: no account
    /// (not even a child device's anonymous one), no family, no child, no role.
    static var canStart: Bool {
        guard !isOn else { return false }
        #if canImport(FirebaseAuth)
        guard Auth.auth().currentUser == nil else { return false }
        #endif
        let s = ParentSettings.shared
        return AuthManager.shared.userID == nil
            && HouseholdManager.shared.household == nil
            && ProfileStore.shared.profiles.isEmpty
            && s.joinedChildID == nil
            && s.deviceRole == .unset
    }

    func start() {
        guard Self.canStart else { return }
        setOn(true)
        seedFamily()
        kidID = nil
        invite = nil
        active = true
    }

    private func setOn(_ on: Bool) {
        Self.isOn = on
        if on { UserDefaults.standard.set(true, forKey: Self.activeKey) }
        else { UserDefaults.standard.removeObject(forKey: Self.activeKey) }
    }

    // MARK: - The family

    static var familyName: String { tr("משפחת טופי") }

    private struct Kid {
        let name: String, gender: ChildGender, grade: Int, character: String
        /// Today, as the parent's card shows it.
        let answered: Int, correct: Int, minutes: Int
        let playingNow: Bool
    }

    /// Rani: three children — גן חובה, כיתה א׳, כיתה ו׳ — each with a character of their own.
    private static var kids: [Kid] {
        [Kid(name: tr("מיקה"), gender: .girl, grade: 0, character: "bunny", answered: 9, correct: 8, minutes: 11, playingNow: false),
         Kid(name: tr("יואב"), gender: .boy, grade: 1, character: "lion", answered: 14, correct: 11, minutes: 15, playingNow: false),
         Kid(name: tr("דנה"), gender: .girl, grade: 6, character: "redpanda", answered: 22, correct: 20, minutes: 24, playingNow: true)]
    }

    private func seedFamily() {
        let profiles = Self.kids.map {
            Profile(name: $0.name, gender: $0.gender, age: ChildAge.forGrade($0.grade),
                    character3DID: $0.character, grade: $0.grade)
        }
        // Recorded BEFORE anything is added: a tour cut short at any point
        // still knows exactly which children to take away.
        UserDefaults.standard.set(profiles.map { $0.id.uuidString }, forKey: Self.childIDsKey)
        profiles.forEach { ProfileStore.shared.add($0) }
        for (profile, kid) in zip(profiles, Self.kids) {
            // Each child's day is written while that child is the active one;
            // switching away saves it to that child's own slot.
            ProfileStore.shared.setActive(profile)
            ProgressStore.shared.seedForDemoTour(answered: kid.answered, correct: kid.correct, minutes: kid.minutes)
            LearningHistoryStore.shared.seedDemoTour(childID: profile.id, grade: kid.grade,
                                                     today: (kid.answered, kid.correct, kid.minutes))
            HouseholdManager.shared.seedDemoLiveWindow(childID: profile.id, playing: kid.playingNow)
        }
    }

    private var childIDs: [UUID] {
        (UserDefaults.standard.stringArray(forKey: Self.childIDsKey) ?? []).compactMap(UUID.init(uuidString:))
    }

    // MARK: - Inside the tour

    /// "תנו ל… לשחק כאן" on a child's card: that child's own screen, with no
    /// parent code and no Screen Time to approve.
    func showKid(_ id: UUID) {
        guard active else { return }
        if ProfileStore.shared.activeID != id { ProfileStore.shared.setActiveID(id) }
        // The child is now playing HERE: the made-up "playing on the iPad"
        // window would only tell them their time is open somewhere else.
        HouseholdManager.shared.seedDemoLiveWindow(childID: id, playing: false)
        kidID = id
    }

    func backToParent() { kidID = nil }

    /// Call before something that only a real family can do: in the tour it
    /// opens the invitation and returns true (= don't proceed).
    @discardableResult
    static func refuse() -> Bool {
        guard isOn else { return false }
        DispatchQueue.main.async { shared.invite = .closed }
        return true
    }

    // MARK: - Leaving

    /// Out of the tour, with nothing of it left on the device. `signUp` leads
    /// straight on to the parent's sign-up (through the age check, like every
    /// other way to "parent").
    func end(signUp: Bool) {
        guard Self.isOn else { return }
        invite = nil
        kidID = nil
        let ids = Set(ProfileStore.shared.profiles.map(\.id)).union(childIDs)
        HouseholdManager.shared.clearDemoDevices()
        RemoteSyncManager.shared.clearDemoGifts()
        // The same local wipe as "reset this device" — the roster, each
        // child's saved numbers and history, the in-memory copies — and then
        // the live numbers themselves.
        ids.forEach { ProfileStore.shared.purgeDemoProfile($0) }
        DataExporter.wipeLocalData()
        ProgressStore.shared.resetAll()
        Self.removeLeftoverKeys(for: ids)
        UserDefaults.standard.removeObject(forKey: Self.childIDsKey)
        // Nothing the tour's screens may have scheduled about its children
        // fires later. (Off the main thread: this call waits on the system.)
        DispatchQueue.global(qos: .utility).async {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
        if signUp { UserDefaults.standard.set(true, forKey: Self.signUpKey) }
        setOn(false)
        active = false
    }

    /// Anything a store saved under one of the tour's children (their history,
    /// their seen questions, their character…) goes with them.
    private static func removeLeftoverKeys(for ids: Set<UUID>) {
        let marks = ids.map(\.uuidString)
        for store in [UserDefaults.standard, AppGroup.defaults] {
            for key in store.dictionaryRepresentation().keys where marks.contains(where: key.contains) {
                store.removeObject(forKey: key)
            }
        }
    }

    /// True once, right after "להירשם ולהתחיל" — the first screen then goes
    /// straight on to the parent's way in.
    static func consumeSignUpNext() -> Bool {
        guard UserDefaults.standard.bool(forKey: signUpKey) else { return false }
        UserDefaults.standard.removeObject(forKey: signUpKey)
        return true
    }

    /// A tour that was cut short by the app closing simply continues: its
    /// family is still here and still local (only the children's made-up
    /// devices lived in memory, so those are put back). But if its flag is
    /// gone while its children are not (a crash half-way out), finish taking
    /// them away before anything can sync. Called at launch, before any sync
    /// starts.
    static func finishInterruptedExitIfNeeded() {
        if isOn {
            let known = Set(ProfileStore.shared.profiles.map(\.id))
            let playing = shared.childIDs.last
            for id in shared.childIDs where known.contains(id) {
                HouseholdManager.shared.seedDemoLiveWindow(childID: id, playing: id == playing)
            }
            return
        }
        guard let raw = UserDefaults.standard.stringArray(forKey: childIDsKey), !raw.isEmpty else { return }
        let ids = Set(raw.compactMap(UUID.init(uuidString:)))
        ids.forEach { ProfileStore.shared.purgeDemoProfile($0) }
        ProgressStore.shared.resetAll()
        removeLeftoverKeys(for: ids)
        UserDefaults.standard.removeObject(forKey: childIDsKey)
    }
}
