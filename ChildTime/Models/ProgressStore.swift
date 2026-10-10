import Foundation
import Combine

final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    /// Writes land on a background queue (see `WriteBehindDefaults`): a right
    /// answer changes ~30 fields and each one used to save itself to the App
    /// Group plist right there on the main thread — 75% of `recordCorrect`,
    /// the stutter after every correct answer (measured on Rani's phone).
    private let defaults = WriteBehindDefaults(AppGroup.defaults)

    /// Waits until every queued save is on disk — for code (and tests) that read
    /// the App Group store directly instead of through this object.
    func flushPendingWrites() { defaults.flush() }

    private enum Key {
        static let pendingMinutes = "pendingMinutes"
        static let earnedSecondsIn = "wallet.earnedSecondsIn"
        static let earnedSecondsOut = "wallet.earnedSecondsOut"
        static let giftSecondsIn = "wallet.giftSecondsIn"
        static let giftSecondsOut = "wallet.giftSecondsOut"
        static let pendingSecondsCarry = "pendingSecondsCarry"
        static let manualPausedSeconds = "manualPausedSeconds"
        static let totalCorrect = "totalCorrect"
        static let totalAnswered = "totalAnswered"
        static let unlockEndsAt = "unlockEndsAt"
        static let unlockIsManual = "unlockIsManual"
        static let baseRevision = "progress.baseRevision"
        static let unlockGrantedSeconds = "unlockGrantedSeconds"
        static let unlockStartedAt = "unlockStartedAt"
        static let unlockStartedUptime = "unlockStartedUptime"
        static let activeLeaseID = "activeLeaseID"
        static let unlockKind = "unlockKind"
        static let carryIsGift = "carryIsGift"
        static let stars = "stars"
        static let diamonds = "diamonds"
        static let xp = "xp"
        static let ownedCharacters = "ownedCharacterIDs"
        static let currentStreak = "currentStreak"
        static let dayStreak = "dayStreak"
        static let lastSessionDate = "lastSessionDate"
        static let lastDailyChestDate = "lastDailyChestDate"
        static let lastDailyChallengeDate = "lastDailyChallengeDate"
        static let hourlyAnswered = "hourlyAnswered"
        static let hourlyCorrect = "hourlyCorrect"
        static let unlockedWorlds = "unlockedWorlds"
        static let worldProgress = "worldProgress"
        static let worldStage = "worldStage"
        static let ownedCosmetics = "ownedCosmetics"
        static let equippedCosmetic = "equippedCosmetic"
        static let topicAccuracy = "topicAccuracy"
        static let topicAnswered = "topicAnswered"
        static let topicCorrect = "topicCorrect"
        static let batchCounter = "batchCounter"
        static let wrongStreak = "wrongStreak"
        static let totalScore = "totalScore"
        static let minutesEarnedToday = "minutesEarnedToday"
        static let minutesUnlockedToday = "minutesUnlockedToday"
        static let returnedTodayMinutes = "returnedTodayMinutes"
        static let dailyEarnedDate = "dailyEarnedDate"
        static let carryOverMinutes = "carryOverMinutes"
        static let resetEpoch = "resetEpoch"
        static let answeredToday = "answeredToday"
        static let correctToday = "correctToday"
        static let bestStreak = "bestStreak"
        static let cycleSeconds = "cycleSeconds"
        static let topicResponseMs = "topicResponseMs"
        static let topicAffinity = "topicAffinity"
        static let topicExposure = "topicExposure"
        static let topicAbandon = "topicAbandon"
        static let topicAdaptiveLevel = "topicAdaptiveLevel"
        static let wheelProgressCount = "wheelProgressCount"
        static let pendingBonusWheel = "pendingBonusWheel"
        static let lastComebackWheelAt = "lastComebackWheelAt"
        static let recoveryPot = "recoveryPot"
        static let parentGiftMinutes = "parentGiftMinutes"
        static let giftGivenToday = "giftGivenToday"
        static let giftGivenDate = "giftGivenDate"
        static let revision = "progress.revision"
        static let lastModifiedAt = "progress.lastModifiedAt"
    }

    // MARK: - Currencies & progression

    // MARK: - 💰 The wallets
    //
    // SOURCE OF TRUTH: four lifetime totals in SECONDS that only ever increase.
    // `pendingMinutes` / `parentGiftMinutes` below are DERIVED mirrors, kept only
    // because the whole UI and the sync triggers already publish on them — never
    // assign to them directly, or the mirror and the truth drift apart.
    //
    // Why counters: a stored balance cannot be merged. "60" and "0" are equally
    // valid, so the winner replaces the loser and nothing tells "spent it all"
    // apart from "never saw them earn it". Counters merge by `max`, so a device
    // that is behind holds smaller numbers and always loses — minutes cannot be
    // destroyed by accident, while a parent deliberately taking them away still
    // works, because that is an increase to the "out" total.
    @Published private(set) var earnedSecondsIn: Int {
        didSet { defaults.set(earnedSecondsIn, forKey: Key.earnedSecondsIn); recomputeWallets() }
    }
    @Published private(set) var earnedSecondsOut: Int {
        didSet { defaults.set(earnedSecondsOut, forKey: Key.earnedSecondsOut); recomputeWallets() }
    }
    @Published private(set) var giftSecondsIn: Int {
        didSet { defaults.set(giftSecondsIn, forKey: Key.giftSecondsIn); recomputeWallets() }
    }
    @Published private(set) var giftSecondsOut: Int {
        didSet { defaults.set(giftSecondsOut, forKey: Key.giftSecondsOut); recomputeWallets() }
    }

    /// Seconds actually available right now, to the second.
    var earnedSecondsAvailable: Int { max(0, earnedSecondsIn - earnedSecondsOut) }
    var giftSecondsAvailable: Int { max(0, giftSecondsIn - giftSecondsOut) }

    func creditEarned(seconds: Int) { guard seconds > 0 else { return }; earnedSecondsIn += seconds }
    func debitEarned(seconds: Int) {
        guard seconds > 0 else { return }
        earnedSecondsOut += min(seconds, earnedSecondsAvailable)
    }
    func creditGift(seconds: Int) { guard seconds > 0 else { return }; giftSecondsIn += seconds }
    func debitGift(seconds: Int) {
        guard seconds > 0 else { return }
        giftSecondsOut += min(seconds, giftSecondsAvailable)
    }

    /// Wipe both pockets — only for an authoritative reset (which travels with a
    /// higher `resetEpoch` and therefore wins wholesale) and for demo seeding.
    /// Never use this to "correct" a balance: that is what the counters exist to
    /// make unnecessary.
    func resetWallets(earnedMinutes: Int = 0, giftMinutes: Int = 0) {
        earnedSecondsOut = 0
        giftSecondsOut = 0
        earnedSecondsIn = max(0, earnedMinutes) * 60
        giftSecondsIn = max(0, giftMinutes) * 60
    }

    /// 💝 THE MIRRORS ARE DERIVED, NEVER ADOPTED — the one rule behind the gift
    /// that showed 60 minutes on the card and opened nothing at all.
    ///
    /// `apply(_:)` merges both counters with `max`, so this device can legitimately
    /// hold more than the arriving snapshot claims. And the snapshot's own minute
    /// fields are a last-write-wins mirror that any device on an older build can
    /// publish stale — a build with no counters at all publishes `parentGiftMinutes: 0`
    /// beside a pocket this device knows holds 3600 seconds. Taking that field at
    /// face value is what left the card reading the counters and the open reading
    /// the mirror, and the previous guard here missed exactly that case: it only
    /// recomputed when the SNAPSHOT carried counters, never when only WE did.
    ///
    /// Each wallet decides for itself, and the legacy field is read for one case
    /// only: a snapshot written before the counters existed, arriving at a device
    /// that has none either. Anything else comes from what we actually hold.
    private func deriveWalletMirrors(from s: ProgressSnapshot) {
        let earnedKnown = s.earnedSecondsIn != nil || s.earnedSecondsOut != nil
                          || earnedSecondsIn > 0 || earnedSecondsOut > 0
        let giftKnown   = s.giftSecondsIn != nil || s.giftSecondsOut != nil
                          || giftSecondsIn > 0 || giftSecondsOut > 0
        pendingMinutes    = earnedKnown ? earnedSecondsAvailable / 60 : s.pendingMinutes
        parentGiftMinutes = giftKnown   ? giftSecondsAvailable / 60   : (s.parentGiftMinutes ?? 0)
    }

    func recomputeWallets() {
        guard !isRecomputingWallets else { return }
        isRecomputingWallets = true
        pendingMinutes = earnedSecondsAvailable / 60
        parentGiftMinutes = giftSecondsAvailable / 60
        isRecomputingWallets = false
    }
    private var isRecomputingWallets = false

    @Published private(set) var pendingMinutes: Int {
        didSet { defaults.set(pendingMinutes, forKey: Key.pendingMinutes) }
    }
    /// Sub-minute leftover seconds (0–59) owed to the child — the remainder that
    /// doesn't fit into the whole-minute `pendingMinutes` wallet. When a play
    /// window is stopped early we bank the exact leftover (e.g. 58:50 → 58 min +
    /// 50 s carry) instead of flooring the seconds away OR rounding the minute up.
    /// Re-applied to the next window in `startUnlock`, so reopening resumes at
    /// 58:50 — never jumps back up to 59. Local-only (sub-minute, not worth syncing).
    @Published private(set) var pendingSecondsCarry: Int {
        didSet { defaults.set(pendingSecondsCarry, forKey: Key.pendingSecondsCarry) }
    }
    /// Frozen seconds left over from a parent's MANUAL grant that the child paused
    /// ("עֲצֹר וּשְׁמֹר") instead of wasting. Resumed later as a fresh manual window.
    /// Device-local like `unlockEndsAt` — a manual grant is per-device OS state and
    /// isn't synced.
    @Published private(set) var manualPausedSeconds: Int {
        didSet { defaults.set(manualPausedSeconds, forKey: Key.manualPausedSeconds) }
    }
    @Published private(set) var totalCorrect: Int {
        didSet { defaults.set(totalCorrect, forKey: Key.totalCorrect) }
    }
    @Published private(set) var totalAnswered: Int {
        didSet { defaults.set(totalAnswered, forKey: Key.totalAnswered) }
    }
    @Published private(set) var unlockEndsAt: Date? {
        didSet {
            if let d = unlockEndsAt { defaults.set(d, forKey: Key.unlockEndsAt) }
            else { defaults.removeObject(forKey: Key.unlockEndsAt) }
        }
    }
    /// 🕐 What the CURRENT window was actually GRANTED, plus when it started —
    /// both by wall clock and by the MONOTONIC system uptime. Refunds are clamped
    /// against these so moving the device clock backwards can never mint minutes.
    /// (Before this, rolling the clock back 12h and tapping "סיימתי לשחק" banked
    /// 735 minutes from a 15-minute window, over and over.)
    /// The last cloud generation this device ADOPTED. `revision` is now a causal
    /// generation ("what cloud state does this edit descend from?"), not a count
    /// of local activity — see `markLocalChange`. Device-local on purpose: adding
    /// it to ProgressSnapshot would make every device look perpetually "ahead"
    /// and re-upload forever (the a50317e ping-pong).
    private var baseRevision: Int {
        didSet { defaults.set(baseRevision, forKey: Key.baseRevision) }
    }

    private(set) var unlockGrantedSeconds: Int {
        didSet { defaults.set(unlockGrantedSeconds, forKey: Key.unlockGrantedSeconds) }
    }
    private var unlockStartedAt: Date? {
        didSet {
            if let d = unlockStartedAt { defaults.set(d, forKey: Key.unlockStartedAt) }
            else { defaults.removeObject(forKey: Key.unlockStartedAt) }
        }
    }
    private var unlockStartedUptime: Double {
        didSet { defaults.set(unlockStartedUptime, forKey: Key.unlockStartedUptime) }
    }
    /// The cloud lease this OPEN window was granted under (nil for a legacy or
    /// offline-provisional window). Releasing quotes it so the settlement is
    /// exactly-once.
    /// Which pocket the OPEN window was paid from ("earned" / "gift" / "grant").
    /// Needed to retro-claim a lease for a window that was opened while offline —
    /// the refund side reads the kind off the lease doc, but a claim has to write it.
    private(set) var unlockKind: String {
        didSet { defaults.set(unlockKind, forKey: Key.unlockKind) }
    }

    /// Which pocket `pendingSecondsCarry` came out of — see ProgressSnapshot.
    private(set) var carryIsGift: Bool {
        didSet { defaults.set(carryIsGift, forKey: Key.carryIsGift) }
    }

    private(set) var activeLeaseID: String? {
        didSet {
            if let v = activeLeaseID {
                defaults.set(v, forKey: Key.activeLeaseID)
                AppGroup.defaults.set(v, forKey: Key.activeLeaseID)   // the extension reads this
            } else {
                defaults.removeObject(forKey: Key.activeLeaseID)
                AppGroup.defaults.removeObject(forKey: Key.activeLeaseID)
            }
        }
    }

    /// Seconds elapsed since the window opened, measured monotonically when
    /// possible (`systemUptime` cannot be changed from Settings). Falls back to
    /// wall clock only after a reboot, which resets uptime.
    private var elapsedSinceUnlockStart: Int {
        let up = ProcessInfo.processInfo.systemUptime
        if unlockStartedUptime > 0, up >= unlockStartedUptime {
            return Int(up - unlockStartedUptime)
        }
        if let started = unlockStartedAt {
            return max(0, Int(Date().timeIntervalSince(started)))
        }
        return 0
    }

    /// Seconds still legitimately owed from the open window: never more than the
    /// wall-clock remainder, and never more than (granted − actually elapsed).
    private var refundableUnlockSeconds: Int {
        if let quietRefund { return quietRefund }
        // Windows opened by an older build have no grant record — fall back to the
        // old behaviour rather than refusing the child their leftover.
        guard unlockGrantedSeconds > 0 else { return unlockSecondsRemaining }
        let owed = max(0, unlockGrantedSeconds - elapsedSinceUnlockStart)
        return min(unlockSecondsRemaining, owed)
    }
    /// True when the CURRENT window is a parent's one-time manual grant ("quick
    /// open") — a fixed wall-clock window that must NOT bank its leftover minutes
    /// back into the child's earned pool when it ends, and offers no early-stop.
    /// Earned redemptions leave this false (they're pausable + bankable).
    @Published private(set) var unlockIsManual: Bool {
        didSet { defaults.set(unlockIsManual, forKey: Key.unlockIsManual) }
    }
    // MARK: - Opening a play window (transient, never persisted)

    /// True from the tap on "פתחו לי דקות" until the server grants (or refuses)
    /// the play window. The child is taken straight to the play screen, which
    /// shows a warm "we're opening it" state instead of a button that looks
    /// stuck for the 2–3 seconds the claim takes (Rani).
    @Published private(set) var isOpeningWindow = false
    /// Which pocket is being opened — the play screen wears 💝 for parent time.
    @Published private(set) var openingIsGift = false
    /// A gentle line for the child when the open could not happen. Never failure
    /// language; the home screen speaks it through the companion and clears it.
    @Published var openWindowMessage: String?

    private var openingWatchdog: Task<Void, Never>?

    /// Gift opens in a row that could not happen for a reason the child is unable
    /// to resolve alone. The parent is told on the SECOND — once is a blip (a
    /// slow network, a window still open on the iPad), twice means the child is
    /// tapping a gift that will not open and nobody but a parent can fix it.
    ///
    /// Deliberately NOT persisted and deliberately NOT a reason to take anything
    /// away: the counters are the truth, and a bookkeeping disagreement must never
    /// cost a child minutes a parent really gave them.
    var giftOpenFailureStreak = 0

    func beginOpeningWindow(gift: Bool) {
        openWindowMessage = nil
        openingIsGift = gift
        isOpeningWindow = true
        // If a claim never answers (a stalled network), don't strand the child on
        // the opening screen — come back with a kind line.
        openingWatchdog?.cancel()
        openingWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard let self, !Task.isCancelled, self.isOpeningWindow else { return }
            self.endOpeningWindow(message: tr("רֶגַע, הָאִינְטֶרְנֶט קְצָת אִטִּי — נְנַסֶּה שׁוּב? 😊"))
        }
    }

    /// `message` is spoken on the home screen; pass nil when the window opened.
    func endOpeningWindow(message: String? = nil) {
        openingWatchdog?.cancel()
        openingWatchdog = nil
        isOpeningWindow = false
        if let message { openWindowMessage = message }
    }

    @Published private(set) var stars: Int {
        didSet { defaults.set(stars, forKey: Key.stars) }
    }
    /// 💎 the SPENDABLE wallet — earned from correct answers / gifts and burned
    /// in the shop. Kept separate from ⭐ stars (which are the never-decreasing
    /// leaderboard rank) so spending never costs the child their ranking.
    /// (Reuses the formerly-dormant "gems" slot, so all sync plumbing already
    /// carries it end-to-end.)
    @Published private(set) var diamonds: Int {
        didSet { defaults.set(diamonds, forKey: Key.diamonds) }
    }
    /// Characters this (active) child owns — per profile, synced via the snapshot.
    @Published private(set) var ownedCharacterIDs: Set<String> = [] {
        didSet { defaults.set(Array(ownedCharacterIDs), forKey: Key.ownedCharacters) }
    }
    @Published private(set) var xp: Int {
        didSet {
            defaults.set(xp, forKey: Key.xp)
            // 👑 Crossing a level is news for the parent's activity centre. No
            // push (see LiveEventReporter.EventType.levelUp) — just a row.
            // Adopting a snapshot (profile switch / remote update) is not a
            // level-up, however far the number jumps.
            guard !isApplyingSnapshot else { return }
            let was = RewardEngine.level(forXP: oldValue)
            let now = RewardEngine.level(forXP: xp)
            if now > was { Task { @MainActor in LiveEventReporter.report(.levelUp, value: "\(now)") } }
        }
    }
    @Published private(set) var currentStreak: Int {
        didSet { defaults.set(currentStreak, forKey: Key.currentStreak) }
    }
    @Published private(set) var dayStreak: Int {
        didSet { defaults.set(dayStreak, forKey: Key.dayStreak) }
    }
    @Published private(set) var lastSessionDate: Date? {
        didSet {
            if let d = lastSessionDate { defaults.set(d, forKey: Key.lastSessionDate) }
            else { defaults.removeObject(forKey: Key.lastSessionDate) }
        }
    }
    @Published private(set) var lastDailyChestDate: Date? {
        didSet {
            if let d = lastDailyChestDate { defaults.set(d, forKey: Key.lastDailyChestDate) }
            else { defaults.removeObject(forKey: Key.lastDailyChestDate) }
        }
    }
    /// Day the kid last CLAIMED the daily-challenge reward (answer-N-today goal).
    /// nil/older-than-today → the reward is claimable again. Synced like the chest.
    @Published private(set) var lastDailyChallengeDate: Date? {
        didSet {
            if let d = lastDailyChallengeDate { defaults.set(d, forKey: Key.lastDailyChallengeDate) }
            else { defaults.removeObject(forKey: Key.lastDailyChallengeDate) }
        }
    }
    /// 24 hour-of-day buckets of answers / correct answers (lifetime). Feeds the
    /// parent-only "Focus" insight (best time of day). Synced so the parent's
    /// device can read it. Monotonic counters → merged element-wise by max.
    @Published private(set) var hourlyAnswered: [Int] {
        didSet { defaults.set(hourlyAnswered, forKey: Key.hourlyAnswered) }
    }
    @Published private(set) var hourlyCorrect: [Int] {
        didSet { defaults.set(hourlyCorrect, forKey: Key.hourlyCorrect) }
    }
    @Published private(set) var unlockedWorlds: Set<String> {
        didSet { defaults.set(Array(unlockedWorlds), forKey: Key.unlockedWorlds) }
    }
    @Published private(set) var worldProgress: [String: Int] {
        didSet { defaults.set(worldProgress, forKey: Key.worldProgress) }
    }
    /// 🏆 tier × 10 + room — see `ProgressSnapshot.worldStage`.
    @Published private(set) var worldStage: [String: Int] {
        didSet { defaults.set(worldStage, forKey: Key.worldStage) }
    }
    @Published private(set) var ownedCosmetics: Set<String> {
        didSet { defaults.set(Array(ownedCosmetics), forKey: Key.ownedCosmetics) }
    }
    @Published var equippedCosmetic: String? {
        didSet {
            if let s = equippedCosmetic { defaults.set(s, forKey: Key.equippedCosmetic) }
            else { defaults.removeObject(forKey: Key.equippedCosmetic) }
        }
    }
    // [topicRawValue: rolling 0..1 accuracy]
    @Published private(set) var topicAccuracy: [String: Double] {
        didSet { defaults.set(topicAccuracy, forKey: Key.topicAccuracy) }
    }
    @Published private(set) var topicAnswered: [String: Int] {
        didSet { defaults.set(topicAnswered, forKey: Key.topicAnswered) }
    }
    @Published private(set) var topicCorrect: [String: Int] {
        didSet { defaults.set(topicCorrect, forKey: Key.topicCorrect) }
    }
    /// Counts correct answers toward the next batch reward (perBatch mode).
    @Published private(set) var batchCounter: Int {
        didSet { defaults.set(batchCounter, forKey: Key.batchCounter) }
    }
    /// LEGACY: progress toward the next batch of minutes, from before right
    /// answers paid straight into the wallet (2026-10-06). Still synced, so an
    /// older build can keep using it; this build pays whatever it finds out
    /// into the wallet on the next right answer (`payEarned`) and leaves it 0.
    @Published private(set) var cycleSeconds: Double {
        didSet { defaults.set(cycleSeconds, forKey: Key.cycleSeconds) }
    }
    /// Seconds needed for the next bonus.
    var bonusTargetSeconds: Int { max(1, ParentSettings.shared.batchMinutes * 60) }
    /// Seconds one correct answer is worth (the "+Ns" the child sees).
    var secondsPerCorrect: Int { max(1, bonusTargetSeconds / max(1, ParentSettings.shared.batchAnswers)) }
    /// How many questions make a full bonus cycle (for the progress bar).
    var cycleQuestionsTotal: Int { max(1, ParentSettings.shared.batchAnswers) }
    /// Questions completed in the current cycle (derived from cycleSeconds).
    var cycleQuestionsDone: Int {
        let perSec = Double(bonusTargetSeconds) / Double(cycleQuestionsTotal)
        return min(cycleQuestionsTotal, max(0, Int((cycleSeconds / max(1, perSec)).rounded())))
    }
    /// Consecutive wrong-answer count — drives the penalty system.
    @Published private(set) var wrongStreak: Int {
        didSet { defaults.set(wrongStreak, forKey: Key.wrongStreak) }
    }
    /// Set to a positive integer for one tick when a penalty fires, so the UI
    /// can show feedback. Reset to 0 by the consumer after reading.
    @Published var lastPenaltyMinutes: Int = 0
    /// Lifetime score — the headline 'ניקוד' metric shown across the app.
    @Published private(set) var totalScore: Int {
        didSet { defaults.set(totalScore, forKey: Key.totalScore) }
    }
    /// Score earned in the current session only — resets when a new
    /// QuestionRunner session starts.
    @Published private(set) var sessionScore: Int = 0
    /// ⭐ earned (per-answer) in the current session — resets with the session.
    /// Lets the reward screen show the *full* session total instead of a
    /// separate chest figure, so the in-game chip, the reward screen, and the
    /// home total all agree.
    @Published private(set) var sessionStarsEarned: Int = 0
    /// 💎 earned (per-answer) in the current session — resets with the session.
    /// Lets the reward screen show the full session diamond total.
    @Published private(set) var sessionDiamondsEarned: Int = 0
    /// Play-minutes earned in the current session — the single minutes source
    /// (every `batchAnswers` correct → `batchMinutes`). Shown on the reward
    /// screen so it matches exactly what was added to the bank.
    @Published private(set) var sessionMinutesEarned: Int = 0

    // MARK: - Play "sitting" (whole foreground period, across adventures)
    /// A sitting spans the entire time the app is in the foreground, however many
    /// adventures the child enters. It drives a SINGLE "child finished playing"
    /// report when the app backgrounds — NOT one per adventure (which spammed the
    /// parent). Cumulative across adventures; reset when the report fires.
    @Published private(set) var sittingActive = false
    private var sittingQuestions = 0
    private var sittingCorrect = 0
    private var sittingStars = 0
    private var sittingMinutes = 0
    // Analytics accumulators summarized into the sessionEnd event (per sitting).
    private struct SittingTopic { var q = 0; var correct = 0; var ms = 0.0 }
    private var sittingTopics: [String: SittingTopic] = [:]
    private var sittingResponseMsTotal = 0.0
    private var sittingResponseCount = 0
    private var sittingXP = 0
    private var sittingWheelSpins = 0
    private var sittingMystery = 0

    /// Points awarded for the *last* correct answer, so the UI can flash
    /// '+15' next to the running total. Consumers may set it back to 0.
    @Published var lastEarnedPoints: Int = 0
    /// Minutes already earned today (resets at midnight). Used to enforce
    /// the optional `maxMinutesPerDay` cap.
    @Published private(set) var minutesEarnedToday: Int {
        didSet { defaults.set(minutesEarnedToday, forKey: Key.minutesEarnedToday) }
    }
    /// Net play-minutes actually UNLOCKED today (unlocked − returned-unused),
    /// resets on the same daily boundary as `minutesEarnedToday`. Caps a single
    /// redemption so an accumulated wallet can't be cashed in past the daily
    /// screen-time allowance — the overflow waits in `pendingMinutes` for later.
    /// ⏱ Minutes handed BACK to today's allowance — a child who opened 90 and
    /// stopped at 22 gets the other 68 back, in the wallet AND in the cap.
    ///
    /// Why a second counter instead of just lowering `minutesUnlockedToday`:
    /// that field is merged with `max` across devices on purpose, so two devices
    /// opening time today cannot buy two daily caps (ProgressSnapshot's merge
    /// says so). `max` can only ever RAISE, so every refund was erased by the
    /// next sync — the cloud still held the opened total, and the upload itself
    /// goes through the same merge, so the lowered value could never get there.
    /// Yoav lost 68 of his 90 minutes that way and was told he had hit his daily
    /// maximum while 79 unusable minutes sat in his wallet.
    ///
    /// Both counters only climb, so `max` stays correct on each, two devices
    /// still share one cap, and the refund survives. Same shape as the wallet's
    /// own `…SecondsIn` / `…SecondsOut` pair — see [[cross-device-progress-sync]].
    @Published private(set) var returnedTodayMinutes: Int {
        didSet { defaults.set(returnedTodayMinutes, forKey: Key.returnedTodayMinutes) }
    }

    @Published private(set) var minutesUnlockedToday: Int {
        didSet { defaults.set(minutesUnlockedToday, forKey: Key.minutesUnlockedToday) }
    }
    /// Bonus minutes (wheel/chest) won AFTER today's cap was full — banked for
    /// TOMORROW, capped at `maxCarryOverMinutes`. Becomes playable on the next
    /// day's rollover.
    @Published private(set) var carryOverMinutes: Int {
        didSet { defaults.set(carryOverMinutes, forKey: Key.carryOverMinutes) }
    }
    /// Ceiling on minutes banked for tomorrow.
    static let maxCarryOverMinutes = 30
    /// Questions answered / correct today (reset on the same daily boundary as
    /// minutesEarnedToday). Synced so the parent sees today's activity.
    @Published private(set) var answeredToday: Int {
        didSet { defaults.set(answeredToday, forKey: Key.answeredToday) }
    }
    @Published private(set) var correctToday: Int {
        didSet { defaults.set(correctToday, forKey: Key.correctToday) }
    }
    /// The child's longest-ever run of correct answers. Beating it triggers a
    /// celebration — the core "I want a longer streak" motivator.
    @Published private(set) var bestStreak: Int {
        didSet { defaults.set(bestStreak, forKey: Key.bestStreak) }
    }
    /// Transient flag (not persisted): set true the moment a new record is set,
    /// consumed by the UI to fire the celebration.
    @Published var newStreakRecord = false
    /// Whether we've already celebrated a record in the current run of correct
    /// answers — reset when the streak breaks, so we celebrate once per run.
    private var recordCelebratedThisRun = false
    /// The day `minutesEarnedToday` refers to.
    @Published private(set) var dailyEarnedDate: Date? {
        didSet {
            if let d = dailyEarnedDate { defaults.set(d, forKey: Key.dailyEarnedDate) }
            else { defaults.removeObject(forKey: Key.dailyEarnedDate) }
        }
    }

    // MARK: - Smart Learning Feed signals

    /// [topicRawValue: rolling avg response time, ms]
    @Published private(set) var topicResponseMs: [String: Double] {
        didSet { defaults.set(topicResponseMs, forKey: Key.topicResponseMs) }
    }
    /// [topicRawValue: learned affinity 0...1] — drives explore/exploit.
    @Published private(set) var topicAffinity: [String: Double] {
        didSet { defaults.set(topicAffinity, forKey: Key.topicAffinity) }
    }
    /// [topicRawValue: questions served] — novelty signal for explore.
    @Published private(set) var topicExposure: [String: Int] {
        didSet { defaults.set(topicExposure, forKey: Key.topicExposure) }
    }
    /// [topicRawValue: abandonment count] — replaced question / quit mid-topic.
    @Published private(set) var topicAbandon: [String: Int] {
        didSet { defaults.set(topicAbandon, forKey: Key.topicAbandon) }
    }
    /// [topicRawValue: continuous adaptive difficulty level, 0 (easy) … 2 (hard)].
    /// Maintained by `AdaptiveDifficultyEngine`; floats around the parent's
    /// per-topic base. Rides along with the answer's revision bump (like the
    /// other per-topic signals — not a version trigger of its own).
    @Published private(set) var topicAdaptiveLevel: [String: Double] {
        didSet { defaults.set(topicAdaptiveLevel, forKey: Key.topicAdaptiveLevel) }
    }
    /// Questions answered since the last free Lucky Wheel spin.
    @Published private(set) var wheelProgressCount: Int {
        didSet { defaults.set(wheelProgressCount, forKey: Key.wheelProgressCount) }
    }
    /// A free spin earned by a special moment (a comeback after being away, or a
    /// hot correct-answer streak) — surfaces the wheel even before the normal
    /// per-question count is reached, to pull the kid back and keep momentum.
    @Published private(set) var pendingBonusWheel: Bool {
        didSet { defaults.set(pendingBonusWheel, forKey: Key.pendingBonusWheel) }
    }
    /// When we last gave a "welcome back" bonus wheel, so it fires at most once
    /// per day even if the child reopens the app repeatedly.
    @Published private(set) var lastComebackWheelAt: Date? {
        didSet {
            if let d = lastComebackWheelAt { defaults.set(d, forKey: Key.lastComebackWheelAt) }
            else { defaults.removeObject(forKey: Key.lastComebackWheelAt) }
        }
    }
    /// Minutes lost to the most recent mistake, refundable by a clean correct
    /// answer on the very next question (Risk & Recovery loop). 0 = nothing pending.
    @Published private(set) var recoveryPot: Int {
        didSet { defaults.set(recoveryPot, forKey: Key.recoveryPot) }
    }
    /// Set to a positive value for one tick when the recovery loop refunds time,
    /// so the UI can celebrate. Consumers reset to 0 after reading.
    @Published var lastRecoveredMinutes: Int = 0
    /// 💝 Minutes a parent GAVE (dashboard "+10"). A separate pocket from the
    /// earned wallet `pendingMinutes` — never mixed: shown apart, opened apart
    /// (as a fixed `manual` window), and NOT counted against the daily cap.
    @Published private(set) var parentGiftMinutes: Int {
        didSet { defaults.set(parentGiftMinutes, forKey: Key.parentGiftMinutes) }
    }
    /// 💝 given TODAY (for the "until midnight" daily cap) + which day.
    @Published private(set) var giftGivenToday: Int {
        didSet { defaults.set(giftGivenToday, forKey: Key.giftGivenToday) }
    }
    @Published private(set) var giftGivenDate: Date? {
        didSet {
            if let d = giftGivenDate { defaults.set(d, forKey: Key.giftGivenDate) }
            else { defaults.removeObject(forKey: Key.giftGivenDate) }
        }
    }

    // MARK: - Sync versioning

    /// Monotonic version of the ACTIVE profile's progress. The sync layer uses
    /// `revision` (then `lastModifiedAt`) to decide which device's snapshot wins.
    /// Persisted so it survives relaunches — otherwise every capture would look
    /// like revision 0 and the "is the remote newer?" check could never be true.
    private(set) var revision: Int {
        didSet { defaults.set(revision, forKey: Key.revision) }
    }
    /// 🧹 Reset generation (see ProgressSnapshot.resetEpoch). Persisted.
    private(set) var resetEpoch: Int {
        didSet { defaults.set(resetEpoch, forKey: Key.resetEpoch) }
    }
    /// Wall-clock of the last real local change to the active profile. Tiebreaker
    /// when two devices land on the same `revision`.
    private(set) var lastModifiedAt: Date {
        didSet { defaults.set(lastModifiedAt, forKey: Key.lastModifiedAt) }
    }
    /// True while `apply(_:)` is loading a snapshot (profile switch or a winning
    /// remote update), so the change observers don't mistake it for a local edit
    /// and bump the revision — which would make the receiver always look newest
    /// and ping-pong with the sender.
    private var isApplyingSnapshot = false
    private var versionCancellables: Set<AnyCancellable> = []

    // MARK: - Init

    private init() {
        let d = AppGroup.defaults
        self.pendingMinutes = d.integer(forKey: Key.pendingMinutes)
        self.earnedSecondsIn = d.integer(forKey: Key.earnedSecondsIn)
        self.earnedSecondsOut = d.integer(forKey: Key.earnedSecondsOut)
        self.giftSecondsIn = d.integer(forKey: Key.giftSecondsIn)
        self.giftSecondsOut = d.integer(forKey: Key.giftSecondsOut)
        self.pendingSecondsCarry = d.integer(forKey: Key.pendingSecondsCarry)
        self.manualPausedSeconds = d.integer(forKey: Key.manualPausedSeconds)
        self.totalCorrect = d.integer(forKey: Key.totalCorrect)
        self.totalAnswered = d.integer(forKey: Key.totalAnswered)
        self.unlockEndsAt = d.object(forKey: Key.unlockEndsAt) as? Date
        self.unlockIsManual = d.bool(forKey: Key.unlockIsManual)
        self.baseRevision = d.integer(forKey: Key.baseRevision)
        self.unlockGrantedSeconds = d.integer(forKey: Key.unlockGrantedSeconds)
        self.unlockStartedAt = d.object(forKey: Key.unlockStartedAt) as? Date
        self.unlockStartedUptime = d.double(forKey: Key.unlockStartedUptime)
        self.activeLeaseID = d.string(forKey: Key.activeLeaseID)
        self.unlockKind = d.string(forKey: Key.unlockKind) ?? "earned"
        self.carryIsGift = d.bool(forKey: Key.carryIsGift)
        self.stars = d.integer(forKey: Key.stars)
        self.ownedCharacterIDs = Set(d.stringArray(forKey: Key.ownedCharacters) ?? [])
        self.diamonds = d.integer(forKey: Key.diamonds)
        self.xp = d.integer(forKey: Key.xp)
        self.currentStreak = d.integer(forKey: Key.currentStreak)
        self.dayStreak = d.integer(forKey: Key.dayStreak)
        self.lastSessionDate = d.object(forKey: Key.lastSessionDate) as? Date
        self.lastDailyChestDate = d.object(forKey: Key.lastDailyChestDate) as? Date
        self.lastDailyChallengeDate = d.object(forKey: Key.lastDailyChallengeDate) as? Date
        self.hourlyAnswered = (d.array(forKey: Key.hourlyAnswered) as? [Int]).flatMap { $0.count == 24 ? $0 : nil } ?? Array(repeating: 0, count: 24)
        self.hourlyCorrect = (d.array(forKey: Key.hourlyCorrect) as? [Int]).flatMap { $0.count == 24 ? $0 : nil } ?? Array(repeating: 0, count: 24)

        let unlockedArray = d.stringArray(forKey: Key.unlockedWorlds) ?? ["numbers_kingdom"]
        self.unlockedWorlds = Set(unlockedArray)

        self.worldProgress = (d.dictionary(forKey: Key.worldProgress) as? [String: Int]) ?? [:]
        self.worldStage = (d.dictionary(forKey: Key.worldStage) as? [String: Int]) ?? [:]
        self.ownedCosmetics = Set(d.stringArray(forKey: Key.ownedCosmetics) ?? [])
        self.equippedCosmetic = d.string(forKey: Key.equippedCosmetic)

        self.topicAccuracy = (d.dictionary(forKey: Key.topicAccuracy) as? [String: Double]) ?? [:]
        self.topicAnswered = (d.dictionary(forKey: Key.topicAnswered) as? [String: Int]) ?? [:]
        self.topicCorrect = (d.dictionary(forKey: Key.topicCorrect) as? [String: Int]) ?? [:]
        self.batchCounter = d.integer(forKey: Key.batchCounter)
        self.cycleSeconds = d.double(forKey: Key.cycleSeconds)
        self.wrongStreak = d.integer(forKey: Key.wrongStreak)
        self.totalScore = d.integer(forKey: Key.totalScore)
        self.minutesEarnedToday = d.integer(forKey: Key.minutesEarnedToday)
        self.minutesUnlockedToday = d.integer(forKey: Key.minutesUnlockedToday)
        self.returnedTodayMinutes = d.integer(forKey: Key.returnedTodayMinutes)
        self.carryOverMinutes = d.integer(forKey: Key.carryOverMinutes)
        self.answeredToday = d.integer(forKey: Key.answeredToday)
        self.correctToday = d.integer(forKey: Key.correctToday)
        self.bestStreak = d.integer(forKey: Key.bestStreak)
        self.dailyEarnedDate = d.object(forKey: Key.dailyEarnedDate) as? Date

        self.topicResponseMs = (d.dictionary(forKey: Key.topicResponseMs) as? [String: Double]) ?? [:]
        self.topicAffinity = (d.dictionary(forKey: Key.topicAffinity) as? [String: Double]) ?? [:]
        self.topicExposure = (d.dictionary(forKey: Key.topicExposure) as? [String: Int]) ?? [:]
        self.topicAbandon = (d.dictionary(forKey: Key.topicAbandon) as? [String: Int]) ?? [:]
        self.topicAdaptiveLevel = (d.dictionary(forKey: Key.topicAdaptiveLevel) as? [String: Double]) ?? [:]
        self.wheelProgressCount = d.integer(forKey: Key.wheelProgressCount)
        self.pendingBonusWheel = d.bool(forKey: Key.pendingBonusWheel)
        self.lastComebackWheelAt = d.object(forKey: Key.lastComebackWheelAt) as? Date
        self.recoveryPot = d.integer(forKey: Key.recoveryPot)
        self.parentGiftMinutes = d.integer(forKey: Key.parentGiftMinutes)
        self.giftGivenToday = d.integer(forKey: Key.giftGivenToday)
        self.giftGivenDate = d.object(forKey: Key.giftGivenDate) as? Date

        self.resetEpoch = d.integer(forKey: Key.resetEpoch)
        self.revision = d.integer(forKey: Key.revision)
        self.lastModifiedAt = (d.object(forKey: Key.lastModifiedAt) as? Date) ?? .distantPast

        setupVersionTracking()
    }

    // MARK: - Sync versioning

    /// Watch the synced progress fields and bump `revision`/`lastModifiedAt` on
    /// every genuine local change, so a captured snapshot carries a version that
    /// climbs over time. Each `$prop.dropFirst()` ignores the value the publisher
    /// replays on subscribe, so loading the store at launch doesn't count as an
    /// edit. Changes made by `apply(_:)` are skipped via `isApplyingSnapshot`.
    private func setupVersionTracking() {
        let triggers: [AnyPublisher<Void, Never>] = [
            $pendingMinutes.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            // 💝 gift pocket is SYNCED state — a gift/revoke must bump the
            // revision or the upload ratchet keeps the stale cloud value.
            $parentGiftMinutes.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $giftGivenToday.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $totalCorrect.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $totalAnswered.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $stars.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $diamonds.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $xp.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $totalScore.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $unlockEndsAt.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $minutesEarnedToday.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $currentStreak.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $dayStreak.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $bestStreak.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $answeredToday.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $correctToday.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $carryOverMinutes.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $cycleSeconds.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $ownedCharacterIDs.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $unlockedWorlds.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $worldProgress.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $worldStage.dropFirst().map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(triggers)
            .sink { [weak self] _ in self?.markLocalChange() }
            .store(in: &versionCancellables)
    }

    /// Monotonic count of local edits, in memory only — never persisted, never
    /// synced. `revision` cannot serve this purpose: it is a causal GENERATION,
    /// so a whole burst of local edits deliberately lands on ONE number and then
    /// stays there. Something that needs to know "did the store change since I
    /// looked?" must use this.
    private(set) var localEditSeq: Int = 0

    private func markLocalChange() {
        guard !isApplyingSnapshot else { return }
        localEditSeq &+= 1
        // `revision` is a causal GENERATION, not an activity counter. It used to be
        // `+= 1` on every published field — ~10 bumps per answered question — so the
        // device the child played on most had a permanently higher number and won
        // EVERY cross-device merge, regardless of who wrote last. That is what let
        // a spend on one device be overwritten (and re-uploaded) by the other,
        // resurrecting gift/earned minutes and diamonds. Now a burst of local edits
        // lands on ONE generation above the cloud state we last saw, so two devices
        // editing concurrently sit at the SAME generation and `lastModifiedAt`
        // decides — recency, not play volume.
        revision = max(revision, baseRevision + 1)
        lastModifiedAt = .now
    }

    /// Remember the cloud generation we just adopted, so the next local edit is
    /// exactly one generation above it.
    private func noteAdoptedGeneration(_ r: Int) {
        baseRevision = max(baseRevision, r)
    }

    // MARK: - Derived

    var companionLevel: Int { RewardEngine.level(forXP: xp) }

    var xpForCurrentLevel: Int {
        let thresholds = RewardEngine.levelThresholds
        let lvl = companionLevel
        return thresholds.indices.contains(lvl - 1) ? thresholds[lvl - 1] : 0
    }

    var xpForNextLevel: Int {
        let thresholds = RewardEngine.levelThresholds
        let lvl = companionLevel
        return thresholds.indices.contains(lvl) ? thresholds[lvl] : (thresholds.last ?? 0) + 500
    }

    var isUnlocked: Bool {
        guard let end = unlockEndsAt else { return false }
        return end > Date()
    }

    var unlockSecondsRemaining: Int {
        guard let end = unlockEndsAt else { return 0 }
        return max(0, Int(end.timeIntervalSinceNow))
    }

    var dailyChestAvailable: Bool {
        return !DayGate.usedToday(lastDailyChestDate)
    }

    func accuracy(for topic: Topic) -> Double {
        topicAccuracy[topic.rawValue] ?? 0.7
    }

    // MARK: - Smart Learning Feed — derived signals

    /// Learned affinity for a topic. Unseen topics are seeded from whether the
    /// parent enabled them: enabled → 0.6 (slight head-start), else 0.4.
    func affinity(for topic: Topic) -> Double {
        if let a = topicAffinity[topic.rawValue] { return a }
        // One topic's check — building the whole playable set for each topic made
        // every next question cost ~50ms (Rani: the stutter between questions).
        let open = ProfileStore.shared.active.map { $0.allows(topic) } ?? ParentSettings.shared.enabledTopics.contains(topic)
        return open ? 0.6 : 0.4
    }

    /// Rolling average response time (ms) for a topic; nil if never answered.
    func responseMs(for topic: Topic) -> Double? {
        topicResponseMs[topic.rawValue]
    }

    func exposure(for topic: Topic) -> Int {
        topicExposure[topic.rawValue] ?? 0
    }

    /// Current adaptive difficulty level for a topic (continuous 0…2). Seeded
    /// from the parent's chosen base until the child has been measured.
    func adaptiveLevel(for topic: Topic, base: Difficulty) -> Double {
        topicAdaptiveLevel[topic.rawValue] ?? AdaptiveDifficultyEngine.level(for: base)
    }

    /// Feeds one answer's signals into the adaptive engine and stores the new
    /// per-topic level. The parent's per-topic choice is the anchor the level
    /// floats around.
    private func adjustAdaptiveLevel(topic: Topic, correct: Bool, fast: Bool,
                                     hintUsed: Bool, abandoned: Bool) {
        let base = ProfileStore.shared.active?.difficulty(for: topic) ?? .easy
        let key = topic.rawValue
        let current = topicAdaptiveLevel[key] ?? AdaptiveDifficultyEngine.level(for: base)
        let signals = AdaptiveDifficultyEngine.Signals(
            correct: correct, fast: fast, hintUsed: hintUsed, abandoned: abandoned)
        topicAdaptiveLevel[key] = AdaptiveDifficultyEngine.updatedLevel(
            current: current, base: base, signals: signals)
    }

    /// Overall rolling accuracy across every topic the child has touched.
    var overallAccuracy: Double {
        let vals = topicAccuracy.values
        guard !vals.isEmpty else { return 0.7 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    /// Questions still to answer before the next free Lucky Wheel spin.
    var questionsUntilWheel: Int {
        max(0, ParentSettings.shared.questionsPerWheel - wheelProgressCount)
    }

    /// True once enough questions have been answered to earn a free spin — or
    /// when a bonus spin was granted (comeback / hot streak).
    var freeWheelAvailable: Bool {
        pendingBonusWheel || wheelProgressCount >= ParentSettings.shared.questionsPerWheel
    }

    /// Grant a free spin for a special moment (comeback / streak).
    func grantBonusWheel() {
        pendingBonusWheel = true
    }

    /// If the child is returning after being away (~a day), hand them a
    /// "welcome back" spin — at most once per calendar day. Call on the map
    /// before auto-presenting the wheel.
    func grantComebackWheelIfReturning() {
        guard let last = lastSessionDate else { return }   // brand-new child → no comeback
        let hoursAway = -last.timeIntervalSinceNow / 3600
        guard hoursAway >= 20 else { return }
        if DayGate.usedToday(lastComebackWheelAt) { return }
        lastComebackWheelAt = Date()
        grantBonusWheel()
    }

    /// Approximate number of correct answers needed to reach the next level.
    var questionsUntilNextLevel: Int {
        let remaining = max(0, xpForNextLevel - xp)
        let perCorrect = max(1, RewardEngine.xpPerCorrect)
        return Int(ceil(Double(remaining) / Double(perCorrect)))
    }

    /// Reset the wheel counter after the child spins the free wheel (also clears
    /// any pending bonus spin).
    func resetWheelProgress() {
        wheelProgressCount = 0
        pendingBonusWheel = false
        sittingWheelSpins += 1   // the child actually spun the wheel
    }

    /// Records that the child abandoned a topic (replaced its question or quit
    /// mid-topic). Lowers affinity so the feed offers it less often.
    func recordAbandon(topic: Topic) {
        let key = topic.rawValue
        topicAbandon[key] = (topicAbandon[key] ?? 0) + 1
        let current = affinity(for: topic)
        topicAffinity[key] = min(1, max(0, current - 0.08))
        // Giving up on a question is a strong "too hard right now" signal.
        adjustAdaptiveLevel(topic: topic, correct: false, fast: false,
                            hintUsed: false, abandoned: true)
    }

    /// Seed a brand-new child's learning signals from the interests and level
    /// the parent picked, so the Smart Feed isn't cold on day one. No-op once
    /// the child has answered anything (we don't overwrite real signals).
    func seedLearning(from profile: Profile) {
        guard totalAnswered == 0 else { return }
        let topics = InterestCatalog.topics(for: profile.interests)
        let boost = profile.learningLevel.affinityBoost
        for topic in topics {
            let base = (ProfileStore.shared.active?.playableTopics ?? ParentSettings.shared.enabledTopics).contains(topic) ? 0.6 : 0.4
            topicAffinity[topic.rawValue] = min(1, base + boost)
        }
        // Starting difficulty is no longer seeded into a global setting — it's
        // derived per-child from `profile.learningLevel` (see `Profile.difficulty(for:)`)
        // until the parent overrides it per-topic from their dashboard.
    }

    /// Continuously updates the per-topic learning signals after each answer.
    /// Called from `recordCorrect` / `recordWrong`.
    private func updateLearningSignals(topic: Topic, correct: Bool, responseMs: Double,
                                       hintUsed: Bool = false, affectsAdaptive: Bool = true) {
        let key = topic.rawValue
        // Rolling response time (only when we have a real measurement).
        var fast = false
        if responseMs > 0 {
            if let prev = topicResponseMs[key] {
                fast = responseMs < prev * 0.9
                topicResponseMs[key] = prev * 0.8 + responseMs * 0.2
            } else {
                topicResponseMs[key] = responseMs
            }
        }
        topicExposure[key] = (topicExposure[key] ?? 0) + 1

        // Affinity drift — the heart of the discovery engine.
        var delta = correct ? 0.06 : -0.04
        if correct && fast { delta += 0.03 }
        let current = affinity(for: topic)
        topicAffinity[key] = min(1, max(0, current + delta))

        // Nudge the adaptive difficulty level from this answer's signals —
        // except in the bonus arena, where EVERYTHING is deliberately extra-hard
        // and must not distort the child's regular per-topic level.
        if affectsAdaptive {
            adjustAdaptiveLevel(topic: topic, correct: correct, fast: fast,
                                hintUsed: hintUsed, abandoned: false)
        }
    }

    // MARK: - Recording

    struct AnswerContext {
        let topic: Topic
        let combo: Int
        let isSuperQuestion: Bool
        let isMysteryPortal: Bool
        /// 💫 The rare extra-hard question worth real minutes.
        var isBonusQuestion: Bool = false
    }

    @discardableResult
    func recordCorrect(_ ctx: AnswerContext,
                       minutesPerCorrect: Int,
                       responseMs: Double = 0,
                       hadMistakeThisQuestion: Bool = false,
                       hintUsed: Bool = false,
                       grantsScreenTime: Bool = true,
                       cycleMultiplier: Double = 1,
                       affectsAdaptive: Bool = true) -> Int {
        totalAnswered += 1
        totalCorrect += 1
        _ = minutesEarnedTodayRespectingDate()   // roll over the day if needed
        answeredToday += 1
        correctToday += 1
        recordHourly(correct: true)
        currentStreak += 1
        wrongStreak = 0  // any correct answer breaks the penalty streak
        AppAnalytics.questionAnswered(topic: ctx.topic.rawValue, correct: true)
        // Hot-streak reward: a free spin at streak milestones (fires once each
        // since the streak rises by 1) — keeps the run exciting and motivating.
        if currentStreak == 5 || currentStreak == 10 { grantBonusWheel() }
        // Stars scale with the NEW streak length, so each consecutive correct
        // answer is worth more — the incentive to keep the run going.
        let earned = RewardEngine.starsForCorrect(
            combo: currentStreak,
            isSuperQuestion: ctx.isSuperQuestion,
            isMysteryPortal: ctx.isMysteryPortal,
            isBonusQuestion: ctx.isBonusQuestion
        )
        stars += earned
        // 💎 spendable wallet — earned alongside ⭐, but at a slower rate so the
        // shop keeps its value. Stars stay the leaderboard rank; diamonds buy.
        // Limited-time event bonus (e.g. weekend / topic-of-the-day → 💎×2).
        let eventMult = GameEvent.current()?.diamondMultiplier(for: ctx.topic) ?? 1
        let earnedDiamonds = RewardEngine.diamondsForCorrect(
            combo: currentStreak,
            isSuperQuestion: ctx.isSuperQuestion,
            isMysteryPortal: ctx.isMysteryPortal,
            isBonusQuestion: ctx.isBonusQuestion
        ) * eventMult
        diamonds += earnedDiamonds
        sessionDiamondsEarned += earnedDiamonds
        // Personal best — beating it is a big, celebrated moment. Fire the
        // celebration ONCE per run (the moment the record breaks), not on every
        // subsequent answer.
        if currentStreak > bestStreak {
            bestStreak = currentStreak
            if currentStreak >= 3 && !recordCelebratedThisRun {
                recordCelebratedThisRun = true
                newStreakRecord = true
                // 🏆 …and one row in the parent's activity centre (no push).
                let best = currentStreak
                Task { @MainActor in LiveEventReporter.report(.personalBest, value: "\(best)") }
            }
        }
        sessionStarsEarned += earned
        sittingQuestions += 1
        sittingCorrect += 1
        sittingStars += earned

        // Score — the headline 'ניקוד' metric. Includes combo / bonus boosts.
        let topicDifficulty = ProfileStore.shared.active?.difficulty(for: ctx.topic) ?? .easy
        let pts = RewardEngine.pointsForCorrect(
            combo: ctx.combo,
            isSuperQuestion: ctx.isSuperQuestion,
            isMysteryPortal: ctx.isMysteryPortal,
            difficulty: topicDifficulty,
            isBonusQuestion: ctx.isBonusQuestion
        )
        totalScore += pts
        sessionScore += pts
        lastEarnedPoints = pts

        // Time reward — ONLY in Earn-to-Unlock sessions. In Free Learning mode
        // the reward is in-game progression (XP/coins/levels), never minutes.
        // 🌈 Topic balance counts every earn-mode correct answer per topic/day.
        let topicCountToday = grantsScreenTime ? bumpTopicAnsweredToday(ctx.topic) : 0
        lastPaidSeconds = 0
        if grantsScreenTime {
            // ⏱ Each right answer pays its seconds STRAIGHT into the wallet (24s of
            // a 4-min/10-answer rate by default) — the number on the home screen
            // moves with every answer (Rani, 2026-10-06; it used to wait for a
            // whole batch of 10). See `payEarned`.
            // 🌈 A) Diminishing returns: past the daily soft cap in ONE topic,
            // that topic earns at HALF rate — grinding a single favorite all
            // day stops paying; other topics stay at full rate. The companion
            // nudges (positively) the moment the cap is reached.
            let balanceFactor: Double = topicCountToday > Self.sameTopicSoftCap ? 0.5 : 1.0
            if topicCountToday == Self.sameTopicSoftCap { topicBalanceNudgeTopic = ctx.topic }
            // 💫 Bonus arena pays DOUBLE (cycleMultiplier 2).
            let pay = Double(secondsPerCorrect) * max(1, cycleMultiplier) * balanceFactor
            lastPaidSeconds = payEarned(seconds: Int(pay.rounded()))
            // 🌈 B) Variety bonus — once per day, playing enough in 3 different
            // topics grants extra minutes (the carrot beside A's gentle brake).
            if !varietyBonusGrantedToday {
                let varied = topicCountsToday().values.filter { $0 >= Self.varietyMinAnswersPerTopic }.count
                if varied >= Self.varietyTopicsNeeded {
                    defaults.set(Date(), forKey: varietyBonusDateKey)
                    let granted = grantMinutesCapped(Self.varietyBonusMinutes)
                    if granted > 0 {
                        sessionMinutesEarned += granted
                        sittingMinutes += granted
                        varietyBonusJustEarned = granted
                    }
                }
            }
        }
        xp += RewardEngine.xpPerCorrect
        updateTopicStat(topic: ctx.topic, correct: true)
        updateLearningSignals(topic: ctx.topic, correct: true, responseMs: responseMs,
                              hintUsed: hintUsed, affectsAdaptive: affectsAdaptive)
        wheelProgressCount += 1

        // Per-sitting analytics for the sessionEnd summary.
        sittingXP += RewardEngine.xpPerCorrect
        if responseMs > 0 { sittingResponseMsTotal += responseMs; sittingResponseCount += 1 }
        if ctx.isMysteryPortal { sittingMystery += 1 }
        var st = sittingTopics[ctx.topic.displayName] ?? SittingTopic()
        st.q += 1; st.correct += 1; if responseMs > 0 { st.ms += responseMs }
        sittingTopics[ctx.topic.displayName] = st

        // Risk & Recovery loop (Earn mode only — there's no time to win back in
        // Free Learning). A clean first-try correct answer redeems minutes a
        // previous mistake parked in the recovery pot.
        if grantsScreenTime {
            if hadMistakeThisQuestion {
                // This question contributed to the pot — carry it forward.
            } else if recoveryPot > 0 {
                let refund = recoveryPot
                creditEarned(seconds: refund * 60)
                recoveryPot = 0
                lastRecoveredMinutes = refund
            }
        }

        return earned
    }

    // MARK: - Daily cap on earned minutes

    /// Effective daily cap for the ACTIVE child: a per-child value (set by the
    /// parent and synced via ChildRecord) overrides the device-global setting.
    var dailyCap: (enabled: Bool, max: Int) {
        let s = ParentSettings.shared
        return ProfileStore.shared.active?
            .resolvedDailyCap(globalEnabled: s.dailyCapEnabled, globalMax: s.maxMinutesPerDay)
            ?? (s.dailyCapEnabled, s.maxMinutesPerDay)
    }

    // MARK: - 💫 Bonus question: once a day

    /// The 7-minute "שאלת ענק" was meant to be the rarest event in the game, but
    /// at 6% a question from Q3 on it showed up in ~43% of 15-question sessions —
    /// and paid what 17.5 regular right answers pay. Rani saw Dan get it out of
    /// nowhere. One per child per day keeps it a jackpot.
    private var bonusQuestionDayKey: String {
        "bonusQ.servedDay." + (ProfileStore.shared.activeID?.uuidString ?? "none")
    }
    var bonusQuestionServedToday: Bool {
        DayGate.usedToday(UserDefaults.standard.object(forKey: bonusQuestionDayKey) as? Date)
    }
    /// Marked when the question is SHOWN, not when it is answered — a wrong
    /// answer still used up today's chance.
    func markBonusQuestionServed() {
        UserDefaults.standard.set(Date(), forKey: bonusQuestionDayKey)
    }

    /// True iff the kid has already hit today's earning ceiling.
    var atDailyCap: Bool {
        guard dailyCap.enabled else { return false }
        return minutesRemainingTodayCap == 0
    }

    /// Minutes the kid can still earn today (when cap is active). When the
    /// cap is disabled, returns `.max` so callers can treat it as unlimited.
    var minutesRemainingTodayCap: Int {
        let cap = dailyCap
        guard cap.enabled else { return .max }
        return max(0, max(0, cap.max) - minutesEarnedTodayRespectingDate())
    }

    /// Minutes earned today, rolling over silently if the date has changed.
    /// Mutating helper so the in-memory counter always reflects "today".
    @discardableResult
    private func minutesEarnedTodayRespectingDate() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        // Roll over ONLY when the stored date is a genuinely PAST day. A same-day
        // value must NOT trigger a rollover — a spurious rollover re-releases
        // banked carry-over minutes and zeroes the daily counters, which made the
        // redeemable minutes jump around.
        if let last = dailyEarnedDate.map({ Calendar.current.startOfDay(for: $0) }) {
            if last == today { return minutesEarnedToday }
            if last > today {
                // FUTURE-dated: the clock was moved forward (Settings → Date &
                // Time), or a peer merged a future-dated snapshot. The old code
                // took the `last >= today` branch FOREVER, which permanently
                // froze both daily caps — `minutesUnlockedTodayResolved` then read
                // 0 and the child could re-open a full cap all day, on every
                // device. Pin the record to today and KEEP the counters (so the
                // caps still bite); never release carry-over on a future stamp.
                dailyEarnedDate = today
                return minutesEarnedToday
            }
        }
        // New day — first, yesterday's banked bonus minutes become playable.
        if carryOverMinutes > 0 {
            creditEarned(seconds: carryOverMinutes * 60)
            carryOverMinutes = 0
        }
        // Reset the daily counters together.
        minutesEarnedToday = 0
        minutesUnlockedToday = 0
        returnedTodayMinutes = 0
        answeredToday = 0
        correctToday = 0
        dailyEarnedDate = today
        return 0
    }

    /// Adds minutes to `pendingMinutes` while honoring the daily cap.
    /// Outcome of granting bonus minutes — lets the UI explain exactly what
    /// happened (added now vs. banked for tomorrow vs. bank full).
    struct BonusGrant { var addedToday: Int = 0; var bankedForTomorrow: Int = 0; var bankFull: Bool = false }

    /// How many bonus minutes can still be granted right now — today's remaining
    /// cap room PLUS the room left in tomorrow's bank. 0 means no minute prize can
    /// land (used to stop the wheel/chest from offering minutes).
    func bonusMinutesRoom() -> Int {
        let cap = dailyCap
        guard cap.enabled else { return .max }
        let todayRoom = max(0, cap.max - minutesEarnedToday)
        let bankRoom = max(0, Self.maxCarryOverMinutes - carryOverMinutes)
        return todayRoom + bankRoom
    }

    /// Roll the daily counters over if the calendar day changed — and release any
    /// minutes banked for "tomorrow" into the playable pool. Safe to call often
    /// (e.g. on app foreground); it's a no-op within the same day.
    func applyDailyRolloverIfNeeded() {
        _ = minutesEarnedTodayRespectingDate()
    }

    /// Bonus play-minutes from the Lucky Wheel / chests — a reward for engagement.
    /// Fills today's remaining allowance first; once today's cap is full, the
    /// overflow is BANKED for tomorrow (capped at `maxCarryOverMinutes`). Returns
    /// what actually happened so the UI can show the right message.
    @discardableResult
    func grantBonusMinutes(_ amount: Int) -> BonusGrant {
        guard amount > 0 else { return BonusGrant() }
        let cap = dailyCap
        guard cap.enabled else {
            creditEarned(seconds: amount * 60)
            return BonusGrant(addedToday: amount)
        }
        _ = minutesEarnedTodayRespectingDate()
        var result = BonusGrant()
        let todayRoom = max(0, cap.max - minutesEarnedToday)
        let toToday = min(amount, todayRoom)
        if toToday > 0 {
            creditEarned(seconds: toToday * 60)
            minutesEarnedToday += toToday
            result.addedToday = toToday
        }
        let overflow = amount - toToday
        if overflow > 0 {
            let bankRoom = max(0, Self.maxCarryOverMinutes - carryOverMinutes)
            let banked = min(overflow, bankRoom)
            if banked > 0 { carryOverMinutes += banked; result.bankedForTomorrow = banked }
        }
        result.bankFull = (carryOverMinutes >= Self.maxCarryOverMinutes)
        return result
    }

    /// Grant earned play-minutes, respecting the daily cap. What fits under
    /// today's cap becomes playable now; the OVERFLOW is banked for tomorrow
    /// (up to `maxCarryOverMinutes`), so the parent dashboard's promise —
    /// "מה שירוויח עכשיו נשמר למחר" — is actually kept for regular earning,
    /// not just for wheel/chest bonuses. Returns the amount added to TODAY's
    /// playable pool (0 when the cap is full — the rest is banked).
    @discardableResult
    func grantMinutesCapped(_ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        _ = minutesEarnedTodayRespectingDate()
        let cap = dailyCap
        guard cap.enabled else {
            creditEarned(seconds: amount * 60)
            return amount
        }
        let remaining = max(0, cap.max - minutesEarnedToday)
        let toToday = min(amount, remaining)
        if toToday > 0 {
            creditEarned(seconds: toToday * 60)
            minutesEarnedToday += toToday
            if dailyEarnedDate == nil {
                dailyEarnedDate = Calendar.current.startOfDay(for: Date())
            }
        }
        // Bank the overflow for tomorrow — capped, like grantBonusMinutes.
        let overflow = amount - toToday
        if overflow > 0 {
            let bankRoom = max(0, Self.maxCarryOverMinutes - carryOverMinutes)
            if bankRoom > 0 { carryOverMinutes += min(overflow, bankRoom) }
        }
        return toToday
    }

    /// Seed pleasant demo numbers for App Store screenshots (DEMO_SCREEN only).
    func seedForDemo() {
        stars = 213
        resetWallets(earnedMinutes: 12, giftMinutes: 10)   // 💝 gift shown apart from earned
        cycleSeconds = 144            // 6/10 toward the 4-min bonus
        currentStreak = 5
        bestStreak = 9
        dayStreak = 4
        totalAnswered = 48
        totalCorrect = 44
        answeredToday = 12
        correctToday = 11
        minutesEarnedToday = 16
        // Stamp TODAY so the date-rollover guard doesn't wipe the seeded daily
        // counters the first time minutes are granted (e.g. opening the chest).
        dailyEarnedDate = Calendar.current.startOfDay(for: Date())
        sessionStarsEarned = 24
        sessionDiamondsEarned = 6
        diamonds = 120
        xp = 96
        topicAnswered = [Topic.math.rawValue: 20, Topic.logic.rawValue: 12, Topic.hebrew.rawValue: 9, Topic.science.rawValue: 7]
        topicCorrect  = [Topic.math.rawValue: 19, Topic.logic.rawValue: 11, Topic.hebrew.rawValue: 8, Topic.science.rawValue: 6]
        topicAccuracy = [Topic.math.rawValue: 0.95, Topic.logic.rawValue: 0.92, Topic.hebrew.rawValue: 0.89, Topic.science.rawValue: 0.86]
        topicAffinity = [Topic.math.rawValue: 0.9, Topic.logic.rawValue: 0.8, Topic.science.rawValue: 0.7]
        unlockedWorlds = Set(Worlds.all.prefix(4).map { $0.id })
        // DEMO_TIERS=1 → 🏆 every tier on one screen: silver room 4, bronze boss
        // waiting, champion, gold room 3; the rest unvisited.
        if ProcessInfo.processInfo.environment["DEMO_TIERS"] != nil {
            worldStage = ["math_kingdom": 9, "english_land": 13, "hebrew_land": 30, "logic_lab": 22]
            worldProgress = ["math_kingdom": 9, "english_land": 9, "hebrew_land": 9, "logic_lab": 9]
            // Like a real child who has played: no "חָדָשׁ!" / gift moments left.
            if let cid = ProfileStore.shared.activeID {
                for w in Worlds.all {
                    if let item = w.topic.pack ?? WorldPasses.pass(for: w.topic) {
                        PackKidState.markRevealed(item.id, childID: cid)
                        PackKidState.markOpened(item.id, childID: cid)
                    }
                }
            }
        }
        // DEMO_BIG=1 → stress-test the currency chips with huge balances.
        if ProcessInfo.processInfo.environment["DEMO_BIG"] != nil {
            stars = 1284500      // → "1.3M"
            diamonds = 2500      // → "2.5K"
            resetWallets(earnedMinutes: 1280, giftMinutes: giftSecondsAvailable / 60)
        }
    }

    /// Reset the per-session score — call at the start of QuestionRunner.
    func resetSessionScore() {
        sessionScore = 0
        sessionStarsEarned = 0
        sessionDiamondsEarned = 0
        sessionMinutesEarned = 0
        lastEarnedPoints = 0
    }

    /// Begin (or continue) a play sitting. Reports `sessionStart` to the parent
    /// ONCE — on the first adventure of the sitting — instead of on every adventure.
    func beginSitting() {
        guard !sittingActive else { return }   // already in a sitting → don't re-notify
        sittingActive = true
        sittingQuestions = 0; sittingCorrect = 0; sittingStars = 0; sittingMinutes = 0
        sittingTopics = [:]; sittingResponseMsTotal = 0; sittingResponseCount = 0
        sittingXP = 0; sittingWheelSpins = 0; sittingMystery = 0
        LiveEventReporter.report(.sessionStart)
    }

    /// End the sitting when the child LEAVES THE APP (call on app background).
    /// Sends ONE `sessionEnd` summary covering every adventure in the sitting.
    /// No-op if nothing was played, so browsing the map alone never notifies.
    func endSittingAndReport() {
        guard sittingActive else { return }
        sittingActive = false
        let answered = max(sittingQuestions, sittingCorrect)
        let accuracy = answered > 0 ? Int(Double(sittingCorrect) / Double(answered) * 100) : 0
        let avgMs = sittingResponseCount > 0 ? Int(sittingResponseMsTotal / Double(sittingResponseCount)) : 0
        let topicsPayload: [String: [String: Int]] = sittingTopics.mapValues { t in
            ["q": t.q, "correct": t.correct, "avgMs": t.correct > 0 ? Int(t.ms / Double(t.correct)) : 0]
        }
        LiveEventReporter.report(.sessionEnd, extra: [
            "questions": answered,
            "correct": sittingCorrect,
            "accuracy": accuracy,
            "minutes": sittingMinutes,
            "stars": sittingStars,
            "xp": sittingXP,
            "avgResponseMs": avgMs,
            "wheelSpins": sittingWheelSpins,
            "mystery": sittingMystery,
            "topics": topicsPayload
        ])
        sittingQuestions = 0; sittingCorrect = 0; sittingStars = 0; sittingMinutes = 0
        sittingTopics = [:]; sittingResponseMsTotal = 0; sittingResponseCount = 0
        sittingXP = 0; sittingWheelSpins = 0; sittingMystery = 0
    }

    /// Records a wrong answer. Returns the number of penalty minutes applied
    /// this tick (0 if penalty disabled or threshold not met). The caller can
    /// use the return value to show a gentle "lost X minutes" toast.
    /// Minutes a single mistake costs: half of the per-correct reward, rounded,
    /// at least 1 (4→2, 2→1, 3→2). 0 when the parent disabled mistake costs.
    func mistakePenaltyMinutes(minutesPerCorrect: Int) -> Int {
        guard ParentSettings.shared.penaltyEnabled, minutesPerCorrect > 0 else { return 0 }
        return max(1, Int((Double(minutesPerCorrect) / 2.0).rounded()))
    }

    /// 🐉 A boss-battle answer COUNTS as a question — answered/correct totals,
    /// today's count and the hourly stat — but pays nothing per answer: the boss
    /// pays its own prize on a win. Before this, boss answers were invisible to
    /// the parent's reports, the admin panel and the gift activation count
    /// (Rani saw Noa playing with "0 questions today", 2026-10-03).
    func recordBossAnswer(correct: Bool) {
        totalAnswered += 1
        _ = minutesEarnedTodayRespectingDate()   // roll over the day if needed
        answeredToday += 1
        if correct {
            totalCorrect += 1
            correctToday += 1
        }
        recordHourly(correct: correct)
    }

    /// 🎮 A mini-game answer (⚡ נָכוֹן אוֹ לֹא, 🔗 זוּגוֹת) counts exactly like a
    /// boss answer: it shows up in the parent's reports and today's total, and
    /// pays nothing per answer — the game pays its own ⭐/💎 at the end, and
    /// never minutes.
    func recordGameAnswer(correct: Bool) {
        recordBossAnswer(correct: correct)
    }

    /// Records a wrong pick. Deducts half the per-correct reward and parks it in
    /// the recovery pot — a clean correct answer on the next question wins it
    /// back (Risk & Recovery loop). Returns the minutes deducted this tick.
    @discardableResult
    func recordWrong(topic: Topic, minutesPerCorrect: Int, hintUsed: Bool = false,
                     grantsScreenTime: Bool = true, affectsAdaptive: Bool = true) -> Int {
        AppAnalytics.questionAnswered(topic: topic.rawValue, correct: false)
        totalAnswered += 1
        _ = minutesEarnedTodayRespectingDate()   // roll over the day if needed
        answeredToday += 1
        recordHourly(correct: false)
        sittingQuestions += 1
        currentStreak = 0
        recordCelebratedThisRun = false   // streak broke — arm the next record
        wrongStreak += 1
        xp += RewardEngine.xpPerQuestion
        updateTopicStat(topic: topic, correct: false)
        sittingXP += RewardEngine.xpPerQuestion
        var stW = sittingTopics[topic.displayName] ?? SittingTopic()
        stW.q += 1; sittingTopics[topic.displayName] = stW
        // A miss eases the adaptive level for this topic (gentle, capped) — but
        // NOT in the bonus arena, where missing extra-hard questions is expected
        // and must not lower the child's regular level.
        if affectsAdaptive {
            adjustAdaptiveLevel(topic: topic, correct: false, fast: false,
                                hintUsed: hintUsed, abandoned: false)
        }

        // Gentle affinity nudge down (no exposure/response bump — those are
        // counted once per question when it's finally answered correctly).
        let key = topic.rawValue
        topicAffinity[key] = min(1, max(0, affinity(for: topic) - 0.04))

        // Free Learning mode has no screen-time economy, so mistakes never cost
        // anything there — only in-game progress is at stake.
        guard grantsScreenTime else { return 0 }
        guard ParentSettings.shared.penaltyEnabled else { return 0 }

        // Gentle: a mistake costs HALF a step, taken off the next right answer —
        // never out of the wallet, so the number the child sees never drops.
        // Returns the SECONDS owed, for a soft "−Ns · כמעט!" toast.
        lastPenaltyMinutes = 0
        return oweEarned(seconds: halfStepSeconds)
    }

    /// 💡 What one hint costs — the same as a mistake: half a step off the cycle
    /// progress, never a minute the child already banked.
    ///
    /// It used to cost 2 banked minutes. A right answer is worth one step (24
    /// seconds by default), so a hint cost five of them for removing ONE wrong
    /// option out of four (Rani: "רמז לדעתי צריך להיות 12 שניות כמו טעות").
    /// Charging it in the same currency as a mistake also means it follows the
    /// parent's own settings instead of a number written here.
    var hintCostSeconds: Int {
        guard ParentSettings.shared.penaltyEnabled else { return 0 }
        return halfStepSeconds
    }

    /// Take the hint's cost, off the next right answer. Returns the seconds
    /// owed (0 when the parent turned penalties off, or a miss already owes it).
    @discardableResult
    func chargeHint() -> Int {
        guard ParentSettings.shared.penaltyEnabled else { return 0 }
        return oweEarned(seconds: hintCostSeconds)
    }

    private func updateTopicStat(topic: Topic, correct: Bool) {
        let key = topic.rawValue
        let answered = (topicAnswered[key] ?? 0) + 1
        let correctCount = (topicCorrect[key] ?? 0) + (correct ? 1 : 0)
        topicAnswered[key] = answered
        topicCorrect[key] = correctCount

        // Rolling accuracy: weighted average favoring recent
        let newAcc: Double
        if let prev = topicAccuracy[key] {
            let weight = 0.2
            newAcc = prev * (1 - weight) + (correct ? 1.0 : 0.0) * weight
        } else {
            newAcc = correct ? 1.0 : 0.0
        }
        topicAccuracy[key] = newAcc
    }

    // MARK: - Chest / Daily

    @discardableResult
    func applyChestReward(_ reward: ChestReward) -> BonusGrant {
        // Two pockets: ⭐ stars climb the leaderboard rank, 💎 diamonds fill the
        // spendable shop wallet. A gift can grant either or both.
        stars += reward.stars
        diamonds += reward.diamonds
        // Chest/wheel time is a BONUS: it fills today's allowance, then banks the
        // overflow for tomorrow (≤30) — so a win is never silently lost.
        let grant = grantBonusMinutes(reward.minutes)
        if let cosmetic = reward.cosmeticID {
            ownedCosmetics.insert(cosmetic)
        }
        return grant
    }

    func openDailyChest() {
        lastDailyChestDate = Date()
    }

    // MARK: - Daily challenge (answer-N-today goal + streak)

    /// How many questions make up today's challenge. Small enough to finish in
    /// one short sitting, so the streak feels achievable every day.
    static let dailyChallengeTarget = 10

    /// CORRECT answers today toward the goal, capped at the target.
    ///
    /// It counted every answer, right or wrong — while the card's own copy says
    /// "ענה נכון על 10 שאלות היום". Ten random taps collected the diamonds, and
    /// the promise on screen was not the promise in the code.
    var dailyChallengeProgress: Int { min(correctToday, Self.dailyChallengeTarget) }

    /// The goal was reached today (regardless of whether the reward was claimed).
    var dailyChallengeGoalMet: Bool { correctToday >= Self.dailyChallengeTarget }

    /// Today's reward was already collected.
    var dailyChallengeClaimed: Bool {
        return DayGate.usedToday(lastDailyChallengeDate)
    }

    /// Goal met AND not yet claimed today → the card shows a "collect" button.
    var dailyChallengeRewardReady: Bool { dailyChallengeGoalMet && !dailyChallengeClaimed }

    /// Collect today's challenge reward (once per day). Diamonds + bonus minutes
    /// grow gently with the day-streak so a longer streak feels more rewarding.
    /// The streak itself is the existing `dayStreak` (maintained per session).
    @discardableResult
    func claimDailyChallenge() -> BonusGrant {
        guard dailyChallengeRewardReady else { return BonusGrant() }
        lastDailyChallengeDate = Date()
        let streakBonus = min(dayStreak, 7)                 // caps the ramp at a week
        let reward = ChestReward(stars: 0,
                                 diamonds: 15 + streakBonus * 2,
                                 minutes: 3,
                                 cosmeticID: nil)
        AppAnalytics.log("daily_challenge_claimed", ["streak": "\(dayStreak)"])
        return applyChestReward(reward)
    }

    // MARK: - World progression

    func unlockWorld(_ id: String) {
        let isNew = !unlockedWorlds.contains(id)
        unlockedWorlds.insert(id)
        if isNew {
            AppAnalytics.worldUnlocked(id)
            // 🗺 …and one row in the parent's activity centre (no push).
            let name = Worlds.all.first { $0.id == id }?.name ?? id
            Task { @MainActor in LiveEventReporter.report(.worldUnlocked, value: name) }
        }
    }

    func canUnlock(world: World) -> Bool {
        stars >= world.starsToUnlock
    }

    // MARK: - 🏆 World tiers (Rani, 2026-10-06: "10/10 and then nothing")
    //
    // Each world is walked three times — ⭐ bronze, ⭐⭐ silver, ⭐⭐⭐ gold — ten
    // rooms each, the boss in the tenth. Beating it completes the tier (👑 +
    // diamonds) and opens the next one a grade higher; after gold the world is
    // "champion" and simply stays playable. Stored as ONE growing number per
    // world (tier × 10 + room) so the cross-device max-merge can never undo a
    // tier: resetting rooms to 1 would be overwritten by the other device's 9.

    static let worldTierCount = 3
    static let championStage = worldTierCount * 10
    static let tierCompleteDiamonds = 100
    static let firstVisitDiamonds = 20

    /// tier × 10 + room. Legacy kids (rooms only) read as bronze at their room.
    func stage(in worldID: String) -> Int {
        min(Self.championStage, max(worldStage[worldID] ?? 0, worldProgress[worldID] ?? 0))
    }

    /// 0 = ⭐ bronze, 1 = ⭐⭐ silver, 2 = ⭐⭐⭐ gold, 3 = champion.
    func worldTier(in worldID: String) -> Int { stage(in: worldID) / 10 }

    /// Grades added to this world's questions: one per tier, at most two.
    func tierGradeOffset(in worldID: String) -> Int { min(worldTier(in: worldID), Self.worldTierCount - 1) }

    /// Room index 0…9 within the current tier (a champion sits in the last room,
    /// so the boss stays there to replay).
    func progress(in worldID: String) -> Int {
        let s = stage(in: worldID)
        return s >= Self.championStage ? 9 : s % 10
    }

    func advanceRoom(in worldID: String) {
        // Read the stage BEFORE the legacy bump: stage() takes the max with
        // worldProgress, so reading after it moved a fresh world 0 → 2.
        let s = stage(in: worldID)
        // The legacy counter keeps old builds on other devices right.
        worldProgress[worldID] = min((worldProgress[worldID] ?? 0) + 1, 9)
        guard s < Self.championStage else { return }
        worldStage[worldID] = min(s + 1, (s / 10) * 10 + 9)
    }

    /// A world this child has played in at all (on any device).
    func hasVisited(_ worldID: String) -> Bool {
        worldStage[worldID] != nil || (worldProgress[worldID] ?? 0) > 0
    }

    /// First time in a world: marks it visited and pays the 💎 nudge once.
    /// Returns the diamonds paid (0 on every later visit).
    @discardableResult
    func markVisited(_ worldID: String) -> Int {
        guard !hasVisited(worldID) else { return 0 }
        worldStage[worldID] = 0
        addDiamonds(Self.firstVisitDiamonds)
        return Self.firstVisitDiamonds
    }

    /// The boss was beaten in the last room: completes the tier. Returns the
    /// tier just completed (0 bronze…2 gold), or nil when it was a replay.
    @discardableResult
    func completeTier(in worldID: String) -> Int? {
        let s = stage(in: worldID)
        guard s < Self.championStage, s % 10 == 9 else { return nil }
        let done = s / 10
        worldStage[worldID] = (done + 1) * 10
        addDiamonds(Self.tierCompleteDiamonds)
        return done
    }

    /// Worlds completed through gold.
    var championWorlds: Int { worldStage.values.filter { $0 >= Self.championStage }.count }
    /// Tier crowns earned across all worlds (each completed tier = one 👑).
    var totalCrowns: Int { worldStage.keys.reduce(0) { $0 + min(worldTier(in: $1), Self.worldTierCount) } }

    // MARK: - 🌈 Topic balance (A: diminishing returns, B: variety bonus)

    /// Rani: kids grind ONE favorite topic (e.g. math) all day to earn time.
    /// A) After `sameTopicSoftCap` answers in the same topic in one day, that
    ///    topic's minute-earning rate halves (positive nudge, no blocking).
    /// B) Answering ≥`varietyMinAnswersPerTopic` in ≥`varietyTopicsNeeded`
    ///    different topics in a day grants a one-time daily bonus.
    /// Counters are device-local (play happens on one device at a sitting).
    static let sameTopicSoftCap = 30
    static let varietyBonusMinutes = 10
    static let varietyTopicsNeeded = 3
    static let varietyMinAnswersPerTopic = 5

    /// One-shot flags for the runner's companion lines — consumer resets them.
    @Published var topicBalanceNudgeTopic: Topic? = nil
    @Published var varietyBonusJustEarned: Int = 0

    /// Per-profile suffix so two siblings on ONE shared device don't share the
    /// daily topic-balance counters (sibling A's 30 math answers used to start
    /// sibling B at half-rate).
    private var balanceKeySuffix: String { (keyOwner ?? ProfileStore.shared.activeID).map { ".\($0.uuidString)" } ?? "" }
    /// Set while a profile switch applies the INCOMING child's snapshot — the
    /// active id still names the outgoing child then, and her variety-bonus day
    /// landed under her sibling's key (one got it twice, the other never).
    private var keyOwner: UUID?

    func apply(_ s: ProgressSnapshot, owner: UUID) {
        keyOwner = owner
        defer { keyOwner = nil }
        apply(s)
    }
    private var topicAnsweredKey: String { "topicAnsweredToday" + balanceKeySuffix }
    private var topicAnsweredDateKey: String { "topicAnsweredDate" + balanceKeySuffix }
    private var varietyBonusDateKey: String { "varietyBonusDate" + balanceKeySuffix }

    private func topicCountsToday() -> [String: Int] {
        guard let d = defaults.object(forKey: topicAnsweredDateKey) as? Date,
              DayGate.usedToday(d),
              let dict = defaults.dictionary(forKey: topicAnsweredKey) as? [String: Int]
        else { return [:] }
        return dict
    }

    /// ⚡ A right answer in a surprise round pays screen time like any right
    /// answer (Rani, 2026-10-06: the end card has to show ⏱ too). Only the
    /// TIME share of `recordCorrect` — the round still pays its own ⭐/💎 ×2
    /// at the end. Returns the seconds credited (0 at today's cap).
    @discardableResult
    func creditSurpriseAnswer(topic: Topic) -> Int {
        guard !atDailyCap else { return 0 }
        let topicCountToday = bumpTopicAnsweredToday(topic)
        let balanceFactor: Double = topicCountToday > Self.sameTopicSoftCap ? 0.5 : 1.0
        return payEarned(seconds: Int((Double(secondsPerCorrect) * balanceFactor).rounded()))
    }

    // MARK: - ⏱ Per-answer pay

    /// What `payEarned` keeps between answers, for ONE child and ONE day. Kept
    /// out of the synced snapshot on purpose (each is under a minute) and keyed
    /// by the bound child, so `apply()` — which runs on every sync merge as well
    /// as on a profile switch — never wipes it, and a sibling never inherits it.
    private struct EarnLedger: Codable {
        var day: Date
        /// Seconds already in the wallet that `minutesEarnedToday` hasn't counted
        /// yet (it counts whole minutes) — so the daily cap bites to the second.
        var capCarry = 0
        /// Seconds earned past today's cap, banked for tomorrow a minute at a time.
        var overflow = 0
        /// Owed by the next right answers after a miss / hint (never taken from
        /// the wallet). At most half a step — a run of misses costs only once.
        var debt = 0
    }
    private var earnLedgerKey: String { "earnLedger." + (belongsTo?.uuidString ?? "unbound") }
    private func loadEarnLedger() -> EarnLedger {
        let today = Calendar.current.startOfDay(for: Date())
        guard let data = defaults.data(forKey: earnLedgerKey),
              let l = try? JSONDecoder().decode(EarnLedger.self, from: data),
              Calendar.current.isDate(l.day, inSameDayAs: today) else { return EarnLedger(day: today) }
        return l
    }
    private func saveEarnLedger(_ l: EarnLedger) {
        if let data = try? JSONEncoder().encode(l) { defaults.set(data, forKey: earnLedgerKey) }
    }

    /// Seconds the last `recordCorrect` actually put in the wallet (0 in Free
    /// Learning, at the cap, or while paying off a miss) — the "+Ns" to show.
    private(set) var lastPaidSeconds = 0

    /// Pays `seconds` of earned play time into the wallet NOW, minus what a
    /// miss left owed. Today's cap is honoured to the second; past it the
    /// seconds are banked for tomorrow (up to `maxCarryOverMinutes`), exactly
    /// like the batches were. Returns the seconds that reached the wallet.
    @discardableResult
    private func payEarned(seconds: Int) -> Int {
        _ = minutesEarnedTodayRespectingDate()
        var l = loadEarnLedger()
        defer { saveEarnLedger(l) }
        // Progress an older build left toward its next batch — paid out once.
        var amount = max(0, seconds)
        if cycleSeconds > 0 {
            amount += Int(cycleSeconds.rounded())
            cycleSeconds = 0
        }
        let owed = min(l.debt, amount)
        l.debt -= owed
        amount -= owed
        guard amount > 0 else { return 0 }
        let cap = dailyCap
        var toWallet = amount
        if cap.enabled {
            let room = max(0, (max(0, cap.max) - minutesEarnedToday) * 60 - l.capCarry)
            toWallet = min(amount, room)
            l.overflow += amount - toWallet
            while l.overflow >= 60, carryOverMinutes < Self.maxCarryOverMinutes {
                carryOverMinutes += 1
                l.overflow -= 60
            }
            l.overflow = min(l.overflow, 59)
        }
        guard toWallet > 0 else { return 0 }
        creditEarned(seconds: toWallet)
        l.capCarry += toWallet
        while l.capCarry >= 60 {
            l.capCarry -= 60
            if cap.enabled { minutesEarnedToday += 1 }
            sessionMinutesEarned += 1
            sittingMinutes += 1
        }
        if dailyEarnedDate == nil { dailyEarnedDate = Calendar.current.startOfDay(for: Date()) }
        return toWallet
    }

    /// A miss / hint: `seconds` owed by the next right answers — never a
    /// second out of the wallet. Capped at half a step in all. Returns what was
    /// newly owed (0 once the cap is reached), for the "−Ns · כמעט!" toast.
    private func oweEarned(seconds: Int) -> Int {
        guard seconds > 0 else { return 0 }
        var l = loadEarnLedger()
        let added = min(seconds, max(0, halfStepSeconds - l.debt))
        l.debt += added
        saveEarnLedger(l)
        return added
    }

    /// Half of what a right answer pays — what a miss or a hint costs.
    private var halfStepSeconds: Int { Int((Double(secondsPerCorrect) / 2).rounded()) }

    /// Count a correct answer for `topic` today; returns the new count.
    private func bumpTopicAnsweredToday(_ topic: Topic) -> Int {
        var counts = topicCountsToday()
        counts[topic.rawValue, default: 0] += 1
        defaults.set(counts, forKey: topicAnsweredKey)
        defaults.set(Date(), forKey: topicAnsweredDateKey)
        return counts[topic.rawValue] ?? 1
    }

    private var varietyBonusGrantedToday: Bool {
        DayGate.usedToday(defaults.object(forKey: varietyBonusDateKey) as? Date)
    }

    // MARK: - Spending pending minutes

    /// Pays for an in-app benefit (e.g. a hint) by burning pending minutes.
    /// Returns `true` if the kid had enough minutes and the spend succeeded.
    @discardableResult
    func spendPendingMinutes(_ count: Int) -> Bool {
        guard count > 0 else { return true }
        guard pendingMinutes >= count else { return false }
        debitEarned(seconds: count * 60)
        return true
    }

    /// Burn stars — the single currency, used to buy cosmetics in the shop.
    /// Caller must verify `stars >= amount` first.
    func spendStars(_ amount: Int) {
        guard amount > 0 else { return }
        stars = max(0, stars - amount)
    }

    /// Add stars — earned in play, or bought as a real-money star pack
    /// (parent-gated). Single entry point so the balance stays canonical.
    func addStars(_ amount: Int) {
        guard amount > 0 else { return }
        stars += amount
    }

    /// Burn 💎 diamonds — the SPENDABLE shop currency. Spending never touches
    /// ⭐ stars, so the child's leaderboard rank is unaffected by purchases.
    /// Caller must verify `diamonds >= amount` first.
    func spendDiamonds(_ amount: Int) {
        guard amount > 0 else { return }
        diamonds = max(0, diamonds - amount)
    }

    /// Add 💎 diamonds — earned in play, won from chests/wheel, or bought as a
    /// real-money pack (parent-gated). Single entry point so it stays canonical.
    func addDiamonds(_ amount: Int) {
        guard amount > 0 else { return }
        diamonds += amount
    }

    /// Generic XP grant — used by Lucky Wheel and any future "+XP" rewards.
    func addXP(_ amount: Int) {
        guard amount > 0 else { return }
        xp += amount
    }

    /// Generic score bump — used by Lucky Wheel.
    func addScore(_ amount: Int) {
        guard amount > 0 else { return }
        totalScore += amount
        sessionScore += amount
    }

    // MARK: - Session time

    func consumePendingMinutes() -> Int {
        let m = pendingMinutes
        resetWallets()
        return m
    }

    /// The most minutes the kid may unlock RIGHT NOW: their accumulated wallet,
    /// clamped to what's left of today's screen-time allowance (daily cap minus
    /// what's already been unlocked today). Wallet beyond the daily cap stays put
    /// for future days. When the cap is disabled, the whole wallet is available.
    /// The earned pocket the button may open RIGHT NOW, to the second.
    ///
    /// Rani (2026-10-05): the gift button says "0:24" while the earned one said a
    /// rounded "16 דקות" — two pockets, two truths, and the leftover seconds were
    /// never openable at all. Both now read from here and spend every second.
    var redeemableSecondsNow: Int {
        let wallet = openableSeconds(gift: false)
        let cap = dailyCap
        guard cap.enabled else { return wallet }
        let roomToday = max(0, cap.max - minutesUnlockedTodayResolved)
        return min(wallet, roomToday * 60)
    }

    var redeemableMinutesNow: Int {
        // From the COUNTERS, not `pendingMinutes`: this value both labels the button
        // and decides the debit, so it must come from the one ledger that is the
        // truth. The mirror is for display on older builds and the parent's tiles.
        // + a refund still on its way back from the cloud: right after "סיימתי
        // לשחק" the key read "0 דק'" for a few seconds until it landed (Rani).
        // The gift key already counted it; now both do. (The lease claim that
        // opens the window is checked on the server, so nothing is overspent.)
        let wallet = openableSeconds(gift: false) / 60
        let cap = dailyCap
        guard cap.enabled else { return wallet }
        let roomToday = max(0, cap.max - minutesUnlockedTodayResolved)
        return min(wallet, roomToday)
    }

    /// `minutesUnlockedToday`, but treated as 0 if the stored counter is from a
    /// previous day — so the redeem math is correct even if the daily rollover
    /// hasn't run yet (e.g. the app stayed foreground across midnight). Read-only:
    /// the real reset still happens in `minutesEarnedTodayRespectingDate()`.
    private var minutesUnlockedTodayResolved: Int {
        guard DayGate.usedToday(dailyEarnedDate) else { return 0 }
        // Opened minus handed back: the minutes a child returned by stopping early
        // are not spent, so they must not keep counting against today's cap.
        return max(0, minutesUnlockedToday - returnedTodayMinutes)
    }

    /// Smallest grant the kid may open — ALWAYS 15 min, in every blocking mode.
    /// iOS can't reliably re-lock a shorter window in the background (block-all has
    /// a hard 15-min schedule minimum, and the block-list usage event is flaky), so
    /// we never open less than that; the kid accumulates to 15 first.
    var minimumUnlockMinutes: Int { 15 }

    /// True when there are enough redeemable minutes to open a window we can enforce.
    var canRedeemNow: Bool { redeemableMinutesNow >= minimumUnlockMinutes }

    /// True when the kid has wallet minutes they CAN'T open today only because
    /// today's screen-time cap is already used up (the rest waits for tomorrow) —
    /// distinct from simply not having earned enough yet. Drives an accurate
    /// "you hit today's limit" message instead of "answer more questions".
    /// Screen time actually opened today (minus what was handed back) — what the
    /// kid has PLAYED against today's cap, for "שיחקת היום X מתוך Y".
    var minutesPlayedToday: Int { minutesUnlockedTodayResolved }

    var dailyScreenTimeMaxedOut: Bool {
        dailyCap.enabled && !canRedeemNow && pendingMinutes > redeemableMinutesNow
    }

    /// Seconds this pocket can open RIGHT NOW — the whole minutes plus the odd
    /// seconds, but only when the carry actually belongs to it. Opening from
    /// `minutes * 60` stranded the carry: a window locked at 29:40 re-opened at
    /// 29:00 and the 40 seconds could never be spent.
    /// Seconds handed back by a stop that the cloud has not confirmed yet, shown
    /// to the child IMMEDIATELY so the open button returns the instant they stop.
    ///
    /// DISPLAY ONLY, and that is the whole point. Crediting the real wallet here
    /// is what double-paid every stop: the same path calls `pushNow()`, so the
    /// optimistic credit reached the cloud before the release transaction read it,
    /// and the transaction added the refund on top of a value that already held
    /// it. This never enters `captureSnapshot()`, never syncs, and is dropped the
    /// moment the authoritative number arrives.
    @Published private(set) var inFlightRefundSeconds: Int = 0
    private(set) var inFlightRefundIsGift = false

    private func beginInFlightRefund(seconds: Int, gift: Bool) {
        guard seconds > 0 else { return }
        inFlightRefundSeconds = seconds
        inFlightRefundIsGift = gift
        // Safety net: if the transaction never answers (killed app, lost network
        // with no error), the child must not be left staring at time they cannot
        // actually open.
        let token = seconds
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard let self, self.inFlightRefundSeconds == token else { return }
            self.inFlightRefundSeconds = 0
        }
    }

    func clearInFlightRefund() { inFlightRefundSeconds = 0 }
    func clearSecondsCarry() { pendingSecondsCarry = 0; carryIsGift = false }

    /// WHICH CHILD the live data in this store belongs to.
    ///
    /// Everything here is one global mutable store, and the code that decides
    /// WHERE to write (`ProfileStore.activeID`, or a `for:` argument) is separate
    /// from the code that decides WHAT to write (`captureSnapshot()`). Those two
    /// are read at different moments, so any gap between them — a profile switch,
    /// a Kid Mode entry, a debounced upload firing late, a switch interrupted
    /// half-way — can write one child's progress into another child's document.
    ///
    /// That is not hypothetical: it happened to a real family, and because
    /// accumulators merge by `max`, the sibling's stars ratcheted up permanently
    /// and could not be undone from the cloud.
    ///
    /// So the data carries its owner. Every path that writes this store OUT must
    /// check `belongsTo` first and refuse when it does not match.
    private(set) var belongsTo: UUID? = {
        // On launch the live store holds whatever was persisted for the profile
        // that was active when the app last ran — `profiles.activeID` records
        // exactly who that was. Binding to it here matters: `ProfileStore` only
        // calls `switchTo` on the NEXT main-loop turn, and until then an unbound
        // store would refuse every upload and sync would silently die.
        UserDefaults.standard.string(forKey: "profiles.activeID").flatMap(UUID.init(uuidString:))
    }()

    func bind(to profileID: UUID?) { belongsTo = profileID }

    /// True when this store's live data really is `id`'s, and may be written to
    /// `id`'s document. Refuses when nothing is bound — a store that has never
    /// been bound holds whatever the last profile left behind.
    func holdsData(for id: UUID) -> Bool { belongsTo == id }

    func openableSeconds(gift: Bool) -> Int {
        let settled = gift ? giftSecondsAvailable : earnedSecondsAvailable
        // Include a refund the cloud has not confirmed yet: it is genuinely the
        // child's, and making them wait a network round trip to see their own
        // minutes come back is exactly the delay this exists to remove.
        return settled + (inFlightRefundIsGift == gift ? inFlightRefundSeconds : 0)
    }

    /// Attach a lease we won retroactively for an already-open window.
    func adoptLeaseID(_ id: String) { if isUnlocked { activeLeaseID = id } }

    /// Adopt the wallet EXACTLY as the lease transaction left it in the cloud.
    ///
    /// Not a local "debit": on the receiving side of a transfer this device's own
    /// pocket is stale by construction — the minutes it is spending were refunded
    /// Apply what a lease transaction moved, to this device's own counters.
    ///
    /// Counters make this trivial where the old value-based wallet made it hard.
    /// The transaction incremented the CLOUD's totals; incrementing ours by the
    /// same amount lands on the same number, and because the merge takes `max`
    /// per counter, doing it on both sides converges rather than double-counting.
    /// Every "is this result stale?" question the old code had to answer — and got
    /// wrong twice today — simply does not arise: a stale result carries smaller
    /// totals and loses.
    func applyClaimedWallet(_ w: ClaimedWallet) {
        clearInFlightRefund()   // the authoritative number is here
        if w.deltaSeconds > 0 {
            if w.deltaIsGift { creditGift(seconds: w.deltaSeconds) }
            else { creditEarned(seconds: w.deltaSeconds) }
        } else if w.deltaSeconds < 0 {
            if w.deltaIsGift { debitGift(seconds: -w.deltaSeconds) }
            else { debitEarned(seconds: -w.deltaSeconds) }
        }
        minutesUnlockedToday = max(minutesUnlockedToday, w.minutesUnlockedToday)
        returnedTodayMinutes = max(returnedTodayMinutes, w.returnedTodayMinutes)
        // A refund of an earned window: those minutes were never played, so the
        // parent's "used today" must not count them either.
        if w.deltaSeconds >= 60, !w.deltaIsGift {
            LearningHistoryStore.shared.recordMinutesReturned(w.deltaSeconds / 60)
        }
        adoptRevision(w.revision)
    }

    /// Consume up to today's remaining allowance from the wallet for an unlock.
    /// Returns the granted amount; any leftover stays in `pendingMinutes` for a
    /// later day so a large wallet can't be cashed in past the daily cap at once.
    @discardableResult
    func consumeMinutesForUnlock() -> Int {
        _ = minutesEarnedTodayRespectingDate()   // roll the day over first if needed
        var amount = redeemableMinutesNow
        guard amount > 0 else { return 0 }
        // ✈️ OFFLINE BOUND: the debit and the "is another device already playing?"
        // check are both cloud round-trips. In airplane mode neither happens, so a
        // child could open the FULL wallet on the iPad and then the full wallet
        // again on the iPhone. We can't verify while offline — but we can bound the
        // damage: an unverified device may open at most one minimum window at a
        // time, instead of everything the wallet holds. Play still works with no
        // network (a kid on a plane is not stranded); it just can't be duplicated
        // wholesale. The debit is still recorded locally and reconciles on sync.
        if !cloudStateIsFresh {
            amount = min(amount, minimumUnlockMinutes)
        }
        debitEarned(seconds: amount * 60)
        minutesUnlockedToday += amount
        return amount
    }

    /// Have we exchanged state with the cloud recently enough to trust the wallet
    /// and the cross-device "someone else is playing" guard? Conservative: any
    /// doubt counts as stale.
    private var cloudStateIsFresh: Bool {
        let sync = RemoteSyncManager.shared
        guard sync.isActive, let last = sync.lastUploadAt else { return false }
        return Date().timeIntervalSince(last) < 120   // 2 minutes
    }

    /// `manual: true` marks a parent's one-time "quick open" grant — a fixed
    /// wall-clock window whose leftover minutes are NEVER banked back to the
    /// earned pool (see `endUnlockAndReturnRemainingMinutes`).
    /// Apply a parent's minute grant/deduction to the live balance (clamped ≥0).
    /// Bumps revision via the normal change path so it syncs back to the cloud and
    /// the parent's dashboard. Used by RemoteSyncManager when the child's device
    /// consumes a `pendingMinuteAdjustment` command.
    func addPendingMinutes(_ delta: Int) {
        guard delta != 0 else { return }
        if delta > 0 { creditEarned(seconds: delta * 60) } else { debitEarned(seconds: -delta * 60) }
    }

    // MARK: - 💝 Parent gift pocket (separate from the earned wallet)

    /// A parent's "+N" gift (or "−N" taken back from the gift pocket). Clamped ≥0.
    /// Never touches `pendingMinutes` — the earned wallet stays the child's own.
    func addParentGiftMinutes(_ delta: Int) {
        guard delta != 0 else { return }
        if delta > 0 { creditGift(seconds: delta * 60) } else { debitGift(seconds: -delta * 60) }
        // Count what was GIVEN today (for the "until midnight" cap). Roll the
        // counter when the day changed. Unused gift itself carries over (Rani).
        if delta > 0 {
            if DayGate.usedToday(giftGivenDate) {
                giftGivenToday += delta
            } else {
                giftGivenToday = delta
                giftGivenDate = Date()
            }
        }
    }

    /// 💝 given today, day-aware (0 if the counter is from a previous day).
    var giftGivenTodayResolved: Int {
        guard DayGate.usedToday(giftGivenDate) else { return 0 }
        return giftGivenToday
    }

    /// The daily cap for parent gifts: you can't give more than there is left
    /// until midnight (a 20:00 gift can be at most 240 min in total today).
    static func minutesUntilMidnight(_ now: Date = Date()) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        guard let midnight = cal.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return max(0, Int(midnight.timeIntervalSince(now) / 60))
    }

    /// Parent revoked their gift ("נעל ואפס דקות מתנה"): wipe EVERY bit of parent
    /// time — the gift pocket, frozen leftover, and an open MANUAL window (a
    /// parent grant/gift). Earned minutes are the child's own and are untouched:
    /// an open EARNED window is stopped-and-banked back to the wallet.
    /// Returns true if an open window was closed (caller re-shields).
    @discardableResult
    func revokeAllParentTime() -> Bool {
        debitGift(seconds: giftSecondsAvailable)
        manualPausedSeconds = 0
        guard isUnlocked else { return false }
        let leaseID = activeLeaseID
        let childID = ProfileStore.shared.activeID
        if unlockIsManual { endUnlock() }                       // parent time → gone
        else { _ = endUnlockAndReturnRemainingMinutes() }      // earned → banked
        // Hand the family's ONE window back. Refund 0 — whatever was owed was
        // already settled locally above (or deliberately revoked).
        if PlayWindowLeaseManager.isEnabled, let leaseID, let childID {
            Task { await PlayWindowLeaseManager.shared.release(childID: childID,
                                                               leaseID: leaseID,
                                                               localRemainingSeconds: 0) }
        }
        return true
    }

    /// Child opens the whole gift pocket as ONE fixed `manual` window (like a
    /// remote grant): not capped by the daily limit, and its leftover freezes
    /// on stop-and-save (`pauseManualUnlock`) rather than banking to the wallet.
    /// Returns the minutes opened (0 = nothing to open).
    @discardableResult
    func consumeParentGiftForUnlock() -> Int {
        // The COUNTERS decide, never `parentGiftMinutes`. That field is a display
        // mirror, and `apply(_:)` used to adopt it straight from a snapshot whose
        // own copy was behind — so the card read the counters and showed a real
        // 60-minute gift while this line read the mirror, found 0, and opened
        // nothing at all. The child was returned to the map in silence.
        //
        // `max(1, ...)` honours a sub-minute pocket instead of stranding it: the
        // button shows "0:40 דקות", so 40 seconds must open something. We debit
        // every second we were holding, so nothing is handed out twice.
        let seconds = giftSecondsAvailable
        guard seconds > 0 else { return 0 }
        debitGift(seconds: seconds)
        return max(1, seconds / 60)
    }

    /// `extraSeconds` overrides the device-local carry: with the lease on, the
    /// sub-minute remainder was already spent inside the claim transaction and
    /// comes back in the grant, so folding the local carry in again would hand
    /// the child those seconds twice.
    func startUnlock(minutes: Int, manual: Bool = false, leaseID: String? = nil,
                     leaseKind: String? = nil, extraSeconds overrideSeconds: Int? = nil) {
        // Never silently overwrite an OPEN EARNED window with a parent/manual one —
        // bank its leftover back to the wallet first (pocket integrity).
        if isUnlocked && !unlockIsManual { _ = endUnlockAndReturnRemainingMinutes() }
        // Fold any banked sub-minute carry into a real (non-manual) window so the
        // kid resumes at the exact leftover (e.g. 58 min wallet + 50 s carry →
        // 58:50). A parent's manual quick-open is a fixed window — it ignores carry.
        let extraSeconds = overrideSeconds ?? (manual ? 0 : pendingSecondsCarry)
        if overrideSeconds == nil, !manual { pendingSecondsCarry = 0 }
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60 + extraSeconds))
        NSLog("[ScreenTime] startUnlock(minutes: %d, manual: %@) → window %d min + %ds carry", minutes, manual ? "true" : "false", minutes, extraSeconds)
        unlockIsManual = manual
        unlockEndsAt = end
        // Record what we actually granted + a monotonic start, so the refund can
        // be clamped no matter what the clock does afterwards.
        unlockGrantedSeconds = minutes * 60 + extraSeconds
        unlockStartedAt = Date()
        unlockStartedUptime = ProcessInfo.processInfo.systemUptime
        unlockKind = leaseKind ?? (manual ? "grant" : "earned")
        if let leaseID { activeLeaseID = leaseID }
        // Lock-screen / Dynamic Island countdown of the remaining play time.
        PlayTimeLiveActivity.start(endsAt: end,
                                   characterName: ProfileStore.shared.active?.character.name ?? "")
    }

    /// Add minutes to the CURRENTLY open window (keeps its manual/earned kind).
    /// Used when the gift pocket is opened together with resumed frozen time.
    func extendUnlock(minutes: Int) {
        // Only ever extends a MANUAL (parent) window. If the open window is EARNED,
        // start a fresh manual one instead (startUnlock banks the earned leftover) —
        // gift minutes must never be folded into the earned pocket.
        guard minutes > 0, let end = unlockEndsAt, end > Date(), unlockIsManual else {
            startUnlock(minutes: minutes, manual: true, leaseKind: "gift"); return
        }
        let newEnd = end.addingTimeInterval(TimeInterval(minutes * 60))
        unlockEndsAt = newEnd
        unlockGrantedSeconds += minutes * 60
        PlayTimeLiveActivity.start(endsAt: newEnd,
                                   characterName: ProfileStore.shared.active?.character.name ?? "")
    }

    /// When the open window started (nil = none open).
    var unlockOpenedAt: Date? { unlockEndsAt == nil ? nil : unlockStartedAt }

    /// 🏫🌙 Set only inside `closeForQuietTime`: the leftover as it stood when
    /// the quiet time began, so every stop path below banks THAT and not
    /// whatever the clock says by the time the app woke up.
    private var quietRefund: Int?
    private var quietCutAt: Date?

    /// A school time / bedtime began at `cut` while this window was open. Close
    /// it through the normal stop path (earned → wallet, gift → 💝 pocket, the
    /// cloud lease released exactly once) with the leftover AS OF `cut`. A
    /// kid who opened 30 minutes at 20:10 and met bedtime at 20:30 gets 10 back
    /// — even if Tofy only wakes at 21:00, long after the window would have run
    /// out. The parent's own manual open ("grant") is not touched.
    @discardableResult
    func closeForQuietTime(at cut: Date) -> Bool {
        guard let end = unlockEndsAt, unlockKind != "grant" else { return false }
        var owed = max(0, Int(end.timeIntervalSince(cut)))
        if unlockGrantedSeconds > 0, let started = unlockStartedAt {
            let used = max(0, Int(cut.timeIntervalSince(started)))
            owed = min(owed, max(0, unlockGrantedSeconds - used))
        }
        quietRefund = owed
        quietCutAt = cut
        defer { quietRefund = nil; quietCutAt = nil }
        stopAndSaveCurrentUnlock()
        if unlockEndsAt != nil { endUnlock() }
        return true
    }

    func endUnlock() {
        unlockEndsAt = nil
        unlockIsManual = false
        unlockGrantedSeconds = 0
        unlockStartedAt = nil
        unlockStartedUptime = 0
        activeLeaseID = nil
        PlayTimeLiveActivity.end()
    }

    // MARK: - Device-local play state per profile (not in the synced snapshot)

    /// Frozen parent time is device-local AND per-child. On a shared device the
    /// active profile can change (multi-kid device, Kid Mode), so park the
    /// outgoing kid's frozen seconds under THEIR id and clear the live value.
    /// Non-destructive: ADDS to any existing stash (a second stash on the same
    /// switch with a now-empty live value must not overwrite a real one with 0).
    func stashDeviceLocalPlayState(for profileID: UUID) {
        guard manualPausedSeconds > 0 else { return }
        let key = "manualPausedSeconds.\(profileID.uuidString)"
        defaults.set(defaults.integer(forKey: key) + manualPausedSeconds, forKey: key)
        manualPausedSeconds = 0
    }

    /// Bring back the incoming kid's own frozen seconds — additive + consumed, so
    /// it's idempotent and can never resurrect the same seconds twice.
    func restoreDeviceLocalPlayState(for profileID: UUID) {
        let key = "manualPausedSeconds.\(profileID.uuidString)"
        let stashed = defaults.integer(forKey: key)
        guard stashed > 0 else { return }
        manualPausedSeconds += stashed
        defaults.removeObject(forKey: key)
    }

    /// Kid Mode exit on a PARENT phone: nothing kid-specific may remain live.
    func clearDeviceLocalPlayState() {
        manualPausedSeconds = 0
        if isUnlocked { endUnlock() }
    }

    /// Whole minutes of frozen manual time waiting to be resumed (ceil, so 20:10
    /// reads as "21" rather than hiding the leftover). For display.
    var pausedManualMinutes: Int { (manualPausedSeconds + 59) / 60 }
    var hasPausedManualTime: Bool { manualPausedSeconds > 0 }

    /// Stop the current play window and SAVE the leftover: FREEZE it for a parent's
    /// manual grant (resume later), or BANK it to the wallet for earned time. Does
    /// NOT re-apply the shield — the caller does. Used by the "עצור ושמור" action
    /// (play screen + Live Activity button).
    @discardableResult
    func stopAndSaveCurrentUnlock() -> Int {
        guard isUnlocked || (quietRefund != nil && unlockEndsAt != nil) else { return 0 }
        // Capture what the lease needs BEFORE the local stop clears it. Every stop
        // path in the app funnels through here (timer end, Live Activity button,
        // remote lock, Kid Mode exit, profile switch), so this is the single place
        // the cloud lease is released.
        let leaseID = activeLeaseID
        let remaining = refundableUnlockSeconds
        let cutAt = quietCutAt
        let childID = ProfileStore.shared.activeID
        let wasManual = unlockIsManual
        var banked = 0

        // EXACTLY ONE path may credit this refund.
        //
        // Crediting locally AND in the release transaction double-pays: this same
        // stop path calls pushNow(), so the locally-credited wallet can reach the
        // cloud BEFORE the transaction reads it — and the transaction then adds
        // the refund on top of a value that already contains it. Every stop
        // doubled the child's time.
        //
        // So when the lease is going to settle this, the local stop closes the
        // window WITHOUT paying, and the transaction's own result comes back
        // through applyClaimedWallet. The cost is that the wallet lags by one
        // round trip; the benefit is that the number is right.
        if PlayWindowLeaseManager.isEnabled, let leaseID, let childID {
            banked = remaining / 60
            endUnlock()
            beginInFlightRefund(seconds: remaining, gift: wasManual)
            // Captured NOW, while this store still holds `childID` — the Task
            // below runs after the caller may have switched to another child.
            let capture: PlayWindowLeaseManager.LocalCapture? = holdsData(for: childID)
                ? PlayWindowLeaseManager.captureLocal() : nil
            Task {
                let ok = await PlayWindowLeaseManager.shared.release(childID: childID,
                                                                     leaseID: leaseID,
                                                                     localRemainingSeconds: remaining,
                                                                     asOf: cutAt,
                                                                     captured: capture)
                // The cloud could not take it (offline — transactions never queue).
                // Pay locally instead, or the child just lost the leftover — and
                // pay the RIGHT child: if the store moved on, into their saved slot.
                if !ok {
                    await MainActor.run {
                        if self.holdsData(for: childID) {
                            self.creditRefundLocally(seconds: remaining, manual: wasManual)
                        } else {
                            ProgressVault.shared.creditRefund(seconds: remaining, gift: wasManual, to: childID)
                        }
                    }
                }
            }
        } else if wasManual {
            pauseManualUnlock()
        } else {
            banked = endUnlockAndReturnRemainingMinutes()
        }
        return banked
    }

    /// Mirror of `creditRefundLocally` for a spend the cloud already made.
    func debitSpendLocally(seconds: Int, gift: Bool) {
        guard seconds > 0 else { return }
        if gift { debitGift(seconds: seconds) } else { debitEarned(seconds: seconds) }
    }

    private func debitSpendLocally_unused(seconds: Int, gift: Bool) {
        guard seconds > 0 else { return }
        let r = WalletSeconds.spend(want: seconds,
                                    minutes: gift ? parentGiftMinutes : pendingMinutes,
                                    carry: carryIsGift == gift ? pendingSecondsCarry : 0)
        pendingSecondsCarry = r.carryLeft
        carryIsGift = gift
        if gift {
            debitGift(seconds: r.minutesOut * 60)
        } else {
            debitEarned(seconds: r.minutesOut * 60)
            minutesUnlockedToday += r.minutesOut
        }
    }

    /// Credit a refund the CLOUD could not take. Mirrors the release transaction's
    /// arithmetic exactly — whole minutes to the pocket, odd seconds to the carry —
    /// so an offline stop and an online one leave the child with the same balance.
    func creditRefundLocally(seconds: Int, manual: Bool) {
        clearInFlightRefund()   // this IS the credit now — don't show it twice
        guard seconds > 0 else { return }
        if manual { creditGift(seconds: seconds) } else {
            creditEarned(seconds: seconds)
            // Same as the cloud release: unplayed minutes go back into today's
            // allowance and out of the parent's "used today".
            returnedTodayMinutes += seconds / 60
            LearningHistoryStore.shared.recordMinutesReturned(seconds / 60)
        }
    }

    private func creditRefundLocally_unused(seconds: Int, manual: Bool) {
        guard seconds > 0 else { return }
        let r = WalletSeconds.refund(seconds: seconds, carry: carryIsGift == manual ? pendingSecondsCarry : 0)
        pendingSecondsCarry = r.carryLeft
        carryIsGift = manual
        guard r.minutesIn > 0 else { return }
        if manual {
            creditGift(seconds: r.minutesIn * 60)
        } else {
            creditEarned(seconds: r.minutesIn * 60)
            returnedTodayMinutes += r.minutesIn
        }
    }

    /// Child stopped mid-play on a parent's MANUAL grant — FREEZE the exact leftover
    /// (to the second) instead of wasting it, and end the live window. Caller
    /// re-applies the shield. No-op for an earned window (that banks to the wallet).
    func pauseManualUnlock() {
        guard unlockIsManual else { return }
        let remaining = refundableUnlockSeconds
        // The leftover of a PARENT window goes back to the SYNCED gift pocket
        // (whole minutes, rounded UP so the child never loses a partial minute)
        // — not to a device-local freezer. Rani: "חייב להיות אותו דבר בשני
        // המכשירים" — the kid must see the same 💝 on the iPad and the iPhone
        // and be able to resume from either. `manualPausedSeconds` stays as a
        // legacy field (always 0 from now on; old stashes are migrated below).
        // FLOOR to whole minutes (a round-up let a kid replay <60s chunks forever).
        if remaining > 0 { creditGift(seconds: remaining) }
        endUnlock()
    }

    /// One-time cleanup of the pre-sync design's device-local frozen seconds
    /// (live value or a per-profile stash). DISCARDED, not migrated: a parent may
    /// have already revoked/reset this child's parent time while this device was
    /// on the old build — folding a stale local freezer into the synced pocket
    /// would resurrect exactly what the parent removed (Dan's phone held a
    /// phantom 121 min). From now on leftovers go straight into the synced 💝.
    @discardableResult
    func migrateFrozenIntoGiftPocket(for profileID: UUID) -> Bool {
        let key = "manualPausedSeconds.\(profileID.uuidString)"
        let secs = manualPausedSeconds + defaults.integer(forKey: key)
        defaults.removeObject(forKey: key)
        guard secs > 0 else { return false }
        manualPausedSeconds = 0
        NSLog("[ScreenTime] discarded %ds of legacy device-local frozen time (parent time is synced now)", secs)
        return true
    }

    /// Resume frozen manual time — reopen a manual window from the saved seconds and
    /// clear the frozen balance. Returns whole minutes (ceil) for the shield schedule.
    @discardableResult
    func resumeManualUnlock() -> Int {
        guard manualPausedSeconds > 0 else { return 0 }
        // Same guard as startUnlock: an open EARNED window banks first.
        if isUnlocked && !unlockIsManual { _ = endUnlockAndReturnRemainingMinutes() }
        let seconds = manualPausedSeconds
        manualPausedSeconds = 0
        let end = Date().addingTimeInterval(TimeInterval(seconds))
        unlockIsManual = true
        unlockEndsAt = end
        PlayTimeLiveActivity.start(endsAt: end,
                                   characterName: ProfileStore.shared.active?.character.name ?? "")
        return (seconds + 59) / 60
    }

    /// True while a play-time grant is still LIVE — i.e. the DeviceActivity
    /// monitor extension hasn't re-locked yet. The extension clears the shared
    /// `unlockEndsAt` key ONLY when the grant is truly spent (real usage reached
    /// the threshold, or the long safety backstop ended). So a present key means
    /// the kid still has usage budget, even if the wall-clock deadline elapsed
    /// while the iPad was locked/idle — we must NOT burn it.
    var hasLiveUnlockGrant: Bool {
        guard let end = defaults.object(forKey: Key.unlockEndsAt) as? Date else { return false }
        // Fail CLOSED: the wall-clock window is the source of truth. A grant is
        // only "live" while its deadline is still in the future. The background
        // monitor may re-lock EARLIER (usage-based), but if it never fires we must
        // NOT leave apps open past the granted window — a present-but-expired key
        // is treated as spent so the baseline lock re-applies.
        if end <= Date() { return false }
        // …and a MONOTONIC backstop the child cannot touch. Moving the wall clock
        // backwards used to resurrect an expired window, and every Tofy foreground
        // then cleared the shield again for the whole rollback. `systemUptime`
        // cannot be changed from Settings, so once the granted budget has really
        // elapsed the window is over no matter what the clock says.
        return !unlockBudgetExhausted
    }

    /// The open window's GRANTED budget has really elapsed, measured monotonically.
    /// False when we can't judge (no grant record, or the device rebooted and
    /// uptime restarted) — never fail closed on a legitimate window.
    var unlockBudgetExhausted: Bool {
        let granted = defaults.integer(forKey: Key.unlockGrantedSeconds)
        let startUp = defaults.double(forKey: Key.unlockStartedUptime)
        guard granted > 0, startUp > 0 else { return false }
        let up = ProcessInfo.processInfo.systemUptime
        guard up >= startUp else { return false }        // rebooted — uptime reset
        return (up - startUp) >= Double(granted)
    }

    /// Re-sync the unlock deadline from the shared app group (the monitor
    /// extension may have cleared it while we were backgrounded). Call on
    /// foreground before deciding whether to re-lock.
    func reloadUnlockFromShared() {
        let shared = defaults.object(forKey: Key.unlockEndsAt) as? Date
        if shared == nil {
            if unlockEndsAt != nil { endUnlock() }   // extension spent/ended it
        } else if shared! <= Date() || unlockBudgetExhausted {
            // Window elapsed but the monitor never cleared it (e.g. the extension
            // didn't fire), OR the granted budget is monotonically spent while the
            // wall clock claims otherwise (clock moved backwards). Fail CLOSED —
            // end the grant so the baseline lock re-applies. Apps must never stay
            // open past the granted window.
            endUnlock()
        } else if shared != unlockEndsAt {
            unlockEndsAt = shared
        }
    }

    /// Stop the current unlock window early and return whatever full minutes
    /// remained back to the pending pool so the kid doesn't lose them.
    /// Returns the number of minutes returned.
    @discardableResult
    func endUnlockAndReturnRemainingMinutes() -> Int {
        // A parent's one-time manual grant is a fixed window — its leftover time is
        // NOT the child's to keep. End it without banking anything back.
        if unlockIsManual { endUnlock(); return 0 }
        let remainingSeconds = refundableUnlockSeconds
        // Bank the EXACT leftover time, to the second. Neither floor it (which wasted
        // the partial minute: 58:50 → 58) nor round the minute up (which invented
        // time: 58:50 → 59). Instead split into whole minutes + a sub-minute carry,
        // so reopening resumes at precisely 58:50.
        let totalSeconds = (pendingSecondsCarry + remainingSeconds)
        let remainingMinutes = totalSeconds / 60
        pendingSecondsCarry = totalSeconds % 60
        if remainingMinutes > 0 {
            creditEarned(seconds: remainingMinutes * 60)
            // These minutes were returned unused — they don't count against today's
            // unlocked allowance, so the kid can re-open them later today.
            returnedTodayMinutes += remainingMinutes
            LearningHistoryStore.shared.recordMinutesReturned(remainingMinutes)
        }
        unlockEndsAt = nil
        PlayTimeLiveActivity.end()
        return remainingMinutes
    }

    // MARK: - Focus (hour-of-day buckets)

    /// Bump the current hour's answer/correct counters (parent-only Focus insight).
    private func recordHourly(correct: Bool) {
        let h = Calendar.current.component(.hour, from: Date())
        guard h >= 0, h < 24 else { return }
        if hourlyAnswered.count == 24 { hourlyAnswered[h] += 1 }
        if correct, hourlyCorrect.count == 24 { hourlyCorrect[h] += 1 }
    }

    // MARK: - Day streak

    func registerSessionToday() {
        dayStreak = Self.nextDayStreak(current: dayStreak, last: lastSessionDate, now: Date())
        lastSessionDate = Date()
    }

    /// Pure, testable day-streak transition. Same calendar day → unchanged; the
    /// next consecutive day → +1; a gap of >1 day (or the first ever play) → 1.
    /// Calendar-based so it's timezone/DST-safe.
    static func nextDayStreak(current: Int, last: Date?, now: Date,
                              calendar: Calendar = .current) -> Int {
        guard let last else { return 1 }
        let today = calendar.startOfDay(for: now)
        let lastDay = calendar.startOfDay(for: last)
        let dayDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        if dayDiff == 0 { return current }   // same day — already counted
        if dayDiff == 1 { return current + 1 }
        return 1                              // gap → restart at 1
    }

    // MARK: - Dev / reset

    func resetCombo() {
        currentStreak = 0
    }

    // MARK: - Snapshot capture / apply (per-profile)

    /// Read the current store state into a portable snapshot.
    func captureSnapshot() -> ProgressSnapshot {
        var s = ProgressSnapshot()
        s.pendingMinutes      = pendingMinutes
        s.totalCorrect        = totalCorrect
        s.totalAnswered       = totalAnswered
        // unlockEndsAt is intentionally NOT synced — the screen-time unlock window
        // is per-DEVICE OS state (which apps are open right now). Syncing it made a
        // stale/other-device grant re-appear on every sync, popping the "game time"
        // screen unprompted and surviving "סיימתי לשחק".
        s.stars               = stars
        s.diamonds            = diamonds
        s.xp                  = xp
        s.currentStreak       = currentStreak
        s.dayStreak           = dayStreak
        s.lastSessionDate     = lastSessionDate
        s.lastDailyChestDate  = lastDailyChestDate
        s.lastDailyChallengeDate = lastDailyChallengeDate
        s.hourlyAnswered = hourlyAnswered
        s.hourlyCorrect = hourlyCorrect
        s.unlockedWorlds      = Array(unlockedWorlds)
        s.worldProgress       = worldProgress
        s.worldStage          = worldStage
        s.topicAccuracy       = topicAccuracy
        s.topicAnswered       = topicAnswered
        s.topicCorrect        = topicCorrect
        s.batchCounter        = batchCounter
        s.cycleSeconds        = cycleSeconds
        s.wrongStreak         = wrongStreak
        s.totalScore          = totalScore
        s.lastComebackWheelAt = lastComebackWheelAt
        s.varietyBonusDate    = defaults.object(forKey: varietyBonusDateKey) as? Date
        s.minutesEarnedToday  = minutesEarnedToday
        s.minutesUnlockedToday = minutesUnlockedToday
        s.returnedTodayMinutes = returnedTodayMinutes
        s.dailyEarnedDate     = dailyEarnedDate
        s.answeredToday       = answeredToday
        s.correctToday        = correctToday
        s.carryOverMinutes    = carryOverMinutes
        s.bestStreak          = bestStreak
        s.topicResponseMs     = topicResponseMs
        s.topicAffinity       = topicAffinity
        s.topicExposure       = topicExposure
        s.topicAbandon        = topicAbandon
        s.topicAdaptiveLevel  = topicAdaptiveLevel
        s.wheelProgressCount  = wheelProgressCount
        s.recoveryPot         = recoveryPot
        s.parentGiftMinutes   = parentGiftMinutes
        s.giftGivenToday      = giftGivenToday
        s.giftGivenDate       = giftGivenDate
        s.ownedCharacterIDs   = Array(ownedCharacterIDs)
        // Carry the REAL version forward. Stamping `.now` here (the old bug) made
        // every capture look freshly-modified, so a remote snapshot's older
        // timestamp could never win the comparison and cross-device sync was dead.
        s.resetEpoch          = resetEpoch
        s.revision            = revision
        s.lastModifiedAt      = lastModifiedAt
        s.deviceID            = ProgressSnapshot.thisDeviceID
        s.earnedSecondsIn     = earnedSecondsIn
        s.earnedSecondsOut    = earnedSecondsOut
        s.giftSecondsIn       = giftSecondsIn
        s.giftSecondsOut      = giftSecondsOut
        s.secondsCarry        = pendingSecondsCarry
        s.carryIsGift         = carryIsGift
        // The legacy minute fields are DERIVED from the counters, so they have to
        // be derived AFTER the counters are in. Called before them (the old
        // order), this wrote `pendingMinutes: 0` into every snapshot we publish —
        // exactly the zero-beside-a-full-pocket the counters exist to prevent.
        s.syncWalletMirrors()
        return s
    }

    /// Overwrite the store with a snapshot — used when switching profiles
    /// or applying a remote update.
    /// When a snapshot was last applied (a sync from another device, or a
    /// profile switch). Reactions that mean "you just did this HERE" — the
    /// buddy's cheer, a world-unlock "wow", the challenge celebration — skip a
    /// change that arrived this way: Dan answered on his iPad and his iPhone
    /// cheered out loud (Rani, 2026-10-08).
    private(set) var lastSnapshotAppliedAt: Date = .distantPast
    var changeCameFromSync: Bool { Date().timeIntervalSince(lastSnapshotAppliedAt) < 1.5 }

    func apply(_ s: ProgressSnapshot) {
        lastSnapshotAppliedAt = Date()
        // Loading a snapshot is not a local edit — suppress revision bumps while
        // the fields change, then adopt the snapshot's own version so a later
        // local edit builds on top of it (and outranks what we just received).
        isApplyingSnapshot = true
        defer {
            isApplyingSnapshot = false
            resetEpoch = s.resetEpoch
            revision = s.revision
            noteAdoptedGeneration(s.revision)
            lastModifiedAt = s.lastModifiedAt
            // LAST word on both wallets, and the only place either mirror is set.
            deriveWalletMirrors(from: s)
        }
        totalCorrect        = s.totalCorrect
        totalAnswered       = s.totalAnswered
        // 🧹 A snapshot from a NEWER reset epoch is an authoritative wipe: its
        // wallet replaces ours instead of being max-merged with it (the max kept
        // the pre-reset minutes on a device that received someone else's reset).
        if s.resetEpoch > resetEpoch {
            resetWallets()
            clearInFlightRefund()
            pendingSecondsCarry = 0
            carryIsGift = false
        }
        earnedSecondsIn  = max(earnedSecondsIn,  s.earnedSecondsIn  ?? 0)
        earnedSecondsOut = max(earnedSecondsOut, s.earnedSecondsOut ?? 0)
        giftSecondsIn    = max(giftSecondsIn,    s.giftSecondsIn    ?? 0)
        giftSecondsOut   = max(giftSecondsOut,   s.giftSecondsOut   ?? 0)
        if let c = s.secondsCarry { pendingSecondsCarry = max(0, min(59, c)) }
        if let g = s.carryIsGift { carryIsGift = g }
        // unlockEndsAt deliberately NOT applied from sync (per-device — see captureSnapshot).
        stars               = s.stars
        diamonds            = s.diamonds
        xp                  = s.xp
        currentStreak       = s.currentStreak
        dayStreak           = s.dayStreak
        lastSessionDate     = s.lastSessionDate
        lastDailyChestDate  = s.lastDailyChestDate
        lastDailyChallengeDate = s.lastDailyChallengeDate
        if let h = s.hourlyAnswered, h.count == 24 { hourlyAnswered = h }
        if let h = s.hourlyCorrect, h.count == 24 { hourlyCorrect = h }
        unlockedWorlds      = Set(s.unlockedWorlds)
        worldProgress       = s.worldProgress
        worldStage          = s.worldStage
        topicAccuracy       = s.topicAccuracy
        topicAnswered       = s.topicAnswered
        topicCorrect        = s.topicCorrect
        batchCounter        = s.batchCounter
        cycleSeconds        = s.cycleSeconds
        wrongStreak         = s.wrongStreak
        totalScore          = s.totalScore
        lastComebackWheelAt = s.lastComebackWheelAt
        // Keep the family-wide variety-bonus day; never move it backwards.
        if let d = s.varietyBonusDate,
           d > ((defaults.object(forKey: varietyBonusDateKey) as? Date) ?? .distantPast) {
            defaults.set(d, forKey: varietyBonusDateKey)
        }
        minutesEarnedToday  = s.minutesEarnedToday
        minutesUnlockedToday = s.minutesUnlockedToday
        returnedTodayMinutes = s.returnedTodayMinutes
        dailyEarnedDate     = s.dailyEarnedDate
        answeredToday       = s.answeredToday
        correctToday        = s.correctToday
        carryOverMinutes    = s.carryOverMinutes ?? 0
        bestStreak          = max(bestStreak, s.bestStreak)
        topicResponseMs     = s.topicResponseMs
        topicAffinity       = s.topicAffinity
        topicExposure       = s.topicExposure
        topicAbandon        = s.topicAbandon
        topicAdaptiveLevel  = s.topicAdaptiveLevel ?? [:]
        wheelProgressCount  = s.wheelProgressCount
        recoveryPot         = s.recoveryPot
        giftGivenToday      = s.giftGivenToday ?? 0
        giftGivenDate       = s.giftGivenDate
        // Replace (not union) — apply() also runs on profile switch, so merging
        // would leak one child's characters onto another. Revision/lastModified
        // ordering in the sync layer already keeps the newest set.
        ownedCharacterIDs   = Set(s.ownedCharacterIDs)
    }

    /// Merge a remote snapshot of the SAME active profile into local state
    /// WITHOUT ever losing locally-earned progress — used only by the sync
    /// layer (profile switching still uses the wholesale `apply(_:)`).
    ///
    /// • Monotonic accumulators (stars, score, XP, lifetime totals, per-topic
    ///   counts, world progress, best streak) take the **max** of local/remote,
    ///   so neither device's earnings are thrown away by a revision race.
    /// • Owned sets (characters, unlocked worlds) are **unioned**.
    /// • "Latest" dates (last session / last daily chest) take the later one.
    /// • Spendable / session fields (pending minutes, the active unlock, current
    ///   streak, cycle progress, today's counters) can't be safely maxed, so
    ///   they follow last-write-wins by (revision, lastModifiedAt).
    ///
    /// Returns `true` when the caller should explicitly re-upload — i.e. local
    /// holds something the remote lacked, so the peer must be told. When local
    /// gained nothing new we adopt the remote as-is (or do nothing if already
    /// equal), which is what guarantees the exchange CONVERGES instead of
    /// ping-ponging: re-uploading at the same revision would make each device's
    /// listener fire forever. Crucially we only touch the live `@Published`
    /// fields when the data actually changes, so an unchanged merge produces no
    /// publisher events (and therefore no spurious upload).
    @discardableResult
    func mergeRemote(_ remote: ProgressSnapshot) -> Bool {
        let local = captureSnapshot()
        // Record the cloud generation we just SAW, on every path — including the
        // fully-converged one. Without this, a device that is in sync but whose
        // stored `revision` is an old inflated number never learns the cloud's
        // generation, so its next local edit stays BELOW the cloud and loses the
        // merge: minutes the child just earned would silently vanish.
        noteAdoptedGeneration(remote.revision)

        // LWW fields come from the winner; the mergeable fields ratchet up over
        // both (shared with the merge-on-upload path so neither can lose data).
        var merged = ProgressSnapshot.ratchetMerged(local: local, remote: remote)

        let changedLocal = !ProgressSnapshot.sameProgressData(merged, local)   // does adopting change us?
        let aheadOfRemote = !ProgressSnapshot.sameProgressData(merged, remote)  // do we hold more than remote?

        if changedLocal {
            // Real change → adopt it. If we're also ahead of the remote, stamp a
            // winning revision so the peer accepts our merged copy; otherwise we
            // merely caught up to the remote, so adopt its exact version.
            if aheadOfRemote {
                merged.revision = max(local.revision, remote.revision) + 1
                merged.lastModifiedAt = .now
            } else {
                merged.revision = remote.revision
                merged.lastModifiedAt = remote.lastModifiedAt
            }
            merged.deviceID = ProgressSnapshot.thisDeviceID
            apply(merged)
            // Only force an upload when we out-hold the remote; if we just caught
            // up, the harmless echo from apply() dies at the peer (same revision).
            return aheadOfRemote
        }

        // No data change. If we're still ahead of the remote, bump the revision
        // SILENTLY (revision/lastModifiedAt aren't @Published, so this fires no
        // upload loop) and let the caller push once. Otherwise we're converged.
        if aheadOfRemote {
            noteAdoptedGeneration(remote.revision)
            revision = max(local.revision, remote.revision) + 1
            lastModifiedAt = .now
            return true
        }
        return false
    }

    // (mergeMaxInt / laterDate / sameProgressData now live on ProgressSnapshot,
    // shared with the merge-on-upload transaction in RemoteSyncManager.)

    /// Grant a character to the active child (bought or awarded).
    func addOwnedCharacter(_ id: String) {
        ownedCharacterIDs.insert(id)
    }

    /// Hard-reset everything for a fresh profile. Keeps onboarding /
    /// settings — only the progress side.
    /// After an authoritative cloud write (reset wipe), adopt that revision so the
    /// next local edit outranks the wipe and our own echo is skipped.
    func adoptRevision(_ r: Int) {
        revision = max(revision, r)
        noteAdoptedGeneration(r)
        // NOTE: deliberately does NOT restamp `lastModifiedAt`. Under a
        // recency-aware comparator that would be a free "I am newest" token for
        // whoever last adopted a revision.
    }

    /// After OUR upload landed at cloud generation `r`, track it. Without this
    /// the child sat one generation BELOW the cloud forever: the upload writes
    /// `max(local, cloud) + 1`, the echo of that write is skipped as our own,
    /// and the next local edit lands on `baseRevision + 1` — which is where we
    /// already were. So every following merge let the cloud win the LWW fields
    /// and the child's newest values were dropped before the write.
    /// `editedSince` = the store changed between the capture that was uploaded
    /// and now; those edits must OUTRANK the generation we just wrote, or the
    /// next merge discards them the same way.
    func adoptUploadedGeneration(_ r: Int, editedSince: Bool) {
        noteAdoptedGeneration(r)
        revision = max(revision, editedSince ? r + 1 : r)
    }

    /// After an authoritative cloud wipe (reset), adopt the resetEpoch we just
    /// published to the cloud. Without this the resetting device stays an epoch
    /// BEHIND the blank it wrote: its post-reset earnings then ratchet-merge
    /// against the higher-epoch cloud blank (higher epoch wins wholesale) and
    /// never upload — the child keeps playing but the parent/siblings stay
    /// frozen at zero, and a peer at the higher epoch can wipe the earnings.
    func adoptResetEpoch(_ e: Int) {
        resetEpoch = max(resetEpoch, e)
    }

    func resetAll() {
        let nextRevision = revision + 1
        apply(.blank)                  // zeroes the data (and adopts blank's rev 0)
        // 💰 …except the wallets: `apply` merges their counters with `max`, so a
        // blank left every minute and the whole gift pocket in place — "איפוס
        // didn't do anything" again, and the next upload put them back in the
        // cloud. A reset is total: the counters and the carry go to zero too.
        resetWallets()
        clearInFlightRefund()
        pendingSecondsCarry = 0
        carryIsGift = false
        recomputeWallets()
        revision = nextRevision        // …but bump so the wipe outranks cloud state
        lastModifiedAt = .now
        // Device-local pockets aren't in the snapshot — wipe them too (a reset is
        // total): frozen parent time and any open window.
        manualPausedSeconds = 0
        defaults.removeObject(forKey: earnLedgerKey)   // ⏱ a reset also clears what a miss left owed
        if isUnlocked { endUnlock() }
        sessionScore = 0
        lastEarnedPoints = 0
        lastPenaltyMinutes = 0
        lastRecoveredMinutes = 0
    }
}


/// UserDefaults with the writes moved off the main thread.
///
/// `set`/`removeObject` return at once; a serial queue applies them to the
/// real store in order. Until a write lands, a read of that key answers from
/// the queued value — so code that reads straight after it writes (the topic
/// counters, the earn ledger) never sees an older value. Only ProgressStore
/// reads these keys; values the extensions need (the lease) are still written
/// directly.
final class WriteBehindDefaults: @unchecked Sendable {
    private enum Pending { case value(Any), removed }

    private let base: UserDefaults
    private let queue = DispatchQueue(label: "tofy.progress.defaults", qos: .userInitiated)
    private let lock = NSLock()
    private var pending: [String: (Pending, UInt64)] = [:]
    private var counter: UInt64 = 0

    init(_ base: UserDefaults) {
        self.base = base
        // Going to the background: land everything before iOS may suspend us.
        NotificationCenter.default.addObserver(forName: Notification.Name("UIApplicationDidEnterBackgroundNotification"),
                                               object: nil, queue: nil) { [weak self] _ in self?.flush() }
    }

    func set(_ value: Any?, forKey key: String) {
        guard let value else { removeObject(forKey: key); return }
        enqueue(key, .value(value))
    }

    func removeObject(forKey key: String) { enqueue(key, .removed) }

    private func enqueue(_ key: String, _ change: Pending) {
        lock.lock()
        counter &+= 1
        let ticket = counter
        pending[key] = (change, ticket)
        lock.unlock()
        queue.async { [self] in
            switch change {
            case .value(let v): base.set(v, forKey: key)
            case .removed:      base.removeObject(forKey: key)
            }
            lock.lock()
            if pending[key]?.1 == ticket { pending[key] = nil }   // a newer write keeps its entry
            lock.unlock()
        }
    }

    /// Blocks until every queued write is in the store.
    func flush() { queue.sync {} }

    func object(forKey key: String) -> Any? {
        lock.lock()
        let p = pending[key]?.0
        lock.unlock()
        switch p {
        case .value(let v): return v
        case .removed:      return nil
        case nil:           return base.object(forKey: key)
        }
    }

    // The same conversions UserDefaults applies to what it stores.
    func integer(forKey key: String) -> Int {
        let o = object(forKey: key)
        if let n = o as? NSNumber { return n.intValue }
        if let s = o as? String { return Int(s) ?? Int(Double(s) ?? 0) }
        return 0
    }
    func double(forKey key: String) -> Double {
        let o = object(forKey: key)
        if let n = o as? NSNumber { return n.doubleValue }
        if let s = o as? String { return Double(s) ?? 0 }
        return 0
    }
    func bool(forKey key: String) -> Bool {
        let o = object(forKey: key)
        if let n = o as? NSNumber { return n.boolValue }
        if let s = o as? String { return ["yes", "true", "1"].contains(s.lowercased()) }
        return false
    }
    func string(forKey key: String) -> String? {
        let o = object(forKey: key)
        if let s = o as? String { return s }
        if let n = o as? NSNumber { return n.stringValue }
        return nil
    }
    func data(forKey key: String) -> Data? { object(forKey: key) as? Data }
    func array(forKey key: String) -> [Any]? { object(forKey: key) as? [Any] }
    func stringArray(forKey key: String) -> [String]? { object(forKey: key) as? [String] }
    func dictionary(forKey key: String) -> [String: Any]? { object(forKey: key) as? [String: Any] }
}
