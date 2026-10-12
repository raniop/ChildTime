import Foundation
import Combine
import UserNotifications
#if canImport(WidgetKit)
import WidgetKit
#endif
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
    /// The children of a tour that has ended — swept for once more at the
    /// next launch (a store that saves a beat late can write one of their
    /// keys back after the sweep on the way out).
    private static let sweepKey = "demoTour.sweepIDs"

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

    // MARK: - First run: straight into the questions

    /// Rani's final shape (2026-10-12, after four others): a parent who has
    /// just installed Tofy lands straight on Tofy Time's questions. The first
    /// time they are right, and the first time they are wrong, Tofy himself
    /// explains what that did to the seconds; after four answers they are
    /// asked whether to create a child's profile — "ליצור ילד" or "להמשיך
    /// לשחק" — and, if they play on, again every five.
    @Published private(set) var firstRunQuiz = UserDefaults.standard.bool(forKey: DemoTour.quizKey)
    /// The question itself, over the quiz.
    @Published var askToCreate = false
    /// Answers given in this first run.
    @Published private(set) var answered = 0

    private static let quizKey = "demoTour.firstRunQuiz"
    static let firstAskAfter = 4
    static let askAgainEvery = 5

    /// The two moments Tofy explains — each once per first run.
    enum Explained { case right, wrong }
    private var explained: Set<Explained> = []

    /// True the first time only: Tofy explains it now, and never again.
    func firstTime(_ what: Explained) -> Bool {
        guard active, firstRunQuiz else { return false }
        return explained.insert(what).inserted
    }

    /// After the 4th answer, then the 9th, the 14th…
    static func asks(afterAnswer n: Int) -> Bool {
        n == firstAskAfter || (n > firstAskAfter && (n - firstAskAfter) % askAgainEvery == 0)
    }

    /// Called by the quiz for every answer, right or wrong.
    func noteAnswer() {
        guard active, firstRunQuiz else { return }
        answered += 1
        guard Self.asks(afterAnswer: answered) else { return }
        // A beat later: the answer's own "צדקת / טעית" is read first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self, self.active, self.firstRunQuiz else { return }
            self.askToCreate = true
        }
    }

    /// Whether a first launch should open the first run by itself. Never in a
    /// test run: the test host IS a first launch on a blank device, and a tour
    /// puts the whole process in demo mode (every other suite then sees "no
    /// cloud, every family write refused").
    static var opensOnFirstLaunch: Bool {
        canStart && NSClassFromString("XCTestCase") == nil
    }

    /// A first launch on a device with no family at all: straight into the
    /// questions, with no welcome pages and nothing asked first. Returns false
    /// (and does nothing) anywhere else.
    @discardableResult
    func startFirstRun() -> Bool {
        guard Self.canStart else { return false }
        start()
        guard active else { return false }
        // The welcome pages are what this replaces; leaving the quiz (✕, or
        // "ליצור ילד") goes straight to "who uses this device".
        ParentSettings.shared.hasSeenWelcome = true
        if let kid = ProfileStore.shared.profiles.first(where: { $0.grade == Self.firstRunGrade }) ?? ProfileStore.shared.profiles.first {
            ProfileStore.shared.setActive(kid)
            // A clean slate for the one who plays: the clock starts at 0:00,
            // so the first right answer visibly puts the first seconds on it.
            ProgressStore.shared.resetAll()
        }
        UserDefaults.standard.set(true, forKey: Self.quizKey)
        firstRunQuiz = true
        return true
    }
    /// The child a first run plays as: כיתה א׳ — quick questions anyone answers.
    static let firstRunGrade = 1

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
        askToCreate = false
        answered = 0
        explained = []
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
        askToCreate = false
        kidID = nil
        answered = 0
        explained = []
        firstRunQuiz = false
        UserDefaults.standard.removeObject(forKey: Self.quizKey)
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
        Self.forgetMirroredChild()
        UserDefaults.standard.removeObject(forKey: Self.childIDsKey)
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: Self.sweepKey)
        // Measured on a device after leaving: a store that saves a beat late
        // wrote one child's (blank) slot back. Sweep once more when it has.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard !Self.isOn else { return }
            Self.removeLeftoverKeys(for: ids)
            if ProfileStore.shared.profiles.isEmpty { Self.forgetMirroredChild() }
        }
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

    /// What the tour left OUTSIDE its children's own keys (found by listing a
    /// device's storage after leaving it):
    ///  • the settings' copy of "the active child" (name, gender, photo) — the
    ///    old one-child migration reads it at the next launch and would bring
    ///    a child called דנה back, for the first sign-in to upload;
    ///  • the home-screen widgets' copy of the family.
    /// Only ever called while this device holds no child at all.
    private static func forgetMirroredChild() {
        let s = ParentSettings.shared
        if !s.childName.isEmpty { s.childName = "" }
        if s.childGender != nil { s.childGender = nil }
        if s.childPhotoData != nil { s.childPhotoData = nil }
        // …and that migration has nothing left to do here in any case.
        UserDefaults.standard.set(true, forKey: "profiles.didMigrateLegacyKid")
        for key in ["widget.kid.v1", "widget.family.v1"] { AppGroup.defaults.removeObject(forKey: key) }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
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
        // The late sweep for a tour that ended properly (only keys that carry
        // one of ITS children's ids — a real family's are never touched).
        if let swept = UserDefaults.standard.stringArray(forKey: sweepKey) {
            removeLeftoverKeys(for: Set(swept.compactMap(UUID.init(uuidString:))))
            UserDefaults.standard.removeObject(forKey: sweepKey)
        }
        guard let raw = UserDefaults.standard.stringArray(forKey: childIDsKey), !raw.isEmpty else { return }
        let ids = Set(raw.compactMap(UUID.init(uuidString:)))
        ids.forEach { ProfileStore.shared.purgeDemoProfile($0) }
        ProgressStore.shared.resetAll()
        removeLeftoverKeys(for: ids)
        if ProfileStore.shared.profiles.isEmpty { forgetMirroredChild() }
        UserDefaults.standard.removeObject(forKey: childIDsKey)
    }
}
