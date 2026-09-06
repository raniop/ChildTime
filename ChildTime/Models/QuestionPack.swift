import SwiftUI

/// A paid question pack — an ADD-ON the parent buys per child, on top of Tofy+
/// (Rani, 2026-09-06: "תוספת לטופי+ — עוד דברים שאפשר לקנות בנוסף"). A pack is
/// a `Topic` with its own bank, world tile and StoreKit products. The questions
/// ship with the build; the cloud only switches a pack ON (`packs/{id}.enabled`)
/// so a launch happens the day we choose, not the day Apple approves.
///
/// Never shown with a price or a buy button on a child's device — the child only
/// ever sees "בקש מאבא או אמא" (Kids Category).
struct QuestionPack: Identifiable, Hashable {
    let id: String
    let topic: Topic
    let name: String
    let emoji: String
    /// One line under the name ("שחקנים, קבוצות, תחרויות ועובדות מפתיעות").
    let tagline: String
    /// "מה הילד ילמד" — the parent-facing pitch, 2–3 sentences.
    let description: String
    /// Bullet points of what's inside.
    let learns: [String]
    /// School grades the pack suits (1=א׳ … 6=ו׳).
    let grades: ClosedRange<Int>
    /// Consumable StoreKit products: full price for the first child in the
    /// family, half price for every additional child ("הוסיפו גם ל…").
    let productID: String
    let siblingProductID: String
    let heroColors: [Color]
    /// The App Store Connect price (₪), for the DEBUG demo only — the real
    /// label always comes from StoreKit.
    let plannedPriceLabel: String
    /// The bare subject for "רוצה ללמוד על …?" ("כַּדּוּרֶגֶל").
    let shortSubject: String
    /// nil → bought once, forever (a real pack). 30 → a "world pass": one base
    /// world for one child for 30 days, no auto-renew (Rani: a single world
    /// must not make Tofy+ pointless).
    var durationDays: Int? = nil

    var isPass: Bool { durationDays != nil }
    /// "30 יום" / "לתמיד"
    var durationLabel: String { durationDays.map { "\($0) יוֹם" } ?? "לְתָמִיד" }

    /// "כיתות ב׳–ו׳"
    var gradesLabel: String {
        let names = ["גן", "א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳"]
        let lo = names[max(0, min(6, grades.lowerBound))]
        let hi = names[max(0, min(6, grades.upperBound))]
        return grades.lowerBound == grades.upperBound ? "כִּתָּה \(lo)" : "כִּתּוֹת \(lo)–\(hi)"
    }

    /// Questions bundled for this pack (the compiler-checked bank). 0 for the
    /// generated/passage topics (math, reading) — the UI says "מתחדשות".
    var questionCount: Int { QuestionBanks.bank(for: topic)?.count ?? 0 }
    var questionsLabel: String { questionCount > 0 ? "\(questionCount) שְׁאֵלוֹת · 3 רָמוֹת" : "שְׁאֵלוֹת מִתְחַדְּשׁוֹת · 3 רָמוֹת" }

    var heroGradient: LinearGradient {
        LinearGradient(colors: heroColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum QuestionPacks {
    static let all: [QuestionPack] = [
        QuestionPack(
            id: "soccer",
            topic: .soccer,
            name: "עוֹלַם הַכַּדּוּרֶגֶל",
            emoji: "⚽",
            tagline: "שַׂחְקָנִים, קְבוּצוֹת, תַּחֲרֻיּוֹת וְעֻבְדּוֹת מַפְתִּיעוֹת",
            description: "הַיֶּלֶד מַכִּיר אֶת הַמִּשְׂחָק הַכִּי אָהוּב בָּעוֹלָם: קְבוּצוֹת וְשַׂחְקָנִים מִיִּשְׂרָאֵל וּמֵהָעוֹלָם, מְדִינוֹת וְתַחֲרֻיּוֹת, חֻקִּים, הִיסְטוֹרְיָה וְקְצָת חֶשְׁבּוֹן שֶׁל תּוֹצָאוֹת — וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק, בְּדִיּוּק כְּמוֹ בְּכָל עוֹלָם.",
            learns: [
                "קְבוּצוֹת וְשַׂחְקָנִים מִיִּשְׂרָאֵל וּמֵהָעוֹלָם",
                "מְדִינוֹת, יַבָּשׁוֹת וְתַחֲרֻיּוֹת גְּדוֹלוֹת",
                "חֻקֵּי הַמִּשְׂחָק וְתַפְקִידִים בַּמִּגְרָשׁ",
                "חֶשְׁבּוֹן שֶׁל תּוֹצָאוֹת, דַּקּוֹת וְשַׁעֲרִים",
            ],
            grades: 2...6,
            productID: "com.rani.ChildTime.pack.soccer",
            siblingProductID: "com.rani.ChildTime.pack.soccer.sibling",
            heroColors: [Color(hex: "8CFFC4"), Color(hex: "37E2D5")],
            plannedPriceLabel: "₪14.90",
            shortSubject: "כַּדּוּרֶגֶל"
        ),
        QuestionPack(
            id: "dinosaurs", topic: .dinosaurs, name: "דִּינוֹזָאוּרִים", emoji: "🦖",
            tagline: "מִינִים, גֹּדֶל, מָה אָכְלוּ, וְאֵיךְ מְגַלִּים מְאֻבָּנִים",
            description: "מִינִים, גֹּדֶל, מָה אָכְלוּ, וְאֵיךְ מְגַלִּים מְאֻבָּנִים — בְּשָׁלוֹשׁ רָמוֹת שֶׁמִּתְאִימוֹת אֶת עַצְמָן לַיֶּלֶד, וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק, בְּדִיּוּק כְּמוֹ בְּכָל עוֹלָם.",
            learns: ["מִינֵי דִּינוֹזָאוּרִים וּמָה הֵם אָכְלוּ", "מְאֻבָּנִים וְאֵיךְ מוֹצְאִים אוֹתָם", "לָמָּה נֶעֶלְמוּ הַדִּינוֹזָאוּרִים", "חֶשְׁבּוֹן שֶׁל רַגְלַיִם, בֵּיצִים וְאֹרֶךְ"],
            grades: 0...4,
            productID: "com.rani.ChildTime.pack.dinosaurs",
            siblingProductID: "com.rani.ChildTime.pack.dinosaurs.sibling",
            heroColors: [Color(hex: "8CFFC4"), Color(hex: "2ECC71")],
            plannedPriceLabel: "₪14.90",
            shortSubject: "דִּינוֹזָאוּרִים"
        ),
        QuestionPack(
            id: "space", topic: .space, name: "חָלָל וְכוֹכָבִים", emoji: "🚀",
            tagline: "כּוֹכְבֵי לֶכֶת, יָרֵחַ, אַסְטְרוֹנָאוּטִים וְשֶׁמֶשׁ",
            description: "כּוֹכְבֵי לֶכֶת, יָרֵחַ, אַסְטְרוֹנָאוּטִים וְשֶׁמֶשׁ — בְּשָׁלוֹשׁ רָמוֹת שֶׁמִּתְאִימוֹת אֶת עַצְמָן לַיֶּלֶד, וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק, בְּדִיּוּק כְּמוֹ בְּכָל עוֹלָם.",
            learns: ["שְׁמוֹנָה כּוֹכְבֵי הַלֶּכֶת וְהַסֵּדֶר שֶׁלָּהֶם", "הַיָּרֵחַ, הַשֶּׁמֶשׁ, יוֹם וְלַיְלָה", "אַסְטְרוֹנָאוּטִים, טִילִים וְיִשְׂרָאֵל בֶּחָלָל", "טֶלֶסְקוֹפִּים, כּוֹכָבִים וְשָׁבִיטִים"],
            grades: 1...6,
            productID: "com.rani.ChildTime.pack.space",
            siblingProductID: "com.rani.ChildTime.pack.space.sibling",
            heroColors: [Color(hex: "B7ABFF"), Color(hex: "5E60CE")],
            plannedPriceLabel: "₪14.90",
            shortSubject: "חָלָל"
        ),
        QuestionPack(
            id: "animals", topic: .animals, name: "עוֹלַם הַחַיּוֹת", emoji: "🐾",
            tagline: "יַבָּשׁוֹת, חַיּוֹת בְּסַכָּנָה וְשִׂיאִים",
            description: "יַבָּשׁוֹת, חַיּוֹת בְּסַכָּנָה וְשִׂיאִים — בְּשָׁלוֹשׁ רָמוֹת שֶׁמִּתְאִימוֹת אֶת עַצְמָן לַיֶּלֶד, וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק, בְּדִיּוּק כְּמוֹ בְּכָל עוֹלָם.",
            learns: ["מִי הֲכִי מָהִיר, גָּדוֹל וְגָבוֹהַּ", "חַיּוֹת לְפִי יַבָּשׁוֹת וּבָתֵּי גִּדּוּל", "גּוּרִים, קוֹלוֹת וּמָה חַיּוֹת אוֹכְלוֹת", "חַיּוֹת יִשְׂרָאֵל וְלָמָּה שׁוֹמְרִים עֲלֵיהֶן"],
            grades: 0...4,
            productID: "com.rani.ChildTime.pack.animals",
            siblingProductID: "com.rani.ChildTime.pack.animals.sibling",
            heroColors: [Color(hex: "FFD23F"), Color(hex: "FF8C42")],
            plannedPriceLabel: "₪14.90",
            shortSubject: "חַיּוֹת"
        ),
        QuestionPack(
            id: "sea", topic: .sea, name: "מַעֲמַקֵּי הַיָּם", emoji: "🌊",
            tagline: "כְּרִישִׁים, לִוְיְתָנִים, שׁוּנִיּוֹת, וּמִי חַי אֵיפֹה",
            description: "כְּרִישִׁים, לִוְיְתָנִים, שׁוּנִיּוֹת, וּמִי חַי אֵיפֹה — בְּשָׁלוֹשׁ רָמוֹת שֶׁמִּתְאִימוֹת אֶת עַצְמָן לַיֶּלֶד, וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק, בְּדִיּוּק כְּמוֹ בְּכָל עוֹלָם.",
            learns: ["כְּרִישִׁים, לִוְיְתָנִים וְדוֹלְפִינִים", "תַּמְנוּן, מֶדוּזָה וְצַבֵּי יָם", "יַם הַמֶּלַח, הַכִּנֶּרֶת וְהָאוֹקְיָנוֹסִים", "צוֹלְלוֹת, צוֹלְלָנִים וְעוֹלַם הַמַּיִם"],
            grades: 0...5,
            productID: "com.rani.ChildTime.pack.sea",
            siblingProductID: "com.rani.ChildTime.pack.sea.sibling",
            heroColors: [Color(hex: "7CF3FF"), Color(hex: "3E8BF0")],
            plannedPriceLabel: "₪14.90",
            shortSubject: "הַיָּם"
        ),
        QuestionPack(
            id: "gifted", topic: .gifted, name: "הֲכָנָה לִמְחוֹנָנִים", emoji: "🧠",
            tagline: "חֲשִׁיבָה, סְדָרוֹת, הֶקֵּשִׁים וּתְפִיסָה מֶרְחָבִית",
            description: "חֲשִׁיבָה, סְדָרוֹת, הֶקֵּשִׁים וּתְפִיסָה מֶרְחָבִית — בְּשָׁלוֹשׁ רָמוֹת שֶׁמִּתְאִימוֹת אֶת עַצְמָן לַיֶּלֶד, וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק, בְּדִיּוּק כְּמוֹ בְּכָל עוֹלָם.",
            learns: ["סְדָרוֹת מִסְפָּרִים וְתַבְנִיּוֹת", "אָנָלוֹגְיוֹת וּמִי לֹא שַׁיָּךְ", "חִידוֹת הִגָּיוֹן וּתְפִיסָה מֶרְחָבִית", "בְּעָיוֹת מִלּוּלִיּוֹת בִּשְׁנֵי שְׁלַבִּים"],
            grades: 2...5,
            productID: "com.rani.ChildTime.pack.gifted",
            siblingProductID: "com.rani.ChildTime.pack.gifted.sibling",
            heroColors: [Color(hex: "FF7BD3"), Color(hex: "9B5DE5")],
            plannedPriceLabel: "₪14.90",
            shortSubject: "חֲשִׁיבָה"
        ),
        QuestionPack(
            id: "food", topic: .food, name: "מִטְבָּח וּמַדָּע שֶׁל אֹכֶל", emoji: "🍳",
            tagline: "מֵאַיִן מַגִּיעַ אֹכֶל, מְדִידוֹת וּמַתְכּוֹנִים בְּחֶשְׁבּוֹן",
            description: "מֵאַיִן מַגִּיעַ אֹכֶל, מְדִידוֹת וּמַתְכּוֹנִים בְּחֶשְׁבּוֹן — בְּשָׁלוֹשׁ רָמוֹת שֶׁמִּתְאִימוֹת אֶת עַצְמָן לַיֶּלֶד, וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק, בְּדִיּוּק כְּמוֹ בְּכָל עוֹלָם.",
            learns: ["מֵאַיִן מַגִּיעִים חָלָב, לֶחֶם, דְּבַשׁ וְשׁוֹקוֹלָד", "כּוֹסוֹת, כַּפּוֹת, גְּרָמִים וְלִיטְרִים", "מַתְכּוֹנִים בְּחֶשְׁבּוֹן: כָּפוּל וָחֵצִי", "לָמָּה הַלֶּחֶם תּוֹפֵחַ וְהַמַּיִם רוֹתְחִים"],
            grades: 1...5,
            productID: "com.rani.ChildTime.pack.food",
            siblingProductID: "com.rani.ChildTime.pack.food.sibling",
            heroColors: [Color(hex: "FFD98A"), Color(hex: "FF8C42")],
            plannedPriceLabel: "₪14.90",
            shortSubject: "אֹכֶל"
        ),
        QuestionPack(
            id: "israel", topic: .israel, name: "יִשְׂרָאֵל שֶׁלִּי", emoji: "🏛️",
            tagline: "עָרִים, סְמָלִים, חַגִּים, דְּמֻיּוֹת וְטֶבַע",
            description: "עָרִים, סְמָלִים, חַגִּים, דְּמֻיּוֹת וְטֶבַע — בְּשָׁלוֹשׁ רָמוֹת שֶׁמִּתְאִימוֹת אֶת עַצְמָן לַיֶּלֶד, וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק, בְּדִיּוּק כְּמוֹ בְּכָל עוֹלָם.",
            learns: ["עָרִים, יַמִּים וַהֲרֵי יִשְׂרָאֵל", "הַדֶּגֶל, הַסֵּמֶל וְהַהִמְנוֹן", "חַגִּים וְהַסְּמָלִים שֶׁלָּהֶם", "הַמְצָאוֹת וּדְמֻיּוֹת מִיִּשְׂרָאֵל"],
            grades: 2...6,
            productID: "com.rani.ChildTime.pack.israel",
            siblingProductID: "com.rani.ChildTime.pack.israel.sibling",
            heroColors: [Color(hex: "8CFFC4"), Color(hex: "37E2D5")],
            plannedPriceLabel: "₪14.90",
            shortSubject: "יִשְׂרָאֵל"
        ),
        QuestionPack(
            id: "music", topic: .music, name: "מוּזִיקָה", emoji: "🎵",
            tagline: "כְּלֵי נְגִינָה, קֶצֶב, מַלְחִינִים וְשִׁירֵי יְלָדִים",
            description: "כְּלֵי נְגִינָה, קֶצֶב, מַלְחִינִים וְשִׁירֵי יְלָדִים — בְּשָׁלוֹשׁ רָמוֹת שֶׁמִּתְאִימוֹת אֶת עַצְמָן לַיֶּלֶד, וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק, בְּדִיּוּק כְּמוֹ בְּכָל עוֹלָם.",
            learns: ["כְּלֵי נְגִינָה וְהַמִּשְׁפָּחוֹת שֶׁלָּהֶם", "שִׁבְעַת הַתָּוִים, קֶצֶב וְטֶמְפּוֹ", "מַלְחִינִים מְפֻרְסָמִים בְּמִשְׁפָּט אֶחָד", "תִּזְמֹרֶת, מַקְהֵלָה וּמְנַצֵּחַ"],
            grades: 0...4,
            productID: "com.rani.ChildTime.pack.music",
            siblingProductID: "com.rani.ChildTime.pack.music.sibling",
            heroColors: [Color(hex: "B7ABFF"), Color(hex: "FF7BD3")],
            plannedPriceLabel: "₪14.90",
            shortSubject: "מוּזִיקָה"
        ),
        QuestionPack(
            id: "body", topic: .body, name: "גּוּף הָאָדָם", emoji: "🧍",
            tagline: "עֲצָמוֹת, לֵב, נְשִׁימָה וּבְרִיאוּת",
            description: "עֲצָמוֹת, לֵב, נְשִׁימָה וּבְרִיאוּת — בְּשָׁלוֹשׁ רָמוֹת שֶׁמִּתְאִימוֹת אֶת עַצְמָן לַיֶּלֶד, וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק, בְּדִיּוּק כְּמוֹ בְּכָל עוֹלָם.",
            learns: ["עֲצָמוֹת, שְׁרִירִים וּמִפְרָקִים", "הַלֵּב, הָרֵאוֹת וְהַדָּם", "חֲמֵשֶׁת הַחוּשִׁים וְהַמֹּחַ", "הֶרְגֵּלִים בְּרִיאִים: שֵׁנָה, צִחְצוּחַ, מַיִם"],
            grades: 2...6,
            productID: "com.rani.ChildTime.pack.body",
            siblingProductID: "com.rani.ChildTime.pack.body.sibling",
            heroColors: [Color(hex: "FF9AA0"), Color(hex: "FF7BD3")],
            plannedPriceLabel: "₪14.90",
            shortSubject: "גּוּף הָאָדָם"
        ),
        QuestionPack(
            id: "vehicles", topic: .vehicles, name: "כְּלֵי רֶכֶב וְתַחְבּוּרָה", emoji: "🚗",
            tagline: "מְכוֹנִיּוֹת, רַכָּבוֹת, מְטוֹסִים, וְאֵיךְ זֶה עוֹבֵד",
            description: "מְכוֹנִיּוֹת, רַכָּבוֹת, מְטוֹסִים, וְאֵיךְ זֶה עוֹבֵד — בְּשָׁלוֹשׁ רָמוֹת שֶׁמִּתְאִימוֹת אֶת עַצְמָן לַיֶּלֶד, וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק, בְּדִיּוּק כְּמוֹ בְּכָל עוֹלָם.",
            learns: ["מָה נוֹסֵעַ עַל פַּסִּים, בַּמַּיִם וּבָאֲוִיר", "מִי נוֹהֵג, מַטִּיס וּמְנַוֵּט", "רַמְזוֹר וּבְטִיחוּת בַּדֶּרֶךְ", "גַּלְגַּלִּים בְּחֶשְׁבּוֹן"],
            grades: 0...3,
            productID: "com.rani.ChildTime.pack.vehicles",
            siblingProductID: "com.rani.ChildTime.pack.vehicles.sibling",
            heroColors: [Color(hex: "7CF3FF"), Color(hex: "5E60CE")],
            plannedPriceLabel: "₪14.90",
            shortSubject: "כְּלֵי רֶכֶב"
        ),
        QuestionPack(
            id: "flags", topic: .flags, name: "דְּגָלִים וּמְדִינוֹת", emoji: "🌍",
            tagline: "דְּגָלִים, בִּירוֹת וְיַבָּשׁוֹת",
            description: "דְּגָלִים, בִּירוֹת וְיַבָּשׁוֹת — בְּשָׁלוֹשׁ רָמוֹת שֶׁמִּתְאִימוֹת אֶת עַצְמָן לַיֶּלֶד, וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק, בְּדִיּוּק כְּמוֹ בְּכָל עוֹלָם.",
            learns: ["דְּגָלִים שֶׁל מְדִינוֹת מֻכָּרוֹת", "בִּירוֹת וְיַבָּשׁוֹת", "אֲתָרִים מְפֻרְסָמִים בָּעוֹלָם", "הַשְּׁכֵנוֹת שֶׁל יִשְׂרָאֵל"],
            grades: 3...6,
            productID: "com.rani.ChildTime.pack.flags",
            siblingProductID: "com.rani.ChildTime.pack.flags.sibling",
            heroColors: [Color(hex: "FFD23F"), Color(hex: "8CFFC4")],
            plannedPriceLabel: "₪14.90",
            shortSubject: "דְּגָלִים וּמְדִינוֹת"
        ),
    ]

    /// A pack OR a world pass by id ("soccer", "math").
    static func find(_ id: String) -> QuestionPack? { all.first { $0.id == id } ?? WorldPasses.find(id) }
    /// Real packs only (a base world is never "a pack" — see Topic.core).
    static func pack(for topic: Topic) -> QuestionPack? { all.first { $0.topic == topic } }
    static var allProductIDs: Set<String> {
        Set((all + WorldPasses.all).flatMap { [$0.productID, $0.siblingProductID] })
    }
}

/// 🌍 World passes — every BASE world sold for 30 days per child, next to
/// Tofy+ (Rani, 2026-09-06: "יש כאלה שירצו לשלם חד פעמי"). Same purchase
/// machinery as packs; ownership carries an expiry (`Profile.packExpiry`).
enum WorldPasses {
    static let all: [QuestionPack] = Worlds.all.filter { !$0.isBonusWorld && !$0.topic.isPack }.map { w in
        QuestionPack(
            id: w.topic.rawValue, topic: w.topic, name: w.name, emoji: w.emoji,
            tagline: tagline(w.topic),
            description: description(w.topic),
            learns: learns(w.topic),
            grades: w.topic == .reading ? 1...6 : 0...6,
            productID: "com.rani.ChildTime.world.\(w.topic.rawValue).30d",
            siblingProductID: "com.rani.ChildTime.world.\(w.topic.rawValue).30d.sibling",
            heroColors: [w.glowColor, w.glowColor.opacity(0.6)],
            plannedPriceLabel: "₪6.90",
            shortSubject: w.topic.displayName,
            durationDays: 30
        )
    }
    static func find(_ id: String) -> QuestionPack? { all.first { $0.id == id } }
    static func pass(for topic: Topic) -> QuestionPack? { all.first { $0.topic == topic } }

    private static func tagline(_ t: Topic) -> String {
        switch t {
        case .math:      return "חִבּוּר, חִסּוּר, כֶּפֶל, חִלּוּק וּבְעָיוֹת מִלּוּלִיּוֹת"
        case .english:   return "מִלִּים, מִשְׁפָּטִים וְשִׂיחָה בְּאַנְגְּלִית"
        case .hebrew:    return "כְּתִיב נָכוֹן, מִלִּים וְדִקְדּוּק"
        case .logic:     return "חִידוֹת, סְדָרוֹת וַחֲשִׁיבָה"
        case .science:   return "גּוּף, טֶבַע, חַיּוֹת וְנִסּוּיִים"
        case .history:   return "אֲנָשִׁים, תְּקוּפוֹת וְסִפּוּרִים מֵהֶעָבָר"
        case .geography: return "מְדִינוֹת, יַבָּשׁוֹת, יַמִּים וּדְגָלִים"
        case .money:     return "כֶּסֶף, חִסָּכוֹן וּבְחִירוֹת חֲכָמוֹת"
        case .reading:   return "קְטָעִים קְצָרִים וּשְׁאֵלוֹת עֲלֵיהֶם"
        case .soccer, .dinosaurs, .space, .animals, .sea, .gifted, .food, .israel, .music, .body, .vehicles, .flags: return ""
        }
    }
    private static func description(_ t: Topic) -> String {
        "\(tagline(t)) — לְפִי תָּכְנִית הַלִּמּוּדִים שֶׁל הַכִּתָּה שֶׁל הַיֶּלֶד, בְּשָׁלוֹשׁ רָמוֹת שֶׁמִּתְאִימוֹת אֶת עַצְמָן. עַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק."
    }
    private static func learns(_ t: Topic) -> [String] {
        ["שְׁאֵלוֹת לְפִי הַכִּתָּה וְהָרָמָה שֶׁל הַיֶּלֶד", "דּוּחַ לַהוֹרִים: בַּמֶּה חָזָק, מָה לְתַרְגֵּל", "רְמָזִים וְהַקְרָאָה לְמִי שֶׁעוֹד לֹא קוֹרֵא", "30 יוֹם · לְיֶלֶד אֶחָד · בְּלִי חִדּוּשׁ אוֹטוֹמָטִי"]
    }
}

/// Who can play a pack RIGHT NOW. Rani (2026-09-06): every pack is open to a
/// Tofy+ family the moment it launches; a family without Tofy+ buys it once
/// per child (or a base world for 30 days).
@MainActor
enum PackAccess {
    static func has(_ profile: Profile, _ pack: QuestionPack) -> Bool {
        if SubscriptionManager.shared.isPremium { return true }
        return profile.owns(pack)
    }
    /// A Tofy+ family didn't BUY it — the kid's reveal says "a new world
    /// arrived", not "mom and dad sent you a gift".
    static func isGift(_ profile: Profile, _ pack: QuestionPack) -> Bool { profile.owns(pack) }
}

/// Per-child, per-device memory of the pack "moments" on the KID's screen:
/// the 🎁 reveal (shown once) and the first open (the "חדש!" badge lives until
/// then). Local on purpose — a surprise should play on the device the child is
/// holding, not be consumed by the parent's phone syncing first.
enum PackKidState {
    private static func key(_ what: String, _ childID: UUID) -> String { "packs.\(what).\(childID.uuidString)" }
    private static func set(_ what: String, _ childID: UUID) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key(what, childID)) ?? [])
    }
    private static func mark(_ what: String, _ childID: UUID, _ packID: String) {
        var s = set(what, childID); s.insert(packID)
        UserDefaults.standard.set(Array(s), forKey: key(what, childID))
    }
    static func isRevealed(_ packID: String, childID: UUID) -> Bool { set("revealed", childID).contains(packID) }
    static func isOpened(_ packID: String, childID: UUID) -> Bool { set("opened", childID).contains(packID) }
    static func markRevealed(_ packID: String, childID: UUID) {
        mark("revealed", childID, packID)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key("revealedAt.\(packID)", childID))
    }
    /// Rani: the new world sits next to טופי טיים and BLINKS on its first day.
    /// True for 24 h after the reveal (whether or not the child opened it yet).
    static func isFirstDay(_ packID: String, childID: UUID) -> Bool {
        let at = UserDefaults.standard.double(forKey: key("revealedAt.\(packID)", childID))
        return at > 0 && Date().timeIntervalSince1970 - at < 86_400
    }
    static func markOpened(_ packID: String, childID: UUID) { mark("opened", childID, packID) }
    /// Demo/test: forget everything for this child.
    static func reset(childID: UUID) {
        UserDefaults.standard.removeObject(forKey: key("revealed", childID))
        UserDefaults.standard.removeObject(forKey: key("opened", childID))
        for p in QuestionPacks.all { UserDefaults.standard.removeObject(forKey: key("revealedAt.\(p.id)", childID)) }
    }
    /// The first pack / world pass this child can play and hasn't been shown the
    /// 🎁 for yet — bought for them, or (Tofy+) a pack that just launched.
    static func pendingReveal(for profile: Profile) -> QuestionPack? {
        let bought = (QuestionPacks.all + WorldPasses.all).first { profile.owns($0) && !isRevealed($0.id, childID: profile.id) }
        if let bought { return bought }
        guard SubscriptionManager.shared.isPremium else { return nil }
        return PackStore.shared.visiblePacks.first { PackStore.shared.isFirstDay($0) && !isRevealed($0.id, childID: profile.id) }
    }
}
