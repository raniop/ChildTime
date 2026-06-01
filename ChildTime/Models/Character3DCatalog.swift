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
        case 0:           self = .free
        case 1...300:     self = .common
        case 301...650:   self = .rare
        case 651...1100:  self = .epic
        case 1101...2500: self = .legendary
        default:          self = .mythic
        }
    }

    var label: String {
        switch self {
        case .free:      return "חִינָּם"
        case .common:    return "רָגִיל"
        case .rare:      return "נָדִיר"
        case .epic:      return "מְיוּחָד"
        case .legendary: return "אַגָּדִי"
        case .mythic:    return "מִיתִי"
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
    static let all: [Character3D] = [
        // 🆓 Free (owned from day one) — encourage-level help.
        Character3D(id: "fox",      name: "שׁוּעָל",    priceStars: 0,    imageAsset: "fox"),
        Character3D(id: "bunny",    name: "אַרְנָב",     priceStars: 0,    imageAsset: "bunny"),
        Character3D(id: "penguin",  name: "פִּינְגְּוִין", priceStars: 0,    imageAsset: "penguin"),
        Character3D(id: "bear",     name: "דֹּב",       priceStars: 0,    imageAsset: "bear"),

        // 🟢 Common (≤300) — encourage-level help.
        Character3D(id: "hamster",  name: "אוֹגֵר",      priceStars: 120,  imageAsset: "hamster"),
        Character3D(id: "squirrel", name: "סְנָאִי",      priceStars: 120,  imageAsset: "squirrel"),
        Character3D(id: "turtle",   name: "צָב",        priceStars: 140,  imageAsset: "turtle"),
        Character3D(id: "hedgehog", name: "קִיפּוֹד",     priceStars: 140,  imageAsset: "hedgehog"),
        Character3D(id: "fennec",   name: "פֶנֶק",       priceStars: 160,  imageAsset: "fennec"),
        Character3D(id: "monkey",   name: "קוֹף",       priceStars: 170,  imageAsset: "monkey"),
        Character3D(id: "gazelle",  name: "צְבִי",       priceStars: 180,  imageAsset: "gazelle"),
        Character3D(id: "ibex",     name: "יָעֵל",       priceStars: 190,  imageAsset: "ibex"),
        Character3D(id: "koala",    name: "קוֹאָלָה",    priceStars: 220,  imageAsset: "koala"),
        Character3D(id: "otter",    name: "לוּטְרָה",     priceStars: 240,  imageAsset: "otter"),
        Character3D(id: "pig",      name: "חֲזַרְזִיר",    priceStars: 260,  imageAsset: "pig"),

        // 🔵 Rare (301–650) — hint-level help.
        Character3D(id: "tiger",    name: "נָמֵר",      priceStars: 380,  imageAsset: "tiger"),
        Character3D(id: "zebra",    name: "זֶבְּרָה",     priceStars: 420,  imageAsset: "zebra"),
        Character3D(id: "crocodile", name: "תַּנִּין",     priceStars: 460,  imageAsset: "crocodile"),
        Character3D(id: "elephant", name: "פִּיל",       priceStars: 520,  imageAsset: "elephant"),

        // 🟣 Epic (651–1100) — hint-level help.
        Character3D(id: "panda",    name: "פַּנְדָּה",     priceStars: 750,  imageAsset: "panda"),
        Character3D(id: "octopus",  name: "תַּמְנוּן",     priceStars: 850,  imageAsset: "octopus"),
        Character3D(id: "lion",     name: "אַרְיֵה",     priceStars: 1000, imageAsset: "lion"),

        // 👑 Legendary (1101–2500) — explain-level help.
        Character3D(id: "dragon",   name: "דְּרָקוֹן",   priceStars: 1500, imageAsset: "dragon"),
        Character3D(id: "unicorn",  name: "חַד-קֶרֶן",  priceStars: 2000, imageAsset: "unicorn"),

        // 🩷 Mythic (2501+) — explain-level help. (Premium tier; more coming.)
    ]

    static let defaultID = "fox"

    static func find(_ id: String?) -> Character3D {
        if let id, let match = all.first(where: { $0.id == id }) { return match }
        // nil / unknown → the default character (not just the first listed).
        return all.first { $0.id == defaultID } ?? all[0]
    }
}
