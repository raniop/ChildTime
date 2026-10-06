import SwiftUI
import Combine

/// 🏆 World tiers — the look and the "where next" shared by the map, the
/// chooser, the boss and the parent's page. The numbers live in
/// `ProgressStore` (stage = tier × 10 + room); this file only says how a tier
/// reads and which world to suggest.
enum WorldTiers {
    /// Card/badge colours: bronze, silver, gold, champion.
    static func color(tier: Int) -> Color {
        switch tier {
        case 0:  return Color(hex: "D08A4E")
        case 1:  return Color(hex: "DDE5F2")
        case 2:  return Color(hex: "FFD25A")
        default: return Color(hex: "38D18C")
        }
    }

    /// The kid's badge for a tier (the mockup: every played world wears one).
    static func kidBadge(tier: Int, girl: Bool) -> String? {
        switch tier {
        case 0:  return tr("⭐ דַּרְגָּה 1")
        case 1:  return tr("⭐⭐ דַּרְגָּה 2")
        case 2:  return tr("⭐⭐⭐ דַּרְגָּה 3")
        default: return girl ? tr("👑 אַלּוּפָה") : tr("👑 אַלּוּף")
        }
    }

    /// The crowns line under a world's name once a tier is done.
    static func crownsLine(tier: Int) -> String? {
        switch tier {
        case 1:  return tr("👑 דַּרְגָּה 1 הֻשְׁלְמָה")
        case 2:  return tr("👑👑 2 דַּרְגּוֹת הֻשְׁלְמוּ")
        case 3...: return tr("👑👑👑 כָּל הַדַּרְגּוֹת הֻשְׁלְמוּ")
        default: return nil
        }
    }

    /// The parent's line for a world: tier, then room or "boss waiting".
    static func parentLabel(tier: Int, room: Int) -> String {
        let where_ = room >= 9 ? tr("הַבּוֹס מְחַכֶּה") : tr("חֶדֶר \(room + 1)/10")
        switch tier {
        case 0:  return tr("⭐ אָרָד") + " · " + where_
        case 1:  return tr("⭐⭐ כֶּסֶף") + " · " + where_
        case 2:  return tr("⭐⭐⭐ זָהָב") + " · " + where_
        default: return tr("👑 הֻשְׁלַם")
        }
    }

    /// An unvisited world this child can open right now: Tofy+ opens every base
    /// world, a pack opens only when it was bought for this child.
    @MainActor
    static func suggestedNewWorld(excluding id: String) -> World? {
        guard let profile = ProfileStore.shared.active else { return nil }
        let progress = ProgressStore.shared
        let premium = SubscriptionManager.shared.isPremium
        let playable = profile.playableTopics
        return Worlds.all.first { w in
            guard w.id != id, !w.isBonusWorld, playable.contains(w.topic),
                  !progress.hasVisited(w.id) else { return false }
            if let item = w.topic.pack ?? WorldPasses.pass(for: w.topic), PackAccess.has(profile, item) { return true }
            return premium && w.topic.pack == nil
        }
    }
}

/// Opens a world from anywhere inside one (the "new world" button after a
/// boss). The map closes whatever is on top and opens the pending world.
@MainActor
final class WorldRouter: ObservableObject {
    static let shared = WorldRouter()
    @Published var pending: World?
    private init() {}
}
