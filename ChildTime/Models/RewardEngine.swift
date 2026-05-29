import Foundation

/// Centralized rules: how many stars / gems / minutes for each event.
enum RewardEngine {
    /// Stars granted for a correct answer, taking combo + super into account.
    static func starsForCorrect(combo: Int, isSuperQuestion: Bool, isMysteryPortal: Bool) -> Int {
        if isMysteryPortal { return 3 }
        if isSuperQuestion { return 5 }
        if combo >= 5 { return 3 }
        if combo >= 3 { return 2 }
        return 1
    }

    /// Bonus minutes for a streak of correct answers (added on top of per-correct rate).
    static func bonusMinutesForStreak(_ streak: Int) -> Int {
        switch streak {
        case ..<3: return 0
        case 3..<5: return 1
        case 5..<10: return 2
        default: return 3
        }
    }

    /// XP per question (correct or wrong — they learn either way).
    static let xpPerQuestion = 1
    static let xpPerCorrect = 2

    // MARK: - Score (the headline "ניקוד" metric)

    /// Base points per correct answer. Tunable from one spot.
    static let pointsPerCorrect = 10

    /// Score awarded for a single correct answer. Reflects difficulty,
    /// combos, super-Qs, and mystery portals so the kid sees the number
    /// jump in moments of mastery.
    static func pointsForCorrect(
        combo: Int,
        isSuperQuestion: Bool,
        isMysteryPortal: Bool,
        difficulty: Difficulty
    ) -> Int {
        var base = pointsPerCorrect
        // Difficulty bump
        switch difficulty {
        case .easy:   base += 0
        case .medium: base += 5
        case .hard:   base += 10
        }
        // Combo bump
        if combo >= 10 { base += 10 }
        else if combo >= 5 { base += 5 }
        else if combo >= 3 { base += 2 }
        // Event multipliers (compound)
        if isSuperQuestion { base *= 5 }
        if isMysteryPortal { base *= 3 }
        return base
    }

    /// XP thresholds for each level.
    static let levelThresholds: [Int] = [0, 10, 25, 50, 100, 200, 350, 550, 800, 1100, 1500]

    static func level(forXP xp: Int) -> Int {
        var lvl = 1
        for (i, threshold) in levelThresholds.enumerated() {
            if xp >= threshold { lvl = i + 1 }
        }
        return lvl
    }

    /// Gems are converted from stars (1 gem per 10 stars) plus rare drops.
    static let gemsPer10Stars = 1
    static let rareGemDropChance: Double = 0.05  // 5%
    static let rareGemAmount = 3
}

enum ChestKind: String, Codable {
    case wood
    case gold
    case magic     // daily
    case legendary // world completion / 30-day streak

    var emoji: String {
        switch self {
        case .wood: return "📦"
        case .gold: return "🎁"
        case .magic: return "🪄"
        case .legendary: return "🌌"
        }
    }

    var label: String {
        switch self {
        case .wood: return "קֻפְסַת עֵץ"
        case .gold: return "קֻפְסַת זָהָב"
        case .magic: return "קֻפְסַת קֶסֶם"
        case .legendary: return "קֻפְסַת אַגָּדָה"
        }
    }
}

struct ChestReward: Equatable {
    var stars: Int
    var gems: Int
    var minutes: Int
    var cosmeticID: String?
}

extension RewardEngine {
    static func chestContents(kind: ChestKind, correctInSession: Int, minutesPerCorrect: Int) -> ChestReward {
        // Play-minutes come from ONE place only: the per-batch grant during play
        // (every N correct → M minutes). Session chests (wood/gold) therefore add
        // NO bonus minutes — only a small flat ⭐ bonus + cosmetics. (magic /
        // legendary are non-session chests like the daily chest, so they grant
        // their own minutes/stars outright.)
        switch kind {
        case .wood:
            return ChestReward(stars: 0, gems: 0, minutes: 0, cosmeticID: nil)
        case .gold:
            return ChestReward(stars: 3, gems: 0, minutes: 0, cosmeticID: nil)
        case .magic:
            return ChestReward(stars: 10, gems: 0, minutes: 5, cosmeticID: nil)
        case .legendary:
            return ChestReward(stars: 50, gems: 0, minutes: 15, cosmeticID: "legendary_aura")
        }
    }

    /// 15% chance of upgrading a wood chest to gold at end of session.
    static func endOfSessionChestKind(correctInSession: Int, total: Int) -> ChestKind {
        if correctInSession == total && Double.random(in: 0...1) < 0.5 {
            return .gold  // perfect session: 50% gold
        }
        return Double.random(in: 0...1) < 0.15 ? .gold : .wood
    }
}
