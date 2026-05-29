import Foundation

enum Topic: String, CaseIterable, Codable, Identifiable {
    case math       // חשבון — חיבור/חיסור/כפל/חילוק מאוחדים
    case english    // אנגלית
    case hebrew     // עברית — איות/כתיב נכון
    case logic      // לוגיקה
    case science    // מדע
    case history    // היסטוריה
    case geography  // גיאוגרפיה

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .math:      return "חשבון"
        case .english:   return "אנגלית"
        case .hebrew:    return "עברית"
        case .logic:     return "לוגיקה"
        case .science:   return "מדע"
        case .history:   return "היסטוריה"
        case .geography: return "גיאוגרפיה"
        }
    }

    var emoji: String {
        switch self {
        case .math:      return "🧮"
        case .english:   return "🇬🇧"
        case .hebrew:    return "✍️"
        case .logic:     return "🧩"
        case .science:   return "🔬"
        case .history:   return "🏛️"
        case .geography: return "🌍"
        }
    }
}

enum Difficulty: String, CaseIterable, Codable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "קל"
        case .medium: return "בינוני"
        case .hard: return "קשה"
        }
    }
}
