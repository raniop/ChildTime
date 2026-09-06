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
    case dinosaurs
    case space
    case animals
    case sea
    case gifted
    case food
    case israel
    case music
    case body
    case vehicles
    case flags

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
        case .dinosaurs: return "דִּינוֹזָאוּרִים"
        case .space: return "חָלָל וְכוֹכָבִים"
        case .animals: return "עוֹלַם הַחַיּוֹת"
        case .sea: return "מַעֲמַקֵּי הַיָּם"
        case .gifted: return "הֲכָנָה לִמְחוֹנָנִים"
        case .food: return "מִטְבָּח וּמַדָּע שֶׁל אֹכֶל"
        case .israel: return "יִשְׂרָאֵל שֶׁלִּי"
        case .music: return "מוּזִיקָה"
        case .body: return "גּוּף הָאָדָם"
        case .vehicles: return "כְּלֵי רֶכֶב וְתַחְבּוּרָה"
        case .flags: return "דְּגָלִים וּמְדִינוֹת"
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
        case .dinosaurs: return "🦖"
        case .space: return "🚀"
        case .animals: return "🐾"
        case .sea: return "🌊"
        case .gifted: return "🧠"
        case .food: return "🍳"
        case .israel: return "🏛️"
        case .music: return "🎵"
        case .body: return "🧍"
        case .vehicles: return "🚗"
        case .flags: return "🌍"
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
