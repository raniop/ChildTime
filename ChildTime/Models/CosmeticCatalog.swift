import Foundation

/// The master list of every cosmetic that exists in the shop.
///
/// Price tiers (in gems) — common ≤ 15, rare 20–40, epic 50–80, legendary 100+.
/// Stable string IDs (e.g. `hat_crown`) so refactors / renames don't reset
/// kids' inventories.
enum CosmeticCatalog {
    static let all: [CosmeticItem] = [
        // MARK: - Hats (10)
        CosmeticItem(id: "hat_party",     category: .hat, name: "כובע מסיבה",   emoji: "🎉", rarity: .common,    price: 10),
        CosmeticItem(id: "hat_cap",       category: .hat, name: "כובע מצחייה",   emoji: "🧢", rarity: .common,    price: 10),
        CosmeticItem(id: "hat_top",       category: .hat, name: "כובע צילינדר",  emoji: "🎩", rarity: .rare,      price: 25),
        CosmeticItem(id: "hat_graduate",  category: .hat, name: "כובע סטודנט",  emoji: "🎓", rarity: .rare,      price: 30),
        CosmeticItem(id: "hat_cowboy",    category: .hat, name: "כובע בוקרים",   emoji: "🤠", rarity: .epic,      price: 55),
        CosmeticItem(id: "hat_crown",     category: .hat, name: "כתר זהב",      emoji: "👑", rarity: .legendary, price: 120),
        CosmeticItem(id: "hat_helmet",    category: .hat, name: "קסדה",         emoji: "⛑",  rarity: .rare,      price: 25),
        CosmeticItem(id: "hat_unicorn",   category: .hat, name: "קרן חד-קרן",   emoji: "🦄", rarity: .legendary, price: 130),
        CosmeticItem(id: "hat_pirate",    category: .hat, name: "כובע פיראט",   emoji: "🏴‍☠️", rarity: .epic,    price: 60),
        CosmeticItem(id: "hat_santa",     category: .hat, name: "כובע חורף",    emoji: "🎄", rarity: .common,    price: 12),

        // MARK: - Glasses (6)
        CosmeticItem(id: "glasses_round", category: .glasses, name: "משקפיים עגולים",   emoji: "🤓", rarity: .common,    price: 12),
        CosmeticItem(id: "glasses_shade", category: .glasses, name: "משקפי שמש",       emoji: "😎", rarity: .rare,      price: 22),
        CosmeticItem(id: "glasses_3d",    category: .glasses, name: "משקפי 3D",        emoji: "🥽", rarity: .epic,      price: 50),
        CosmeticItem(id: "glasses_vr",    category: .glasses, name: "משקפי VR",        emoji: "🕶",  rarity: .epic,      price: 70),
        CosmeticItem(id: "glasses_heart", category: .glasses, name: "משקפי לב",        emoji: "💖", rarity: .legendary, price: 110),
        CosmeticItem(id: "glasses_star",  category: .glasses, name: "משקפי כוכבים",    emoji: "⭐", rarity: .legendary, price: 115),

        // MARK: - Shirts (8)
        CosmeticItem(id: "shirt_tee",        category: .shirt, name: "חולצת טריקו",  emoji: "👕", rarity: .common, price: 8),
        CosmeticItem(id: "shirt_hoodie",     category: .shirt, name: "קפוצ׳ון",       emoji: "🧥", rarity: .rare,   price: 25),
        CosmeticItem(id: "shirt_kimono",     category: .shirt, name: "קימונו",        emoji: "🥋", rarity: .rare,   price: 30),
        CosmeticItem(id: "shirt_lab",        category: .shirt, name: "חלוק מדען",     emoji: "🥼", rarity: .epic,   price: 55),
        CosmeticItem(id: "shirt_tuxedo",     category: .shirt, name: "סמוקינג",       emoji: "🤵", rarity: .epic,   price: 65),
        CosmeticItem(id: "shirt_jersey",     category: .shirt, name: "חולצת ספורט",   emoji: "🎽", rarity: .common, price: 12),
        CosmeticItem(id: "shirt_kingrobe",   category: .shirt, name: "גלימת מלך",     emoji: "👘", rarity: .legendary, price: 130),
        CosmeticItem(id: "shirt_jacket",     category: .shirt, name: "ז'קט",          emoji: "🧥", rarity: .rare,   price: 28),

        // MARK: - Pants (5)
        CosmeticItem(id: "pants_jeans",      category: .pants, name: "ג'ינס",         emoji: "👖", rarity: .common, price: 10),
        CosmeticItem(id: "pants_shorts",     category: .pants, name: "מכנסיים קצרים", emoji: "🩳", rarity: .common, price: 8),
        CosmeticItem(id: "pants_skirt",      category: .pants, name: "חצאית",         emoji: "👗", rarity: .rare,   price: 25),
        CosmeticItem(id: "pants_sweats",     category: .pants, name: "מכנסי טרנינג",  emoji: "🩲", rarity: .common, price: 9),
        CosmeticItem(id: "pants_overalls",   category: .pants, name: "אוברול",        emoji: "👨‍🌾", rarity: .epic,  price: 55),

        // MARK: - Shoes (6)
        CosmeticItem(id: "shoes_sneakers",   category: .shoes, name: "סניקרס",        emoji: "👟", rarity: .common, price: 10),
        CosmeticItem(id: "shoes_boots",      category: .shoes, name: "מגפיים",        emoji: "🥾", rarity: .rare,   price: 25),
        CosmeticItem(id: "shoes_heels",      category: .shoes, name: "עקבים",         emoji: "👠", rarity: .rare,   price: 28),
        CosmeticItem(id: "shoes_runners",    category: .shoes, name: "נעלי ריצה",     emoji: "🏃",  rarity: .epic,   price: 55),
        CosmeticItem(id: "shoes_ballet",     category: .shoes, name: "נעלי בלט",      emoji: "🩰", rarity: .epic,   price: 60),
        CosmeticItem(id: "shoes_magic",      category: .shoes, name: "נעלי קסם",      emoji: "✨", rarity: .legendary, price: 120),

        // MARK: - Accessories (7)
        CosmeticItem(id: "acc_watch",        category: .accessory, name: "שעון",       emoji: "⌚", rarity: .common,    price: 12),
        CosmeticItem(id: "acc_medal",        category: .accessory, name: "מדליה",      emoji: "🏅", rarity: .rare,      price: 25),
        CosmeticItem(id: "acc_trophy",       category: .accessory, name: "גביע",       emoji: "🏆", rarity: .epic,      price: 60),
        CosmeticItem(id: "acc_wand",         category: .accessory, name: "שרביט קסם",  emoji: "🪄", rarity: .epic,      price: 65),
        CosmeticItem(id: "acc_balloon",      category: .accessory, name: "בלון",       emoji: "🎈", rarity: .common,    price: 10),
        CosmeticItem(id: "acc_butterfly",    category: .accessory, name: "פרפר",       emoji: "🦋", rarity: .rare,      price: 22),
        CosmeticItem(id: "acc_lightning",    category: .accessory, name: "ברק קסם",    emoji: "⚡", rarity: .legendary, price: 115),

        // MARK: - Backpacks (4)
        CosmeticItem(id: "bag_school",       category: .backpack, name: "תיק בית ספר", emoji: "🎒", rarity: .common, price: 12),
        CosmeticItem(id: "bag_briefcase",    category: .backpack, name: "תיק עבודה",   emoji: "💼", rarity: .rare,   price: 25),
        CosmeticItem(id: "bag_purse",        category: .backpack, name: "ארנק",        emoji: "👛", rarity: .common, price: 10),
        CosmeticItem(id: "bag_pouch",        category: .backpack, name: "תיק קטן",     emoji: "👝", rarity: .rare,   price: 22),

        // MARK: - Vehicles / wheels (5)
        CosmeticItem(id: "ride_skateboard",  category: .vehicle, name: "סקייטבורד",   emoji: "🛹", rarity: .rare,      price: 30),
        CosmeticItem(id: "ride_scooter",     category: .vehicle, name: "קורקינט",     emoji: "🛴", rarity: .rare,      price: 28),
        CosmeticItem(id: "ride_bike",        category: .vehicle, name: "אופניים",     emoji: "🚲", rarity: .epic,      price: 60),
        CosmeticItem(id: "ride_surfboard",   category: .vehicle, name: "גלשן",        emoji: "🏄", rarity: .epic,      price: 65),
        CosmeticItem(id: "ride_basketball",  category: .vehicle, name: "כדורסל",      emoji: "🏀", rarity: .common,    price: 12),
    ]

    /// O(1) lookup by ID — handy when restoring an equipped item from disk.
    static let byID: [String: CosmeticItem] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    static func item(_ id: String) -> CosmeticItem? { byID[id] }

    static func items(in category: CosmeticCategory) -> [CosmeticItem] {
        all.filter { $0.category == category }
           .sorted { (a, b) in
               if a.rarity != b.rarity { return a.rarity < b.rarity }
               return a.price < b.price
           }
    }

    /// Item IDs every kid starts owning for free — keeps the avatar
    /// editable from minute zero even before they've earned any gems.
    static let starterFreeIDs: Set<String> = [
        "shirt_tee", "pants_jeans", "shoes_sneakers", "hat_cap"
    ]
}
