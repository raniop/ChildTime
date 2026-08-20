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
        case .preK:   return "גַּן וּטְרוֹם"
        case .grade1: return "כִּתּוֹת א-ב"
        case .grade3: return "כִּתּוֹת ג-ד"
        case .older:  return "כִּתָּה ה וּמַעְלָה"
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

    /// Topics that should be enabled by default for this age.
    /// PreK gets a lighter set; older kids get all 6 topics.
    var defaultEnabledTopics: Set<Topic> {
        switch self {
        case .preK:    return [.math, .logic]                                                                            // Basic only (no reading yet)
        case .grade1:  return [.math, .hebrew, .english, .logic, .science, .money, .reading]                             // Most topics
        case .grade3:  return [.math, .hebrew, .english, .logic, .science, .history, .geography, .money, .reading]       // All topics
        case .older:   return [.math, .hebrew, .english, .logic, .science, .history, .geography, .money, .reading]       // All topics
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
