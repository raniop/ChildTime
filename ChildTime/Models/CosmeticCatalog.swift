import Foundation

/// The master list of every cosmetic that exists in the shop.
///
/// Price tiers (in gems) — common ≤ 15, rare 20–40, epic 50–80, legendary 100+.
/// Stable string IDs (e.g. `hat_crown`) so refactors / renames don't reset
/// kids' inventories.
enum CosmeticCatalog {
    static let all: [CosmeticItem] = [
        // MARK: - Hats (10)
        CosmeticItem(id: "hat_party",     category: .hat, name: "כּוֹבַע מְסִיבָּה",   emoji: "🎉", rarity: .common,    price: 10),
        CosmeticItem(id: "hat_cap",       category: .hat, name: "כּוֹבַע מִצְחִיָּה",   emoji: "🧢", rarity: .common,    price: 10),
        CosmeticItem(id: "hat_top",       category: .hat, name: "כּוֹבַע צִילִינְדֶּר",  emoji: "🎩", rarity: .rare,      price: 25),
        CosmeticItem(id: "hat_graduate",  category: .hat, name: "כּוֹבַע סְטוּדֶנְט",  emoji: "🎓", rarity: .rare,      price: 30),
        CosmeticItem(id: "hat_cowboy",    category: .hat, name: "כּוֹבַע בּוֹקְרִים",   emoji: "🤠", rarity: .epic,      price: 55),
        CosmeticItem(id: "hat_crown",     category: .hat, name: "כֶּתֶר זָהָב",      emoji: "👑", rarity: .legendary, price: 120),
        CosmeticItem(id: "hat_helmet",    category: .hat, name: "קַסְדָּה",         emoji: "⛑",  rarity: .rare,      price: 25),
        CosmeticItem(id: "hat_unicorn",   category: .hat, name: "קֶרֶן חַד-קֶרֶן",   emoji: "🦄", rarity: .legendary, price: 130),
        CosmeticItem(id: "hat_pirate",    category: .hat, name: "כּוֹבַע פִּירָאט",   emoji: "🏴‍☠️", rarity: .epic,    price: 60),
        CosmeticItem(id: "hat_santa",     category: .hat, name: "כּוֹבַע חוֹרֶף",    emoji: "🎄", rarity: .common,    price: 12),

        // MARK: - Glasses (6)
        CosmeticItem(id: "glasses_round", category: .glasses, name: "מִשְׁקָפַיִים עֲגוּלִים",   emoji: "🤓", rarity: .common,    price: 12),
        CosmeticItem(id: "glasses_shade", category: .glasses, name: "מִשְׁקְפֵי שֶׁמֶשׁ",       emoji: "😎", rarity: .rare,      price: 22),
        CosmeticItem(id: "glasses_3d",    category: .glasses, name: "מִשְׁקְפֵי 3D",        emoji: "🥽", rarity: .epic,      price: 50),
        CosmeticItem(id: "glasses_vr",    category: .glasses, name: "מִשְׁקְפֵי VR",        emoji: "🕶",  rarity: .epic,      price: 70),
        CosmeticItem(id: "glasses_heart", category: .glasses, name: "מִשְׁקְפֵי לֵב",        emoji: "💖", rarity: .legendary, price: 110),
        CosmeticItem(id: "glasses_star",  category: .glasses, name: "מִשְׁקְפֵי כּוֹכָבִים",    emoji: "⭐", rarity: .legendary, price: 115),

        // MARK: - Shirts (8)
        CosmeticItem(id: "shirt_tee",        category: .shirt, name: "חוּלְצַת טְרִיקוֹ",  emoji: "👕", rarity: .common, price: 8),
        CosmeticItem(id: "shirt_hoodie",     category: .shirt, name: "קַפּוּצ׳וֹן",       emoji: "🧥", rarity: .rare,   price: 25),
        CosmeticItem(id: "shirt_kimono",     category: .shirt, name: "קִימוֹנוֹ",        emoji: "🥋", rarity: .rare,   price: 30),
        CosmeticItem(id: "shirt_lab",        category: .shirt, name: "חָלוּק מַדְעָן",     emoji: "🥼", rarity: .epic,   price: 55),
        CosmeticItem(id: "shirt_tuxedo",     category: .shirt, name: "סְמוֹקִינְג",       emoji: "🤵", rarity: .epic,   price: 65),
        CosmeticItem(id: "shirt_jersey",     category: .shirt, name: "חוּלְצַת סְפּוֹרְט",   emoji: "🎽", rarity: .common, price: 12),
        CosmeticItem(id: "shirt_kingrobe",   category: .shirt, name: "גְּלִימַת מֶלֶךְ",     emoji: "👘", rarity: .legendary, price: 130),
        CosmeticItem(id: "shirt_jacket",     category: .shirt, name: "זָ'קֵט",          emoji: "🧥", rarity: .rare,   price: 28),

        // MARK: - Pants (5)
        CosmeticItem(id: "pants_jeans",      category: .pants, name: "גִּ'ינְס",         emoji: "👖", rarity: .common, price: 10),
        CosmeticItem(id: "pants_shorts",     category: .pants, name: "מִכְנָסַיִים קְצָרִים", emoji: "🩳", rarity: .common, price: 8),
        CosmeticItem(id: "pants_skirt",      category: .pants, name: "חֲצָאִית",         emoji: "👗", rarity: .rare,   price: 25),
        CosmeticItem(id: "pants_sweats",     category: .pants, name: "מִכְנְסֵי טְרֶנִינְג",  emoji: "🩲", rarity: .common, price: 9),
        CosmeticItem(id: "pants_overalls",   category: .pants, name: "אוֹבֵרוֹל",        emoji: "👨‍🌾", rarity: .epic,  price: 55),

        // MARK: - Shoes (6)
        CosmeticItem(id: "shoes_sneakers",   category: .shoes, name: "סְנִיקֶרְס",        emoji: "👟", rarity: .common, price: 10),
        CosmeticItem(id: "shoes_boots",      category: .shoes, name: "מַגָּפַיִים",        emoji: "🥾", rarity: .rare,   price: 25),
        CosmeticItem(id: "shoes_heels",      category: .shoes, name: "עֲקֵבִים",         emoji: "👠", rarity: .rare,   price: 28),
        CosmeticItem(id: "shoes_runners",    category: .shoes, name: "נַעֲלֵי רִיצָה",     emoji: "🏃",  rarity: .epic,   price: 55),
        CosmeticItem(id: "shoes_ballet",     category: .shoes, name: "נַעֲלֵי בָּלֵט",      emoji: "🩰", rarity: .epic,   price: 60),
        CosmeticItem(id: "shoes_magic",      category: .shoes, name: "נַעֲלֵי קֶסֶם",      emoji: "✨", rarity: .legendary, price: 120),

        // MARK: - Accessories (7)
        CosmeticItem(id: "acc_watch",        category: .accessory, name: "שָׁעוֹן",       emoji: "⌚", rarity: .common,    price: 12),
        CosmeticItem(id: "acc_medal",        category: .accessory, name: "מֶדַלְיָה",      emoji: "🏅", rarity: .rare,      price: 25),
        CosmeticItem(id: "acc_trophy",       category: .accessory, name: "גָּבִיעַ",       emoji: "🏆", rarity: .epic,      price: 60),
        CosmeticItem(id: "acc_wand",         category: .accessory, name: "שַׁרְבִיט קֶסֶם",  emoji: "🪄", rarity: .epic,      price: 65),
        CosmeticItem(id: "acc_balloon",      category: .accessory, name: "בַּלּוֹן",       emoji: "🎈", rarity: .common,    price: 10),
        CosmeticItem(id: "acc_butterfly",    category: .accessory, name: "פַּרְפַּר",       emoji: "🦋", rarity: .rare,      price: 22),
        CosmeticItem(id: "acc_lightning",    category: .accessory, name: "בָּרָק קֶסֶם",    emoji: "⚡", rarity: .legendary, price: 115),

        // MARK: - Backpacks (4)
        CosmeticItem(id: "bag_school",       category: .backpack, name: "תִּיק בֵּית סֵפֶר", emoji: "🎒", rarity: .common, price: 12),
        CosmeticItem(id: "bag_briefcase",    category: .backpack, name: "תִּיק עֲבוֹדָה",   emoji: "💼", rarity: .rare,   price: 25),
        CosmeticItem(id: "bag_purse",        category: .backpack, name: "אַרְנָק",        emoji: "👛", rarity: .common, price: 10),
        CosmeticItem(id: "bag_pouch",        category: .backpack, name: "תִּיק קָטָן",     emoji: "👝", rarity: .rare,   price: 22),

        // MARK: - Vehicles / wheels (5)
        CosmeticItem(id: "ride_skateboard",  category: .vehicle, name: "סְקֵייטְבּוֹרְד",   emoji: "🛹", rarity: .rare,      price: 30),
        CosmeticItem(id: "ride_scooter",     category: .vehicle, name: "קוֹרְקִינֶט",     emoji: "🛴", rarity: .rare,      price: 28),
        CosmeticItem(id: "ride_bike",        category: .vehicle, name: "אוֹפַנַּיִים",     emoji: "🚲", rarity: .epic,      price: 60),
        CosmeticItem(id: "ride_surfboard",   category: .vehicle, name: "גַּלְשָׁן",        emoji: "🏄", rarity: .epic,      price: 65),
        CosmeticItem(id: "ride_basketball",  category: .vehicle, name: "כַּדּוּרְסַל",      emoji: "🏀", rarity: .common,    price: 12),
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
