import Foundation

enum Topic: String, CaseIterable, Codable, Identifiable {
    case math       // חשבון — חיבור/חיסור/כפל/חילוק מאוחדים
    case english    // אנגלית
    case hebrew     // עברית — איות/כתיב נכון
    case logic      // לוגיקה
    case science    // מדע
    case history    // היסטוריה
    case geography  // גיאוגרפיה
    case money      // כסף וחיים — חינוך פיננסי בסיסי

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .math:      return "חֶשְׁבּוֹן"
        case .english:   return "אַנְגְּלִית"
        case .hebrew:    return "עִבְרִית"
        case .logic:     return "לוֹגִיקָה"
        case .science:   return "מַדָּע"
        case .history:   return "הִיסְטוֹרְיָה"
        case .geography: return "גֵּאוֹגְרַפְיָה"
        case .money:     return "כֶּסֶף וְחַיִּים"
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
        case .money:     return "💰"
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
        case .easy: return "קַל"
        case .medium: return "בֵּינוֹנִי"
        case .hard: return "קָשֶׁה"
        }
    }
}
