import Foundation

/// The master list of every cosmetic that exists in the shop.
///
/// Price tiers (in gems) — common ≤ 15, rare 20–40, epic 50–80, legendary 100+.
/// Stable string IDs (e.g. `hat_crown`) so refactors / renames don't reset
/// kids' inventories.
enum CosmeticCatalog {
    static var all: [CosmeticItem] { LocalizedCache.value("CosmeticCatalog.all") { [
        // MARK: - Hats (10)
        CosmeticItem(id: "hat_party",     category: .hat, name: tr("כּוֹבַע מְסִיבָּה"),   emoji: "🎉", rarity: .common,    price: 30),
        CosmeticItem(id: "hat_cap",       category: .hat, name: tr("כּוֹבַע מִצְחִיָּה"),   emoji: "🧢", rarity: .common,    price: 30),
        CosmeticItem(id: "hat_top",       category: .hat, name: tr("כּוֹבַע צִילִינְדֶּר"),  emoji: "🎩", rarity: .rare,      price: 75),
        CosmeticItem(id: "hat_graduate",  category: .hat, name: tr("כּוֹבַע סְטוּדֶנְט"),  emoji: "🎓", rarity: .rare,      price: 90),
        CosmeticItem(id: "hat_cowboy",    category: .hat, name: tr("כּוֹבַע בּוֹקְרִים"),   emoji: "🤠", rarity: .epic,      price: 165),
        CosmeticItem(id: "hat_crown",     category: .hat, name: tr("כֶּתֶר זָהָב"),      emoji: "👑", rarity: .legendary, price: 360),
        CosmeticItem(id: "hat_helmet",    category: .hat, name: tr("קַסְדָּה"),         emoji: "⛑",  rarity: .rare,      price: 75),
        CosmeticItem(id: "hat_unicorn",   category: .hat, name: tr("קֶרֶן חַד-קֶרֶן"),   emoji: "🦄", rarity: .legendary, price: 390),
        CosmeticItem(id: "hat_pirate",    category: .hat, name: tr("כּוֹבַע פִּירָאט"),   emoji: "🏴‍☠️", rarity: .epic,    price: 180),
        CosmeticItem(id: "hat_santa",     category: .hat, name: tr("כּוֹבַע חוֹרֶף"),    emoji: "🎄", rarity: .common,    price: 36),

        // MARK: - Glasses (6)
        CosmeticItem(id: "glasses_round", category: .glasses, name: tr("מִשְׁקָפַיִים עֲגוּלִים"),   emoji: "🤓", rarity: .common,    price: 36),
        CosmeticItem(id: "glasses_shade", category: .glasses, name: tr("מִשְׁקְפֵי שֶׁמֶשׁ"),       emoji: "😎", rarity: .rare,      price: 66),
        CosmeticItem(id: "glasses_3d",    category: .glasses, name: tr("מִשְׁקְפֵי 3D"),        emoji: "🥽", rarity: .epic,      price: 150),
        CosmeticItem(id: "glasses_vr",    category: .glasses, name: tr("מִשְׁקְפֵי VR"),        emoji: "🕶",  rarity: .epic,      price: 210),
        CosmeticItem(id: "glasses_heart", category: .glasses, name: tr("מִשְׁקְפֵי לֵב"),        emoji: "💖", rarity: .legendary, price: 330),
        CosmeticItem(id: "glasses_star",  category: .glasses, name: tr("מִשְׁקְפֵי כּוֹכָבִים"),    emoji: "⭐", rarity: .legendary, price: 345),

        // MARK: - Shirts (8)
        CosmeticItem(id: "shirt_tee",        category: .shirt, name: tr("חוּלְצַת טְרִיקוֹ"),  emoji: "👕", rarity: .common, price: 24),
        CosmeticItem(id: "shirt_hoodie",     category: .shirt, name: tr("קַפּוּצ׳וֹן"),       emoji: "🧥", rarity: .rare,   price: 75),
        CosmeticItem(id: "shirt_kimono",     category: .shirt, name: tr("קִימוֹנוֹ"),        emoji: "🥋", rarity: .rare,   price: 90),
        CosmeticItem(id: "shirt_lab",        category: .shirt, name: tr("חָלוּק מַדְעָן"),     emoji: "🥼", rarity: .epic,   price: 165),
        CosmeticItem(id: "shirt_tuxedo",     category: .shirt, name: tr("סְמוֹקִינְג"),       emoji: "🤵", rarity: .epic,   price: 195),
        CosmeticItem(id: "shirt_jersey",     category: .shirt, name: tr("חוּלְצַת סְפּוֹרְט"),   emoji: "🎽", rarity: .common, price: 36),
        CosmeticItem(id: "shirt_kingrobe",   category: .shirt, name: tr("גְּלִימַת מֶלֶךְ"),     emoji: "👘", rarity: .legendary, price: 390),
        CosmeticItem(id: "shirt_jacket",     category: .shirt, name: tr("זָ'קֵט"),          emoji: "🧥", rarity: .rare,   price: 84),

        // MARK: - Pants (5)
        CosmeticItem(id: "pants_jeans",      category: .pants, name: tr("גִּ'ינְס"),         emoji: "👖", rarity: .common, price: 30),
        CosmeticItem(id: "pants_shorts",     category: .pants, name: tr("מִכְנָסַיִים קְצָרִים"), emoji: "🩳", rarity: .common, price: 24),
        CosmeticItem(id: "pants_skirt",      category: .pants, name: tr("חֲצָאִית"),         emoji: "👗", rarity: .rare,   price: 75),
        CosmeticItem(id: "pants_sweats",     category: .pants, name: tr("מִכְנְסֵי טְרֶנִינְג"),  emoji: "🩲", rarity: .common, price: 27),
        CosmeticItem(id: "pants_overalls",   category: .pants, name: tr("אוֹבֵרוֹל"),        emoji: "👨‍🌾", rarity: .epic,  price: 165),

        // MARK: - Shoes (6)
        CosmeticItem(id: "shoes_sneakers",   category: .shoes, name: tr("סְנִיקֶרְס"),        emoji: "👟", rarity: .common, price: 30),
        CosmeticItem(id: "shoes_boots",      category: .shoes, name: tr("מַגָּפַיִים"),        emoji: "🥾", rarity: .rare,   price: 75),
        CosmeticItem(id: "shoes_heels",      category: .shoes, name: tr("עֲקֵבִים"),         emoji: "👠", rarity: .rare,   price: 84),
        CosmeticItem(id: "shoes_runners",    category: .shoes, name: tr("נַעֲלֵי רִיצָה"),     emoji: "🏃",  rarity: .epic,   price: 165),
        CosmeticItem(id: "shoes_ballet",     category: .shoes, name: tr("נַעֲלֵי בָּלֵט"),      emoji: "🩰", rarity: .epic,   price: 180),
        CosmeticItem(id: "shoes_magic",      category: .shoes, name: tr("נַעֲלֵי קֶסֶם"),      emoji: "✨", rarity: .legendary, price: 360),

        // MARK: - Accessories (7)
        CosmeticItem(id: "acc_watch",        category: .accessory, name: tr("שָׁעוֹן"),       emoji: "⌚", rarity: .common,    price: 36),
        CosmeticItem(id: "acc_medal",        category: .accessory, name: tr("מֶדַלְיָה"),      emoji: "🏅", rarity: .rare,      price: 75),
        CosmeticItem(id: "acc_trophy",       category: .accessory, name: tr("גָּבִיעַ"),       emoji: "🏆", rarity: .epic,      price: 180),
        CosmeticItem(id: "acc_wand",         category: .accessory, name: tr("שַׁרְבִיט קֶסֶם"),  emoji: "🪄", rarity: .epic,      price: 195),
        CosmeticItem(id: "acc_balloon",      category: .accessory, name: tr("בַּלּוֹן"),       emoji: "🎈", rarity: .common,    price: 30),
        CosmeticItem(id: "acc_butterfly",    category: .accessory, name: tr("פַּרְפַּר"),       emoji: "🦋", rarity: .rare,      price: 66),
        CosmeticItem(id: "acc_lightning",    category: .accessory, name: tr("בָּרָק קֶסֶם"),    emoji: "⚡", rarity: .legendary, price: 345),

        // MARK: - Backpacks (4)
        CosmeticItem(id: "bag_school",       category: .backpack, name: tr("תִּיק בֵּית סֵפֶר"), emoji: "🎒", rarity: .common, price: 36),
        CosmeticItem(id: "bag_briefcase",    category: .backpack, name: tr("תִּיק עֲבוֹדָה"),   emoji: "💼", rarity: .rare,   price: 75),
        CosmeticItem(id: "bag_purse",        category: .backpack, name: tr("אַרְנָק"),        emoji: "👛", rarity: .common, price: 30),
        CosmeticItem(id: "bag_pouch",        category: .backpack, name: tr("תִּיק קָטָן"),     emoji: "👝", rarity: .rare,   price: 66),

        // MARK: - Vehicles / wheels (5)
        CosmeticItem(id: "ride_skateboard",  category: .vehicle, name: tr("סְקֵייטְבּוֹרְד"),   emoji: "🛹", rarity: .rare,      price: 90),
        CosmeticItem(id: "ride_scooter",     category: .vehicle, name: tr("קוֹרְקִינֶט"),     emoji: "🛴", rarity: .rare,      price: 84),
        CosmeticItem(id: "ride_bike",        category: .vehicle, name: tr("אוֹפַנַּיִים"),     emoji: "🚲", rarity: .epic,      price: 180),
        CosmeticItem(id: "ride_surfboard",   category: .vehicle, name: tr("גַּלְשָׁן"),        emoji: "🏄", rarity: .epic,      price: 195),
        CosmeticItem(id: "ride_basketball",  category: .vehicle, name: tr("כַּדּוּרְסַל"),      emoji: "🏀", rarity: .common,    price: 36),
    ] } }

    /// O(1) lookup by ID — handy when restoring an equipped item from disk.
    static var byID: [String: CosmeticItem] { LocalizedCache.value("CosmeticCatalog.byID") {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    } }

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
