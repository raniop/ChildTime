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

    /// Higher-priced characters are smarter helpers. The help is always a HINT or
    /// explanation — never the answer.
    enum HelpLevel { case none, encourage, hint, explain }
    var helpLevel: HelpLevel {
        switch priceStars {
        case 0...200:    return .encourage
        case 201...900:  return .hint
        default:         return .explain
        }
    }
}

enum Character3DCatalog {
    /// Roster grows over time (downloaded from Mixamo via tools/mixamo_fetch.py).
    /// Order = display order in the picker.
    static let all: [Character3D] = [
        // 🆓 Free starters (owned from day one) — encourage-level help.
        Character3D(id: "fox",      name: "שׁוּעָל",    priceStars: 0,    imageAsset: "fox"),
        Character3D(id: "bunny",    name: "אַרְנָב",     priceStars: 0,    imageAsset: "bunny"),
        Character3D(id: "penguin",  name: "פִּינְגְּוִין", priceStars: 0,    imageAsset: "penguin"),
        Character3D(id: "bear",     name: "דֹּב",       priceStars: 0,    imageAsset: "bear"),

        // ⭐ Common (~120–220) — encourage-level help.
        Character3D(id: "monkey",   name: "קוֹף",       priceStars: 140,  imageAsset: "monkey"),
        Character3D(id: "tiger",    name: "נָמֵר",      priceStars: 180,  imageAsset: "tiger"),
        Character3D(id: "koala",    name: "קוֹאָלָה",    priceStars: 160,  imageAsset: "koala"),
        Character3D(id: "hamster",  name: "אוֹגֵר",      priceStars: 120,  imageAsset: "hamster"),
        Character3D(id: "squirrel", name: "סְנָאִי",      priceStars: 120,  imageAsset: "squirrel"),
        Character3D(id: "otter",    name: "לוּטְרָה",     priceStars: 150,  imageAsset: "otter"),
        Character3D(id: "turtle",   name: "צָב",        priceStars: 130,  imageAsset: "turtle"),
        Character3D(id: "crocodile", name: "תַּנִּין",     priceStars: 200,  imageAsset: "crocodile"),
        Character3D(id: "elephant", name: "פִּיל",       priceStars: 190,  imageAsset: "elephant"),
        Character3D(id: "zebra",    name: "זֶבְּרָה",     priceStars: 170,  imageAsset: "zebra"),
        Character3D(id: "ibex",     name: "יָעֵל",       priceStars: 160,  imageAsset: "ibex"),
        Character3D(id: "gazelle",  name: "צְבִי",       priceStars: 160,  imageAsset: "gazelle"),
        Character3D(id: "fennec",   name: "פֶנֶק",       priceStars: 140,  imageAsset: "fennec"),
        Character3D(id: "hedgehog", name: "קִיפּוֹד",     priceStars: 130,  imageAsset: "hedgehog"),

        // 💎 Rare (~550–700) — hint-level help.
        Character3D(id: "lion",     name: "אַרְיֵה",     priceStars: 650,  imageAsset: "lion"),
        Character3D(id: "panda",    name: "פַּנְדָּה",     priceStars: 600,  imageAsset: "panda"),
        Character3D(id: "octopus",  name: "תַּמְנוּן",     priceStars: 550,  imageAsset: "octopus"),

        // 👑 Legendary (~1500–1800) — explain-level help.
        Character3D(id: "unicorn",  name: "חַד-קֶרֶן",  priceStars: 1800, imageAsset: "unicorn"),
        Character3D(id: "dragon",   name: "דְּרָקוֹן",   priceStars: 1500, imageAsset: "dragon"),
    ]

    static let defaultID = "fox"

    static func find(_ id: String?) -> Character3D {
        if let id, let match = all.first(where: { $0.id == id }) { return match }
        // nil / unknown → the default character (not just the first listed).
        return all.first { $0.id == defaultID } ?? all[0]
    }
}
