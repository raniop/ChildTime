import Foundation
import SwiftUI

/// One wedge on the lucky wheel.
struct WheelPrize: Identifiable, Equatable {
    enum Kind: Equatable {
        case stars(Int)
        case diamonds(Int)           // 💎 spendable shop wallet
        case minutes(Int)
        case rareItem(String)        // cosmetic item ID
        case funMission(String)      // family chore — gentle "loser" wedge
    }

    let id = UUID()
    let kind: Kind
    let label: String
    let emoji: String
    let color: Color

    var isPenalty: Bool {
        if case .funMission = kind { return true }
        return false
    }
}

/// Stateless catalog of possible wedges. The wheel picks 8 of these per
/// spin so kids see fresh combinations.
enum LuckyWheelCatalog {
    /// Bias toward upbeat wedges (~75% good vs 25% chore).
    static let prizes: [WheelPrize] = [
        // Good (10 wedges)
        WheelPrize(kind: .stars(15),         label: "15 כּוֹכָבִים",     emoji: "⭐", color: Color(hex: "9B5DE5")),
        WheelPrize(kind: .stars(45),         label: "45 כּוֹכָבִים",     emoji: "⭐", color: Color(hex: "5E60CE")),
        WheelPrize(kind: .stars(90),         label: "90 כּוֹכָבִים!",   emoji: "🌟", color: Color(hex: "F15BB5")),
        WheelPrize(kind: .stars(30),         label: "30 כּוֹכָבִים",     emoji: "⭐", color: Color(hex: "FFD166")),
        WheelPrize(kind: .minutes(5),        label: "+5 דַּק' מִשְׂחָק",   emoji: "⏰", color: Color(hex: "06D6A0")),
        WheelPrize(kind: .minutes(10),       label: "+10 דַּק' מִשְׂחָק",  emoji: "⏱", color: Color(hex: "118AB2")),
        WheelPrize(kind: .stars(60),         label: "+60 כּוֹכָבִים",   emoji: "🌟", color: Color(hex: "FFB84D")),
        WheelPrize(kind: .stars(150),        label: "+150 כּוֹכָבִים!", emoji: "🌟", color: Color(hex: "F59E0B")),
        WheelPrize(kind: .rareItem("hat_crown"),
                                              label: "כֶּתֶר זָהָב!",     emoji: "👑", color: Color(hex: "FFD166")),
        WheelPrize(kind: .rareItem("hat_unicorn"),
                                              label: "קֶרֶן חַד-קֶרֶן!", emoji: "🦄", color: Color(hex: "9B5DE5")),

        // 💎 Diamonds — the spendable shop wallet (kids buy characters with these).
        WheelPrize(kind: .diamonds(10),      label: "10 יַהֲלוֹמִים",   emoji: "💎", color: Color(hex: "4CC9F0")),
        WheelPrize(kind: .diamonds(25),      label: "25 יַהֲלוֹמִים",   emoji: "💎", color: Color(hex: "4895EF")),
        WheelPrize(kind: .diamonds(50),      label: "50 יַהֲלוֹמִים!",  emoji: "💎", color: Color(hex: "3A86FF")),

        // Fun missions (4 wedges) — gentle "you lost" alternatives.
        // Phrased as friendly nudges, never punishment.
        WheelPrize(kind: .funMission("לְסַדֵּר אֶת הַחֶדֶר 🧸"),
                                              label: "מְסַדְּרִים חֶדֶר",   emoji: "🧹", color: Color(hex: "FF6B6B")),
        WheelPrize(kind: .funMission("לְהָכִין תִּיק לַגַּן/בֵּית סֵפֶר 🎒"),
                                              label: "מְכִינִים תִּיק",   emoji: "🎒", color: Color(hex: "FF6B9D")),
        WheelPrize(kind: .funMission("לַעֲזוֹר לַעֲרוֹךְ שׁוּלְחָן 🍽"),
                                              label: "עוֹרְכִים שׁוּלְחָן", emoji: "🍽",  color: Color(hex: "FFB84D")),
        WheelPrize(kind: .funMission("לְקַפֵּל גַּרְבַּיִם קְטַנִּים 🧦"),
                                              label: "מְקַפְּלִים גַּרְבַּיִם", emoji: "🧦", color: Color(hex: "5B9BFF")),
    ]

    /// 8-wedge layout for one spin. Every wedge is a win — no "loss"/chore
    /// wedges, so the wheel is always a happy moment.
    static func wedgesForSpin(excludeMinutes: Bool = false) -> [WheelPrize] {
        var pool = prizes.filter { !$0.isPenalty }
        // When there's no room left for play-minutes (daily cap full AND the
        // tomorrow-bank is full), don't offer minute prizes at all.
        if excludeMinutes {
            pool = pool.filter { if case .minutes = $0.kind { return false }; return true }
        }
        return Array(pool.shuffled().prefix(8))
    }
}

// MARK: - Application of the chosen prize

extension WheelPrize {
    /// Apply the prize to the active profile / global progress.
    /// Returns a user-facing description of what just happened.
    @MainActor
    func apply() -> String {
        let progress = ProgressStore.shared
        let cosmetics = CosmeticStore.shared
        switch kind {
        case .stars(let n):
            progress.applyChestReward(ChestReward(stars: n, diamonds: 0, minutes: 0, cosmeticID: nil))
            return "+\(n) כּוֹכָבִים נוֹסְפוּ!"
        case .diamonds(let n):
            progress.applyChestReward(ChestReward(stars: 0, diamonds: n, minutes: 0, cosmeticID: nil))
            return "+\(n) יַהֲלוֹמִים נוֹסְפוּ! 💎"
        case .minutes(let n):
            let g = progress.grantBonusMinutes(n)
            if g.addedToday > 0 && g.bankedForTomorrow > 0 {
                return "+\(g.addedToday) דַּקּוֹת עַכְשָׁיו · עוֹד \(g.bankedForTomorrow) נִשְׁמְרוּ לְמָחָר 🎁"
            } else if g.bankedForTomorrow > 0 {
                return "הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי! \(g.bankedForTomorrow) דַּקּוֹת נִשְׁמְרוּ לְמָחָר 🎁 (\(progress.carryOverMinutes)/\(ProgressStore.maxCarryOverMinutes))"
            } else {
                return "+\(g.addedToday) דַּקּוֹת נוֹסְפוּ לִזְמַן הַמִּשְׂחָק"
            }
        case .rareItem(let id):
            if let item = CosmeticCatalog.item(id), !cosmetics.owns(item) {
                cosmetics.unlockFree(item)
                return "פָּתַחְתָּ פְּרִיט נָדִיר: \(item.name)!"
            }
            // Already owned — fall back to a nice diamond consolation the kid
            // can actually spend (not just rank), so it never feels like a loss.
            progress.applyChestReward(ChestReward(stars: 45, diamonds: 15, minutes: 0, cosmeticID: nil))
            return "כְּבָר יֵשׁ לְךָ אֶת הַפְּרִיט הַזֶּה — קַבֵּל 15 יַהֲלוֹמִים בִּמְקוֹם 💎"
        case .funMission(let task):
            return "משימה: \(task)"
        }
    }
}
