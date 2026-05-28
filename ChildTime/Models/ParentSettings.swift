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

    private init() {
        let d = AppGroup.defaults
        self.pin = (d.string(forKey: Key.pin) ?? "1234")
        let mpc = d.integer(forKey: Key.minutesPerCorrect)
        self.minutesPerCorrectAnswer = mpc == 0 ? 2 : mpc
        let qps = d.integer(forKey: Key.questionsPerSession)
        self.questionsPerSession = qps == 0 ? 5 : qps

        if let raw = d.stringArray(forKey: Key.enabledTopics) {
            let parsed = Set(raw.compactMap(Topic.init(rawValue:)))
            // If migration left us with no recognized topics, fall back to defaults.
            self.enabledTopics = parsed.isEmpty
                ? [.math, .english, .logic, .science]
                : parsed
        } else {
            self.enabledTopics = [.math, .english, .logic, .science]
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
    }

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
