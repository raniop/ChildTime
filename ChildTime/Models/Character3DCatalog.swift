import Foundation

/// One pickable 3D character. `id` matches the bundled `<id>.scn` model
/// (e.g. "ty" → "ty.scn"). Price is for the upcoming paid-character phase;
/// 0 means free for now.
struct Character3D: Identifiable, Hashable {
    let id: String
    let name: String
    /// Cost in earned stars. 0 = free (owned from the start).
    var priceStars: Int = 0
    /// When set, this is a flat 2D character (bundled `<imageAsset>.png`) instead
    /// of a 3D `.scn` model — rendered as an image everywhere.
    var imageAsset: String? = nil

    var scn: String { id + ".scn" }
    var is2D: Bool { imageAsset != nil }
    var isFree: Bool { priceStars == 0 }

    /// 💎 cost in the shop — the legacy ⭐ price re-denominated into diamonds
    /// (the spendable currency). Catalog stays authored in `priceStars`.
    var priceDiamonds: Int { RewardEngine.diamondPrice(forStarPrice: priceStars) }

    /// Rarity tier, derived from price so adding a character only needs a price.
    var tier: CharacterTier { CharacterTier(priceStars: priceStars) }

    /// Higher tiers are smarter helpers. The help is always a HINT or
    /// explanation — never the answer.
    enum HelpLevel { case encourage, hint, explain }
    var helpLevel: HelpLevel { tier.help }
}

/// Collectible rarity, like a real game. Drives the price band, the card color,
/// and how smart a helper the character is. Derived from a character's price.
enum CharacterTier: Int, CaseIterable {
    case free, common, rare, epic, legendary, mythic

    init(priceStars p: Int) {
        switch p {
        case 0:              self = .free
        case 1...2400:       self = .common
        case 2401...5200:    self = .rare
        case 5201...8800:    self = .epic
        case 8801...20000:   self = .legendary
        default:             self = .mythic
        }
    }

    var label: String {
        switch self {
        case .free:      return tr("חִינָּם")
        case .common:    return tr("רָגִיל")
        case .rare:      return tr("נָדִיר")
        case .epic:      return tr("מְיוּחָד")
        case .legendary: return tr("אַגָּדִי")
        case .mythic:    return tr("מִיתִי")
        }
    }

    var help: Character3D.HelpLevel {
        switch self {
        case .free, .common:      return .encourage
        case .rare, .epic:        return .hint
        case .legendary, .mythic: return .explain
        }
    }

    /// Card border / badge color — a rarity ladder (grey→green→blue→purple→gold→pink).
    /// Stored as RGB so the model layer stays free of SwiftUI.
    var rgb: (r: Double, g: Double, b: Double) {
        switch self {
        case .free:      return (0.62, 0.66, 0.72)   // slate grey
        case .common:    return (0.30, 0.78, 0.45)   // green
        case .rare:      return (0.25, 0.60, 0.98)   // blue
        case .epic:      return (0.68, 0.40, 0.95)   // purple
        case .legendary: return (1.00, 0.78, 0.18)   // gold
        case .mythic:    return (0.98, 0.35, 0.62)   // pink
        }
    }
}

enum Character3DCatalog {
    /// Roster grows over time (downloaded from Mixamo via tools/mixamo_fetch.py).
    /// Order = display order in the picker.
    static var all: [Character3D] { LocalizedCache.value("Character3DCatalog.all") { [
        // 🆓 Free (owned from day one) — encourage-level help.
        Character3D(id: "fox",      name: tr("שׁוּעָל"),    priceStars: 0,    imageAsset: "fox"),
        Character3D(id: "bunny",    name: tr("אַרְנָב"),     priceStars: 0,    imageAsset: "bunny"),
        Character3D(id: "penguin",  name: tr("פִּינְגְּוִין"), priceStars: 0,    imageAsset: "penguin"),
        Character3D(id: "bear",     name: tr("דּוֹב"),       priceStars: 0,    imageAsset: "bear"),

        // 🟢 Common (≤2400) — encourage-level help. (incl. alternate-art variants)
        // Prices are intentionally high — a character should be days/weeks of
        // learning, not an afternoon's worth of stars.
        Character3D(id: "hamster",     name: tr("אוֹגֵר"),     priceStars: 950,  imageAsset: "hamster"),
        Character3D(id: "hamster_b",   name: tr("אוֹגֵר"),     priceStars: 1050, imageAsset: "hamster_b"),
        Character3D(id: "squirrel",    name: tr("סְנָאִי"),     priceStars: 1050, imageAsset: "squirrel"),
        Character3D(id: "squirrel_b",  name: tr("סְנָאִי"),     priceStars: 1100, imageAsset: "squirrel_b"),
        Character3D(id: "turtle",      name: tr("צָב"),       priceStars: 1150, imageAsset: "turtle"),
        Character3D(id: "hedgehog",    name: tr("קִיפּוֹד"),    priceStars: 1200, imageAsset: "hedgehog"),
        Character3D(id: "hedgehog_b",  name: tr("קִיפּוֹד"),    priceStars: 1250, imageAsset: "hedgehog_b"),
        Character3D(id: "fennec",      name: tr("פֶנֶק"),      priceStars: 1300, imageAsset: "fennec"),
        Character3D(id: "monkey",      name: tr("קוֹף"),      priceStars: 1350, imageAsset: "monkey"),
        Character3D(id: "gazelle",     name: tr("צְבִי"),      priceStars: 1450, imageAsset: "gazelle"),
        Character3D(id: "ibex",        name: tr("יָעֵל"),      priceStars: 1550, imageAsset: "ibex"),
        Character3D(id: "pig",         name: tr("חֲזַרְזִיר"),   priceStars: 1600, imageAsset: "pig"),
        Character3D(id: "pig_b",       name: tr("חֲזַרְזִיר"),   priceStars: 1700, imageAsset: "pig_b"),
        Character3D(id: "koala",       name: tr("קוֹאָלָה"),   priceStars: 1800, imageAsset: "koala"),
        Character3D(id: "koala_b",     name: tr("קוֹאָלָה"),   priceStars: 1850, imageAsset: "koala_b"),
        Character3D(id: "koala_c",     name: tr("קוֹאָלָה"),   priceStars: 1950, imageAsset: "koala_c"),
        Character3D(id: "otter",       name: tr("לוּטְרָה"),    priceStars: 2000, imageAsset: "otter"),
        Character3D(id: "fox_b",       name: tr("שׁוּעָל"),    priceStars: 2100, imageAsset: "fox_b"),
        Character3D(id: "crocodile_b", name: tr("תַּנִּין"),    priceStars: 2250, imageAsset: "crocodile_b"),
        Character3D(id: "mouse",       name: tr("עַכְבָּר"),    priceStars: 1500, imageAsset: "mouse"),
        Character3D(id: "chinchilla",  name: tr("צִ'ינְצִ'ילָה"), priceStars: 1650, imageAsset: "chinchilla"),
        Character3D(id: "koala_d",     name: tr("קוֹאָלָה"),   priceStars: 1900, imageAsset: "koala_d"),
        Character3D(id: "koala_e",     name: tr("קוֹאָלָה"),   priceStars: 2300, imageAsset: "koala_e"),

        // 🔵 Rare (2401–5200) — hint-level help.
        Character3D(id: "tiger",       name: tr("נָמֵר"),      priceStars: 2900, imageAsset: "tiger"),
        Character3D(id: "zebra",       name: tr("זֶבְּרָה"),    priceStars: 3200, imageAsset: "zebra"),
        Character3D(id: "zebra_b",     name: tr("זֶבְּרָה"),    priceStars: 3450, imageAsset: "zebra_b"),
        Character3D(id: "crocodile",   name: tr("תַּנִּין"),    priceStars: 3750, imageAsset: "crocodile"),
        Character3D(id: "elephant",    name: tr("פִּיל"),      priceStars: 4200, imageAsset: "elephant"),
        Character3D(id: "elephant_b",  name: tr("פִּיל"),      priceStars: 4500, imageAsset: "elephant_b"),
        Character3D(id: "elephant_c",  name: tr("פִּיל"),      priceStars: 4800, imageAsset: "elephant_c"),
        Character3D(id: "hedgehog_c",  name: tr("קִיפּוֹד"),    priceStars: 2650, imageAsset: "hedgehog_c"),
        Character3D(id: "lemur",       name: tr("לֶמוּר"),     priceStars: 3100, imageAsset: "lemur"),
        Character3D(id: "camel",       name: tr("גָּמָל"),      priceStars: 3600, imageAsset: "camel"),
        Character3D(id: "quokka",      name: tr("קְווֹקָה"),   priceStars: 4300, imageAsset: "quokka"),

        // 🟣 Epic (5201–8800) — hint-level help.
        Character3D(id: "panda",       name: tr("פַּנְדָּה"),    priceStars: 6000, imageAsset: "panda"),
        Character3D(id: "panda_b",     name: tr("פַּנְדָּה"),    priceStars: 6600, imageAsset: "panda_b"),
        Character3D(id: "octopus",     name: tr("תַּמְנוּן"),    priceStars: 7200, imageAsset: "octopus"),
        Character3D(id: "lion",        name: tr("אַרְיֵה"),    priceStars: 8000, imageAsset: "lion"),
        Character3D(id: "octopus_b",   name: tr("תַּמְנוּן"),    priceStars: 7400, imageAsset: "octopus_b"),
        Character3D(id: "lion_b",      name: tr("אַרְיֵה"),    priceStars: 8400, imageAsset: "lion_b"),

        // 👑 Legendary (8801–20000) — explain-level help.
        Character3D(id: "dragon",      name: tr("דְּרָקוֹן"),  priceStars: 12000, imageAsset: "dragon"),
        Character3D(id: "redpanda",    name: tr("פַּנְדָּה אֲדוּמָּה"), priceStars: 13000, imageAsset: "redpanda"),
        Character3D(id: "unicorn",     name: tr("חַד-קֶרֶן"), priceStars: 16000, imageAsset: "unicorn"),

        // 🩷 Mythic (20001+) — explain-level help. (Premium tier; more coming.)
        Character3D(id: "owl",         name: tr("יַנְשׁוּף"),    priceStars: 22000, imageAsset: "owl"),
    ] } }

    static let defaultID = "fox"

    static func find(_ id: String?) -> Character3D {
        if let id, let match = all.first(where: { $0.id == id }) { return match }
        // nil / unknown → the default character (not just the first listed).
        return all.first { $0.id == defaultID } ?? all[0]
    }
}
