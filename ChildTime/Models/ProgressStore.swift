import Foundation
import Combine

final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    private let defaults = AppGroup.defaults

    private enum Key {
        static let pendingMinutes = "pendingMinutes"
        static let pendingSecondsCarry = "pendingSecondsCarry"
        static let manualPausedSeconds = "manualPausedSeconds"
        static let totalCorrect = "totalCorrect"
        static let totalAnswered = "totalAnswered"
        static let unlockEndsAt = "unlockEndsAt"
        static let unlockIsManual = "unlockIsManual"
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
        static let dailyEarnedDate = "dailyEarnedDate"
        static let carryOverMinutes = "carryOverMinutes"
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
        static let revision = "progress.revision"
        static let lastModifiedAt = "progress.lastModifiedAt"
    }

    // MARK: - Currencies & progression

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
    /// True when the CURRENT window is a parent's one-time manual grant ("quick
    /// open") — a fixed wall-clock window that must NOT bank its leftover minutes
    /// back into the child's earned pool when it ends, and offers no early-stop.
    /// Earned redemptions leave this false (they're pausable + bankable).
    @Published private(set) var unlockIsManual: Bool {
        didSet { defaults.set(unlockIsManual, forKey: Key.unlockIsManual) }
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
        didSet { defaults.set(xp, forKey: Key.xp) }
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
    /// Progress toward the next play-minutes bonus, in SECONDS. Each correct
    /// answer adds a fraction (target ÷ batchAnswers, e.g. 24s); a wrong answer
    /// gently removes half a step. When it reaches the target (batchMinutes × 60),
    /// batchMinutes are banked into pendingMinutes. Gives immediate per-question
    /// progress instead of waiting for the whole batch.
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

    // MARK: - Sync versioning

    /// Monotonic version of the ACTIVE profile's progress. The sync layer uses
    /// `revision` (then `lastModifiedAt`) to decide which device's snapshot wins.
    /// Persisted so it survives relaunches — otherwise every capture would look
    /// like revision 0 and the "is the remote newer?" check could never be true.
    private(set) var revision: Int {
        didSet { defaults.set(revision, forKey: Key.revision) }
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
        self.pendingSecondsCarry = d.integer(forKey: Key.pendingSecondsCarry)
        self.manualPausedSeconds = d.integer(forKey: Key.manualPausedSeconds)
        self.totalCorrect = d.integer(forKey: Key.totalCorrect)
        self.totalAnswered = d.integer(forKey: Key.totalAnswered)
        self.unlockEndsAt = d.object(forKey: Key.unlockEndsAt) as? Date
        self.unlockIsManual = d.bool(forKey: Key.unlockIsManual)
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
        ]
        Publishers.MergeMany(triggers)
            .sink { [weak self] _ in self?.markLocalChange() }
            .store(in: &versionCancellables)
    }

    private func markLocalChange() {
        guard !isApplyingSnapshot else { return }
        revision += 1
        lastModifiedAt = .now
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
        guard let last = lastDailyChestDate else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    func accuracy(for topic: Topic) -> Double {
        topicAccuracy[topic.rawValue] ?? 0.7
    }

    // MARK: - Smart Learning Feed — derived signals

    /// Learned affinity for a topic. Unseen topics are seeded from whether the
    /// parent enabled them: enabled → 0.6 (slight head-start), else 0.4.
    func affinity(for topic: Topic) -> Double {
        if let a = topicAffinity[topic.rawValue] { return a }
        return (ProfileStore.shared.active?.enabledTopics ?? ParentSettings.shared.enabledTopics).contains(topic) ? 0.6 : 0.4
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
        let cal = Calendar.current
        if let granted = lastComebackWheelAt, cal.isDate(granted, inSameDayAs: Date()) { return }
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
            let base = (ProfileStore.shared.active?.enabledTopics ?? ParentSettings.shared.enabledTopics).contains(topic) ? 0.6 : 0.4
            topicAffinity[topic.rawValue] = min(1, base + boost)
        }
        // Starting difficulty is no longer seeded into a global setting — it's
        // derived per-child from `profile.learningLevel` (see `Profile.difficulty(for:)`)
        // until the parent overrides it per-topic from their dashboard.
    }

    /// Continuously updates the per-topic learning signals after each answer.
    /// Called from `recordCorrect` / `recordWrong`.
    private func updateLearningSignals(topic: Topic, correct: Bool, responseMs: Double,
                                       hintUsed: Bool = false) {
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

        // Nudge the adaptive difficulty level from this answer's signals.
        adjustAdaptiveLevel(topic: topic, correct: correct, fast: fast,
                            hintUsed: hintUsed, abandoned: false)
    }

    // MARK: - Recording

    struct AnswerContext {
        let topic: Topic
        let combo: Int
        let isSuperQuestion: Bool
        let isMysteryPortal: Bool
    }

    @discardableResult
    func recordCorrect(_ ctx: AnswerContext,
                       minutesPerCorrect: Int,
                       responseMs: Double = 0,
                       hadMistakeThisQuestion: Bool = false,
                       hintUsed: Bool = false,
                       grantsScreenTime: Bool = true) -> Int {
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
            isMysteryPortal: ctx.isMysteryPortal
        )
        stars += earned
        // 💎 spendable wallet — earned alongside ⭐, but at a slower rate so the
        // shop keeps its value. Stars stay the leaderboard rank; diamonds buy.
        // Limited-time event bonus (e.g. weekend / topic-of-the-day → 💎×2).
        let eventMult = GameEvent.current()?.diamondMultiplier(for: ctx.topic) ?? 1
        let earnedDiamonds = RewardEngine.diamondsForCorrect(
            combo: currentStreak,
            isSuperQuestion: ctx.isSuperQuestion,
            isMysteryPortal: ctx.isMysteryPortal
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
            difficulty: topicDifficulty
        )
        totalScore += pts
        sessionScore += pts
        lastEarnedPoints = pts

        // Time reward — ONLY in Earn-to-Unlock sessions. In Free Learning mode
        // the reward is in-game progression (XP/coins/levels), never minutes.
        if grantsScreenTime {
            // Fractional reward: each correct answer adds its share of seconds to
            // the cycle (e.g. 24s of a 4-min/10-question bonus). When the cycle
            // fills, bank batchMinutes into the spendable balance.
            let target = Double(bonusTargetSeconds)
            let perSec = target / Double(cycleQuestionsTotal)
            cycleSeconds += perSec
            while cycleSeconds >= target - 0.01 {
                let granted = grantMinutesCapped(max(1, ParentSettings.shared.batchMinutes))
                sessionMinutesEarned += granted
                sittingMinutes += granted
                cycleSeconds -= target
            }
        }
        xp += RewardEngine.xpPerCorrect
        updateTopicStat(topic: ctx.topic, correct: true)
        updateLearningSignals(topic: ctx.topic, correct: true, responseMs: responseMs, hintUsed: hintUsed)
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
                pendingMinutes += refund
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
        // (or, due to sync/clock-skew, a future-dated) value must NOT trigger a
        // rollover — a spurious rollover re-releases banked carry-over minutes and
        // zeroes the daily counters, which made the redeemable minutes jump around.
        if let last = dailyEarnedDate.map({ Calendar.current.startOfDay(for: $0) }),
           last >= today {
            return minutesEarnedToday
        }
        // New day — first, yesterday's banked bonus minutes become playable.
        if carryOverMinutes > 0 {
            pendingMinutes += carryOverMinutes
            carryOverMinutes = 0
        }
        // Reset the daily counters together.
        minutesEarnedToday = 0
        minutesUnlockedToday = 0
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
            pendingMinutes += amount
            return BonusGrant(addedToday: amount)
        }
        _ = minutesEarnedTodayRespectingDate()
        var result = BonusGrant()
        let todayRoom = max(0, cap.max - minutesEarnedToday)
        let toToday = min(amount, todayRoom)
        if toToday > 0 {
            pendingMinutes += toToday
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

    /// Returns the amount actually granted (may be less than `amount` if
    /// the cap clips it).
    @discardableResult
    func grantMinutesCapped(_ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        _ = minutesEarnedTodayRespectingDate()
        let allowed: Int = {
            let cap = dailyCap
            guard cap.enabled else { return amount }
            let remaining = max(0, cap.max - minutesEarnedToday)
            return min(amount, remaining)
        }()
        guard allowed > 0 else { return 0 }
        pendingMinutes += allowed
        minutesEarnedToday += allowed
        if dailyEarnedDate == nil {
            dailyEarnedDate = Calendar.current.startOfDay(for: Date())
        }
        return allowed
    }

    /// Seed pleasant demo numbers for App Store screenshots (DEMO_SCREEN only).
    func seedForDemo() {
        stars = 213
        pendingMinutes = 12
        parentGiftMinutes = 10        // 💝 a parent gift, shown apart from earned
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
        // DEMO_BIG=1 → stress-test the currency chips with huge balances.
        if ProcessInfo.processInfo.environment["DEMO_BIG"] != nil {
            stars = 1284500      // → "1.3M"
            diamonds = 2500      // → "2.5K"
            pendingMinutes = 1280
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

    /// Records a wrong pick. Deducts half the per-correct reward and parks it in
    /// the recovery pot — a clean correct answer on the next question wins it
    /// back (Risk & Recovery loop). Returns the minutes deducted this tick.
    @discardableResult
    func recordWrong(topic: Topic, minutesPerCorrect: Int, hintUsed: Bool = false,
                     grantsScreenTime: Bool = true) -> Int {
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
        // A miss eases the adaptive level for this topic (gentle, capped).
        adjustAdaptiveLevel(topic: topic, correct: false, fast: false,
                            hintUsed: hintUsed, abandoned: false)

        // Gentle affinity nudge down (no exposure/response bump — those are
        // counted once per question when it's finally answered correctly).
        let key = topic.rawValue
        topicAffinity[key] = min(1, max(0, affinity(for: topic) - 0.04))

        // Free Learning mode has no screen-time economy, so mistakes never cost
        // anything there — only in-game progress is at stake.
        guard grantsScreenTime else { return 0 }
        guard ParentSettings.shared.penaltyEnabled else { return 0 }

        // Gentle: a mistake removes HALF a step from the cycle progress (no
        // banked minutes are ever taken). One correct answer wins it back.
        // Returns the SECONDS removed, for a soft "−Ns · כמעט!" toast.
        let perSec = Double(bonusTargetSeconds) / Double(cycleQuestionsTotal)
        let before = cycleSeconds
        cycleSeconds = max(0, cycleSeconds - perSec / 2)
        lastPenaltyMinutes = 0
        return Int((before - cycleSeconds).rounded())
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

    /// Questions answered today toward the goal, capped at the target.
    var dailyChallengeProgress: Int { min(answeredToday, Self.dailyChallengeTarget) }

    /// The goal was reached today (regardless of whether the reward was claimed).
    var dailyChallengeGoalMet: Bool { answeredToday >= Self.dailyChallengeTarget }

    /// Today's reward was already collected.
    var dailyChallengeClaimed: Bool {
        guard let last = lastDailyChallengeDate else { return false }
        return Calendar.current.isDateInToday(last)
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
        if isNew { AppAnalytics.worldUnlocked(id) }
    }

    func canUnlock(world: World) -> Bool {
        stars >= world.starsToUnlock
    }

    func progress(in worldID: String) -> Int {
        worldProgress[worldID] ?? 0
    }

    func advanceRoom(in worldID: String) {
        let current = progress(in: worldID)
        worldProgress[worldID] = min(current + 1, 9)
    }

    // MARK: - Spending pending minutes

    /// Pays for an in-app benefit (e.g. a hint) by burning pending minutes.
    /// Returns `true` if the kid had enough minutes and the spend succeeded.
    @discardableResult
    func spendPendingMinutes(_ count: Int) -> Bool {
        guard count > 0 else { return true }
        guard pendingMinutes >= count else { return false }
        pendingMinutes -= count
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
        pendingMinutes = 0
        return m
    }

    /// The most minutes the kid may unlock RIGHT NOW: their accumulated wallet,
    /// clamped to what's left of today's screen-time allowance (daily cap minus
    /// what's already been unlocked today). Wallet beyond the daily cap stays put
    /// for future days. When the cap is disabled, the whole wallet is available.
    var redeemableMinutesNow: Int {
        let cap = dailyCap
        guard cap.enabled else { return pendingMinutes }
        let roomToday = max(0, cap.max - minutesUnlockedTodayResolved)
        return min(pendingMinutes, roomToday)
    }

    /// `minutesUnlockedToday`, but treated as 0 if the stored counter is from a
    /// previous day — so the redeem math is correct even if the daily rollover
    /// hasn't run yet (e.g. the app stayed foreground across midnight). Read-only:
    /// the real reset still happens in `minutesEarnedTodayRespectingDate()`.
    private var minutesUnlockedTodayResolved: Int {
        guard let d = dailyEarnedDate,
              Calendar.current.isDate(d, inSameDayAs: Date()) else { return 0 }
        return minutesUnlockedToday
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
    var dailyScreenTimeMaxedOut: Bool {
        dailyCap.enabled && !canRedeemNow && pendingMinutes > redeemableMinutesNow
    }

    /// Consume up to today's remaining allowance from the wallet for an unlock.
    /// Returns the granted amount; any leftover stays in `pendingMinutes` for a
    /// later day so a large wallet can't be cashed in past the daily cap at once.
    @discardableResult
    func consumeMinutesForUnlock() -> Int {
        _ = minutesEarnedTodayRespectingDate()   // roll the day over first if needed
        let amount = redeemableMinutesNow
        guard amount > 0 else { return 0 }
        pendingMinutes -= amount
        minutesUnlockedToday += amount
        return amount
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
        pendingMinutes = max(0, pendingMinutes + delta)
    }

    // MARK: - 💝 Parent gift pocket (separate from the earned wallet)

    /// A parent's "+N" gift (or "−N" taken back from the gift pocket). Clamped ≥0.
    /// Never touches `pendingMinutes` — the earned wallet stays the child's own.
    func addParentGiftMinutes(_ delta: Int) {
        guard delta != 0 else { return }
        parentGiftMinutes = max(0, parentGiftMinutes + delta)
    }

    /// Child opens the whole gift pocket as ONE fixed `manual` window (like a
    /// remote grant): not capped by the daily limit, and its leftover freezes
    /// on stop-and-save (`pauseManualUnlock`) rather than banking to the wallet.
    /// Returns the minutes opened (0 = nothing to open).
    @discardableResult
    func consumeParentGiftForUnlock() -> Int {
        let amount = parentGiftMinutes
        guard amount > 0 else { return 0 }
        parentGiftMinutes = 0
        return amount
    }

    func startUnlock(minutes: Int, manual: Bool = false) {
        // Fold any banked sub-minute carry into a real (non-manual) window so the
        // kid resumes at the exact leftover (e.g. 58 min wallet + 50 s carry →
        // 58:50). A parent's manual quick-open is a fixed window — it ignores carry.
        let extraSeconds = manual ? 0 : pendingSecondsCarry
        if !manual { pendingSecondsCarry = 0 }
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60 + extraSeconds))
        NSLog("[ScreenTime] startUnlock(minutes: %d, manual: %@) → window %d min + %ds carry", minutes, manual ? "true" : "false", minutes, extraSeconds)
        unlockIsManual = manual
        unlockEndsAt = end
        // Lock-screen / Dynamic Island countdown of the remaining play time.
        PlayTimeLiveActivity.start(endsAt: end,
                                   characterName: ProfileStore.shared.active?.character.name ?? "")
    }

    func endUnlock() {
        unlockEndsAt = nil
        unlockIsManual = false
        PlayTimeLiveActivity.end()
    }

    /// Whole minutes of frozen manual time waiting to be resumed (ceil, so 20:10
    /// reads as "21" rather than hiding the leftover). For display.
    var pausedManualMinutes: Int { (manualPausedSeconds + 59) / 60 }
    var hasPausedManualTime: Bool { manualPausedSeconds > 0 }

    /// Stop the current play window and SAVE the leftover: FREEZE it for a parent's
    /// manual grant (resume later), or BANK it to the wallet for earned time. Does
    /// NOT re-apply the shield — the caller does. Used by the "עצור ושמור" action
    /// (play screen + Live Activity button).
    func stopAndSaveCurrentUnlock() {
        guard isUnlocked else { return }
        if unlockIsManual { pauseManualUnlock() }
        else { _ = endUnlockAndReturnRemainingMinutes() }
    }

    /// Child stopped mid-play on a parent's MANUAL grant — FREEZE the exact leftover
    /// (to the second) instead of wasting it, and end the live window. Caller
    /// re-applies the shield. No-op for an earned window (that banks to the wallet).
    func pauseManualUnlock() {
        guard unlockIsManual else { return }
        let remaining = unlockSecondsRemaining
        if remaining > 0 { manualPausedSeconds += remaining }
        endUnlock()
    }

    /// Resume frozen manual time — reopen a manual window from the saved seconds and
    /// clear the frozen balance. Returns whole minutes (ceil) for the shield schedule.
    @discardableResult
    func resumeManualUnlock() -> Int {
        guard manualPausedSeconds > 0 else { return 0 }
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
        return end > Date()
    }

    /// Re-sync the unlock deadline from the shared app group (the monitor
    /// extension may have cleared it while we were backgrounded). Call on
    /// foreground before deciding whether to re-lock.
    func reloadUnlockFromShared() {
        let shared = defaults.object(forKey: Key.unlockEndsAt) as? Date
        if shared == nil {
            if unlockEndsAt != nil { endUnlock() }   // extension spent/ended it
        } else if shared! <= Date() {
            // Window elapsed but the monitor never cleared it (e.g. the extension
            // didn't fire). Fail CLOSED — end the grant so the baseline lock
            // re-applies. Apps must never stay open past the granted window.
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
        let remainingSeconds = unlockSecondsRemaining
        // Bank the EXACT leftover time, to the second. Neither floor it (which wasted
        // the partial minute: 58:50 → 58) nor round the minute up (which invented
        // time: 58:50 → 59). Instead split into whole minutes + a sub-minute carry,
        // so reopening resumes at precisely 58:50.
        let totalSeconds = (pendingSecondsCarry + remainingSeconds)
        let remainingMinutes = totalSeconds / 60
        pendingSecondsCarry = totalSeconds % 60
        if remainingMinutes > 0 {
            pendingMinutes += remainingMinutes
            // These minutes were returned unused — they don't count against today's
            // unlocked allowance, so the kid can re-open them later today.
            minutesUnlockedToday = max(0, minutesUnlockedToday - remainingMinutes)
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
        s.topicAccuracy       = topicAccuracy
        s.topicAnswered       = topicAnswered
        s.topicCorrect        = topicCorrect
        s.batchCounter        = batchCounter
        s.cycleSeconds        = cycleSeconds
        s.wrongStreak         = wrongStreak
        s.totalScore          = totalScore
        s.minutesEarnedToday  = minutesEarnedToday
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
        s.ownedCharacterIDs   = Array(ownedCharacterIDs)
        // Carry the REAL version forward. Stamping `.now` here (the old bug) made
        // every capture look freshly-modified, so a remote snapshot's older
        // timestamp could never win the comparison and cross-device sync was dead.
        s.revision            = revision
        s.lastModifiedAt      = lastModifiedAt
        s.deviceID            = ProgressSnapshot.thisDeviceID
        return s
    }

    /// Overwrite the store with a snapshot — used when switching profiles
    /// or applying a remote update.
    func apply(_ s: ProgressSnapshot) {
        // Loading a snapshot is not a local edit — suppress revision bumps while
        // the fields change, then adopt the snapshot's own version so a later
        // local edit builds on top of it (and outranks what we just received).
        isApplyingSnapshot = true
        defer {
            isApplyingSnapshot = false
            revision = s.revision
            lastModifiedAt = s.lastModifiedAt
        }
        pendingMinutes      = s.pendingMinutes
        totalCorrect        = s.totalCorrect
        totalAnswered       = s.totalAnswered
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
        topicAccuracy       = s.topicAccuracy
        topicAnswered       = s.topicAnswered
        topicCorrect        = s.topicCorrect
        batchCounter        = s.batchCounter
        cycleSeconds        = s.cycleSeconds
        wrongStreak         = s.wrongStreak
        totalScore          = s.totalScore
        minutesEarnedToday  = s.minutesEarnedToday
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
        parentGiftMinutes   = s.parentGiftMinutes ?? 0
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
    func resetAll() {
        let nextRevision = revision + 1
        apply(.blank)                  // zeroes the data (and adopts blank's rev 0)
        revision = nextRevision        // …but bump so the wipe outranks cloud state
        lastModifiedAt = .now
        sessionScore = 0
        lastEarnedPoints = 0
        lastPenaltyMinutes = 0
        lastRecoveredMinutes = 0
    }
}
