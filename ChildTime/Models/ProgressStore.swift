import Foundation
import Combine

final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    private let defaults = AppGroup.defaults

    private enum Key {
        static let pendingMinutes = "pendingMinutes"
        static let totalCorrect = "totalCorrect"
        static let totalAnswered = "totalAnswered"
        static let unlockEndsAt = "unlockEndsAt"
        static let stars = "stars"
        static let gems = "gems"
        static let xp = "xp"
        static let currentStreak = "currentStreak"
        static let dayStreak = "dayStreak"
        static let lastSessionDate = "lastSessionDate"
        static let lastDailyChestDate = "lastDailyChestDate"
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
        static let dailyEarnedDate = "dailyEarnedDate"
        static let answeredToday = "answeredToday"
        static let correctToday = "correctToday"
        static let bestStreak = "bestStreak"
        static let cycleSeconds = "cycleSeconds"
        static let topicResponseMs = "topicResponseMs"
        static let topicAffinity = "topicAffinity"
        static let topicExposure = "topicExposure"
        static let topicAbandon = "topicAbandon"
        static let wheelProgressCount = "wheelProgressCount"
        static let pendingBonusWheel = "pendingBonusWheel"
        static let lastComebackWheelAt = "lastComebackWheelAt"
        static let recoveryPot = "recoveryPot"
    }

    // MARK: - Currencies & progression

    @Published private(set) var pendingMinutes: Int {
        didSet { defaults.set(pendingMinutes, forKey: Key.pendingMinutes) }
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
    @Published private(set) var stars: Int {
        didSet { defaults.set(stars, forKey: Key.stars) }
    }
    @Published private(set) var gems: Int {
        didSet { defaults.set(gems, forKey: Key.gems) }
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
    /// Play-minutes earned in the current session — the single minutes source
    /// (every `batchAnswers` correct → `batchMinutes`). Shown on the reward
    /// screen so it matches exactly what was added to the bank.
    @Published private(set) var sessionMinutesEarned: Int = 0
    /// Points awarded for the *last* correct answer, so the UI can flash
    /// '+15' next to the running total. Consumers may set it back to 0.
    @Published var lastEarnedPoints: Int = 0
    /// Minutes already earned today (resets at midnight). Used to enforce
    /// the optional `maxMinutesPerDay` cap.
    @Published private(set) var minutesEarnedToday: Int {
        didSet { defaults.set(minutesEarnedToday, forKey: Key.minutesEarnedToday) }
    }
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

    // MARK: - Init

    private init() {
        let d = AppGroup.defaults
        self.pendingMinutes = d.integer(forKey: Key.pendingMinutes)
        self.totalCorrect = d.integer(forKey: Key.totalCorrect)
        self.totalAnswered = d.integer(forKey: Key.totalAnswered)
        self.unlockEndsAt = d.object(forKey: Key.unlockEndsAt) as? Date
        self.stars = d.integer(forKey: Key.stars)
        self.gems = d.integer(forKey: Key.gems)
        self.xp = d.integer(forKey: Key.xp)
        self.currentStreak = d.integer(forKey: Key.currentStreak)
        self.dayStreak = d.integer(forKey: Key.dayStreak)
        self.lastSessionDate = d.object(forKey: Key.lastSessionDate) as? Date
        self.lastDailyChestDate = d.object(forKey: Key.lastDailyChestDate) as? Date

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
        self.answeredToday = d.integer(forKey: Key.answeredToday)
        self.correctToday = d.integer(forKey: Key.correctToday)
        self.bestStreak = d.integer(forKey: Key.bestStreak)
        self.dailyEarnedDate = d.object(forKey: Key.dailyEarnedDate) as? Date

        self.topicResponseMs = (d.dictionary(forKey: Key.topicResponseMs) as? [String: Double]) ?? [:]
        self.topicAffinity = (d.dictionary(forKey: Key.topicAffinity) as? [String: Double]) ?? [:]
        self.topicExposure = (d.dictionary(forKey: Key.topicExposure) as? [String: Int]) ?? [:]
        self.topicAbandon = (d.dictionary(forKey: Key.topicAbandon) as? [String: Int]) ?? [:]
        self.wheelProgressCount = d.integer(forKey: Key.wheelProgressCount)
        self.pendingBonusWheel = d.bool(forKey: Key.pendingBonusWheel)
        self.lastComebackWheelAt = d.object(forKey: Key.lastComebackWheelAt) as? Date
        self.recoveryPot = d.integer(forKey: Key.recoveryPot)
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
        return ParentSettings.shared.enabledTopics.contains(topic) ? 0.6 : 0.4
    }

    /// Rolling average response time (ms) for a topic; nil if never answered.
    func responseMs(for topic: Topic) -> Double? {
        topicResponseMs[topic.rawValue]
    }

    func exposure(for topic: Topic) -> Int {
        topicExposure[topic.rawValue] ?? 0
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
    }

    /// Records that the child abandoned a topic (replaced its question or quit
    /// mid-topic). Lowers affinity so the feed offers it less often.
    func recordAbandon(topic: Topic) {
        let key = topic.rawValue
        topicAbandon[key] = (topicAbandon[key] ?? 0) + 1
        let current = affinity(for: topic)
        topicAffinity[key] = min(1, max(0, current - 0.08))
    }

    /// Seed a brand-new child's learning signals from the interests and level
    /// the parent picked, so the Smart Feed isn't cold on day one. No-op once
    /// the child has answered anything (we don't overwrite real signals).
    func seedLearning(from profile: Profile) {
        guard totalAnswered == 0 else { return }
        let topics = InterestCatalog.topics(for: profile.interests)
        let boost = profile.learningLevel.affinityBoost
        for topic in topics {
            let base = ParentSettings.shared.enabledTopics.contains(topic) ? 0.6 : 0.4
            topicAffinity[topic.rawValue] = min(1, base + boost)
        }
        // Seed starting difficulty from the level for enabled topics.
        let seed = profile.learningLevel.seedDifficulty
        for topic in ParentSettings.shared.enabledTopics {
            ParentSettings.shared.setDifficulty(seed, for: topic)
        }
    }

    /// Continuously updates the per-topic learning signals after each answer.
    /// Called from `recordCorrect` / `recordWrong`.
    private func updateLearningSignals(topic: Topic, correct: Bool, responseMs: Double) {
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
                       grantsScreenTime: Bool = true) -> Int {
        totalAnswered += 1
        totalCorrect += 1
        _ = minutesEarnedTodayRespectingDate()   // roll over the day if needed
        answeredToday += 1
        correctToday += 1
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

        // Score — the headline 'ניקוד' metric. Includes combo / bonus boosts.
        let settings = ParentSettings.shared
        let topicDifficulty = settings.difficulty(for: ctx.topic)
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
                sessionMinutesEarned += grantMinutesCapped(max(1, ParentSettings.shared.batchMinutes))
                cycleSeconds -= target
            }
        }
        xp += RewardEngine.xpPerCorrect
        updateTopicStat(topic: ctx.topic, correct: true)
        updateLearningSignals(topic: ctx.topic, correct: true, responseMs: responseMs)
        wheelProgressCount += 1

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

    /// True iff the kid has already hit today's earning ceiling.
    var atDailyCap: Bool {
        let s = ParentSettings.shared
        guard s.dailyCapEnabled else { return false }
        return minutesRemainingTodayCap == 0
    }

    /// Minutes the kid can still earn today (when cap is active). When the
    /// cap is disabled, returns `.max` so callers can treat it as unlimited.
    var minutesRemainingTodayCap: Int {
        let s = ParentSettings.shared
        guard s.dailyCapEnabled else { return .max }
        let limit = max(0, s.maxMinutesPerDay)
        return max(0, limit - minutesEarnedTodayRespectingDate())
    }

    /// Minutes earned today, rolling over silently if the date has changed.
    /// Mutating helper so the in-memory counter always reflects "today".
    @discardableResult
    private func minutesEarnedTodayRespectingDate() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = dailyEarnedDate.map({ Calendar.current.startOfDay(for: $0) }),
           Calendar.current.isDate(last, inSameDayAs: today) {
            return minutesEarnedToday
        }
        // New day — reset the daily counters together.
        minutesEarnedToday = 0
        answeredToday = 0
        correctToday = 0
        dailyEarnedDate = today
        return 0
    }

    /// Adds minutes to `pendingMinutes` while honoring the daily cap.
    /// Returns the amount actually granted (may be less than `amount` if
    /// the cap clips it).
    @discardableResult
    func grantMinutesCapped(_ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        _ = minutesEarnedTodayRespectingDate()
        let allowed: Int = {
            let s = ParentSettings.shared
            guard s.dailyCapEnabled else { return amount }
            let remaining = max(0, s.maxMinutesPerDay - minutesEarnedToday)
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
        cycleSeconds = 144            // 6/10 toward the 4-min bonus
        currentStreak = 5
        bestStreak = 9
        dayStreak = 4
        totalAnswered = 48
        totalCorrect = 44
        answeredToday = 12
        correctToday = 11
        minutesEarnedToday = 16
        sessionStarsEarned = 24
        xp = 96
        topicAnswered = [Topic.math.rawValue: 20, Topic.logic.rawValue: 12, Topic.hebrew.rawValue: 9, Topic.science.rawValue: 7]
        topicCorrect  = [Topic.math.rawValue: 19, Topic.logic.rawValue: 11, Topic.hebrew.rawValue: 8, Topic.science.rawValue: 6]
        topicAccuracy = [Topic.math.rawValue: 0.95, Topic.logic.rawValue: 0.92, Topic.hebrew.rawValue: 0.89, Topic.science.rawValue: 0.86]
        topicAffinity = [Topic.math.rawValue: 0.9, Topic.logic.rawValue: 0.8, Topic.science.rawValue: 0.7]
        unlockedWorlds = Set(Worlds.all.prefix(4).map { $0.id })
    }

    /// Reset the per-session score — call at the start of QuestionRunner.
    func resetSessionScore() {
        sessionScore = 0
        sessionStarsEarned = 0
        sessionMinutesEarned = 0
        lastEarnedPoints = 0
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
    func recordWrong(topic: Topic, minutesPerCorrect: Int, grantsScreenTime: Bool = true) -> Int {
        AppAnalytics.questionAnswered(topic: topic.rawValue, correct: false)
        totalAnswered += 1
        _ = minutesEarnedTodayRespectingDate()   // roll over the day if needed
        answeredToday += 1
        currentStreak = 0
        recordCelebratedThisRun = false   // streak broke — arm the next record
        wrongStreak += 1
        xp += RewardEngine.xpPerQuestion
        updateTopicStat(topic: topic, correct: false)

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

    func applyChestReward(_ reward: ChestReward) {
        // Single currency: any legacy "gem" portion of a reward is folded into
        // stars so the child only ever collects ⭐.
        stars += reward.stars + reward.gems
        // Time bonuses honor the daily cap (so chests can't smuggle around it).
        _ = grantMinutesCapped(reward.minutes)
        if let cosmetic = reward.cosmeticID {
            ownedCosmetics.insert(cosmetic)
        }
    }

    func openDailyChest() {
        lastDailyChestDate = Date()
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

    func startUnlock(minutes: Int) {
        unlockEndsAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }

    func endUnlock() {
        unlockEndsAt = nil
    }

    /// Stop the current unlock window early and return whatever full minutes
    /// remained back to the pending pool so the kid doesn't lose them.
    /// Returns the number of minutes returned.
    @discardableResult
    func endUnlockAndReturnRemainingMinutes() -> Int {
        let remainingSeconds = unlockSecondsRemaining
        // Round to nearest full minute (don't credit partial seconds back).
        let remainingMinutes = remainingSeconds / 60
        if remainingMinutes > 0 {
            pendingMinutes += remainingMinutes
        }
        unlockEndsAt = nil
        return remainingMinutes
    }

    // MARK: - Day streak

    func registerSessionToday() {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = lastSessionDate.map({ Calendar.current.startOfDay(for: $0) }) {
            let dayDiff = Calendar.current.dateComponents([.day], from: last, to: today).day ?? 0
            if dayDiff == 0 {
                // same day, no change
            } else if dayDiff == 1 {
                dayStreak += 1
            } else {
                dayStreak = 1
            }
        } else {
            dayStreak = 1
        }
        lastSessionDate = Date()
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
        s.unlockEndsAt        = unlockEndsAt
        s.stars               = stars
        s.gems                = gems
        s.xp                  = xp
        s.currentStreak       = currentStreak
        s.dayStreak           = dayStreak
        s.lastSessionDate     = lastSessionDate
        s.lastDailyChestDate  = lastDailyChestDate
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
        s.bestStreak          = bestStreak
        s.topicResponseMs     = topicResponseMs
        s.topicAffinity       = topicAffinity
        s.topicExposure       = topicExposure
        s.topicAbandon        = topicAbandon
        s.wheelProgressCount  = wheelProgressCount
        s.recoveryPot         = recoveryPot
        s.lastModifiedAt      = .now
        return s
    }

    /// Overwrite the store with a snapshot — used when switching profiles
    /// or applying a remote update.
    func apply(_ s: ProgressSnapshot) {
        pendingMinutes      = s.pendingMinutes
        totalCorrect        = s.totalCorrect
        totalAnswered       = s.totalAnswered
        unlockEndsAt        = s.unlockEndsAt
        stars               = s.stars
        gems                = s.gems
        xp                  = s.xp
        currentStreak       = s.currentStreak
        dayStreak           = s.dayStreak
        lastSessionDate     = s.lastSessionDate
        lastDailyChestDate  = s.lastDailyChestDate
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
        bestStreak          = max(bestStreak, s.bestStreak)
        topicResponseMs     = s.topicResponseMs
        topicAffinity       = s.topicAffinity
        topicExposure       = s.topicExposure
        topicAbandon        = s.topicAbandon
        wheelProgressCount  = s.wheelProgressCount
        recoveryPot         = s.recoveryPot
    }

    /// Hard-reset everything for a fresh profile. Keeps onboarding /
    /// settings — only the progress side.
    func resetAll() {
        apply(.blank)
        sessionScore = 0
        lastEarnedPoints = 0
        lastPenaltyMinutes = 0
        lastRecoveredMinutes = 0
    }
}
