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

    /// "כיתות ב׳–ו׳"
    var gradesLabel: String {
        let names = ["גן", "א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳"]
        let lo = names[max(0, min(6, grades.lowerBound))]
        let hi = names[max(0, min(6, grades.upperBound))]
        return grades.lowerBound == grades.upperBound ? "כִּתָּה \(lo)" : "כִּתּוֹת \(lo)–\(hi)"
    }

    /// Questions bundled for this pack (the compiler-checked bank).
    var questionCount: Int { QuestionBanks.bank(for: topic)?.count ?? 0 }

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
            plannedPriceLabel: "₪14.90"
        ),
    ]

    static func find(_ id: String) -> QuestionPack? { all.first { $0.id == id } }
    static func pack(for topic: Topic) -> QuestionPack? { all.first { $0.topic == topic } }
    static var allProductIDs: Set<String> {
        Set(all.flatMap { [$0.productID, $0.siblingProductID] })
    }
}
