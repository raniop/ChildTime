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
    /// Points awarded for the *last* correct answer, so the UI can flash
    /// '+15' next to the running total. Consumers may set it back to 0.
    @Published var lastEarnedPoints: Int = 0
    /// Minutes already earned today (resets at midnight). Used to enforce
    /// the optional `maxMinutesPerDay` cap.
    @Published private(set) var minutesEarnedToday: Int {
        didSet { defaults.set(minutesEarnedToday, forKey: Key.minutesEarnedToday) }
    }
    /// The day `minutesEarnedToday` refers to.
    @Published private(set) var dailyEarnedDate: Date? {
        didSet {
            if let d = dailyEarnedDate { defaults.set(d, forKey: Key.dailyEarnedDate) }
            else { defaults.removeObject(forKey: Key.dailyEarnedDate) }
        }
    }

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
        self.wrongStreak = d.integer(forKey: Key.wrongStreak)
        self.totalScore = d.integer(forKey: Key.totalScore)
        self.minutesEarnedToday = d.integer(forKey: Key.minutesEarnedToday)
        self.dailyEarnedDate = d.object(forKey: Key.dailyEarnedDate) as? Date
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

    // MARK: - Recording

    struct AnswerContext {
        let topic: Topic
        let combo: Int
        let isSuperQuestion: Bool
        let isMysteryPortal: Bool
    }

    @discardableResult
    func recordCorrect(_ ctx: AnswerContext, minutesPerCorrect: Int) -> Int {
        let earned = RewardEngine.starsForCorrect(
            combo: ctx.combo,
            isSuperQuestion: ctx.isSuperQuestion,
            isMysteryPortal: ctx.isMysteryPortal
        )
        let multiplier: Int = {
            if ctx.isMysteryPortal { return 3 }
            if ctx.isSuperQuestion { return 5 }
            return 1
        }()
        totalAnswered += 1
        totalCorrect += 1
        currentStreak += 1
        wrongStreak = 0  // any correct answer breaks the penalty streak
        stars += earned

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

        // Time reward — driven by ParentSettings.rewardMode + daily cap.
        switch settings.rewardMode {
        case .perAnswer:
            // Classic: each correct answer = N minutes (× multiplier on bonus Qs)
            _ = grantMinutesCapped(minutesPerCorrect * multiplier)
        case .perBatch:
            // Save up: every `batchAnswers` correct answers = `batchMinutes`.
            // Bonus questions still count their multiplier so super-Q is rewarding.
            batchCounter += multiplier
            let target = max(1, settings.batchAnswers)
            while batchCounter >= target {
                _ = grantMinutesCapped(settings.batchMinutes)
                batchCounter -= target
            }
        }
        xp += RewardEngine.xpPerCorrect
        updateTopicStat(topic: ctx.topic, correct: true)
        maybeConvertStarsToGems()
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
        // New day — reset.
        minutesEarnedToday = 0
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

    /// Reset the per-session score — call at the start of QuestionRunner.
    func resetSessionScore() {
        sessionScore = 0
        lastEarnedPoints = 0
    }

    /// Records a wrong answer. Returns the number of penalty minutes applied
    /// this tick (0 if penalty disabled or threshold not met). The caller can
    /// use the return value to show a gentle "lost X minutes" toast.
    @discardableResult
    func recordWrong(topic: Topic) -> Int {
        totalAnswered += 1
        currentStreak = 0
        xp += RewardEngine.xpPerQuestion
        updateTopicStat(topic: topic, correct: false)

        // Penalty handling
        let settings = ParentSettings.shared
        guard settings.penaltyEnabled else {
            wrongStreak = 0
            return 0
        }
        wrongStreak += 1
        let threshold = max(1, settings.penaltyAfterMistakes)
        guard wrongStreak >= threshold else { return 0 }

        // Deduct from pending pool first, then from active unlock window.
        var minutesToDeduct = max(0, settings.penaltyMinutes)
        let fromPending = min(pendingMinutes, minutesToDeduct)
        pendingMinutes -= fromPending
        minutesToDeduct -= fromPending

        if minutesToDeduct > 0, let end = unlockEndsAt, end > Date() {
            let newEnd = end.addingTimeInterval(-Double(minutesToDeduct * 60))
            unlockEndsAt = newEnd > Date() ? newEnd : nil
        }

        wrongStreak = 0  // reset streak so penalty doesn't fire again next wrong
        let applied = settings.penaltyMinutes
        lastPenaltyMinutes = applied  // ping the UI
        return applied
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

    private func maybeConvertStarsToGems() {
        // Every 10 stars accumulated total, gain 1 gem
        let totalGemsEarnedFromStars = stars / 10
        let alreadyEarnedFromStars = (defaults.integer(forKey: "gemsFromStars"))
        if totalGemsEarnedFromStars > alreadyEarnedFromStars {
            let delta = totalGemsEarnedFromStars - alreadyEarnedFromStars
            gems += delta
            defaults.set(totalGemsEarnedFromStars, forKey: "gemsFromStars")
        }
        // Rare drop
        if Double.random(in: 0...1) < RewardEngine.rareGemDropChance {
            gems += RewardEngine.rareGemAmount
        }
    }

    // MARK: - Chest / Daily

    func applyChestReward(_ reward: ChestReward) {
        stars += reward.stars
        gems += reward.gems
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
        unlockedWorlds.insert(id)
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

    /// Burn gems (the cosmetic shop currency). Caller must check
    /// affordability first — this asserts only that the value isn't
    /// negative, but happily takes us below the gem count if asked.
    /// Use after `gems >= amount` is verified.
    func spendGems(_ amount: Int) {
        guard amount > 0 else { return }
        gems = max(0, gems - amount)
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
}
