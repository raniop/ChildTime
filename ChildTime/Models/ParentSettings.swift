import Foundation
import Combine

final class ParentSettings: ObservableObject {
    static let shared = ParentSettings()

    private let defaults = AppGroup.defaults

    private enum Key {
        static let pin = "pin"
        static let minutesPerCorrect = "minutesPerCorrect"
        static let questionsPerSession = "questionsPerSession"
        static let enabledTopics = "enabledTopics"
        static let difficulty = "difficulty"
        static let activitySelection = "activitySelection"
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
            case .off:    return "כבוי"
            case .once:   return "פעם ביום"
            case .twice:  return "פעמיים ביום"
            case .thrice: return "שלוש פעמים ביום"
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
            case .perAnswer: return "דקות לכל תשובה"
            case .perBatch:  return "צבירת תשובות"
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
    @Published var difficultyByTopic: [Topic: Difficulty] {
        didSet {
            let raw = difficultyByTopic.reduce(into: [String: String]()) { result, pair in
                result[pair.key.rawValue] = pair.value.rawValue
            }
            defaults.set(raw, forKey: Key.difficulty)
        }
    }
    @Published var activitySelectionData: Data? {
        didSet { defaults.set(activitySelectionData, forKey: Key.activitySelection) }
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
    /// The parental-consent version this parent accepted. 0 = not yet consented.
    @Published var consentVersionAccepted: Int {
        didSet { defaults.set(consentVersionAccepted, forKey: Key.consentVersionAccepted) }
    }
    /// How often to send on-device parent-insight notifications.
    @Published var parentInsightFrequency: InsightFrequency {
        didSet { defaults.set(parentInsightFrequency.rawValue, forKey: Key.parentInsightFrequency) }
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
                ? [.math, .hebrew, .english, .logic, .science]
                : parsed
        } else {
            self.enabledTopics = [.math, .hebrew, .english, .logic, .science]
        }

        if let raw = d.dictionary(forKey: Key.difficulty) as? [String: String] {
            var dict: [Topic: Difficulty] = [:]
            for (k, v) in raw {
                if let t = Topic(rawValue: k), let diff = Difficulty(rawValue: v) {
                    dict[t] = diff
                }
            }
            self.difficultyByTopic = dict.isEmpty ? Self.defaultDifficulties : dict
        } else {
            self.difficultyByTopic = Self.defaultDifficulties
        }

        self.activitySelectionData = d.data(forKey: Key.activitySelection)
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

        // Reward mode
        if let raw = d.string(forKey: Key.rewardMode),
           let mode = RewardMode(rawValue: raw) {
            self.rewardMode = mode
        } else {
            self.rewardMode = .perAnswer
        }
        let ba = d.integer(forKey: Key.batchAnswers)
        self.batchAnswers = ba == 0 ? 5 : ba
        let bm = d.integer(forKey: Key.batchMinutes)
        self.batchMinutes = bm == 0 ? 10 : bm

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
        self.questionsPerWheel = qpw == 0 ? 20 : qpw

        self.faceIDForParentGate = d.bool(forKey: Key.faceIDForParentGate)
        self.consentVersionAccepted = d.integer(forKey: Key.consentVersionAccepted)
        self.parentInsightFrequency = InsightFrequency(
            rawValue: d.string(forKey: Key.parentInsightFrequency) ?? ""
        ) ?? .off
    }

    var hasConsented: Bool { consentVersionAccepted >= Consent.currentVersion }

    /// Apply age-appropriate defaults (called when parent picks an age in onboarding
    /// or changes it later in Settings).
    func applyAgeDefaults(_ age: ChildAge) {
        self.childAge = age
        self.enabledTopics = age.defaultEnabledTopics
        self.minutesPerCorrectAnswer = age.defaultMinutesPerCorrect
        var newDifficulty: [Topic: Difficulty] = [:]
        for topic in age.defaultEnabledTopics {
            newDifficulty[topic] = age.defaultDifficulty(for: topic)
        }
        self.difficultyByTopic = newDifficulty
    }

    static let defaultDifficulties: [Topic: Difficulty] = [
        .math: .easy,
        .english: .easy,
        .hebrew: .easy,
        .logic: .easy,
        .science: .easy,
        .history: .easy,
        .geography: .easy
    ]

    func difficulty(for topic: Topic) -> Difficulty {
        difficultyByTopic[topic] ?? .easy
    }

    func setDifficulty(_ d: Difficulty, for topic: Topic) {
        difficultyByTopic[topic] = d
    }
}
