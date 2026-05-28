import SwiftUI

struct World: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let topic: Topic
    let starsToUnlock: Int
    let rooms: Int           // # of rooms in the world (default 10)
    let gradient: AppGradientKey
    let glowColor: Color

    enum AppGradientKey: String {
        case castle, tower, valley, galaxy, dreamy, gold

        var gradient: LinearGradient {
            switch self {
            case .castle: return AppGradient.castle
            case .tower: return AppGradient.tower
            case .valley: return AppGradient.valley
            case .galaxy: return AppGradient.galaxy
            case .dreamy: return AppGradient.dreamy
            case .gold: return AppGradient.gold
            }
        }
    }
}

enum Worlds {
    static let all: [World] = [
        World(
            id: "numbers_kingdom",
            name: "ממלכת המספרים",
            emoji: "🧮",
            topic: .addSub,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .castle,
            glowColor: AppColor.flameOrange
        ),
        World(
            id: "letter_tower",
            name: "מגדל האותיות",
            emoji: "📚",
            topic: .hebrewSpelling,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .tower,
            glowColor: AppColor.gemPurple
        ),
        World(
            id: "multiplication_galaxy",
            name: "גלקסיית הכפל",
            emoji: "🚀",
            topic: .mulDiv,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .galaxy,
            glowColor: Color(hex: "9B5DE5")
        )
    ]

    static func find(_ id: String) -> World? {
        all.first { $0.id == id }
    }
}
