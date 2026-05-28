import Foundation

enum ChildAge: Int, Codable, CaseIterable, Identifiable {
    case preK = 4    // 4-5 — גן/טרום
    case grade1 = 6  // 6-7 — כיתה א-ב
    case grade3 = 8  // 8-9 — כיתה ג-ד
    case older = 10  // 10+ — כיתה ה ומעלה

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .preK:   return "4-5"
        case .grade1: return "6-7"
        case .grade3: return "8-9"
        case .older:  return "10+"
        }
    }

    var description: String {
        switch self {
        case .preK:   return "גן וטרום"
        case .grade1: return "כיתות א-ב"
        case .grade3: return "כיתות ג-ד"
        case .older:  return "כיתה ה ומעלה"
        }
    }

    var emoji: String {
        switch self {
        case .preK:   return "🧒"
        case .grade1: return "👦"
        case .grade3: return "👧"
        case .older:  return "🧑"
        }
    }

    /// Default difficulty for a topic based on the child's age.
    func defaultDifficulty(for topic: Topic) -> Difficulty {
        switch (self, topic) {
        case (.preK, _):              return .easy
        case (.grade1, _):            return .easy
        case (.grade3, _):            return .medium
        case (.older, _):             return .medium
        }
    }

    /// Topics that should be enabled by default for this age.
    /// PreK gets a lighter set; older kids get all 6 topics.
    var defaultEnabledTopics: Set<Topic> {
        switch self {
        case .preK:    return [.math, .logic]                                                  // Basic only
        case .grade1:  return [.math, .english, .logic, .science]                              // Most topics
        case .grade3:  return [.math, .english, .logic, .science, .history, .geography]       // All topics
        case .older:   return [.math, .english, .logic, .science, .history, .geography]       // All topics
        }
    }

    /// Suggested default minutes per correct answer (younger kids need more reward per Q).
    var defaultMinutesPerCorrect: Int {
        switch self {
        case .preK:    return 3
        case .grade1:  return 2
        case .grade3:  return 2
        case .older:   return 1
        }
    }
}
