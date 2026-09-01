import Foundation

/// 📖 הבנת הנקרא — a passage the child READS, then 2–3 questions about it.
///
/// The unit of content is the PASSAGE (not the single question): in the reading
/// world the runner serves all of a passage's questions back-to-back before
/// moving on, and every generated `Question` carries the passage text in
/// `Question.passage` so it renders above the prompt wherever the question
/// travels (smart feed, re-ask queue, boss battle).
///
/// Difficulty follows the app's existing grain — tiers, not ages:
///   easy = 1–2 sentences · medium = 3–4 sentences · hard = a short paragraph.
struct ReadingPassage {
    let id: String
    let tier: Difficulty
    /// 🎓 Curriculum window (1=א׳ … 6=ו׳). nil → inferred from tier
    /// (easy≈א׳–ב׳, medium≈ב׳–ד׳, hard≈ד׳–ו׳).
    var grades: ClosedRange<Int>? = nil
    let text: String
    let questions: [BankQuestion]   // prompts + answers about `text`

    var gradeWindow: ClosedRange<Int> {
        if let grades { return grades }
        switch tier {
        case .easy:   return 1...2
        case .medium: return 2...4
        case .hard:   return 4...6
        }
    }
}

enum ReadingContent {

    // MARK: - Serving

    /// All questions of ONE fresh passage, shuffled options, passage attached —
    /// the sequential flow for the reading world / smart feed. (Parent-reported
    /// prompts are filtered by the caller, where QuestionReporter is reachable.)
    static func nextGroup(target: Difficulty, grade: Int? = nil) -> [Question] {
        guard let passage = pickPassage(target: target, grade: grade) else { return [] }
        let universeCount: Int = {
            guard let g = grade else { return passages.count }
            let inWindow = passages.filter { $0.gradeWindow.contains(g) }
            return inWindow.isEmpty ? passages.count : inWindow.count
        }()
        markUsed(passage.id, universeCount: universeCount)
        return passage.questions.map { item in
            let options = ([item.correctAnswer] + item.distractors).shuffled()
            return Question(
                topic: .reading,
                prompt: item.prompt,
                options: options,
                correctIndex: options.firstIndex(of: item.correctAnswer) ?? 0,
                passage: passage.text
            )
        }
    }

    /// One passage question (random question of a fresh passage) — for generic
    /// single-question callers like the boss battle.
    static func singleQuestion(target: Difficulty, grade: Int? = nil) -> Question {
        if let q = nextGroup(target: target, grade: grade).randomElement() { return q }
        return Question(
            topic: .reading,
            prompt: "אוֹפְּס... אֵין קְטָעִים חֲדָשִׁים כָּרֶגַע",
            options: ["בְּסֵדֶר", "הַמְשֵׁךְ", "תּוֹדָה", "חֲזוֹר"],
            correctIndex: 0
        )
    }

    /// Prefer the target tier, then drift easier before harder (same spirit as
    /// QuestionMemory's tier preference); within a tier avoid recently-used
    /// passages, relaxing only when the whole tier was seen.
    private static func pickPassage(target: Difficulty, grade: Int? = nil) -> ReadingPassage? {
        let order: [Difficulty]
        switch target {
        case .easy:   order = [.easy, .medium, .hard]
        case .medium: order = [.medium, .easy, .hard]
        case .hard:   order = [.hard, .medium, .easy]
        }
        // 🎓 Curriculum window first; fall back to the whole pool rather than
        // serve nothing when a grade has no matching passages yet.
        var universe = passages
        if let g = grade {
            let inWindow = passages.filter { $0.gradeWindow.contains(g) }
            if !inWindow.isEmpty { universe = inWindow }
        }
        let recent = recentIDs()
        for tier in order {
            let pool = universe.filter { $0.tier == tier }
            if let fresh = pool.filter({ !recent.contains($0.id) }).randomElement() { return fresh }
        }
        // Everything was seen recently — recycle the LEAST-recently-used (its id
        // sits earliest in `recent`), so we never repeat a passage back-to-back.
        let lru: (ReadingPassage) -> Int = { recent.firstIndex(of: $0.id) ?? -1 }
        for tier in order {
            let pool = universe.filter { $0.tier == tier }
            if let oldest = pool.min(by: { lru($0) < lru($1) }) { return oldest }
        }
        return universe.min(by: { lru($0) < lru($1) }) ?? universe.randomElement()
    }

    // MARK: - Anti-repeat (persisted, ~60% of the pool)

    // Per-profile so siblings on one device don't share reading recency, and
    // (below) the cap is computed from the FILTERED universe, not all passages —
    // grade א'-ב' has only ~8 easy passages, so a global 60%-of-24 cap (=14)
    // meant everything was "recent" forever and the recycle path went random.
    private static var recentKey: String {
        "reading.recentPassageIDs" + (ProfileStore.shared.activeID.map { ".\($0.uuidString)" } ?? "")
    }

    private static func recentIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: recentKey) ?? []
    }

    private static func markUsed(_ id: String, universeCount: Int) {
        var ids = recentIDs().filter { $0 != id }
        ids.append(id)
        // Cap at ~60% of the CURRENT universe (min 1, and never the whole set −1
        // so at least one fresh passage always exists).
        let cap = max(1, min((universeCount * 6) / 10, universeCount - 1))
        if ids.count > cap { ids.removeFirst(ids.count - cap) }
        UserDefaults.standard.set(ids, forKey: recentKey)
    }

    // MARK: - The passages

    static let passages: [ReadingPassage] = [

        // ——— קל: משפט־שניים ———

        ReadingPassage(
            id: "cat_roof", tier: .easy,
            text: "לְמִיכַל יֵשׁ חֲתוּלָה בְּשֵׁם לוּנָה. לוּנָה אוֹהֶבֶת לִישׁוֹן עַל הַגַּג הַחַם.",
            questions: [
                BankQuestion(prompt: "אֵיךְ קוֹרְאִים לַחֲתוּלָה?", correctAnswer: "לוּנָה", distractors: ["מִיכַל", "שֶׁמֶשׁ", "חַמָּה"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "אֵיפֹה לוּנָה אוֹהֶבֶת לִישׁוֹן?", correctAnswer: "עַל הַגַּג", distractors: ["בַּמִּטָּה", "בַּגִּנָּה", "עַל הַסַּפָּה"], tier: .easy, grades: 1...2),
            ]),

        ReadingPassage(
            id: "red_ball", tier: .easy,
            text: "יוֹנָתָן קִבֵּל כַּדּוּר אָדֹם לְיוֹם הַהֻלֶּדֶת. הוּא שִׂחֵק בּוֹ בַּחָצֵר עִם אָחִיו הַקָּטָן.",
            questions: [
                BankQuestion(prompt: "בְּאֵיזֶה צֶבַע הַכַּדּוּר?", correctAnswer: "אָדֹם", distractors: ["כָּחֹל", "יָרֹק", "צָהֹב"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "עִם מִי שִׂחֵק יוֹנָתָן?", correctAnswer: "עִם אָחִיו הַקָּטָן", distractors: ["עִם אַבָּא", "עִם חָבֵר מֵהַגַּן", "לְבַד"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "לָמָּה יוֹנָתָן קִבֵּל כַּדּוּר?", correctAnswer: "לְיוֹם הַהֻלֶּדֶת", distractors: ["כִּי נִצֵּחַ בְּמִשְׂחָק", "לַחֲנֻכָּה", "סְתָם, בְּלִי סִבָּה"], tier: .easy, grades: 1...2),
            ]),

        ReadingPassage(
            id: "rain_boots", tier: .easy,
            text: "בַּחוּץ יָרַד גֶּשֶׁם חָזָק. נֹעָה נָעֲלָה מַגָּפַיִם וְרֻדִּים וְקָפְצָה בַּשְּׁלוּלִיּוֹת.",
            questions: [
                BankQuestion(prompt: "מָה יָרַד בַּחוּץ?", correctAnswer: "גֶּשֶׁם", distractors: ["שֶׁלֶג", "בָּרָד", "עָלִים"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "מָה נָעֲלָה נֹעָה?", correctAnswer: "מַגָּפַיִם וְרֻדִּים", distractors: ["סַנְדָּלִים", "נַעֲלֵי סְפּוֹרְט", "מַגָּפַיִם כְּחֻלִּים"], tier: .easy, grades: 1...2),
            ]),

        ReadingPassage(
            id: "dog_bone", tier: .easy,
            text: "הַכֶּלֶב רֶקְס חָפַר בּוֹר בַּגִּנָּה. הוּא הֶחְבִּיא שָׁם עֶצֶם גְּדוֹלָה לְמָחָר.",
            questions: [
                BankQuestion(prompt: "מָה עָשָׂה רֶקְס בַּגִּנָּה?", correctAnswer: "חָפַר בּוֹר", distractors: ["קָטַף פְּרָחִים", "רָדַף אַחֲרֵי חָתוּל", "יָשַׁן בַּשֶּׁמֶשׁ"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "מָה רֶקְס הֶחְבִּיא בַּבּוֹר?", correctAnswer: "עֶצֶם גְּדוֹלָה", distractors: ["כַּדּוּר", "נַעַל", "אֹכֶל שֶׁל חֲתוּלִים"], tier: .easy, grades: 1...2),
            ]),

        ReadingPassage(
            id: "morning_sun", tier: .easy,
            text: "בַּבֹּקֶר הַשֶּׁמֶשׁ זָרְחָה. אִמָּא הֵכִינָה לְעוֹמֶר שׁוֹקוֹ חַם וְלֶחֶם עִם רִבָּה.",
            questions: [
                BankQuestion(prompt: "מָה הֵכִינָה אִמָּא לְעוֹמֶר?", correctAnswer: "שׁוֹקוֹ וְלֶחֶם עִם רִבָּה", distractors: ["מָרָק חַם", "פִּיצָה", "דַּיְסָה עִם דְּבַשׁ"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "מָתַי זֶה קָרָה?", correctAnswer: "בַּבֹּקֶר", distractors: ["בַּלַּיְלָה", "בַּצָּהֳרַיִם", "בָּעֶרֶב"], tier: .easy, grades: 1...2),
            ]),

        ReadingPassage(
            id: "library_visit", tier: .easy,
            text: "טַל הָלַךְ עִם סַבְתָּא לַסִּפְרִיָּה. הוּא בָּחַר סֵפֶר עַל דִּינוֹזָאוּרִים.",
            questions: [
                BankQuestion(prompt: "לְאָן הָלַךְ טַל?", correctAnswer: "לַסִּפְרִיָּה", distractors: ["לַגַּן", "לַחֲנוּת", "לַבְּרֵכָה"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "עַל מָה הַסֵּפֶר שֶׁטַּל בָּחַר?", correctAnswer: "עַל דִּינוֹזָאוּרִים", distractors: ["עַל חָלָל", "עַל פִּירָטִים", "עַל כְּלָבִים"], tier: .easy, grades: 1...2),
            ]),

        // ——— בינוני: 3–4 משפטים ———

        ReadingPassage(
            id: "picnic_ants", tier: .medium,
            text: "בְּיוֹם שִׁשִּׁי נָסְעָה מִשְׁפַּחַת לֵוִי לְפִּיקְנִיק בַּפַּארְק. אִמָּא פָּרְשָׂה שְׂמִיכָה גְּדוֹלָה מִתַּחַת לְעֵץ, וְאַבָּא הוֹצִיא כָּרִיכִים וַאֲבַטִּיחַ. פִּתְאוֹם הִגִּיעָה שַׁיָּרָה שֶׁל נְמָלִים יְשָׁר אֶל הָעוּגָה. כֻּלָּם צָחֲקוּ וְהֶעֱבִירוּ אֶת הַשְּׂמִיכָה לְמָקוֹם אַחֵר.",
            questions: [
                BankQuestion(prompt: "מָתַי נָסְעָה הַמִּשְׁפָּחָה לַפִּיקְנִיק?", correctAnswer: "בְּיוֹם שִׁשִּׁי", distractors: ["בְּשַׁבָּת", "בְּיוֹם רִאשׁוֹן", "בַּחֹפֶשׁ הַגָּדוֹל"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "לְאָן הָלְכוּ הַנְּמָלִים?", correctAnswer: "אֶל הָעוּגָה", distractors: ["אֶל הָאֲבַטִּיחַ", "אֶל הַכָּרִיכִים", "אֶל הָעֵץ"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "מָה עָשְׂתָה הַמִּשְׁפָּחָה בַּסּוֹף?", correctAnswer: "הֶעֱבִירָה אֶת הַשְּׂמִיכָה לְמָקוֹם אַחֵר", distractors: ["נָסְעָה הַבַּיְתָה", "זָרְקָה אֶת הָעוּגָה", "רָדְפָה אַחֲרֵי הַנְּמָלִים"], tier: .medium, grades: 2...4),
            ]),

        ReadingPassage(
            id: "lost_tooth", tier: .medium,
            text: "לְרוֹנִי הִתְנַדְנְדָה שֵׁן כְּבָר שָׁבוּעַ שָׁלֵם. בַּאֲרוּחַת הָעֶרֶב, בְּדִיּוּק כְּשֶׁנָּגְסָה בְּתַפּוּחַ, הַשֵּׁן נָפְלָה! רוֹנִי שָׂמָה אֶת הַשֵּׁן מִתַּחַת לַכָּרִית. בַּבֹּקֶר הִיא מָצְאָה שָׁם מַטְבֵּעַ נוֹצֵץ.",
            questions: [
                BankQuestion(prompt: "כַּמָּה זְמַן הִתְנַדְנְדָה הַשֵּׁן?", correctAnswer: "שָׁבוּעַ", distractors: ["יוֹם אֶחָד", "חֹדֶשׁ", "שָׁעָה"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "מָתַי נָפְלָה הַשֵּׁן?", correctAnswer: "כְּשֶׁרוֹנִי נָגְסָה בְּתַפּוּחַ", distractors: ["כְּשֶׁרוֹנִי צִחְצְחָה שִׁנַּיִם", "בְּזְמַן הַשֵּׁנָה", "בַּמִּשְׂחָק בַּחָצֵר"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "מָה מָצְאָה רוֹנִי מִתַּחַת לַכָּרִית?", correctAnswer: "מַטְבֵּעַ נוֹצֵץ", distractors: ["שֵׁן חֲדָשָׁה", "מַמְתָּק", "מִכְתָּב"], tier: .medium, grades: 2...4),
            ]),

        ReadingPassage(
            id: "robot_project", tier: .medium,
            text: "בְּשִׁעוּר מַדָּעִים בָּנוּ אִיתַי וְשִׁירָה רוֹבּוֹט קָטָן מִקֻּפְסָאוֹת. הָרוֹבּוֹט יָדַע לְהָזִיז יָד אַחַת וּלְהַדְלִיק נוּרָה אֲדֻמָּה בָּאַף. בַּתַּעֲרוּכָה שֶׁל בֵּית הַסֵּפֶר הָרוֹבּוֹט זָכָה בַּמָּקוֹם הָרִאשׁוֹן. הַמּוֹרָה תָּלְתָה אֶת הַתְּמוּנָה שֶׁלּוֹ עַל לוּחַ הַכִּתָּה.",
            questions: [
                BankQuestion(prompt: "מִמָּה בָּנוּ אִיתַי וְשִׁירָה אֶת הָרוֹבּוֹט?", correctAnswer: "מִקֻּפְסָאוֹת", distractors: ["מִלֶּגוֹ", "מִפְּלַסְטֶלִינָה", "מִבַּרְזֶל"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "מָה יָדַע הָרוֹבּוֹט לְהַדְלִיק?", correctAnswer: "נוּרָה אֲדֻמָּה בָּאַף", distractors: ["פָּנָס בַּיָּד", "מָסָךְ קָטָן", "שְׁתֵּי עֵינַיִם יְרֻקּוֹת"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "בְּמָה זָכָה הָרוֹבּוֹט בַּתַּעֲרוּכָה?", correctAnswer: "בַּמָּקוֹם הָרִאשׁוֹן", distractors: ["בַּמָּקוֹם הַשֵּׁנִי", "בְּמֶדַלְיַת כֶּסֶף", "בְּפַרְס הַקְּהָל"], tier: .medium, grades: 2...4),
            ]),

        ReadingPassage(
            id: "grandpa_garden", tier: .medium,
            text: "כָּל יוֹם שְׁלִישִׁי דָּנִיאֵל עוֹזֵר לְסַבָּא בַּגִּנָּה. הַשָּׁבוּעַ הֵם שָׁתְלוּ עַגְבָנִיּוֹת וּמְלָפְפוֹנִים. סַבָּא לִמֵּד אֶת דָּנִיאֵל שֶׁצְּמָחִים צְרִיכִים שֶׁמֶשׁ, מַיִם וְהַרְבֵּה סַבְלָנוּת. דָּנִיאֵל הִבְטִיחַ לְהַשְׁקוֹת אֶת הַגִּנָּה גַּם בְּיָמִים שֶׁסַּבָּא נָח.",
            questions: [
                BankQuestion(prompt: "בְּאֵיזֶה יוֹם דָּנִיאֵל עוֹזֵר לְסַבָּא?", correctAnswer: "בְּיוֹם שְׁלִישִׁי", distractors: ["בְּיוֹם שִׁשִּׁי", "בְּשַׁבָּת", "כָּל יוֹם"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "מָה שָׁתְלוּ הַשָּׁבוּעַ?", correctAnswer: "עַגְבָנִיּוֹת וּמְלָפְפוֹנִים", distractors: ["פְּרָחִים", "תַּפּוּחִים וַאֲגַסִּים", "תּוּת שָׂדֶה"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "לְפִי סַבָּא, מָה צְמָחִים צְרִיכִים?", correctAnswer: "שֶׁמֶשׁ, מַיִם וְסַבְלָנוּת", distractors: ["רַק מַיִם", "חֹשֶׁךְ וְקֹר", "מוּזִיקָה שְׁקֵטָה"], tier: .medium, grades: 2...4),
            ]),

        ReadingPassage(
            id: "beach_shell", tier: .medium,
            text: "בַּחֻפְשָׁה נָסְעָה עֲדִי עִם הַהוֹרִים לַיָּם. הִיא אָסְפָה צְדָפִים בְּדֶלִי כָּחֹל וּבָנְתָה אַרְמוֹן חוֹל עִם שְׁנֵי מִגְדָּלִים. גַּל גָּדוֹל הִגִּיעַ וּמָחַק אֶת הָאַרְמוֹן, אֲבָל עֲדִי לֹא הִתְעַצְּבָה. הִיא אָמְרָה: \"מָחָר נִבְנֶה אַרְמוֹן עוֹד יוֹתֵר גָּדוֹל!\"",
            questions: [
                BankQuestion(prompt: "בַּמָּה אָסְפָה עֲדִי צְדָפִים?", correctAnswer: "בְּדֶלִי כָּחֹל", distractors: ["בְּשַׂקִּית", "בְּכוֹבַע", "בְּדֶלִי אָדֹם"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "מָה קָרָה לְאַרְמוֹן הַחוֹל?", correctAnswer: "גַּל מָחַק אוֹתוֹ", distractors: ["יֶלֶד דָּרַךְ עָלָיו", "הוּא נִשְׁאַר עַד הָעֶרֶב", "הָרוּחַ פִּזְּרָה אוֹתוֹ"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "אֵיךְ הִרְגִּישָׁה עֲדִי בַּסּוֹף?", correctAnswer: "לֹא הִתְעַצְּבָה — תִּכְנְנָה לִבְנוֹת שׁוּב", distractors: ["בָּכְתָה כָּל הַדֶּרֶךְ", "כָּעֲסָה עַל הַיָּם", "פָּחֲדָה מֵהַגַּלִּים"], tier: .medium, grades: 2...4),
            ]),

        ReadingPassage(
            id: "class_pet", tier: .medium,
            text: "לְכִתָּה ב'2 יֵשׁ אֹגֶר בְּשֵׁם צְנוֹן. כָּל שָׁבוּעַ תַּלְמִיד אַחֵר לוֹקֵחַ אוֹתוֹ הַבַּיְתָה לְשַׁבָּת. הַשָּׁבוּעַ הָיָה הַתּוֹר שֶׁל אֲבִיגַיִל, וְהִיא הֵכִינָה לִצְנוֹן מִגְרַשׁ מִשְׂחָקִים מִגְּלִילֵי נְיָר. צְנוֹן כָּל כָּךְ נֶהֱנָה שֶׁהוּא נִרְדַּם בְּתוֹךְ גָּלִיל.",
            questions: [
                BankQuestion(prompt: "אֵיזוֹ חַיָּה יֵשׁ לַכִּתָּה?", correctAnswer: "אֹגֶר", distractors: ["אַרְנָב", "תֻּכִּי", "דָּג זָהָב"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "מָה הֵכִינָה אֲבִיגַיִל לִצְנוֹן?", correctAnswer: "מִגְרַשׁ מִשְׂחָקִים מִגְּלִילֵי נְיָר", distractors: ["עוּגָה קְטַנָּה", "בַּיִת מִלֶּגוֹ", "סְוֶדֶר צֶמֶר"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "אֵיפֹה נִרְדַּם צְנוֹן?", correctAnswer: "בְּתוֹךְ גָּלִיל", distractors: ["בַּכְּלוּב", "עַל הַסַּפָּה", "בַּכִּיס שֶׁל אֲבִיגַיִל"], tier: .medium, grades: 2...4),
            ]),

        // ——— קשה: פסקה קצרה ———

        ReadingPassage(
            id: "night_hike", tier: .hard,
            text: "בְּמוֹצָאֵי שַׁבָּת יָצְאָה מִשְׁפַּחַת כֹּהֵן לְטִיּוּל לַיְלָה בַּיַּעַר. אַבָּא חִלֵּק לְכֻלָּם פָּנָסִים, וְהִסְבִּיר שֶׁבַּלַּיְלָה חַיּוֹת רַבּוֹת מִתְעוֹרְרוֹת דַּוְקָא כְּשֶׁאֲנַחְנוּ הוֹלְכִים לִישׁוֹן. פִּתְאוֹם שָׁמְעוּ קוֹל נְבִיחָה מְשֻׁנָּה מִבֵּין הָעֵצִים. הַיְּלָדִים קָפְאוּ בִּמְקוֹמָם, אֲבָל אַבָּא חִיֵּךְ וְלָחַשׁ: \"זֶה בְּסַךְ הַכֹּל תַּן — הוּא יוֹתֵר מְפַחֵד מֵאִתָּנוּ מִשֶּׁאֲנַחְנוּ מִמֶּנּוּ.\" בַּדֶּרֶךְ חֲזָרָה סָפְרוּ הַיְּלָדִים שִׁבְעָה זוּגוֹת עֵינַיִם נוֹצְצוֹת בַּחֲשֵׁכָה.",
            questions: [
                BankQuestion(prompt: "מָתַי יָצְאָה הַמִּשְׁפָּחָה לַטִּיּוּל?", correctAnswer: "בְּמוֹצָאֵי שַׁבָּת", distractors: ["בְּשִׁשִּׁי בַּבֹּקֶר", "בְּיוֹם רִאשׁוֹן", "בַּצָּהֳרַיִם"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "שֶׁל מִי הָיְתָה הַנְּבִיחָה הַמְּשֻׁנָּה?", correctAnswer: "שֶׁל תַּן", distractors: ["שֶׁל כֶּלֶב", "שֶׁל זְאֵב", "שֶׁל יַנְשׁוּף"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "מָה לִמֵּד אַבָּא עַל הַתַּן?", correctAnswer: "שֶׁהוּא מְפַחֵד מֵאִתָּנוּ יוֹתֵר מִשֶּׁאֲנַחְנוּ מִמֶּנּוּ", distractors: ["שֶׁהוּא מְסֻכָּן מְאוֹד", "שֶׁהוּא יָשֵׁן כָּל הַלַּיְלָה", "שֶׁהוּא אוֹהֵב פָּנָסִים"], tier: .hard, grades: 4...6),
            ]),

        ReadingPassage(
            id: "bread_bakery", tier: .hard,
            text: "הַאִם יְדַעְתֶּם אֵיךְ נַעֲשֶׂה הַלֶּחֶם שֶׁאֲנַחְנוּ אוֹכְלִים? הַכֹּל מַתְחִיל בְּגַרְגְּרֵי חִטָּה שֶׁגְּדֵלִים בַּשָּׂדֶה. אַחֲרֵי הַקָּצִיר טוֹחֲנִים אֶת הַגַּרְגְּרִים לְקֶמַח לָבָן וְדַק. בַּמַּאֲפִיָּה מְעָרְבְבִים אֶת הַקֶּמַח עִם מַיִם, שְׁמָרִים וּמְעַט מֶלַח, וְלָשִׁים בָּצֵק רַךְ. הַבָּצֵק צָרִיךְ לָנוּחַ כְּשָׁעָה כְּדֵי לִתְפֹּחַ — הַשְּׁמָרִים מְמַלְּאִים אוֹתוֹ בְּבוּעוֹת אֲוִיר קְטַנּוֹת. רַק אָז אוֹפִים אוֹתוֹ בְּתַנּוּר לוֹהֵט, וְהָרֵיחַ הַנִּפְלָא מִתְפַּשֵּׁט בְּכָל הָרְחוֹב.",
            questions: [
                BankQuestion(prompt: "מִמָּה מַתְחִילִים לְהָכִין לֶחֶם?", correctAnswer: "מִגַּרְגְּרֵי חִטָּה", distractors: ["מֵאֹרֶז", "מִתַּפּוּחֵי אֲדָמָה", "מִסֻּכָּר"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "לָמָּה הַבָּצֵק צָרִיךְ לָנוּחַ?", correctAnswer: "כְּדֵי לִתְפֹּחַ מִבּוּעוֹת הָאֲוִיר", distractors: ["כְּדֵי לְהִתְקָרֵר", "כְּדֵי לְהִתְיַבֵּשׁ", "כְּדֵי לְהַחְלִיף צֶבַע"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "מָה עוֹשִׂים לַגַּרְגְּרִים אַחֲרֵי הַקָּצִיר?", correctAnswer: "טוֹחֲנִים אוֹתָם לְקֶמַח", distractors: ["מְבַשְּׁלִים אוֹתָם", "צוֹבְעִים אוֹתָם", "שׁוֹתְלִים אוֹתָם שׁוּב"], tier: .hard, grades: 4...6),
            ]),

        ReadingPassage(
            id: "dolphin_rescue", tier: .hard,
            text: "בְּבֹקֶר חֹרְפִּי אֶחָד מָצְאוּ דַּיָּגִים בְּחוֹף אַשְׁקְלוֹן גּוּר דּוֹלְפִינִים שֶׁנִּסְחַף אֶל הַמַּיִם הָרְדוּדִים. הֵם הִזְעִיקוּ מִיָּד אֶת מְצִילֵי הַטֶּבַע, שֶׁהִגִּיעוּ עִם סִירָה מְיֻחֶדֶת. בְּמֶשֶׁךְ שָׁעָה שְׁלֵמָה שָׁמְרוּ הַמְּצִילִים שֶׁעוֹר הַדּוֹלְפִין יִשָּׁאֵר רָטֹב, כִּי דּוֹלְפִין שֶׁמִּתְיַבֵּשׁ נִמְצָא בְּסַכָּנָה גְּדוֹלָה. לְבַסּוֹף, כְּשֶׁעָלָה הַגֵּאוּת, הִצְלִיחוּ לְהַחְזִיר אוֹתוֹ בִּזְהִירוּת לַמַּיִם הָעֲמֻקִּים. הַגּוּר הִשְׁמִיעַ שְׁרִיקָה גְּבוֹהָה — כְּמוֹ תּוֹדָה — וְנֶעְלַם בַּגַּלִּים.",
            questions: [
                BankQuestion(prompt: "מִי מָצָא אֶת גּוּר הַדּוֹלְפִינִים?", correctAnswer: "דַּיָּגִים", distractors: ["מְטַיְּלִים", "יְלָדִים", "מְצִילִים בַּבְּרֵכָה"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "לָמָּה שָׁמְרוּ שֶׁעוֹר הַדּוֹלְפִין יִשָּׁאֵר רָטֹב?", correctAnswer: "כִּי דּוֹלְפִין שֶׁמִּתְיַבֵּשׁ בְּסַכָּנָה", distractors: ["כְּדֵי שֶׁיִּהְיֶה לוֹ נָעִים", "כְּדֵי לְנַקּוֹת אוֹתוֹ", "כִּי הוּא אָהַב מַיִם קָרִים"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "מָתַי הֶחְזִירוּ אוֹתוֹ לַמַּיִם הָעֲמֻקִּים?", correctAnswer: "כְּשֶׁעָלָה הַגֵּאוּת", distractors: ["בַּלַּיְלָה", "מִיָּד כְּשֶׁמָּצְאוּ אוֹתוֹ", "אַחֲרֵי שֶׁאָכַל"], tier: .hard, grades: 4...6),
            ]),

        ReadingPassage(
            id: "old_clock", tier: .hard,
            text: "בַּעֲלִיַּת הַגַּג שֶׁל סָבְתָא מָצְאָה אֶלָּה שָׁעוֹן קִיר עַתִּיק וּמְאֻבָּק. סָבְתָא סִפְּרָה שֶׁהַשָּׁעוֹן הִגִּיעַ עִם סָבָא רַבָּא שֶׁלָּהּ בָּאֳנִיָּה, לִפְנֵי יוֹתֵר מִמֵּאָה שָׁנָה. הַמְּחוֹגִים שֶׁלּוֹ עָצְרוּ מִזְּמַן, אֲבָל אֶלָּה לֹא וִתְּרָה: הִיא נִקְּתָה אוֹתוֹ בְּמַטְלִית רַכָּה, וְאַבָּא הֵבִיא שַׁעֲוָן חָדָשׁ לַמַּנְגָּנוֹן. בְּיוֹם שִׁשִּׁי בָּעֶרֶב, כְּשֶׁכָּל הַמִּשְׁפָּחָה יָשְׁבָה לַשֻּׁלְחָן, הַשָּׁעוֹן הִשְׁמִיעַ פִּתְאוֹם צִלְצוּל עָמֹק. לְסָבְתָא זָלְגָה דִּמְעָה — הִיא לֹא שָׁמְעָה אֶת הַצְּלִיל הַזֶּה מֵאָז שֶׁהָיְתָה יַלְדָּה.",
            questions: [
                BankQuestion(prompt: "אֵיפֹה מָצְאָה אֶלָּה אֶת הַשָּׁעוֹן?", correctAnswer: "בַּעֲלִיַּת הַגַּג", distractors: ["בַּמַּרְתֵּף", "בַּחֲנוּת עַתִּיקוֹת", "בַּגִּנָּה"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "אֵיךְ הִגִּיעַ הַשָּׁעוֹן לַמִּשְׁפָּחָה?", correctAnswer: "עִם סָבָא רַבָּא, בָּאֳנִיָּה", distractors: ["נִקְנָה בַּשּׁוּק", "הִתְקַבֵּל בְּמַתָּנָה מִשָּׁכֵן", "בְּמִכְתָּב מֵחוּץ לָאָרֶץ"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "לָמָּה זָלְגָה לְסָבְתָא דִּמְעָה?", correctAnswer: "כִּי לֹא שָׁמְעָה אֶת הַצִּלְצוּל מֵאָז יַלְדוּתָהּ", distractors: ["כִּי הַשָּׁעוֹן נִשְׁבַּר", "כִּי הִיא נֶחְתְּכָה בָּאֶצְבַּע", "כִּי הָאֹכֶל נִשְׂרַף"], tier: .hard, grades: 4...6),
            ]),

        ReadingPassage(
            id: "bee_dance", tier: .hard,
            text: "דְּבוֹרִים הֵן מִן הַחַיּוֹת הַחֲרוּצוֹת בַּטֶּבַע, וְיֵשׁ לָהֶן דֶּרֶךְ מַפְתִּיעָה לְדַבֵּר זוֹ עִם זוֹ. כְּשֶׁדְּבוֹרָה מוֹצֵאת שָׂדֶה מָלֵא פְּרָחִים, הִיא חוֹזֶרֶת לַכַּוֶּרֶת וְרוֹקֶדֶת רִקּוּד מְיֻחָד בְּצוּרַת הַסִּפְרָה שְׁמוֹנֶה. כִּוּוּן הָרִקּוּד מַרְאֶה לַחֲבֵרוֹת שֶׁלָּהּ לְאֵיזֶה כִּוּוּן לָעוּף, וּמְהִירוּת הַנִּעְנוּעַ מְסַפֶּרֶת כַּמָּה רָחוֹק הַשָּׂדֶה. כָּךְ, בְּלִי מִלָּה אַחַת, יוֹדַעַת כָּל הַכַּוֶּרֶת בְּדִיּוּק לְאָן לָצֵאת לְאִסּוּף צוּף.",
            questions: [
                BankQuestion(prompt: "אֵיךְ דְּבוֹרָה מְסַפֶּרֶת עַל שָׂדֶה פְּרָחִים?", correctAnswer: "בְּרִקּוּד בְּצוּרַת שְׁמוֹנֶה", distractors: ["בְּזִמְזוּם חָזָק", "בִּנְגִיעָה בַּכְּנָפַיִם", "בְּהַשְׁאָרַת רֵיחַ"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "מָה מַרְאֶה כִּוּוּן הָרִקּוּד?", correctAnswer: "לְאֵיזֶה כִּוּוּן לָעוּף", distractors: ["כַּמָּה דְּבוֹרִים לָבוֹא", "אֵיזֶה צֶבַע לַפְּרָחִים", "מָתַי לָצֵאת"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "מָה מְסַפֶּרֶת מְהִירוּת הַנִּעְנוּעַ?", correctAnswer: "כַּמָּה רָחוֹק הַשָּׂדֶה", distractors: ["כַּמָּה צוּף יֵשׁ", "מָה מֶזֶג הָאֲוִיר", "מִי הַמַּלְכָּה"], tier: .hard, grades: 4...6),
            ]),

        ReadingPassage(
            id: "kite_contest", tier: .hard,
            text: "בְּחַג הַסֻּכּוֹת נֶעֶרְכָה בַּמּוֹשָׁב תַּחֲרוּת עֲפִיפוֹנִים גְּדוֹלָה. נֹעַם עָבַד עַל הָעֲפִיפוֹן שֶׁלּוֹ שָׁבוּעַ שָׁלֵם: שֶׁלֶד מִקְּנֵי בַּמְבּוּק קַלִּים, נְיָר מְשִׁי כָּתֹם, וְזָנָב אָרֹךְ מִסְּרָטִים צִבְעוֹנִיִּים. בַּתַּחֲרוּת הָרוּחַ כִּמְעַט וְלֹא נָשְׁבָה, וַעֲפִיפוֹנִים רַבִּים צָנְחוּ לָאֲדָמָה. דַּוְקָא הָעֲפִיפוֹן הַקַּל שֶׁל נֹעַם הִצְלִיחַ לְטַפֵּס מַעְלָה־מַעְלָה, עַד שֶׁנִּרְאָה כִּנְקֻדָּה כְּתֻמָּה קְטַנָּה בַּשָּׁמַיִם. הַשּׁוֹפְטִים הֶעֱנִיקוּ לוֹ אֶת פַּרְס \"הַגָּבוֹהַּ בְּיוֹתֵר\".",
            questions: [
                BankQuestion(prompt: "מִמָּה נַעֲשָׂה שֶׁלֶד הָעֲפִיפוֹן?", correctAnswer: "מִקְּנֵי בַּמְבּוּק", distractors: ["מִבַּרְזֶל", "מִפְּלַסְטִיק", "מֵעֲנָפִים כְּבֵדִים"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "לָמָּה עֲפִיפוֹנִים רַבִּים צָנְחוּ?", correctAnswer: "כִּי כִּמְעַט לֹא הָיְתָה רוּחַ", distractors: ["כִּי יָרַד גֶּשֶׁם", "כִּי הַחוּטִים נִקְרְעוּ", "כִּי הָיָה חֹשֶׁךְ"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "אֵיזֶה פְּרָס קִבֵּל נֹעַם?", correctAnswer: "\"הַגָּבוֹהַּ בְּיוֹתֵר\"", distractors: ["\"הַיָּפֶה בְּיוֹתֵר\"", "\"הַמָּהִיר בְּיוֹתֵר\"", "\"הַגָּדוֹל בְּיוֹתֵר\""], tier: .hard, grades: 4...6),
            ]),
    ]
    // 🎓 Grade-tagged curriculum passages live in their own authored files.
    + CurriculumHebrewBank.readingPassages
    + ReadingExpandedBank.passages
}
