import Foundation

/// Centralized rules: how many stars / diamonds / minutes for each event.
enum RewardEngine {
    /// How many times the base star rewards are multiplied. 3× makes earning
    /// feel more generous without touching world-unlock costs or shop prices.
    static let starMultiplier = 3

    /// The streak (combo) multiplier — the longer the run of correct answers, the
    /// bigger every reward. Escalates well past 5 to make a long streak feel worth
    /// protecting. Tiers: 1× · ×2 (3) · ×3 (5) · ×4 (10) · ×5 (15+).
    static func comboMultiplier(streak: Int) -> Int {
        switch streak {
        case ..<3:    return 1
        case 3..<5:   return 2
        case 5..<10:  return 3
        case 10..<15: return 4
        default:      return 5
        }
    }

    /// Short label for the current combo tier (shown in-game while on a streak).
    static func comboLabel(streak: Int) -> String? {
        switch streak {
        case ..<3:    return nil
        case 3..<5:   return "קוֹמְבּוֹ ×2 🔥"
        case 5..<10:  return "קוֹמְבּוֹ ×3 🔥🔥"
        case 10..<15: return "קוֹמְבּוֹ ×4 ⚡"
        default:      return "עַל הָאֵשׁ! ×5 👑"
        }
    }

    /// Stars granted for a correct answer. Mystery/super are flat bonuses; a
    /// normal answer scales with the combo multiplier so long streaks pay off.
    static func starsForCorrect(combo: Int, isSuperQuestion: Bool, isMysteryPortal: Bool) -> Int {
        if isMysteryPortal { return 3 * starMultiplier }
        if isSuperQuestion { return 5 * starMultiplier }
        return comboMultiplier(streak: combo) * starMultiplier
    }

    /// 💎 diamonds for a correct answer — the SPENDABLE shop wallet. Earned at a
    /// deliberately slower pace than ⭐ stars (roughly ~1 per answer) so the shop
    /// keeps its value: a long streak / super / mystery still pays a little more.
    static func diamondsForCorrect(combo: Int, isSuperQuestion: Bool, isMysteryPortal: Bool) -> Int {
        if isMysteryPortal { return 3 }
        if isSuperQuestion { return 5 }
        switch combo {
        case ..<5:    return 1
        case 5..<10:  return 2
        default:      return 3
        }
    }

    /// Shop prices are authored in ⭐ (legacy `priceStars` / `price`). Diamonds
    /// accrue ~⅕ as fast as stars used to, so a diamond price is the star price
    /// scaled down by this divisor — keeping time-to-buy roughly familiar while
    /// re-denominating the shop in the new, slower currency. Tunable in one spot.
    static let diamondPriceDivisor = 5

    /// Convert a legacy ⭐ price into its 💎 diamond price (never below 1).
    static func diamondPrice(forStarPrice stars: Int) -> Int {
        guard stars > 0 else { return 0 }
        return max(1, Int((Double(stars) / Double(diamondPriceDivisor)).rounded()))
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

    /// THE single play-minutes rule for everyone: every N correct answers
    /// grants M minutes. Fixed (not parent-configurable) so the number shown
    /// in-game, on the reward screen, and banked on home is always the same.
    static let answersPerReward = 10
    static let minutesPerReward = 4

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
        case .wood: return "קוּפְסַת עֵץ"
        case .gold: return "קוּפְסַת זָהָב"
        case .magic: return "קוּפְסַת קֶסֶם"
        case .legendary: return "קוּפְסַת אַגָּדָה"
        }
    }
}

struct ChestReward: Equatable {
    var stars: Int      // ⭐ leaderboard rank
    var diamonds: Int   // 💎 spendable shop wallet
    var minutes: Int
    var cosmeticID: String?
}

extension RewardEngine {
    static func chestContents(kind: ChestKind, correctInSession: Int, minutesPerCorrect: Int) -> ChestReward {
        // Most play-minutes come from the per-batch grant during play (every N
        // correct → M minutes). On top of that, the end-of-session chest hands out
        // a small bonus of play-minutes too, so opening it feels rewarding — the
        // chest visibly adds time, not only stars. The bonus goes through
        // grantBonusMinutes, which respects the daily cap and banks any overflow
        // for tomorrow, so it can never push past the parent's limit.
        switch kind {
        // Star bonuses are ×starMultiplier to match the in-game earn rate.
        // Each chest also drips 💎 diamonds (the spendable wallet), scaled
        // down from its ⭐ figure so a gift fills both pockets at once.
        // Minutes climb with the chest tier: wood 1 < gold 3 < magic 5 < legendary 15.
        case .wood:
            return ChestReward(stars: 2 * starMultiplier, diamonds: 2, minutes: 1, cosmeticID: nil)
        case .gold:
            return ChestReward(stars: 3 * starMultiplier, diamonds: 3, minutes: 3, cosmeticID: nil)
        case .magic:
            return ChestReward(stars: 10 * starMultiplier, diamonds: 8, minutes: 5, cosmeticID: nil)
        case .legendary:
            return ChestReward(stars: 50 * starMultiplier, diamonds: 35, minutes: 15, cosmeticID: "legendary_aura")
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
