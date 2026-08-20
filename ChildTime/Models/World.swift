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
    /// 💫 זירת הענקים — mixes ALL the child's topics and serves ONLY the
    /// extra-hard bonus pool, paying double minutes. `topic` is nominal for
    /// such a world (theming/fallbacks only) — never used to pick questions.
    var isBonusWorld: Bool = false

    enum AppGradientKey: String {
        case castle, tower, valley, galaxy, dreamy, gold
        case englishWorld, logicWorld, scienceWorld, historyWorld, geographyWorld
        case readingWorld, bonusWorld

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
            case .readingWorld: return AppGradient.readingWorld
            case .bonusWorld: return AppGradient.bonusWorld
            }
        }
    }
}

enum Worlds {
    static let all: [World] = [
        World(
            id: "math_kingdom",
            name: "מַמְלֶכֶת הַחֶשְׁבּוֹן",
            emoji: "🧮",
            topic: .math,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .castle,
            glowColor: AppColor.flameOrange
        ),
        World(
            id: "english_land",
            name: "אֶרֶץ אַנְגְּלִית",
            emoji: "🔤",
            topic: .english,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .englishWorld,
            glowColor: Color(hex: "FF5252")
        ),
        World(
            id: "hebrew_land",
            name: "אֶרֶץ הָעִבְרִית",
            emoji: "✍️",
            topic: .hebrew,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .valley,
            glowColor: Color(hex: "FF8FAB")
        ),
        World(
            id: "logic_lab",
            name: "חִידוֹת הַלּוֹגִיקָה",
            emoji: "🧩",
            topic: .logic,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .logicWorld,
            glowColor: Color(hex: "7C4DFF")
        ),
        World(
            id: "science_lab",
            name: "מַעְבְּדַת הַמַּדָּע",
            emoji: "🔬",
            topic: .science,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .scienceWorld,
            glowColor: Color(hex: "00C853")
        ),
        World(
            id: "history_museum",
            name: "מוּזֵיאוֹן הַהִיסְטוֹרְיָה",
            emoji: "🏛️",
            topic: .history,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .historyWorld,
            glowColor: Color(hex: "FFC107")
        ),
        World(
            id: "geo_journey",
            name: "מַסָּע סְבִיב הָעוֹלָם",
            emoji: "🌍",
            topic: .geography,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .geographyWorld,
            glowColor: Color(hex: "00ACC1")
        ),
        World(
            id: "money_market",
            name: "שׁוּק הַכֶּסֶף",
            emoji: "💰",
            topic: .money,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .gold,
            glowColor: Color(hex: "43A047")
        ),
        World(
            id: "story_forest",
            name: "יַעַר הַסִּפּוּרִים",
            emoji: "📖",
            topic: .reading,
            starsToUnlock: 0,
            rooms: 10,
            gradient: .readingWorld,
            glowColor: Color(hex: "AB47BC")
        ),
        World(
            id: "bonus_arena",
            name: "זִירַת הָעֲנָקִים",
            emoji: "💫",
            topic: .logic,   // nominal — the arena mixes ALL topics (isBonusWorld)
            starsToUnlock: 0,
            rooms: 10,
            gradient: .bonusWorld,
            glowColor: AppColor.flameOrange,
            isBonusWorld: true
        )
    ]

    static func find(_ id: String) -> World? {
        all.first { $0.id == id }
    }
}
