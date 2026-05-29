import Foundation
import SwiftUI

/// Wearable categories. Each profile can equip at most one item per category.
enum CosmeticCategory: String, Codable, CaseIterable, Identifiable {
    case hat
    case glasses
    case shirt
    case pants
    case shoes
    case accessory
    case backpack
    case vehicle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hat:       return "כּוֹבָעִים"
        case .glasses:   return "מִשְׁקָפַיִם"
        case .shirt:     return "חֻלְצוֹת"
        case .pants:     return "מִכְנָסַיִם"
        case .shoes:     return "נַעֲלַיִם"
        case .accessory: return "אַקְסֶסוֹרִיז"
        case .backpack:  return "תִּיקִים"
        case .vehicle:   return "גַּלְגַּלִּים"
        }
    }

    var icon: String {
        switch self {
        case .hat:       return "🎩"
        case .glasses:   return "👓"
        case .shirt:     return "👕"
        case .pants:     return "👖"
        case .shoes:     return "👟"
        case .accessory: return "💎"
        case .backpack:  return "🎒"
        case .vehicle:   return "🛹"
        }
    }

    /// Sort order in the shop sidebar.
    var sortOrder: Int {
        switch self {
        case .hat:       return 0
        case .glasses:   return 1
        case .shirt:     return 2
        case .pants:     return 3
        case .shoes:     return 4
        case .accessory: return 5
        case .backpack:  return 6
        case .vehicle:   return 7
        }
    }
}

/// Rarity tier — drives card border color, price floor, and shop sort priority.
enum CosmeticRarity: String, Codable, CaseIterable, Comparable {
    case common
    case rare
    case epic
    case legendary

    static func < (lhs: CosmeticRarity, rhs: CosmeticRarity) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .common:    return 0
        case .rare:      return 1
        case .epic:      return 2
        case .legendary: return 3
        }
    }

    var label: String {
        switch self {
        case .common:    return "רָגִיל"
        case .rare:      return "נָדִיר"
        case .epic:      return "אַגָּדִי"
        case .legendary: return "נָדִיר בִּמְיֻחָד"
        }
    }

    var color: Color {
        switch self {
        case .common:    return Color(hex: "9CA3AF")
        case .rare:      return Color(hex: "5B9BFF")
        case .epic:      return Color(hex: "9B5DE5")
        case .legendary: return Color(hex: "F59E0B")
        }
    }

    /// Gradient used for the rarity badge.
    var gradient: LinearGradient {
        switch self {
        case .common:
            return LinearGradient(colors: [Color(hex: "9CA3AF"), Color(hex: "6B7280")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rare:
            return LinearGradient(colors: [Color(hex: "5B9BFF"), Color(hex: "118AB2")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .epic:
            return LinearGradient(colors: [Color(hex: "9B5DE5"), Color(hex: "5E60CE")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .legendary:
            return LinearGradient(colors: [Color(hex: "FFD166"), Color(hex: "F59E0B")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// A wearable cosmetic. Stable string `id` so renames / refactors don't
/// break a kid's saved inventory.
struct CosmeticItem: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let category: CosmeticCategory
    let name: String
    let emoji: String         // rendering token; future: swap to bundled art
    let rarity: CosmeticRarity
    let price: Int            // in gems
    /// Optional bundled art (PNG/SVG in Assets) — preferred when present.
    var assetName: String? = nil
    /// Optional SF Symbol — a crisp "worn" look for face/head items (glasses).
    var symbol: String? = nil

    /// How this item should be drawn on the avatar, in priority order:
    /// real art → SF Symbol → themed emoji.
    enum Render: Equatable {
        case image(String)
        case symbol(String)
        case emoji(String)
    }

    var render: Render {
        if let assetName, !assetName.isEmpty { return .image(assetName) }
        if let sym = symbol ?? Self.defaultSymbols[id] { return .symbol(sym) }
        return .emoji(emoji)
    }

    /// Face/head items where a clean SF Symbol reads as truly "worn" better
    /// than a floating emoji. Themed shapes (heart/star glasses) stay emoji.
    static let defaultSymbols: [String: String] = [
        "glasses_round": "eyeglasses",
        "glasses_shade": "sunglasses.fill",
        "glasses_3d":    "eyeglasses",
        "glasses_vr":    "sunglasses.fill"
    ]
}
