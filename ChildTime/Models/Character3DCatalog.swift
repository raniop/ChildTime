import Foundation

/// One pickable 3D character. `id` matches the bundled `<id>.scn` model
/// (e.g. "ty" → "ty.scn"). Price is for the upcoming paid-character phase;
/// 0 means free for now.
struct Character3D: Identifiable, Hashable {
    let id: String
    let name: String
    var price: Int = 0
    var scn: String { id + ".scn" }
}

enum Character3DCatalog {
    /// Roster grows over time (downloaded from Mixamo via tools/mixamo_fetch.py).
    /// Order = display order in the picker.
    static let all: [Character3D] = [
        Character3D(id: "hero3",  name: "מַאיָה"),
        Character3D(id: "hero6",  name: "נוֹעָה"),
        Character3D(id: "hero5",  name: "רוֹנִי"),
        Character3D(id: "mousey", name: "מַאוּסִי"),
        Character3D(id: "kaya",   name: "קַאיָה"),
        Character3D(id: "sophie", name: "סוֹפִי"),
        Character3D(id: "ninja",  name: "נִינְגָ'ה"),
        Character3D(id: "knight", name: "אַבִּיר"),
        Character3D(id: "pirate", name: "שׁוֹדֵד יָם"),
    ]

    static let defaultID = "hero3"

    static func find(_ id: String?) -> Character3D {
        all.first { $0.id == id } ?? all[0]
    }
}
