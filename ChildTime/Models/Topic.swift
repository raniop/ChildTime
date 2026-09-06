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
    case reading    // הבנת הנקרא — קטע קריאה + שאלות עליו
    // ── Paid question packs (add-ons on top of Tofy+; see QuestionPack) ──
    case soccer     // ⚽ עולם הכדורגל

    var id: String { rawValue }

    /// The base curriculum — every topic that is NOT a paid pack. This is what
    /// "all topics" means for a new child, the parent's world toggles, the live
    /// quiz picker, etc. Pack topics join a child only when the pack is bought.
    static let core: [Topic] = allCases.filter { $0.pack == nil }

    /// The paid pack this topic belongs to, if any (nil for the base topics).
    var pack: QuestionPack? { QuestionPacks.pack(for: self) }
    var isPack: Bool { pack != nil }

    var displayName: String {
        switch self {
        // Aligned to the official משרד החינוך subject names (Rani) — logic has
        // no school subject and keeps its game name.
        case .math:      return "מָתֵמָטִיקָה"
        case .english:   return "אַנְגְּלִית"
        case .hebrew:    return "עִבְרִית"
        case .logic:     return "לוֹגִיקָה"
        case .science:   return "מַדָּעִים"
        case .history:   return "הִיסְטוֹרְיָה"
        case .geography: return "גֵּאוֹגְרַפְיָה"
        case .money:     return "חִנּוּךְ פִינַנְסִי"
        case .reading:   return "הֲבָנַת הַנִּקְרָא"
        case .soccer:    return "עוֹלַם הַכַּדּוּרֶגֶל"
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
        case .reading:   return "📖"
        case .soccer:    return "⚽"
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
