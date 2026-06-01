import Foundation

/// One pickable 3D character. `id` matches the bundled `<id>.scn` model
/// (e.g. "ty" → "ty.scn"). Price is for the upcoming paid-character phase;
/// 0 means free for now.
struct Character3D: Identifiable, Hashable {
    let id: String
    let name: String
    var price: Int = 0
    /// When set, this is a flat 2D character (bundled `<imageAsset>.png`) instead
    /// of a 3D `.scn` model — rendered as an image everywhere.
    var imageAsset: String? = nil

    var scn: String { id + ".scn" }
    var is2D: Bool { imageAsset != nil }
}

enum Character3DCatalog {
    /// Roster grows over time (downloaded from Mixamo via tools/mixamo_fetch.py).
    /// Order = display order in the picker.
    static let all: [Character3D] = [
        // Cute 2D animal characters.
        Character3D(id: "fox",      name: "שׁוּעָל",    imageAsset: "fox"),
        Character3D(id: "unicorn",  name: "חַד-קֶרֶן",  imageAsset: "unicorn"),
        Character3D(id: "lion",     name: "אַרְיֵה",     imageAsset: "lion"),
        Character3D(id: "koala",    name: "קוֹאָלָה",    imageAsset: "koala"),
        Character3D(id: "dragon",   name: "דְּרָקוֹן",   imageAsset: "dragon"),
        Character3D(id: "bear",     name: "דֹּב",       imageAsset: "bear"),
        Character3D(id: "tiger",    name: "נָמֵר",      imageAsset: "tiger"),
        Character3D(id: "bunny",    name: "אַרְנָב",     imageAsset: "bunny"),
        Character3D(id: "monkey",   name: "קוֹף",       imageAsset: "monkey"),
        Character3D(id: "penguin",  name: "פִּינְגְּוִין", imageAsset: "penguin"),
        Character3D(id: "elephant", name: "פִּיל",       imageAsset: "elephant"),
        Character3D(id: "octopus",  name: "תַּמְנוּן",     imageAsset: "octopus"),
        Character3D(id: "panda",    name: "פַּנְדָּה",     imageAsset: "panda"),
        Character3D(id: "otter",    name: "לוּטְרָה",     imageAsset: "otter"),
        Character3D(id: "turtle",   name: "צָב",        imageAsset: "turtle"),
        Character3D(id: "fennec",   name: "פֶנֶק",       imageAsset: "fennec"),
        Character3D(id: "ibex",     name: "יָעֵל",       imageAsset: "ibex"),
        Character3D(id: "gazelle",  name: "צְבִי",       imageAsset: "gazelle"),
        Character3D(id: "zebra",    name: "זֶבְּרָה",     imageAsset: "zebra"),
        Character3D(id: "hedgehog", name: "קִיפּוֹד",     imageAsset: "hedgehog"),
        Character3D(id: "hamster",  name: "אוֹגֵר",      imageAsset: "hamster"),
        Character3D(id: "squirrel", name: "סְנָאִי",      imageAsset: "squirrel"),
        Character3D(id: "crocodile", name: "תַּנִּין",     imageAsset: "crocodile"),
        Character3D(id: "pig",      name: "חֲזַרְזִיר",    imageAsset: "pig"),
    ]

    static let defaultID = "fox"

    static func find(_ id: String?) -> Character3D {
        if let id, let match = all.first(where: { $0.id == id }) { return match }
        // nil / unknown → the default character (not just the first listed).
        return all.first { $0.id == defaultID } ?? all[0]
    }
}
