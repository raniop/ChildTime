import Foundation
import Combine
import FamilyControls
import ManagedSettings

final class ParentSettings: ObservableObject {
    static let shared = ParentSettings()

    private let defaults = AppGroup.defaults

    private enum Key {
        static let pin = "pin"
        static let minutesPerCorrect = "minutesPerCorrect"
        static let questionsPerSession = "questionsPerSession"
        static let enabledTopics = "enabledTopics"
        static let activitySelection = "activitySelection"
        static let blockAllExceptAllowed = "blockAllExceptAllowed"
        static let allowedAppsData = "allowedAppsData"
        static let alwaysAllowedAppsData = "alwaysAllowedAppsData"
        static let allowExceptionData = "allowExceptionData"
        static let allowExceptionEndsAt = "allowExceptionEndsAt"
        static let appRemovalUnlockedUntil = "appRemovalUnlockedUntil"
        static let onboardingCompleted = "onboardingCompleted"
        static let childAge = "childAge"
        static let childGender = "childGender"
        static let childName = "childName"
        static let childPhotoData = "childPhotoData"
        static let soundsEnabled = "soundsEnabled"
        static let rewardMode = "rewardMode"
        static let batchAnswers = "batchAnswers"
        static let batchMinutes = "batchMinutes"
        static let penaltyEnabled = "penaltyEnabled"
        static let penaltyAfterMistakes = "penaltyAfterMistakes"
        static let penaltyMinutes = "penaltyMinutes"
        static let dailyCapEnabled = "dailyCapEnabled"
        static let maxMinutesPerDay = "maxMinutesPerDay"
        static let questionsPerWheel = "questionsPerWheel"
        static let faceIDForParentGate = "faceIDForParentGate"
        static let consentVersionAccepted = "consentVersionAccepted"
        static let parentInsightFrequency = "parentInsightFrequency"
        static let deviceRole = "deviceRole"
        static let hasSeenWelcome = "hasSeenWelcome"
        static let hasPromptedChildAppLock = "hasPromptedChildAppLock"
        static let dailyCapCardDone = "dailyCapCardDone"
        static let pendingJoinFamily = "pendingJoinFamily"
        static let joinFamilySucceeded = "joinFamilySucceeded"
        static let pendingJoinPayload = "pendingJoinPayload"
        static let joinedChildID = "joinedChildID"
        static let hasSetParentPIN = "hasSetParentPIN"
        static let justDisconnected = "justDisconnected"
        static let siblingTransferEnabled = "siblingTransferEnabled"
        static let diamondsPerMinute = "diamondsPerMinute"
    }

    /// What this device is used for — chosen once at first launch. Steers the
    /// whole UI: a child's device boots into play; a parent's device boots into
    /// the family monitoring view. Device-local (not synced).
    enum DeviceRole: String, CaseIterable, Identifiable {
        case unset, child, parent
        var id: String { rawValue }
    }

    /// How often the parent wants on-device "insight" notifications about their
    /// kids (what improved, where they struggled, what to practice).
    enum InsightFrequency: String, CaseIterable, Identifiable {
        case off, once, twice, thrice
        var id: String { rawValue }
        var perDay: Int {
            switch self {
            case .off: return 0
            case .once: return 1
            case .twice: return 2
            case .thrice: return 3
            }
        }
        var displayName: String {
            switch self {
            case .off:    return tr("כבוי")
            case .once:   return tr("פעם ביום")
            case .twice:  return tr("פעמיים ביום")
            case .thrice: return tr("שלוש פעמים ביום")
            }
        }
        /// Hours of day to fire at, for each frequency.
        var hours: [Int] {
            switch self {
            case .off:    return []
            case .once:   return [17]
            case .twice:  return [9, 18]
            case .thrice: return [9, 14, 19]
            }
        }
    }

    enum RewardMode: String, CaseIterable, Identifiable {
        /// Each correct answer awards N minutes immediately (default).
        case perAnswer
        /// Every N correct answers in total awards Y minutes (one big chunk).
        case perBatch

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .perAnswer: return tr("דקות לכל תשובה")
            case .perBatch:  return tr("צבירת תשובות")
            }
        }
    }

    @Published var pin: String {
        didSet { defaults.set(pin, forKey: Key.pin) }
    }
    @Published var minutesPerCorrectAnswer: Int {
        didSet { defaults.set(minutesPerCorrectAnswer, forKey: Key.minutesPerCorrect) }
    }
    @Published var questionsPerSession: Int {
        didSet { defaults.set(questionsPerSession, forKey: Key.questionsPerSession) }
    }
    @Published var enabledTopics: Set<Topic> {
        didSet {
            let arr = enabledTopics.map { $0.rawValue }
            defaults.set(arr, forKey: Key.enabledTopics)
        }
    }
    @Published var activitySelectionData: Data? {
        didSet { defaults.set(activitySelectionData, forKey: Key.activitySelection) }
    }
    /// 🔒 "לנעול גם אפליקציות חדשות" — the allow-list model. When on, the locked
    /// baseline shields EVERY app on the device, including one installed after
    /// the policy was written, except `allowedAppsData` + `alwaysAllowedAppsData`
    /// + any open per-app allowance. This is the behaviour Tofy promises: a child
    /// who downloads a new app must not walk straight out of the lock.
    ///
    /// SAFETY: it can only take effect once the parent has picked at least one
    /// app that stays open. Apple's `.all(except:)` shields Tofy itself too, and
    /// an app cannot mint its own `ApplicationToken` — only the parent can, in
    /// Apple's picker — so with an empty list we would lock the child out of the
    /// one app that earns their minutes. Until then we fall back to the classic
    /// (leaky) block-list. See `ShieldPolicy.swift` for the whole story.
    /// Stored under the historical key so an installed build's value carries over.
    @Published var lockNewApps: Bool {
        didSet { defaults.set(lockNewApps, forKey: Key.blockAllExceptAllowed) }
    }
    /// Apps that stay OPEN while the device is locked. Picked by the parent; must
    /// include Tofy itself so the child can always earn time, plus the essentials
    /// (phone, messages, camera, clock).
    @Published var allowedAppsData: Data? {
        didSet { defaults.set(allowedAppsData, forKey: Key.allowedAppsData) }
    }
    /// Apps the parent marked "ALWAYS allowed" in the classic block-list model:
    /// they are NEVER shielded, even when their whole category is blocked (e.g. a
    /// newly installed app that fell under a locked category). The parent uses this
    /// to permanently whitelist a specific app without unlocking its category.
    /// Device-local (FamilyControls tokens can't sync); shared with the monitor
    /// extension via the app group so re-locks honor it too.
    @Published var alwaysAllowedAppsData: Data? {
        didSet { defaults.set(alwaysAllowedAppsData, forKey: Key.alwaysAllowedAppsData) }
    }
    /// Apps the parent chose to keep open on a locked device.
    var openByDesignApps: Set<ApplicationToken> {
        SelectionStorage.decode(allowedAppsData).applicationTokens
    }
    /// True when the allow-list model is actually in force, i.e. a newly
    /// installed app IS shielded. Note it needs APPS, not categories: a category
    /// token is not something `.all(except:)` accepts, so an allow-list holding
    /// only "Education" would still shield Tofy.
    /// Mirrors `ShieldInputs.newAppLockArmed`: every CHILD device is fully
    /// locked, with no setup — see the note there.
    var newAppLockArmed: Bool { lockNewApps && deviceRole == .child }
    /// Kept for the old settings footer; there is no setup left to nag about.
    var allowListNeedsSetup: Bool { false }
    /// A temporary per-app allowance: which apps are open right now even though
    /// they're in the blocked list, and until when. Lets a parent open just one
    /// app (e.g. YouTube) for a while while the rest stay locked.
    @Published var allowExceptionData: Data? {
        didSet { defaults.set(allowExceptionData, forKey: Key.allowExceptionData) }
    }
    @Published var allowExceptionEndsAt: Date? {
        didSet {
            if let d = allowExceptionEndsAt { defaults.set(d, forKey: Key.allowExceptionEndsAt) }
            else { defaults.removeObject(forKey: Key.allowExceptionEndsAt) }
        }
    }
    /// While this is in the future, a child device temporarily ALLOWS app deletion
    /// (the parent opened a short window from Settings to uninstall Tofy). It
    /// auto-re-locks once the window passes.
    @Published var appRemovalUnlockedUntil: Date? {
        didSet {
            if let d = appRemovalUnlockedUntil { defaults.set(d, forKey: Key.appRemovalUnlockedUntil) }
            else { defaults.removeObject(forKey: Key.appRemovalUnlockedUntil) }
        }
    }
    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboardingCompleted) }
    }
    @Published var childAge: ChildAge {
        didSet { defaults.set(childAge.rawValue, forKey: Key.childAge) }
    }
    @Published var childGender: ChildGender? {
        didSet {
            if let g = childGender { defaults.set(g.rawValue, forKey: Key.childGender) }
            else { defaults.removeObject(forKey: Key.childGender) }
        }
    }
    @Published var childName: String {
        didSet { defaults.set(childName, forKey: Key.childName) }
    }
    @Published var childPhotoData: Data? {
        didSet {
            if let d = childPhotoData { defaults.set(d, forKey: Key.childPhotoData) }
            else { defaults.removeObject(forKey: Key.childPhotoData) }
        }
    }
    @Published var soundsEnabled: Bool {
        didSet { defaults.set(soundsEnabled, forKey: Key.soundsEnabled) }
    }
    @Published var rewardMode: RewardMode {
        didSet { defaults.set(rewardMode.rawValue, forKey: Key.rewardMode) }
    }
    /// In `.perBatch` mode: how many correct answers per batch reward.
    @Published var batchAnswers: Int {
        didSet { defaults.set(batchAnswers, forKey: Key.batchAnswers) }
    }
    /// In `.perBatch` mode: minutes awarded when the batch fills.
    @Published var batchMinutes: Int {
        didSet { defaults.set(batchMinutes, forKey: Key.batchMinutes) }
    }
    /// When ON (default), each mistake costs half the per-correct reward, parked
    /// in the recovery pot to be won back by a clean next answer. The parent can
    /// turn this off to make wrong answers entirely consequence-free.
    @Published var penaltyEnabled: Bool {
        didSet { defaults.set(penaltyEnabled, forKey: Key.penaltyEnabled) }
    }
    /// Legacy: consecutive-wrong threshold. No longer drives the penalty (kept
    /// for back-compat / migration); the penalty now applies per mistake.
    @Published var penaltyAfterMistakes: Int {
        didSet { defaults.set(penaltyAfterMistakes, forKey: Key.penaltyAfterMistakes) }
    }
    /// Legacy fixed deduction. Superseded by the half-of-correct rule in
    /// `ProgressStore.mistakePenaltyMinutes`; retained for migration only.
    @Published var penaltyMinutes: Int {
        didSet { defaults.set(penaltyMinutes, forKey: Key.penaltyMinutes) }
    }
    /// When ON, the kid can earn at most `maxMinutesPerDay` minutes per day.
    /// Earnings beyond the cap silently don't add to `pendingMinutes`.
    @Published var dailyCapEnabled: Bool {
        didSet { defaults.set(dailyCapEnabled, forKey: Key.dailyCapEnabled) }
    }
    /// The daily ceiling (only enforced when `dailyCapEnabled == true`).
    @Published var maxMinutesPerDay: Int {
        didSet { defaults.set(maxMinutesPerDay, forKey: Key.maxMinutesPerDay) }
    }
    /// How many answered questions earn one free Lucky Wheel spin.
    @Published var questionsPerWheel: Int {
        didSet { defaults.set(questionsPerWheel, forKey: Key.questionsPerWheel) }
    }
    /// Allow Face ID / Touch ID as an alternative to the PIN at the parent gate.
    @Published var faceIDForParentGate: Bool {
        didSet { defaults.set(faceIDForParentGate, forKey: Key.faceIDForParentGate) }
    }
    /// In-memory "the parent already authenticated this session" flag. Lets the
    /// root dashboard gate skip re-prompting right after another parent gate has
    /// just authenticated (e.g. leaving Kid Mode → one Face ID, not two). NOT
    /// persisted; reset on entering Kid Mode and on app background so a child can
    /// never inherit an open gate.
    @Published var sessionUnlocked = false
    /// The parental-consent version this parent accepted. 0 = not yet consented.
    @Published var consentVersionAccepted: Int {
        didSet { defaults.set(consentVersionAccepted, forKey: Key.consentVersionAccepted) }
    }
    /// How often to send on-device parent-insight notifications.
    @Published var parentInsightFrequency: InsightFrequency {
        didSet { defaults.set(parentInsightFrequency.rawValue, forKey: Key.parentInsightFrequency) }
    }
    /// This device's role (child play device vs parent monitoring device).
    @Published var deviceRole: DeviceRole {
        didSet { defaults.set(deviceRole.rawValue, forKey: Key.deviceRole) }
    }
    /// When ON, a child can buy play-minutes from a sibling using 💎 diamonds
    /// (each transfer is parent-approved). Default ON — it's safe-by-design since
    /// received minutes are still gated by the daily screen-time cap at unlock.
    @Published var siblingTransferEnabled: Bool {
        didSet { defaults.set(siblingTransferEnabled, forKey: Key.siblingTransferEnabled) }
    }
    /// How many 💎 a child pays a sibling per minute of play time bought. Parents
    /// can tune the exchange rate; default 10 💎 per minute.
    @Published var diamondsPerMinute: Int {
        didSet { defaults.set(diamondsPerMinute, forKey: Key.diamondsPerMinute) }
    }
    /// Whether the one-time welcome/explainer has been shown.
    @Published var hasSeenWelcome: Bool {
        didSet { defaults.set(hasSeenWelcome, forKey: Key.hasSeenWelcome) }
    }
    /// Whether we've already offered the one-time "choose apps to lock" setup on
    /// this child device (so we don't nag every launch).
    /// Set on the login screen when a parent chose "join an existing family".
    /// After they sign in, the dashboard auto-opens the family-linking sheet so
    /// they can enter the invite code instead of starting a fresh family.
    @Published var pendingJoinFamily: Bool {
        didSet {
            defaults.set(pendingJoinFamily, forKey: Key.pendingJoinFamily)
            if !pendingJoinFamily { defaults.removeObject(forKey: Key.joinFamilySucceeded) }
        }
    }
    /// Written the moment a join succeeds — see `init`, where a leftover one
    /// means the app was closed on the "הצטרפתם למשפחה!" screen.
    var joinFamilySucceeded: Bool {
        get { defaults.bool(forKey: Key.joinFamilySucceeded) }
        set { defaults.set(newValue, forKey: Key.joinFamilySucceeded) }
    }
    /// A child-join payload ("CODE|childID") captured from a scanned Universal
    /// Link (native Camera). The child connect screen redeems it automatically.
    @Published var pendingJoinPayload: String? {
        didSet {
            if let p = pendingJoinPayload { defaults.set(p, forKey: Key.pendingJoinPayload) }
            else { defaults.removeObject(forKey: Key.pendingJoinPayload) }
        }
    }
    @Published var hasPromptedChildAppLock: Bool {
        didSet { defaults.set(hasPromptedChildAppLock, forKey: Key.hasPromptedChildAppLock) }
    }
    /// ⏱ The parent home's one-time "how much screen time a day?" card was
    /// saved — or this family set the ceiling while creating a child (the
    /// create flow's last step), so it never needs the card.
    @Published var dailyCapCardDone: Bool {
        didSet { defaults.set(dailyCapCardDone, forKey: Key.dailyCapCardDone) }
    }
    /// On a CHILD device, the specific child this device joined as (set when a QR
    /// is scanned). A child device is bound to ONE child — it must scan to join,
    /// even if the account already has children, so it never auto-drops into a
    /// random profile.
    @Published var joinedChildID: String? {
        didSet { defaults.set(joinedChildID, forKey: Key.joinedChildID) }
    }
    /// Whether the parent has explicitly chosen a PIN on this device. Until then
    /// the parent gate runs a first-time "create a code" flow instead of asking
    /// for the (default 1234) code the parent never set.
    @Published var hasSetParentPIN: Bool {
        didSet { defaults.set(hasSetParentPIN, forKey: Key.hasSetParentPIN) }
    }
    /// This CHILD device was just disconnected (parent removed it / tapped
    /// "disconnect"). It stays a child and shows the reconnect (scan) screen —
    /// never the role picker — so a kid's device can't silently become a parent.
    /// Cleared once it rejoins. Persisted so it survives an app relaunch.
    @Published var justDisconnected: Bool {
        didSet { defaults.set(justDisconnected, forKey: Key.justDisconnected) }
    }

    private init() {
        let d = AppGroup.defaults
        self.pin = (d.string(forKey: Key.pin) ?? "1234")
        let mpc = d.integer(forKey: Key.minutesPerCorrect)
        self.minutesPerCorrectAnswer = mpc == 0 ? 2 : mpc
        // Minimum 15 — fewer than that doesn't give the kid enough practice
        // to learn anything meaningful. Cap at 30 for attention-span reasons.
        let qps = d.integer(forKey: Key.questionsPerSession)
        self.questionsPerSession = max(15, qps == 0 ? 15 : qps)

        if let raw = d.stringArray(forKey: Key.enabledTopics) {
            let parsed = Set(raw.compactMap(Topic.init(rawValue:)))
            self.enabledTopics = parsed.isEmpty
                ? [.math, .hebrew, .english, .logic, .science, .reading]
                : parsed
        } else {
            self.enabledTopics = [.math, .hebrew, .english, .logic, .science, .reading]
        }


        self.activitySelectionData = d.data(forKey: Key.activitySelection)
        // Default ON so a new app is locked by default — but it only takes
        // effect once the parent has picked what stays open (see the note on
        // the property: with an empty list we would shield Tofy itself).
        self.lockNewApps = (d.object(forKey: Key.blockAllExceptAllowed) as? Bool) ?? true
        self.allowedAppsData = d.data(forKey: Key.allowedAppsData)
        self.alwaysAllowedAppsData = d.data(forKey: Key.alwaysAllowedAppsData)
        self.allowExceptionData = d.data(forKey: Key.allowExceptionData)
        self.allowExceptionEndsAt = d.object(forKey: Key.allowExceptionEndsAt) as? Date
        self.appRemovalUnlockedUntil = d.object(forKey: Key.appRemovalUnlockedUntil) as? Date
        self.onboardingCompleted = d.bool(forKey: Key.onboardingCompleted)
        let ageRaw = d.integer(forKey: Key.childAge)
        self.childAge = ChildAge(rawValue: ageRaw == 0 ? 6 : ageRaw) ?? .grade1

        if let g = d.string(forKey: Key.childGender), let gender = ChildGender(rawValue: g) {
            self.childGender = gender
        } else {
            self.childGender = nil
        }
        self.childName = d.string(forKey: Key.childName) ?? ""
        self.childPhotoData = d.data(forKey: Key.childPhotoData)

        // Sound: default ON. UserDefaults returns false for missing keys, so use object check.
        if d.object(forKey: Key.soundsEnabled) == nil {
            self.soundsEnabled = true
        } else {
            self.soundsEnabled = d.bool(forKey: Key.soundsEnabled)
        }

        // Reward mode — default for everyone: every 10 answers → 3 minutes.
        if let raw = d.string(forKey: Key.rewardMode),
           let mode = RewardMode(rawValue: raw) {
            self.rewardMode = mode
        } else {
            self.rewardMode = .perBatch
        }
        let ba = d.integer(forKey: Key.batchAnswers)
        self.batchAnswers = ba == 0 ? 10 : ba
        let bm = d.integer(forKey: Key.batchMinutes)
        self.batchMinutes = bm == 0 ? 4 : bm

        // Mistake cost: default ON. Mistakes now matter (half the reward) but
        // are immediately recoverable, so this is gentle by design.
        if d.object(forKey: Key.penaltyEnabled) == nil {
            self.penaltyEnabled = true
        } else {
            self.penaltyEnabled = d.bool(forKey: Key.penaltyEnabled)
        }
        let pam = d.integer(forKey: Key.penaltyAfterMistakes)
        self.penaltyAfterMistakes = pam == 0 ? 3 : pam
        let pm = d.integer(forKey: Key.penaltyMinutes)
        self.penaltyMinutes = pm == 0 ? 1 : pm

        // Daily cap: default ON — it's the "maximum" minutes a child can earn
        // per day. Once hit, play continues but stops granting minutes. Parents
        // can disable it (unlimited) or adjust the ceiling in Settings.
        if d.object(forKey: Key.dailyCapEnabled) == nil {
            self.dailyCapEnabled = true
        } else {
            self.dailyCapEnabled = d.bool(forKey: Key.dailyCapEnabled)
        }
        let mmd = d.integer(forKey: Key.maxMinutesPerDay)
        self.maxMinutesPerDay = mmd == 0 ? 60 : mmd

        let qpw = d.integer(forKey: Key.questionsPerWheel)
        self.questionsPerWheel = qpw == 0 ? 10 : qpw

        self.faceIDForParentGate = d.bool(forKey: Key.faceIDForParentGate)
        self.consentVersionAccepted = d.integer(forKey: Key.consentVersionAccepted)
        // Insight notifications are ON by default (once a day) so parents get
        // updates out of the box.
        self.parentInsightFrequency = InsightFrequency(
            rawValue: d.string(forKey: Key.parentInsightFrequency) ?? ""
        ) ?? .once
        self.deviceRole = DeviceRole(rawValue: d.string(forKey: Key.deviceRole) ?? "") ?? .unset
        self.hasSeenWelcome = d.bool(forKey: Key.hasSeenWelcome)
        self.hasPromptedChildAppLock = d.bool(forKey: Key.hasPromptedChildAppLock)
        self.dailyCapCardDone = d.bool(forKey: Key.dailyCapCardDone)
        // The join screen is kept up after a successful join (it shows "הצטרפתם
        // למשפחה!" until "המשיכו"). An app closed at that moment used to open on
        // the code screen again — for a parent who is already in the family.
        let joinedAlready = d.bool(forKey: Key.joinFamilySucceeded)
        self.pendingJoinFamily = d.bool(forKey: Key.pendingJoinFamily) && !joinedAlready
        if joinedAlready { d.set(false, forKey: Key.pendingJoinFamily); d.removeObject(forKey: Key.joinFamilySucceeded) }
        self.pendingJoinPayload = d.string(forKey: Key.pendingJoinPayload)
        self.joinedChildID = d.string(forKey: Key.joinedChildID)
        self.hasSetParentPIN = d.bool(forKey: Key.hasSetParentPIN)
        self.justDisconnected = d.bool(forKey: Key.justDisconnected)
        // Sibling time-transfer: ON by default (cap-gated, parent-approved).
        if d.object(forKey: Key.siblingTransferEnabled) == nil {
            self.siblingTransferEnabled = true
        } else {
            self.siblingTransferEnabled = d.bool(forKey: Key.siblingTransferEnabled)
        }
        let dpm = d.integer(forKey: Key.diamondsPerMinute)
        self.diamondsPerMinute = dpm == 0 ? 10 : dpm
    }

    var hasConsented: Bool { consentVersionAccepted >= Consent.currentVersion }

    /// Apply age-appropriate defaults (called when parent picks an age in onboarding
    /// or changes it later in Settings).
    func applyAgeDefaults(_ age: ChildAge) {
        self.childAge = age
        self.enabledTopics = age.defaultEnabledTopics
        self.minutesPerCorrectAnswer = age.defaultMinutesPerCorrect
        // Difficulty is per-child now (see `Profile.difficultyByTopic`), seeded
        // from the child's learning level — not a global age default here.
    }

    /// 🔁 One-time repair for selections stored by a build that created them
    /// with `includeEntireCategory: false`. The flag is immutable, so the only
    /// way to fix a stored selection is to rebuild and re-save it — and until
    /// that happens the diagnostics card reports the old flag and a re-opened
    /// picker can still hand back a category with no apps in it.
    /// Idempotent and cheap: a no-op once every stored selection is clean.
    func normalizeStoredSelections() {
        for keyPath in [\ParentSettings.activitySelectionData,
                        \ParentSettings.allowedAppsData,
                        \ParentSettings.alwaysAllowedAppsData,
                        \ParentSettings.allowExceptionData] {
            guard let data = self[keyPath: keyPath] else { continue }
            let decoded = SelectionStorage.decode(data)          // decode normalizes
            guard decoded.includeEntireCategory == SelectionStorage.includeEntireCategory,
                  let fixed = SelectionStorage.encode(decoded), fixed != data else { continue }
            self[keyPath: keyPath] = fixed
        }
    }

    /// True while a temporary per-app allowance is in effect.
    var allowExceptionActive: Bool {
        guard let end = allowExceptionEndsAt else { return false }
        return end > Date()
    }

    func clearAllowException() {
        allowExceptionData = nil
        allowExceptionEndsAt = nil
    }
}
