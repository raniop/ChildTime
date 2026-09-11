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
    case tishrei    // 🍎 חַגֵּי תִּשְׁרֵי — the first event world

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
        case .math:      return tr("מָתֵמָטִיקָה")
        case .english:   return tr("אַנְגְּלִית")
        case .hebrew:    return tr("עִבְרִית")
        case .logic:     return tr("לוֹגִיקָה")
        case .science:   return tr("מַדָּעִים")
        case .history:   return tr("הִיסְטוֹרְיָה")
        case .geography: return tr("גֵּאוֹגְרַפְיָה")
        case .money:     return tr("חִנּוּךְ פִינַנְסִי")
        case .reading:   return tr("הֲבָנַת הַנִּקְרָא")
        case .soccer:    return tr("עוֹלַם הַכַּדּוּרֶגֶל")
        case .dinosaurs: return tr("דִּינוֹזָאוּרִים")
        case .space: return tr("חָלָל וְכוֹכָבִים")
        case .animals: return tr("עוֹלַם הַחַיּוֹת")
        case .sea: return tr("מַעֲמַקֵּי הַיָּם")
        case .gifted: return tr("הֲכָנָה לִמְחוֹנָנִים")
        case .food: return tr("מִטְבָּח וּמַדָּע שֶׁל אֹכֶל")
        case .israel: return tr("יִשְׂרָאֵל שֶׁלִּי")
        case .music: return tr("מוּזִיקָה")
        case .body: return tr("גּוּף הָאָדָם")
        case .vehicles: return tr("כְּלֵי רֶכֶב וְתַחְבּוּרָה")
        case .flags: return tr("דְּגָלִים וּמְדִינוֹת")
        case .tishrei: return tr("חַגֵּי תִּשְׁרֵי")
        }
    }

    var emoji: String {
        switch self {
        case .math:      return "🧮"
        case .english:   return LanguageStore.shared.current == .he ? "🇬🇧" : "📝"   // a US child's own language class, not a foreign one
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
        case .tishrei: return "🍎"
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
        case .easy: return tr("קַל")
        case .medium: return tr("בֵּינוֹנִי")
        case .hard: return tr("קָשֶׁה")
        }
    }
}
