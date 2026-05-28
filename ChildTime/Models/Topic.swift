import Foundation

enum Topic: String, CaseIterable, Codable, Identifiable {
    case addSub
    case mulDiv
    case hebrewSpelling

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .addSub: return "חיבור וחיסור"
        case .mulDiv: return "כפל וחילוק"
        case .hebrewSpelling: return "איות בעברית"
        }
    }

    var emoji: String {
        switch self {
        case .addSub: return "➕"
        case .mulDiv: return "✖️"
        case .hebrewSpelling: return "📖"
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
