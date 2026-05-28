import Foundation
import SwiftUI

/// One wedge on the lucky wheel.
struct WheelPrize: Identifiable, Equatable {
    enum Kind: Equatable {
        case gems(Int)
        case xp(Int)
        case minutes(Int)
        case scoreBoost(Int)
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
        WheelPrize(kind: .gems(5),           label: "5 גבישים",      emoji: "💎", color: Color(hex: "9B5DE5")),
        WheelPrize(kind: .gems(15),          label: "15 גבישים",     emoji: "💎", color: Color(hex: "5E60CE")),
        WheelPrize(kind: .gems(30),          label: "30 גבישים!",   emoji: "💎", color: Color(hex: "F15BB5")),
        WheelPrize(kind: .xp(50),            label: "50 XP",        emoji: "⚡", color: Color(hex: "FFD166")),
        WheelPrize(kind: .minutes(5),        label: "+5 דק' משחק",   emoji: "⏰", color: Color(hex: "06D6A0")),
        WheelPrize(kind: .minutes(10),       label: "+10 דק' משחק",  emoji: "⏱", color: Color(hex: "118AB2")),
        WheelPrize(kind: .scoreBoost(100),   label: "+100 ניקוד",   emoji: "🏆", color: Color(hex: "FFB84D")),
        WheelPrize(kind: .scoreBoost(250),   label: "+250 ניקוד!",  emoji: "🏆", color: Color(hex: "F59E0B")),
        WheelPrize(kind: .rareItem("hat_crown"),
                                              label: "כתר זהב!",     emoji: "👑", color: Color(hex: "FFD166")),
        WheelPrize(kind: .rareItem("shoes_magic"),
                                              label: "נעלי קסם!",    emoji: "✨", color: Color(hex: "9B5DE5")),

        // Fun missions (4 wedges) — gentle "you lost" alternatives.
        // Phrased as friendly nudges, never punishment.
        WheelPrize(kind: .funMission("לסדר את החדר 🧸"),
                                              label: "מסדרים חדר",   emoji: "🧹", color: Color(hex: "FF6B6B")),
        WheelPrize(kind: .funMission("להכין תיק לגן/בית ספר 🎒"),
                                              label: "מכינים תיק",   emoji: "🎒", color: Color(hex: "FF6B9D")),
        WheelPrize(kind: .funMission("לעזור לערוך שולחן 🍽"),
                                              label: "עורכים שולחן", emoji: "🍽",  color: Color(hex: "FFB84D")),
        WheelPrize(kind: .funMission("לקפל גרביים קטנים 🧦"),
                                              label: "מקפלים גרביים", emoji: "🧦", color: Color(hex: "5B9BFF")),
    ]

    /// 8-wedge layout for one spin. Always at least 5 good wedges so the
    /// odds feel friendly.
    static func wedgesForSpin() -> [WheelPrize] {
        let good = prizes.filter { !$0.isPenalty }.shuffled().prefix(6)
        let chores = prizes.filter { $0.isPenalty }.shuffled().prefix(2)
        return Array((good + chores).shuffled())
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
        case .gems(let n):
            progress.applyChestReward(ChestReward(stars: 0, gems: n, minutes: 0, cosmeticID: nil))
            return "+\(n) גבישים נוספו לחשבון"
        case .xp(let n):
            progress.applyChestReward(ChestReward(stars: 0, gems: 0, minutes: 0, cosmeticID: nil))
            progress.addXP(n)
            return "+\(n) XP נוספו"
        case .minutes(let n):
            _ = progress.grantMinutesCapped(n)
            return "+\(n) דקות נוספו לזמן המשחק"
        case .scoreBoost(let n):
            progress.addScore(n)
            return "+\(n) ניקוד מתנה!"
        case .rareItem(let id):
            if let item = CosmeticCatalog.item(id), !cosmetics.owns(item) {
                cosmetics.unlockFree(item)
                return "פתחת פריט נדיר: \(item.name)!"
            }
            // Already owned — fall back to a nice gem consolation.
            progress.applyChestReward(ChestReward(stars: 0, gems: 15, minutes: 0, cosmeticID: nil))
            return "כבר יש לך את הפריט הזה — קבל 15 גבישים במקום"
        case .funMission(let task):
            return "משימה: \(task)"
        }
    }
}
