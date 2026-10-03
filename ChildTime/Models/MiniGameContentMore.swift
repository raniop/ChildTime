import Foundation
import SwiftUI

// 🎮 Content for the second six mini-games (Rani, 2026-10-03):
//
//   🧺 SortSets    — "מִיּוּן לַסַּלִּים": baskets and the items that go in them.
//   🧠 PatternGen  — "הַתַּבְנִית": number / letter / picture sequences.
//   🔢 Board2048   — the 2048 board's rules.
//   🔐 VaultGen    — "הַכַּסֶּפֶת": the secret code, its feedback, its clues.
//   🛒 GroceryGen  — "הַמַּכֹּלֶת": the shelf, the list and the budget.
//   ⚖️ BalanceGen  — "מֹאזְנַיִם": two pans and the missing weight.

// MARK: - 🧺 Sort into baskets

struct SortBasket: Hashable {
    let emoji: String
    let label: String
}

struct SortItem: Identifiable, Hashable {
    let id = UUID()
    let emoji: String
    let label: String
    /// The candidate answer under a true/false statement.
    var detail: String? = nil
    let basket: Int
    /// English words and numbers read left-to-right.
    var ltr: Bool = false
}

struct SortSet {
    let baskets: [SortBasket]
    let items: [SortItem]
    let topic: Topic
}

enum SortSets {
    static let roundItems = 10

    private static func i(_ emoji: String, _ label: String, _ basket: Int, ltr: Bool = false) -> SortItem {
        SortItem(emoji: emoji, label: label, basket: basket, ltr: ltr)
    }

    /// A world's own baskets, sized to the grade (two baskets; three from ד׳
    /// where a natural third exists). nil → the world sorts true / false.
    static func make(topic: Topic, grade: Int) -> SortSet? {
        let g = max(1, grade)
        switch topic {
        case .math:                return numbers(grade: g)
        case .english:             return english(grade: g)
        case .hebrew:              return hebrew(grade: g)
        case .sea, .animals:       return animals(grade: g, topic: topic)
        case .space:               return planets()
        case .dinosaurs:           return dinosaurs()
        case .soccer:              return soccer()
        case .flags, .geography:   return places(grade: g, topic: topic)
        case .science:             return science(grade: g)
        case .body:                return body()
        case .vehicles:            return vehicles(grade: g)
        case .music:               return music(grade: g)
        case .food:                return food()
        case .money:               return money(grade: g)
        default:                   return nil
        }
    }

    /// Mix the round: up to `roundItems`, every basket represented.
    static func round(_ set: SortSet) -> [SortItem] {
        var byBasket = Dictionary(grouping: set.items.shuffled(), by: \.basket)
        var out: [SortItem] = []
        while out.count < roundItems {
            var added = false
            for b in set.baskets.indices {
                if var list = byBasket[b], !list.isEmpty, out.count < roundItems {
                    out.append(list.removeLast())
                    byBasket[b] = list
                    added = true
                }
            }
            if !added { break }
        }
        return out.shuffled()
    }

    /// ✓ / ✗ — a world's own short questions, each with its real answer or a
    /// distractor. The child sorts the statement.
    static func trueFalse(topic: Topic, grade: Int) -> SortSet? {
        let items = GameContent.items(topic: topic, grade: grade, maxPrompt: 45, maxAnswer: 18, standalone: true)
        guard items.count >= 6 else { return nil }
        let cards = items.prefix(roundItems).map { q -> SortItem in
            let right = Bool.random() || q.distractors.isEmpty
            return SortItem(emoji: "", label: q.prompt, detail: right ? q.answer : q.distractors.randomElement()!,
                            basket: right ? 0 : 1)
        }
        return SortSet(baskets: [SortBasket(emoji: "✓", label: tr("נָכוֹן")), SortBasket(emoji: "✗", label: tr("לֹא נָכוֹן"))],
                       items: Array(cards), topic: topic)
    }

    // MARK: Sets

    private static func numbers(grade: Int) -> SortSet {
        if grade >= 4 {
            let pool = Array(10...99).filter { $0 % 15 != 0 }.shuffled()
            let by3 = pool.filter { $0 % 3 == 0 }.prefix(5).map { i("", "\($0)", 0, ltr: true) }
            let by5 = pool.filter { $0 % 5 == 0 }.prefix(5).map { i("", "\($0)", 1, ltr: true) }
            let none = pool.filter { $0 % 3 != 0 && $0 % 5 != 0 }.prefix(5).map { i("", "\($0)", 2, ltr: true) }
            return SortSet(baskets: [SortBasket(emoji: "3️⃣", label: tr("מִתְחַלֵּק בְּ־3")),
                                     SortBasket(emoji: "5️⃣", label: tr("מִתְחַלֵּק בְּ־5")),
                                     SortBasket(emoji: "🚫", label: tr("לֹא בְּ־3 וְלֹא בְּ־5"))],
                           items: by3 + by5 + none, topic: .math)
        }
        let top = grade <= 1 ? 20 : (grade == 2 ? 100 : 200)
        let pool = Array(1...top).shuffled()
        let even = pool.filter { $0 % 2 == 0 }.prefix(7).map { i("", "\($0)", 0, ltr: true) }
        let odd = pool.filter { $0 % 2 == 1 }.prefix(7).map { i("", "\($0)", 1, ltr: true) }
        return SortSet(baskets: [SortBasket(emoji: "👯", label: tr("זוּגִי")), SortBasket(emoji: "🧍", label: tr("אִי־זוּגִי"))],
                       items: even + odd, topic: .math)
    }

    private static func english(grade: Int) -> SortSet {
        func w(_ s: String, _ b: Int) -> SortItem { i("", s, b, ltr: true) }
        if grade <= 3 {
            let animals = ["dog", "cat", "horse", "lion", "fish", "bird", "cow", "duck", "frog", "bear", "monkey", "sheep"]
            let food = ["apple", "bread", "milk", "cake", "egg", "pizza", "rice", "cheese", "banana", "soup", "carrot"]
            return SortSet(baskets: [SortBasket(emoji: "🐾", label: tr("חַיָּה")), SortBasket(emoji: "🍽️", label: tr("אֹכֶל"))],
                           items: animals.map { w($0, 0) } + food.map { w($0, 1) }, topic: .english)
        }
        let nouns = ["table", "book", "house", "tree", "school", "friend", "chair", "window", "garden", "river"]
        let verbs = ["eat", "write", "sing", "go", "come", "think", "bring", "speak", "take", "give"]
        let adjectives = ["happy", "big", "small", "beautiful", "tall", "quiet", "soft", "hungry", "brave", "angry"]
        var baskets = [SortBasket(emoji: "📦", label: tr("שֵׁם עֶצֶם")), SortBasket(emoji: "🏃", label: tr("פֹּעַל"))]
        var items = nouns.map { w($0, 0) } + verbs.map { w($0, 1) }
        if grade >= 5 {
            baskets.append(SortBasket(emoji: "🎨", label: tr("שֵׁם תֹּאַר")))
            items += adjectives.map { w($0, 2) }
        }
        return SortSet(baskets: baskets, items: items, topic: .english)
    }

    /// Hebrew words are the content itself — the same in every app language.
    private static func hebrew(grade: Int) -> SortSet {
        func w(_ s: String, _ b: Int) -> SortItem { i("", s, b) }
        switch grade {
        case ...2:
            let male = ["שֻׁלְחָן", "כִּסֵּא", "סֵפֶר", "כֶּלֶב", "עֵץ", "בַּיִת", "כַּדּוּר", "עִפָּרוֹן", "חַלּוֹן", "שָׁעוֹן"]
            let female = ["מְנוֹרָה", "מִטָּה", "חֻלְצָה", "בֻּבָּה", "מַחְבֶּרֶת", "שִׂמְלָה", "דֶּלֶת", "כַּפִּית", "מְכוֹנִית", "עוּגָה"]
            return SortSet(baskets: [SortBasket(emoji: "👦", label: tr("זָכָר")), SortBasket(emoji: "👧", label: tr("נְקֵבָה"))],
                           items: male.map { w($0, 0) } + female.map { w($0, 1) }, topic: .hebrew)
        case 3:
            let one = ["יֶלֶד", "פֶּרַח", "כּוֹבַע", "יַלְדָּה", "תַּפּוּחַ", "גַּן", "צִפּוֹר", "מַחְבֶּרֶת", "חָבֵר", "עָנָן"]
            let many = ["יְלָדִים", "פְּרָחִים", "כּוֹבָעִים", "יְלָדוֹת", "תַּפּוּחִים", "גַּנִּים", "צִפֳּרִים", "מַחְבָּרוֹת", "חֲבֵרִים", "עֲנָנִים"]
            return SortSet(baskets: [SortBasket(emoji: "☝️", label: tr("יָחִיד")), SortBasket(emoji: "🙌", label: tr("רַבִּים"))],
                           items: one.map { w($0, 0) } + many.map { w($0, 1) }, topic: .hebrew)
        default:
            let past = ["הָלַךְ", "אָכַל", "כָּתַב", "שִׂחֵק", "שָׁתָה", "צִיֵּר", "קָפַץ", "לָמַד"]
            let present = ["הוֹלֵךְ", "אוֹכֵל", "כּוֹתֵב", "מְשַׂחֵק", "שׁוֹתֶה", "מְצַיֵּר", "קוֹפֵץ", "לוֹמֵד"]
            let future = ["יֵלֵךְ", "יֹאכַל", "יִכְתֹּב", "יְשַׂחֵק", "יִשְׁתֶּה", "יְצַיֵּר", "יִקְפֹּץ", "יִלְמַד"]
            return SortSet(baskets: [SortBasket(emoji: "⏪", label: tr("עָבָר")), SortBasket(emoji: "⏺️", label: tr("הוֹוֶה")),
                                     SortBasket(emoji: "⏩", label: tr("עָתִיד"))],
                           items: past.map { w($0, 0) } + present.map { w($0, 1) } + future.map { w($0, 2) }, topic: .hebrew)
        }
    }

    private static func animals(grade: Int, topic: Topic) -> SortSet {
        if grade >= 4 {
            return SortSet(
                baskets: [SortBasket(emoji: "🐾", label: tr("יוֹנֵק")), SortBasket(emoji: "🪶", label: tr("עוֹף")),
                          SortBasket(emoji: "🐟", label: tr("דָּג"))],
                items: [
                    i("🐕", tr("כֶּלֶב"), 0), i("🦁", tr("אַרְיֵה"), 0), i("🐘", tr("פִּיל"), 0), i("🐳", tr("לִוְיָתָן"), 0),
                    i("🐬", tr("דּוֹלְפִין"), 0), i("🦇", tr("עֲטַלֵּף"), 0), i("🐄", tr("פָּרָה"), 0), i("🐒", tr("קוֹף"), 0),
                    i("🦅", tr("נֶשֶׁר"), 1), i("🦜", tr("תֻּכִּי"), 1), i("🐧", tr("פִּינְגְּוִין"), 1), i("🦉", tr("יַנְשׁוּף"), 1),
                    i("🐔", tr("תַּרְנְגֹלֶת"), 1), i("🦩", tr("פְּלָמִינְגּוֹ"), 1), i("🕊️", tr("יוֹנָה"), 1),
                    i("🦈", tr("כָּרִישׁ"), 2), i("🐠", tr("דַּג זָהָב"), 2), i("🐡", tr("אַבּוּ נַפְחָא"), 2),
                    i("🐟", tr("טוּנָה"), 2), i("🐟", tr("סַלְמוֹן"), 2),
                ],
                topic: topic)
        }
        return SortSet(
            baskets: [SortBasket(emoji: "🌊", label: tr("חַי בַּמַּיִם")), SortBasket(emoji: "🌳", label: tr("חַי בַּיַּבָּשָׁה"))],
            items: [
                i("🐟", tr("דָּג"), 0), i("🐙", tr("תְּמָנוּן"), 0), i("🦈", tr("כָּרִישׁ"), 0), i("🐳", tr("לִוְיָתָן"), 0),
                i("🐬", tr("דּוֹלְפִין"), 0), i("🪼", tr("מֵדוּזָה"), 0), i("⭐", tr("כּוֹכַב יָם"), 0), i("🐡", tr("אַבּוּ נַפְחָא"), 0),
                i("🦁", tr("אַרְיֵה"), 1), i("🐘", tr("פִּיל"), 1), i("🦒", tr("גִ'ירָפָה"), 1), i("🐄", tr("פָּרָה"), 1),
                i("🐎", tr("סוּס"), 1), i("🐒", tr("קוֹף"), 1), i("🐇", tr("אַרְנָב"), 1), i("🐫", tr("גָּמָל"), 1),
                i("🦓", tr("זֶבְּרָה"), 1),
            ],
            topic: topic)
    }

    private static func planets() -> SortSet {
        let b = BalloonSets.planets()
        return SortSet(baskets: [SortBasket(emoji: "🪐", label: tr("כּוֹכַב לֶכֶת")), SortBasket(emoji: "✨", label: tr("לֹא כּוֹכַב לֶכֶת"))],
                       items: b.targets.map { i($0.emoji, $0.label, 0) } + b.others.map { i($0.emoji, $0.label, 1) },
                       topic: .space)
    }

    private static func dinosaurs() -> SortSet {
        SortSet(
            baskets: [SortBasket(emoji: "🌿", label: tr("אוֹכֵל צְמָחִים")), SortBasket(emoji: "🍖", label: tr("אוֹכֵל בָּשָׂר"))],
            items: [
                i("🦴", tr("טְרִיצֶרָטוֹפְּס"), 0), i("🦴", tr("סְטֶגוֹזָאוּרוּס"), 0), i("🦕", tr("בְּרָכִיוֹזָאוּרוּס"), 0),
                i("🦕", tr("דִּיפְּלוֹדוֹקוּס"), 0), i("🦴", tr("אַנְקִילוֹזָאוּרוּס"), 0), i("🦕", tr("פָּרָזָאוּרוֹלוֹפוּס"), 0),
                i("🦖", tr("טִירָנוֹזָאוּרוּס"), 1), i("🦖", tr("וֶלוֹצִירַפְּטוֹר"), 1), i("🦖", tr("סְפִּינוֹזָאוּרוּס"), 1),
                i("🦖", tr("אַלוֹזָאוּרוּס"), 1), i("🦖", tr("דִּילוֹפוֹזָאוּרוּס"), 1),
            ],
            topic: .dinosaurs)
    }

    private static func soccer() -> SortSet {
        let b = BalloonSets.soccer()
        return SortSet(baskets: [SortBasket(emoji: "⚽", label: tr("כַּדּוּרֶגֶל")), SortBasket(emoji: "🏅", label: tr("עֲנַף סְפּוֹרְט אַחֵר"))],
                       items: b.targets.map { i($0.emoji, $0.label, 0) } + b.others.map { i($0.emoji, $0.label, 1) },
                       topic: .soccer)
    }

    private static func places(grade: Int, topic: Topic) -> SortSet {
        let europe = [i("🇫🇷", tr("צָרְפַת"), 0), i("🇮🇹", tr("אִיטַלְיָה"), 0), i("🇪🇸", tr("סְפָרַד"), 0),
                      i("🇩🇪", tr("גֶּרְמַנְיָה"), 0), i("🇬🇷", tr("יָוָן"), 0), i("🇳🇱", tr("הוֹלַנְד"), 0)]
        let asia = [i("🇯🇵", tr("יַפָּן"), 1), i("🇨🇳", tr("סִין"), 1), i("🇮🇳", tr("הֹדּוּ"), 1),
                    i("🇹🇭", tr("תָּאִילַנְד"), 1), i("🇰🇷", tr("דְּרוֹם קוֹרֵאָה"), 1)]
        let america = [i("🇺🇸", tr("אַרְצוֹת הַבְּרִית"), 2), i("🇨🇦", tr("קָנָדָה"), 2), i("🇧🇷", tr("בְּרָזִיל"), 2),
                       i("🇦🇷", tr("אַרְגֶּנְטִינָה"), 2), i("🇲🇽", tr("מֶקְסִיקוֹ"), 2)]
        if grade >= 4 {
            return SortSet(baskets: [SortBasket(emoji: "🏰", label: tr("אֵירוֹפָּה")), SortBasket(emoji: "🏯", label: tr("אַסְיָה")),
                                     SortBasket(emoji: "🗽", label: tr("אֲמֶרִיקָה"))],
                           items: europe + asia + america, topic: topic)
        }
        // An Israeli child sorts cities: here or abroad. (An American child gets
        // Europe or not — "Israel or abroad" means nothing at home in Ohio.)
        if grade <= 2, LanguageStore.shared.current.isIsraeli {
            let here = [tr("חֵיפָה"), tr("תֵּל אָבִיב"), tr("אֵילַת"), tr("בְּאֵר שֶׁבַע"), tr("נָצְרַת"), tr("עַכּוֹ"), tr("טְבֶרְיָה"), tr("נְתַנְיָה")]
            let away = [("🇫🇷", tr("פָּרִיז")), ("🇬🇧", tr("לוֹנְדוֹן")), ("🇮🇹", tr("רוֹמָא")), ("🇯🇵", tr("טוֹקְיוֹ")),
                        ("🇺🇸", tr("נְיוּ יוֹרְק")), ("🇪🇬", tr("קָהִיר")), ("🇪🇸", tr("מַדְרִיד")), ("🇩🇪", tr("בֶּרְלִין"))]
            return SortSet(baskets: [SortBasket(emoji: "🏠", label: tr("בְּיִשְׂרָאֵל")), SortBasket(emoji: "✈️", label: tr("בְּחוּץ לָאָרֶץ"))],
                           items: here.map { i("🏙️", $0, 0) } + away.map { i($0.0, $0.1, 1) }, topic: topic)
        }
        return SortSet(baskets: [SortBasket(emoji: "🏰", label: tr("אֵירוֹפָּה")), SortBasket(emoji: "🌏", label: tr("לֹא בְּאֵירוֹפָּה"))],
                       items: europe + (asia + america).map { i($0.emoji, $0.label, 1) }, topic: topic)
    }

    private static func science(grade: Int) -> SortSet {
        if grade >= 4 {
            return SortSet(
                baskets: [SortBasket(emoji: "🧊", label: tr("מוּצָק")), SortBasket(emoji: "💧", label: tr("נוֹזֵל")),
                          SortBasket(emoji: "💨", label: tr("גַּז"))],
                items: [
                    i("🧊", tr("קֶרַח"), 0), i("🪨", tr("אֶבֶן"), 0), i("🪵", tr("קֶרֶשׁ"), 0), i("🪙", tr("מַטְבֵּעַ"), 0), i("🧱", tr("לְבֵנָה"), 0),
                    i("💧", tr("מַיִם"), 1), i("🥛", tr("חָלָב"), 1), i("🧃", tr("מִיץ"), 1), i("🫒", tr("שֶׁמֶן זַיִת"), 1), i("🍯", tr("דְּבַשׁ"), 1),
                    i("♨️", tr("אֵדִים"), 2), i("🌬️", tr("אֲוִיר"), 2), i("🎈", tr("הֶלְיוּם"), 2), i("🫁", tr("חַמְצָן"), 2),
                ],
                topic: .science)
        }
        return SortSet(
            baskets: [SortBasket(emoji: "🌱", label: tr("חַי")), SortBasket(emoji: "🪨", label: tr("דּוֹמֵם"))],
            items: [
                i("🐕", tr("כֶּלֶב"), 0), i("🌳", tr("עֵץ"), 0), i("🌸", tr("פֶּרַח"), 0), i("🐦", tr("צִפּוֹר"), 0),
                i("🐟", tr("דָּג"), 0), i("🍄", tr("פִּטְרִיָּה"), 0), i("🐜", tr("נְמָלָה"), 0),
                i("🪨", tr("אֶבֶן"), 1), i("🪑", tr("כִּסֵּא"), 1), i("🚗", tr("מְכוֹנִית"), 1), i("⚽", tr("כַּדּוּר"), 1),
                i("🥤", tr("כּוֹס"), 1), i("✏️", tr("עִפָּרוֹן"), 1), i("☁️", tr("עָנָן"), 1),
            ],
            topic: .science)
    }

    private static func body() -> SortSet {
        SortSet(
            baskets: [SortBasket(emoji: "🫀", label: tr("בְּתוֹךְ הַגּוּף")), SortBasket(emoji: "✋", label: tr("מִבַּחוּץ"))],
            items: [
                i("🫀", tr("לֵב"), 0), i("🫁", tr("רֵאוֹת"), 0), i("🧠", tr("מֹחַ"), 0), i("🍽️", tr("קֵבָה"), 0),
                i("🩸", tr("כָּבֵד"), 0), i("🫘", tr("כְּלָיוֹת"), 0),
                i("✋", tr("יָד"), 1), i("👃", tr("אַף"), 1), i("👂", tr("אֹזֶן"), 1), i("🦶", tr("כַּף רֶגֶל"), 1),
                i("👁️", tr("עַיִן"), 1), i("🦵", tr("בֶּרֶךְ"), 1),
            ],
            topic: .body)
    }

    private static func vehicles(grade: Int) -> SortSet {
        let land = [i("🚗", tr("מְכוֹנִית"), 0), i("🚌", tr("אוֹטוֹבּוּס"), 0), i("🚆", tr("רַכֶּבֶת"), 0),
                    i("🚲", tr("אוֹפַנַּיִם"), 0), i("🚚", tr("מַשָּׂאִית"), 0), i("🏍️", tr("אוֹפְנוֹעַ"), 0)]
        let air = [i("✈️", tr("מָטוֹס"), 1), i("🚁", tr("מַסּוֹק"), 1), i("🎈", tr("כַּדּוּר פּוֹרֵחַ"), 1),
                   i("🪂", tr("מִצְנָח"), 1), i("🛩️", tr("מָטוֹס קַל"), 1)]
        let water = [i("🚢", tr("אֳנִיָּה"), 2), i("⛵", tr("מִפְרָשִׂית"), 2), i("🛶", tr("קָנוּ"), 2),
                     i("🚤", tr("סִירַת מָנוֹעַ"), 2), i("🌊", tr("צוֹלֶלֶת"), 2)]
        var baskets = [SortBasket(emoji: "🛣️", label: tr("בַּיַּבָּשָׁה")), SortBasket(emoji: "☁️", label: tr("בָּאֲוִיר"))]
        var items = land + air
        if grade >= 3 {
            baskets.append(SortBasket(emoji: "🌊", label: tr("בַּמַּיִם")))
            items += water
        }
        return SortSet(baskets: baskets, items: items, topic: .vehicles)
    }

    private static func music(grade: Int) -> SortSet {
        let strings = [i("🎸", tr("גִּיטָרָה"), 0), i("🎻", tr("כִּנּוֹר"), 0), i("🪕", tr("בַּנְגּ'וֹ"), 0), i("🎼", tr("נֵבֶל"), 0)]
        let drums = [i("🥁", tr("תֻּפִּים"), 1), i("🪘", tr("דַּרְבּוּקָה"), 1), i("🔔", tr("מְצִלְתַּיִם"), 1),
                     i("🎶", tr("קְסִילוֹפוֹן"), 1), i("", tr("מָרָקָס"), 1)]
        let wind = [i("🎺", tr("חֲצוֹצְרָה"), 2), i("🎷", tr("סַקְסוֹפוֹן"), 2), i("", tr("חָלִיל"), 2), i("🎵", tr("קְלַרְנִית"), 2)]
        var baskets = [SortBasket(emoji: "🎻", label: tr("כְּלֵי מֵיתָרִים")), SortBasket(emoji: "🥁", label: tr("כְּלֵי הַקָּשָׁה"))]
        var items = strings + drums
        if grade >= 3 {
            baskets.append(SortBasket(emoji: "🎺", label: tr("כְּלֵי נְשִׁיפָה")))
            items += wind
        }
        return SortSet(baskets: baskets, items: items, topic: .music)
    }

    private static func food() -> SortSet {
        SortSet(
            baskets: [SortBasket(emoji: "🍎", label: tr("פְּרִי")), SortBasket(emoji: "🥕", label: tr("יָרָק"))],
            items: [
                i("🍎", tr("תַּפּוּחַ"), 0), i("🍌", tr("בָּנָנָה"), 0), i("🍇", tr("עֲנָבִים"), 0), i("🍓", tr("תּוּת"), 0),
                i("🍊", tr("תַּפּוּז"), 0), i("🍉", tr("אֲבַטִּיחַ"), 0), i("🍍", tr("אֲנָנָס"), 0), i("🍒", tr("דֻּבְדְּבָנִים"), 0),
                i("🥕", tr("גֶּזֶר"), 1), i("🥦", tr("בְּרוֹקוֹלִי"), 1), i("🥬", tr("חַסָּה"), 1), i("🥔", tr("תַּפּוּחַ אֲדָמָה"), 1),
                i("🧅", tr("בָּצָל"), 1), i("🧄", tr("שׁוּם"), 1),
            ],
            topic: .food)
    }

    private static func money(grade: Int) -> SortSet {
        if grade >= 4 {
            return SortSet(
                baskets: [SortBasket(emoji: "💰", label: tr("הַכְנָסָה")), SortBasket(emoji: "💸", label: tr("הוֹצָאָה"))],
                items: [
                    i("💼", tr("מַשְׂכֹּרֶת"), 0), i("🪙", tr("דְּמֵי כִּיס"), 0), i("🎁", tr("כֶּסֶף שֶׁקִּבַּלְנוּ בְּמַתָּנָה"), 0),
                    i("🍋", tr("מְכִירַת לִימוֹנָדָה"), 0), i("🏆", tr("פְּרָס בְּתַחֲרוּת"), 0),
                    i("🏠", tr("שְׂכַר דִּירָה"), 1), i("🛒", tr("קְנִיּוֹת בַּסּוּפֶּר"), 1), i("💡", tr("חֶשְׁבּוֹן חַשְׁמַל"), 1),
                    i("🎬", tr("כַּרְטִיס לַקּוֹלְנוֹעַ"), 1), i("🧸", tr("קְנִיַּת צַעֲצוּעַ"), 1),
                ],
                topic: .money)
        }
        return SortSet(
            baskets: [SortBasket(emoji: "✅", label: tr("צְרִיכִים")), SortBasket(emoji: "💭", label: tr("רַק רוֹצִים"))],
            items: [
                i("🍞", tr("לֶחֶם"), 0), i("💧", tr("מַיִם"), 0), i("🥛", tr("חָלָב"), 0), i("💊", tr("תְּרוּפָה"), 0),
                i("🎒", tr("תִּיק לְבֵית הַסֵּפֶר"), 0), i("🧥", tr("מְעִיל לַחֹרֶף"), 0),
                i("🍭", tr("סֻכָּרִיָּה"), 1), i("🧸", tr("דֻּבִּי"), 1), i("🎮", tr("מִשְׂחַק מַחְשֵׁב"), 1), i("🍦", tr("גְּלִידָה"), 1),
                i("🪀", tr("יוֹ־יוֹ"), 1), i("🎈", tr("בָּלוֹן"), 1),
            ],
            topic: .money)
    }
}

// MARK: - 🧠 Patterns

struct PatternRound {
    /// The sequence, "?" where the missing piece goes.
    let cells: [String]
    let answer: String
    let options: [String]
    /// Numbers read left-to-right; letters follow their script; pictures LTR.
    let direction: LayoutDirection
    let topic: Topic
}

enum PatternGen {
    static let roundCount = 6

    /// A theme's own pictures for a picture pattern.
    static func pictures(for topic: Topic?) -> [String] {
        switch topic {
        case .soccer?:    return ["⚽", "🥅", "🧤", "🏆"]
        case .sea?:       return ["🐟", "🐙", "🦀", "🐬"]
        case .space?:     return ["🌍", "🪐", "☀️", "🌙"]
        case .animals?:   return ["🐶", "🐱", "🐰", "🦁"]
        case .dinosaurs?: return ["🦖", "🦕", "🥚", "🦴"]
        case .flags?:     return ["🇫🇷", "🇯🇵", "🇧🇷", "🇮🇹"]
        default:          return ["🔴", "🔵", "🟡", "🟢"]
        }
    }

    static func make(topic: Topic?, grade: Int) -> PatternRound {
        let g = max(1, grade)
        switch topic {
        case .english?: return letters(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init), grade: g, dir: .leftToRight, topic: .english)
        case .hebrew?:  return letters(Array("אבגדהוזחטיכלמנסעפצקרשת").map(String.init), grade: g, dir: .rightToLeft, topic: .hebrew)
        case .math?, .logic?, .gifted?, .money?, nil:
            // Pictures for the youngest, and now and then in the logic worlds.
            let pictureChance = g <= 1 ? 0.5 : ((topic == .logic || topic == .gifted) && g <= 4 ? 0.3 : 0)
            if Double.random(in: 0..<1) < pictureChance { return picture(pictures(for: topic), grade: g, topic: topic ?? .logic) }
            return numbers(grade: g, topic: topic ?? .math)
        default:
            // A theme world (surprise rounds): its own pictures.
            return picture(pictures(for: topic), grade: g, topic: topic ?? .logic)
        }
    }

    private static func options(answer: Int, near: [Int]) -> [String] {
        var set: Set<Int> = [answer]
        for n in near.shuffled() where set.count < 4 && n != answer { set.insert(n) }
        var d = 1
        while set.count < 4 { set.insert(answer + (Bool.random() ? d : -d)); d += 1 }
        return set.map(MathFacts.show).shuffled()
    }

    private static func numbers(grade g: Int, topic: Topic) -> PatternRound {
        var seq: [Int] = []
        var near: [Int] = []
        switch g {
        case 1:
            let k = [1, 2, 5, 10].randomElement()!, a = Int.random(in: 0...10)
            seq = (0..<5).map { a + $0 * k }
        case 2:
            let k = Int.random(in: 2...10), a = Int.random(in: 1...20)
            seq = Bool.random() ? (0..<5).map { a + $0 * k } : (0..<5).map { a + 4 * k - $0 * k }
        case 3:
            switch Int.random(in: 0...2) {
            case 0:
                let k = Int.random(in: 3...12), a = Int.random(in: 1...30)
                seq = (0..<6).map { a + $0 * k }
            case 1:
                let a = Int.random(in: 1...5)
                seq = (0..<5).map { a << $0 }
            default:
                let x = Int.random(in: 2...5), y = Int.random(in: 1...4), a = Int.random(in: 1...10)
                var v = a
                seq = [v]
                for i in 0..<5 { v += i % 2 == 0 ? x : y; seq.append(v) }
            }
        case 4, 5, 6:
            switch Int.random(in: 0...3) {
            case 0:
                let m = [2, 3].randomElement()!, a = Int.random(in: 1...4)
                seq = (0..<5).map { a * Int(pow(Double(m), Double($0))) }
            case 1:
                let s = Int.random(in: 1...4)
                seq = (s..<(s + 5)).map { $0 * $0 }
            case 2:
                var a = Int.random(in: 1...3), b = Int.random(in: 2...5)
                seq = [a, b]
                for _ in 0..<4 { let c = a + b; seq.append(c); a = b; b = c }
            default:
                let k = Int.random(in: 6...25), a = Int.random(in: 20...150)
                seq = (0..<6).map { a - $0 * k }
            }
        default:
            switch Int.random(in: 0...3) {
            case 0:
                let s = Int.random(in: 1...3)
                seq = (s..<(s + 5)).map { $0 * $0 * $0 }
            case 1:
                let a = Int.random(in: 1...3)
                seq = (0..<6).map { a * Int(pow(-2.0, Double($0))) }
            case 2:
                var a = Int.random(in: 2...5), b = Int.random(in: 3...7)
                seq = [a, b]
                for _ in 0..<4 { let c = a + b; seq.append(c); a = b; b = c }
            default:
                let k = Int.random(in: 4...9), a = Int.random(in: 5...20)
                seq = (0..<6).map { a - $0 * k }   // into the negatives
            }
        }
        // The hole: the end, or (from ג׳) somewhere in the middle.
        let hole = g >= 3 && Bool.random() ? Int.random(in: 1..<(seq.count - 1)) : seq.count - 1
        let answer = seq[hole]
        let step = seq.count > 1 ? abs(seq[1] - seq[0]) : 1
        near = [answer + step, answer - step, answer + 1, answer - 1, answer * 2, seq[max(0, hole - 1)]]
        if g < 7 { near = near.filter { $0 >= 0 } }
        var cells = seq.map(MathFacts.show)
        cells[hole] = "?"
        return PatternRound(cells: cells, answer: MathFacts.show(answer), options: options(answer: answer, near: near),
                            direction: .leftToRight, topic: topic)
    }

    private static func letters(_ abc: [String], grade g: Int, dir: LayoutDirection, topic: Topic) -> PatternRound {
        let step = g <= 2 ? 1 : (g <= 4 ? 2 : 3)
        let length = 5
        let maxStart = abc.count - 1 - step * (length - 1)
        let start = Int.random(in: 0...max(0, maxStart))
        let seq = (0..<length).map { abc[start + $0 * step] }
        let hole = g >= 3 && Bool.random() ? Int.random(in: 1..<(length - 1)) : length - 1
        let answerIndex = start + hole * step
        var opts: Set<String> = [abc[answerIndex]]
        for d in [1, -1, step + 1, -(step + 1), 2, -2].shuffled() where opts.count < 4 {
            let j = answerIndex + d
            if abc.indices.contains(j) { opts.insert(abc[j]) }
        }
        var cells = seq
        cells[hole] = "?"
        return PatternRound(cells: cells, answer: abc[answerIndex], options: opts.shuffled(), direction: dir, topic: topic)
    }

    private static func picture(_ set: [String], grade g: Int, topic: Topic) -> PatternRound {
        let shapes = Array(set.shuffled().prefix(3))
        let units: [[Int]] = g <= 1 ? [[0, 1], [0, 0, 1]] : [[0, 1], [0, 0, 1], [0, 1, 2], [0, 1, 1], [0, 1, 2, 1]]
        let unit = units.randomElement()!
        let length = min(8, max(6, unit.count * 2 + 1))
        let seq = (0..<length).map { shapes[unit[$0 % unit.count]] }
        let hole = length - 1
        var cells = seq
        cells[hole] = "?"
        let opts = Array(Set(shapes + [set.first { !shapes.contains($0) } ?? shapes[0]])).shuffled()
        return PatternRound(cells: cells, answer: seq[hole], options: opts, direction: .leftToRight, topic: topic)
    }
}

// MARK: - 🔢 2048

struct Tile2048: Identifiable, Equatable {
    let id: UUID
    var value: Int
    var r: Int
    var c: Int
    /// Grew this move — shows half its value until the slide settles, then pops.
    var merged = false
}

enum Move2048 { case left, right, up, down }

enum Board2048 {
    static let size = 4

    /// Slides every tile; equal neighbours merge once. Returns the survivors
    /// (merged ones carry their NEW value), the tiles swallowed (moved onto
    /// their partner's cell, to animate there and vanish), and the points.
    static func slide(_ tiles: [Tile2048], _ dir: Move2048) -> (tiles: [Tile2048], consumed: [Tile2048], moved: Bool, points: Int) {
        let n = size
        var out: [Tile2048] = []
        var consumed: [Tile2048] = []
        var points = 0
        var moved = false
        for line in 0..<n {
            var lineTiles: [Tile2048]
            switch dir {
            case .left:  lineTiles = tiles.filter { $0.r == line }.sorted { $0.c < $1.c }
            case .right: lineTiles = tiles.filter { $0.r == line }.sorted { $0.c > $1.c }
            case .up:    lineTiles = tiles.filter { $0.c == line }.sorted { $0.r < $1.r }
            case .down:  lineTiles = tiles.filter { $0.c == line }.sorted { $0.r > $1.r }
            }
            var placed: [Tile2048] = []
            for var t in lineTiles {
                t.merged = false
                if var last = placed.last, last.value == t.value, !last.merged {
                    last.value *= 2
                    last.merged = true
                    points += last.value
                    placed[placed.count - 1] = last
                    var gone = t
                    gone.r = last.r; gone.c = last.c
                    consumed.append(gone)
                    moved = true
                } else {
                    let i = placed.count
                    let (r, c): (Int, Int)
                    switch dir {
                    case .left:  (r, c) = (line, i)
                    case .right: (r, c) = (line, n - 1 - i)
                    case .up:    (r, c) = (i, line)
                    case .down:  (r, c) = (n - 1 - i, line)
                    }
                    if t.r != r || t.c != c { moved = true }
                    t.r = r; t.c = c
                    placed.append(t)
                }
            }
            out += placed
        }
        return (out, consumed, moved, points)
    }

    static func emptyCells(_ tiles: [Tile2048]) -> [(Int, Int)] {
        let taken = Set(tiles.map { $0.r * size + $0.c })
        return (0..<(size * size)).filter { !taken.contains($0) }.map { ($0 / size, $0 % size) }
    }

    static func canMove(_ tiles: [Tile2048]) -> Bool {
        if tiles.count < size * size { return true }
        for t in tiles {
            if tiles.contains(where: { ($0.r == t.r && $0.c == t.c + 1 || $0.c == t.c && $0.r == t.r + 1) && $0.value == t.value }) {
                return true
            }
        }
        return false
    }

    /// The app's own palette, warming up as the tiles grow.
    static func color(_ value: Int) -> Color {
        switch value {
        case ...2:   return Color(hex: "48BFE3")
        case 4:      return Color(hex: "9B5DE5")
        case 8:      return Color(hex: "FF6B9D")
        case 16:     return Color(hex: "FFB84D")
        case 32:     return Color(hex: "06D6A0")
        case 64:     return Color(hex: "3A86FF")
        case 128:    return Color(hex: "F15BB5")
        case 256:    return Color(hex: "FF9F1C")
        default:     return AppColor.starGold
        }
    }

    static func bestKey() -> String { "g2048.best." + (ProfileStore.shared.activeID?.uuidString ?? "none") }
}

// MARK: - 🔐 The vault

enum VaultMark { case exact, present, absent }

enum VaultGen {
    static let maxTries = 6

    static func digits(grade: Int) -> Int { grade >= 4 ? 4 : 3 }

    /// Distinct digits; never a leading 0 (a "code" that starts with 0 reads oddly).
    static func code(grade: Int) -> [Int] {
        var pool = Array(0...9).shuffled()
        if pool.first == 0 { pool.swapAt(0, 1) }
        return Array(pool.prefix(digits(grade: grade)))
    }

    static func feedback(guess: [Int], code: [Int]) -> [VaultMark] {
        guess.enumerated().map { i, d in
            if code.indices.contains(i), code[i] == d { return .exact }
            return code.contains(d) ? .present : .absent
        }
    }

    static func positionName(_ i: Int) -> String {
        switch i {
        case 0:  return tr("הַסְּפָרָה הָרִאשׁוֹנָה")
        case 1:  return tr("הַסְּפָרָה הַשְּׁנִיָּה")
        case 2:  return tr("הַסְּפָרָה הַשְּׁלִישִׁית")
        default: return tr("הַסְּפָרָה הָרְבִיעִית")
        }
    }

    /// An exercise whose answer is the digit `d` — sized to the grade.
    static func expression(for d: Int, grade g: Int) -> String {
        switch g {
        case ...1:
            let a = Int.random(in: 0...d)
            return "\(a) + \(d - a)"
        case 2:
            if Bool.random() { let b = Int.random(in: 1...9); return "\(d + b) − \(b)" }
            let a = Int.random(in: 0...d); return "\(a) + \(d - a)"
        case 3:
            let factors = (2...9).filter { d % $0 == 0 && d / $0 >= 1 && $0 < d }
            if let f = factors.randomElement() { return "\(f) × \(d / f)" }
            let b = Int.random(in: 2...9); return "\(d + b) − \(b)"
        case 4...6:
            let k = Int.random(in: 2...9)
            if d > 0, Bool.random() { return "\(d * k) ÷ \(k)" }
            let a = Int.random(in: 2...5), c = a * Int.random(in: 2...5)
            return "\(c) ÷ \(a) + \(d - c / a)".replacingOccurrences(of: "+ -", with: "− ")
        default:
            if d >= 2, Bool.random() { return "√\(d * d)" }
            let a = Int.random(in: 2...9)
            return "(−\(a)) + \(d + a)"
        }
    }

    /// The math key card: "הַסְּפָרָה הָרִאשׁוֹנָה = 3 × 2" and four digits.
    static func clue(code: [Int], position i: Int, grade: Int) -> GameItem {
        let d = code[i]
        var opts: Set<Int> = [d]
        for x in [d + 1, d - 1, d + 2, d - 2, d + 3].shuffled() where opts.count < 4 && (0...9).contains(x) { opts.insert(x) }
        while opts.count < 4 { opts.insert(Int.random(in: 0...9)) }
        return GameItem(prompt: positionName(i) + " = " + MiniGameText.ltr(expression(for: d, grade: grade)),
                        answer: "\(d)", distractors: opts.subtracting([d]).map { "\($0)" }, topic: .math)
    }
}

// MARK: - 🛒 The grocery

struct GroceryProduct: Hashable {
    let emoji: String
    /// The Hebrew name — read as-is in the Hebrew world.
    let hebrew: String
    let english: String
}

struct GroceryShelfItem: Identifiable, Hashable {
    let id = UUID()
    let product: GroceryProduct
    /// Agorot / cents — exact arithmetic.
    let price: Int
    /// "20% הֲנָחָה" — the price at the till is `price × (100 − discount) / 100`.
    var discount: Int = 0
    var finalPrice: Int { price * (100 - discount) / 100 }
}

struct GroceryTrip {
    let budget: Int
    let list: [GroceryShelfItem]
    let shelf: [GroceryShelfItem]
    let decimals: Bool
}

enum GroceryGen {
    static func products() -> [GroceryProduct] {
        func p(_ e: String, _ h: String, _ en: String) -> GroceryProduct { GroceryProduct(emoji: e, hebrew: h, english: en) }
        return [p("🥛", "חָלָב", "milk"), p("🍞", "לֶחֶם", "bread"), p("🍎", "תַּפּוּחַ", "apple"), p("🍌", "בָּנָנָה", "banana"),
                p("🧀", "גְּבִינָה", "cheese"), p("🥚", "בֵּיצִים", "eggs"), p("🍫", "שׁוֹקוֹלָד", "chocolate"),
                p("🍪", "עוּגִיּוֹת", "cookies"), p("🧃", "מִיץ", "juice"), p("🥒", "מְלָפְפוֹן", "cucumber"),
                p("🍅", "עַגְבָנִיָּה", "tomato"), p("🍉", "אֲבַטִּיחַ", "watermelon"), p("🍦", "גְּלִידָה", "ice cream"),
                p("🍝", "פַּסְטָה", "pasta"), p("🍚", "אֹרֶז", "rice"), p("🥕", "גֶּזֶר", "carrot")]
    }

    /// The name on the shelf / list in the child's own language.
    static func localName(_ p: GroceryProduct) -> String {
        switch p.english {
        case "milk": return tr("חָלָב")
        case "bread": return tr("לֶחֶם")
        case "apple": return tr("תַּפּוּחַ")
        case "banana": return tr("בָּנָנָה")
        case "cheese": return tr("גְּבִינָה")
        case "eggs": return tr("בֵּיצִים")
        case "chocolate": return tr("שׁוֹקוֹלָד")
        case "cookies": return tr("עוּגִיּוֹת")
        case "juice": return tr("מִיץ")
        case "cucumber": return tr("מְלָפְפוֹן")
        case "tomato": return tr("עַגְבָנִיָּה")
        case "watermelon": return tr("אֲבַטִּיחַ")
        case "ice cream": return tr("גְּלִידָה")
        case "pasta": return tr("פַּסְטָה")
        case "rice": return tr("אֹרֶז")
        default: return tr("גֶּזֶר")
        }
    }

    /// "4.50 ₪" / "$4.50" / "7 ₪".
    static func money(_ cents: Int) -> String {
        let whole = cents / 100, frac = abs(cents % 100)
        let n = frac == 0 ? "\(whole)" : String(format: "%d.%02d", whole, frac)
        return Money.answerPrefix + n + Money.answerSuffix
    }

    /// A typed amount ("4.5", "4.50", "12") in cents, or nil.
    static func cents(_ typed: String) -> Int? {
        guard !typed.isEmpty else { return nil }
        let parts = typed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, let whole = Int(parts[0].isEmpty ? "0" : String(parts[0])) else { return nil }
        guard parts.count == 2 else { return whole * 100 }
        let f = String(parts[1])
        guard f.count <= 2, f.isEmpty || Int(f) != nil else { return nil }
        let fracCents = f.isEmpty ? 0 : (f.count == 1 ? Int(f)! * 10 : Int(f)!)
        return whole * 100 + fracCents
    }

    static func trip(grade g: Int) -> GroceryTrip {
        let all = products().shuffled()
        let listCount = g <= 1 ? 2 : 3
        let decimals = g >= 4
        func price() -> Int {
            switch g {
            case ...1: return Int.random(in: 1...5) * 100
            case 2:    return Int.random(in: 2...12) * 100
            case 3:    return Int.random(in: 3...25) * 100
            default:   return Int.random(in: 4...30) * 100 + (Bool.random() ? 50 : 0)
            }
        }
        var list = all.prefix(listCount).map { GroceryShelfItem(product: $0, price: price()) }
        // ה׳+: one item is on sale — the till price is the child's to work out.
        if g >= 5, let idx = list.indices.randomElement() {
            let (base, off): (Int, Int) = [(Int.random(in: 1...4) * 1000, [10, 20].randomElement()!),
                                           ([8, 12, 16, 20].randomElement()! * 100, 25),
                                           (Int.random(in: 2...15) * 200, 50)].randomElement()!
            list[idx] = GroceryShelfItem(product: list[idx].product, price: base, discount: off)
        }
        let extras = all.dropFirst(listCount).prefix(g <= 1 ? 2 : 3).map { GroceryShelfItem(product: $0, price: price()) }
        let total = list.map(\.finalPrice).reduce(0, +)
        // A budget the list fits in, with change to work out — never exact.
        let steps = g <= 1 ? [1000, 2000] : (g == 2 ? [2000, 3000, 5000] : (g == 3 ? [5000, 10000] : [5000, 10000, 20000]))
        let budget = steps.first { $0 > total } ?? (total / 1000 + 1) * 1000
        return GroceryTrip(budget: budget, list: Array(list), shelf: (list + extras).shuffled(), decimals: decimals)
    }
}

// MARK: - ⚖️ The balance

/// One balance: what each pan holds, how heavy each side is for a given value
/// of the missing piece, and the piece itself.
struct BalancePuzzle {
    let left: String
    let right: String
    /// Shown above the pans — the equation's letter, or the world's question.
    var question: String? = nil
    let answer: String
    let options: [String]
    /// Weights for a value of "?" (Double: fractions and decimals too).
    let weigh: (Double) -> (left: Double, right: Double)
    /// The value each option string stands for.
    let value: (String) -> Double?
    /// Type the answer instead of picking it (older grades, whole numbers).
    var numberPad = false
    let topic: Topic
}

enum BalanceGen {
    static let roundCount = 5

    private static func intOptions(_ x: Int, allowNegative: Bool) -> [String] {
        var set: Set<Int> = [x]
        for d in [1, -1, 2, -2, 3, 5, -3, 10].shuffled() where set.count < 4 {
            let c = x + d
            if allowNegative || c >= 0 { set.insert(c) }
        }
        return set.map(MathFacts.show).shuffled()
    }

    nonisolated private static func intValue(_ s: String) -> Double? {
        GameContent.number(s).map(Double.init)
    }

    /// A computed balance, sized to the grade: א׳ "7 + ? | 10" up to ז׳–ח׳
    /// "3x + 2 | 14" and "2x − 5 | x + 3"; ה׳–ו׳ fractions and decimals.
    static func make(grade g: Int, topic: Topic) -> BalancePuzzle {
        let swap = Bool.random()
        func puzzle(_ l: String, _ r: String, x: Int, question: String? = nil, negative: Bool = false,
                    pad: Bool = false, _ weigh: @escaping (Double) -> (Double, Double)) -> BalancePuzzle {
            // Now and then the missing piece sits in the right pan.
            let (pl, pr) = swap ? (r, l) : (l, r)
            return BalancePuzzle(left: pl, right: pr, question: question, answer: MathFacts.show(x),
                                 options: intOptions(x, allowNegative: negative),
                                 weigh: { v in let w = weigh(v); return swap ? (w.1, w.0) : (w.0, w.1) },
                                 value: intValue, numberPad: pad, topic: topic)
        }
        switch g {
        case ...1:
            let total = Int.random(in: 5...10), a = Int.random(in: 1..<total), x = total - a
            return puzzle("\(a) + ?", "\(total)", x: x) { v in (Double(a) + v, Double(total)) }
        case 2:
            let c = Int.random(in: 3...15), d = Int.random(in: 2...15), a = Int.random(in: 1..<(c + d)), x = c + d - a
            if Bool.random() {
                return puzzle("\(a) + ?", "\(c) + \(d)", x: x) { v in (Double(a) + v, Double(c + d)) }
            }
            let big = Int.random(in: 12...30), y = Int.random(in: 2...(big - 2))
            return puzzle("\(big) − ?", "\(big - y)", x: y) { v in (Double(big) - v, Double(big - y)) }
        case 3:
            let a = Int.random(in: 2...9), x = Int.random(in: 2...10)
            if Bool.random() {
                return puzzle("\(a) × ?", "\(a * x)", x: x) { v in (Double(a) * v, Double(a * x)) }
            }
            let c = Int.random(in: 2...6), d = Int.random(in: 2...6), b = Int.random(in: 1..<(c * d)), y = c * d - b
            return puzzle("? + \(b)", "\(c) × \(d)", x: y) { v in (v + Double(b), Double(c * d)) }
        case 4:
            let a = Int.random(in: 3...9), x = Int.random(in: 3...12), extra = Int.random(in: 2...20)
            if Bool.random() {
                return puzzle("? × \(a)", "\(a * x + extra) − \(extra)", x: x) { v in (v * Double(a), Double(a * x)) }
            }
            let k = Int.random(in: 2...6)
            return puzzle("? × \(a)", "\(a * x * k) ÷ \(k)", x: x) { v in (v * Double(a), Double(a * x)) }
        case 5, 6:
            switch Int.random(in: 0...2) {
            case 0:
                let a = Int.random(in: 2...6), b = Int.random(in: 1...9), x = Int.random(in: 2...9)
                return puzzle("\(a) × ? + \(b)", "\(a * x + b)", x: x, pad: g >= 6) { v in (Double(a) * v + Double(b), Double(a * x + b)) }
            case 1:
                // Fractions to one whole.
                let pairs: [(String, Double, String, Double)] = [("½", 0.5, "½", 0.5), ("¼", 0.25, "¾", 0.75),
                                                                 ("¾", 0.75, "¼", 0.25), ("⅓", 1.0 / 3, "⅔", 2.0 / 3)]
                let (shown, sv, missing, _) = pairs.randomElement()!
                let names: [(String, Double)] = [("½", 0.5), ("¼", 0.25), ("¾", 0.75), ("⅓", 1.0 / 3), ("⅔", 2.0 / 3)]
                var opts: [String] = [missing]
                for n in names.shuffled() where opts.count < 4 && !opts.contains(n.0) { opts.append(n.0) }
                let lookup = Dictionary(uniqueKeysWithValues: names.map { ($0.0, $0.1) })
                let (pl, pr) = swap ? ("1", "\(shown) + ?") : ("\(shown) + ?", "1")
                return BalancePuzzle(left: pl, right: pr, answer: missing, options: opts.shuffled(),
                                     weigh: { v in swap ? (1, sv + v) : (sv + v, 1) },
                                     value: { lookup[$0] }, topic: topic)
            default:
                // Decimals.
                let a = Double(Int.random(in: 1...9)) / 10 + Double(Int.random(in: 0...2))
                let total = Double(Int.random(in: Int(a) + 1...Int(a) + 3))
                let x = total - a
                func f(_ d: Double) -> String { abs(d - d.rounded()) < 0.001 ? String(format: "%.0f", d) : String(format: "%.1f", d) }
                var opts: Set<String> = [f(x)]
                for d in [0.1, -0.1, 1, -1, 0.5].shuffled() where opts.count < 4 && x + d > 0 { opts.insert(f(x + d)) }
                let (pl, pr) = swap ? (f(total), "\(f(a)) + ?") : ("\(f(a)) + ?", f(total))
                return BalancePuzzle(left: pl, right: pr, answer: f(x), options: opts.shuffled(),
                                     weigh: { v in swap ? (total, a + v) : (a + v, total) },
                                     value: { Double($0) }, topic: topic)
            }
        default:
            // ז׳–ח׳: equations in x, signed numbers.
            let q = tr("מָה הוּא x?")
            switch Int.random(in: 0...2) {
            case 0:
                let a = Int.random(in: 2...6), b = Int.random(in: 1...12), x = Int.random(in: 1...9)
                return puzzle("\(a)x + \(b)", "\(a * x + b)", x: x, question: q, pad: true) { v in (Double(a) * v + Double(b), Double(a * x + b)) }
            case 1:
                let a = Int.random(in: 2...5), b = Int.random(in: 1...9), x = Int.random(in: 2...10)
                // a·x − b = x + c  →  c = (a − 1)·x − b
                let c = (a - 1) * x - b
                let right = c >= 0 ? "x + \(c)" : "x − \(-c)"
                return puzzle("\(a)x − \(b)", right, x: x, question: q, pad: true) { v in (Double(a) * v - Double(b), v + Double(c)) }
            default:
                let b = Int.random(in: 3...12), total = Int.random(in: -8...2), x = total - b
                return puzzle("x + \(b)", MathFacts.show(total), x: x, question: q, negative: true) { v in (v + Double(b), Double(total)) }
            }
        }
    }

    /// A world question with a number for an answer: the beam says whether a
    /// guess is too light or too heavy.
    static func compare(_ item: GameItem) -> BalancePuzzle? {
        guard let x = GameContent.number(item.answer) else { return nil }
        return BalancePuzzle(left: "?", right: "🎁", question: item.prompt, answer: item.answer,
                             options: item.shuffledOptions,
                             weigh: { v in (v, Double(x)) }, value: intValue, topic: item.topic)
    }
}
