import Foundation

enum ChildGender: String, Codable, CaseIterable, Identifiable {
    case boy
    case girl

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .boy:  return "👦"
        case .girl: return "👧"
        }
    }

    var displayName: String {
        switch self {
        case .boy:  return "יֶלֶד"
        case .girl: return "יַלְדָּה"
        }
    }
}
