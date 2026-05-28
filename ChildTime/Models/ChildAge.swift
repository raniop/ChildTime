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
        case (.grade3, .addSub):      return .medium
        case (.grade3, .hebrewSpelling): return .medium
        case (.grade3, .mulDiv):      return .easy
        case (.older, .addSub):       return .medium
        case (.older, .hebrewSpelling): return .medium
        case (.older, .mulDiv):       return .medium
        }
    }

    /// Topics that should be enabled by default for this age.
    var defaultEnabledTopics: Set<Topic> {
        switch self {
        case .preK:    return [.addSub, .hebrewSpelling]   // No mul/div in preK
        case .grade1:  return [.addSub, .hebrewSpelling]   // mulDiv just starts at end of grade 2
        case .grade3:  return [.addSub, .hebrewSpelling, .mulDiv]
        case .older:   return [.addSub, .hebrewSpelling, .mulDiv]
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
