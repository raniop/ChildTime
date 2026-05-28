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
        case englishWorld, logicWorld, scienceWorld, historyWorld, geographyWorld

        var gradient: LinearGradient {
            switch self {
            case .castle: return AppGradient.castle
            case .tower: return AppGradient.tower
            case .valley: return AppGradient.valley
            case .galaxy: return AppGradient.galaxy
            case .dreamy: return AppGradient.dreamy
            case .gold: return AppGradient.gold
            case .englishWorld: return AppGradient.englishWorld
            case .logicWorld: return AppGradient.logicWorld
            case .scienceWorld: return AppGradient.scienceWorld
            case .historyWorld: return AppGradient.historyWorld
            case .geographyWorld: return AppGradient.geographyWorld
            }
        }
    }
}

enum Worlds {
    static let all: [World] = [
        World(
            id: "math_kingdom",
            name: "ממלכת החשבון",
            emoji: "🧮",
            topic: .math,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .castle,
            glowColor: AppColor.flameOrange
        ),
        World(
            id: "english_land",
            name: "ארץ אנגלית",
            emoji: "🔤",
            topic: .english,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .englishWorld,
            glowColor: Color(hex: "FF5252")
        ),
        World(
            id: "logic_lab",
            name: "חידות הלוגיקה",
            emoji: "🧩",
            topic: .logic,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .logicWorld,
            glowColor: Color(hex: "7C4DFF")
        ),
        World(
            id: "science_lab",
            name: "מעבדת המדע",
            emoji: "🔬",
            topic: .science,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .scienceWorld,
            glowColor: Color(hex: "00C853")
        ),
        World(
            id: "history_museum",
            name: "מוזיאון ההיסטוריה",
            emoji: "🏛️",
            topic: .history,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .historyWorld,
            glowColor: Color(hex: "FFC107")
        ),
        World(
            id: "geo_journey",
            name: "מסע סביב העולם",
            emoji: "🌍",
            topic: .geography,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .geographyWorld,
            glowColor: Color(hex: "00ACC1")
        )
    ]

    static func find(_ id: String) -> World? {
        all.first { $0.id == id }
    }
}
