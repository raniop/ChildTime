import Foundation

/// 🎓 Curriculum-aligned math (תוכנית משרד החינוך, בקירוב): the generator picks
/// a MODULE from the child's grade, then renders a question at the requested
/// difficulty — so a 4th grader really meets שברים, שארית, שטח והיקף instead of
/// the one-size "84÷7" the legacy generator produced.
///
/// Difficulty stays WITHIN the grade (the adaptive engine keeps working): easy
/// leans on the grade's entry modules, hard on its heaviest — and peeks one
/// grade up 20% of the time (העשרה). Grade comes from `Profile.effectiveGrade`
/// (parent-set grade, else derived from the age bracket); 7+ serves grade-6
/// material until middle-school content exists.
enum CurriculumMath {

    /// Stamp a generated question with the skill it exercises, so the parent
    /// report can tell "strong in multiplication" from "struggling with fractions".
    private static func tagged(_ q: Question, _ skill: String) -> Question {
        var q = q; q.skill = skill; return q
    }

    static func generate(grade: Int, difficulty: Difficulty) -> Question {
        let g = max(1, min(6, grade))
        if difficulty == .hard, g < 6, Double.random(in: 0...1) < 0.2 {
            return generate(grade: g + 1, difficulty: .medium)   // העשרה
        }
        switch g {
        case 1:  return grade1(difficulty)
        case 2:  return grade2(difficulty)
        case 3:  return grade3(difficulty)
        case 4:  return grade4(difficulty)
        case 5:  return grade5(difficulty)
        default: return grade6(difficulty)
        }
    }

    // MARK: - כיתה א׳ — חיבור/חיסור עד 20, השלמה לעשר, השוואות

    private static func grade1(_ d: Difficulty) -> Question {
        switch Int.random(in: 0...3) {
        case 0:  return tagged(addSub(max: d == .easy ? 10 : 20), "addSub")
        case 1:  return tagged(completeToTen(), "completeTen")
        case 2:  return tagged(biggestNumber(max: d == .easy ? 10 : 20), "compare")
        default: return wordProblemAddSub(max: d == .easy ? 10 : 20)
        }
    }

    private static func addSub(max: Int) -> Question {
        let a = Int.random(in: 1...max), b = Int.random(in: 1...max)
        if Bool.random() {
            return numericMCQ(prompt: "\(a) + \(b) = ?", answer: a + b)
        }
        let big = Swift.max(a, b), small = Swift.min(a, b)
        return numericMCQ(prompt: "\(big) − \(small) = ?", answer: big - small)
    }

    private static func completeToTen() -> Question {
        let a = Int.random(in: 1...9)
        return numericMCQ(prompt: "\(a) + ? = 10", answer: 10 - a)
    }

    private static func biggestNumber(max: Int) -> Question {
        var nums = Set<Int>()
        while nums.count < 4 { nums.insert(Int.random(in: 1...max)) }
        let sorted = nums.sorted()
        let options = sorted.shuffled().map(String.init)
        return mcq(prompt: "אֵיזֶה מִסְפָּר הֲכִי גָּדוֹל?",
                   answer: String(sorted.last!), options: options)
    }

    // MARK: - כיתה ב׳ — עד 100, מבוא לכפל (2/5/10), זוגי/אי־זוגי

    private static func grade2(_ d: Difficulty) -> Question {
        switch Int.random(in: 0...3) {
        case 0:  return tagged(addSub(max: d == .easy ? 50 : 100), "addSub")
        case 1:  return tagged(mulIntro(), "mul")
        case 2:  return tagged(evenOdd(max: d == .easy ? 20 : 100), "evenOdd")
        default: return wordProblemAddSub(max: d == .easy ? 50 : 100)
        }
    }

    private static func mulIntro() -> Question {
        let table = [2, 5, 10].randomElement()!
        let b = Int.random(in: 2...9)
        return numericMCQ(prompt: "\(table) × \(b) = ?", answer: table * b)
    }

    private static func evenOdd(max: Int) -> Question {
        let wantEven = Bool.random()
        var pool = Set<Int>()
        // One number of the wanted parity, three of the other.
        let answer = Int.random(in: 1...(max / 2)) * 2 - (wantEven ? 0 : 1)
        pool.insert(answer)
        while pool.count < 4 {
            let n = Int.random(in: 1...(max / 2)) * 2 - (wantEven ? 1 : 0)
            if n != answer { pool.insert(n) }
        }
        return mcq(prompt: wantEven ? "אֵיזֶה מִסְפָּר זוּגִי?" : "אֵיזֶה מִסְפָּר אִי־זוּגִי?",
                   answer: String(answer), options: pool.map(String.init).shuffled())
    }

    // MARK: - כיתה ג׳ — לוח הכפל, חילוק, דו־שלבי, מבוא לשברים, אומדן

    private static func grade3(_ d: Difficulty) -> Question {
        switch Int.random(in: 0...4) {
        case 0:
            let a = Int.random(in: 2...(d == .easy ? 6 : 10))
            let b = Int.random(in: 2...(d == .easy ? 6 : 10))
            return tagged(numericMCQ(prompt: "\(a) × \(b) = ?", answer: a * b), "mul")
        case 1:
            let a = Int.random(in: 2...(d == .easy ? 6 : 10))
            let b = Int.random(in: 2...(d == .easy ? 6 : 10))
            return tagged(numericMCQ(prompt: "\(a * b) ÷ \(a) = ?", answer: b), "div")
        case 2:
            let a = Int.random(in: 2...9), b = Int.random(in: 2...9), c = Int.random(in: 3...20)
            return tagged(numericMCQ(prompt: "\(a) × \(b) + \(c) = ?", answer: a * b + c), "mixedOps")
        case 3:  return tagged(fractionOfShape(), "fractions")
        default: return tagged(wordProblemMultiply(maxFactor: d == .easy ? 5 : 9), "wordProblem")
        }
    }

    /// "חילקנו פיצה ל־N חלקים ואכלנו K" — the visual entry to fractions.
    private static func fractionOfShape() -> Question {
        let parts = [2, 3, 4].randomElement()!
        let eaten = parts == 2 ? 1 : Int.random(in: 1..<parts)
        let answer = "\(eaten)/\(parts)"
        // Compare VALUES, not strings — "2/4" is the same fraction as "1/2" and
        // used to slip in as a second correct answer; the same rule also keeps
        // two equal-valued distractors ("1/3" and "2/6") from appearing together.
        var distractors: [String] = []
        var seenValues: Set<Int> = [eaten * 840 / parts]   // 840 = lcm(2...8)
        for p in [2, 3, 4, 5, 6, 8].shuffled() {
            for e in (1..<p).shuffled() {
                let value = e * 840 / p
                if !seenValues.contains(value) {
                    seenValues.insert(value)
                    distractors.append("\(e)/\(p)")
                }
            }
        }
        return mcq(prompt: "🍕 חִלַּקְנוּ פִּיצָה לְ־\(parts) חֲלָקִים שָׁוִים וְאָכַלְנוּ \(eaten). אֵיזֶה שֶׁבֶר אָכַלְנוּ?",
                   answer: answer,
                   options: ([answer] + Array(distractors.shuffled().prefix(3))).shuffled())
    }

    // MARK: - כיתה ד׳ — שברים, מספרים גדולים, כפל דו־ספרתי, שארית, היקף ושטח

    private static func grade4(_ d: Difficulty) -> Question {
        switch Int.random(in: 0...5) {
        case 0:  return tagged(fractionAddSameDen(), "fractions")
        case 1:  return tagged(fractionCompare(), "fractions")
        case 2:
            let a = Int.random(in: 500...(d == .easy ? 2000 : 8000))
            let b = Int.random(in: 100...1900)
            return tagged(numericMCQ(prompt: "\(a) + \(b) = ?", answer: a + b), "addSub")
        case 3:
            let a = Int.random(in: 12...(d == .easy ? 20 : 40)), b = Int.random(in: 3...9)
            return tagged(numericMCQ(prompt: "\(a) × \(b) = ?", answer: a * b), "mul")
        case 4:  return tagged(divisionWithRemainder(), "divRemainder")
        default: return tagged(rectanglePerimeterArea(), "geometry")
        }
    }

    private static func fractionAddSameDen() -> Question {
        let den = [4, 5, 6, 8, 10].randomElement()!
        let a = Int.random(in: 1..<(den - 1))
        let b = Int.random(in: 1...(den - 1 - a))
        let answer = "\(a + b)/\(den)"
        let distractors = ["\(a + b)/\(den * 2)", "\(max(1, a + b - 1))/\(den)", "\(min(den, a + b + 1))/\(den)"]
            .filter { $0 != answer }
        return mcq(prompt: "\(a)/\(den) + \(b)/\(den) = ?",
                   answer: answer, options: ([answer] + distractors.prefix(3)).shuffled())
    }

    private static func fractionCompare() -> Question {
        // Same numerator, different denominators — the classic ד׳ trap.
        var dens = Set<Int>()
        while dens.count < 2 { dens.insert([2, 3, 4, 5, 6, 8].randomElement()!) }
        let sorted = dens.sorted()
        let (small, big) = (sorted[1], sorted[0])   // bigger denominator = smaller fraction
        let f1 = "1/\(small)", f2 = "1/\(big)"
        return mcq(prompt: "מָה גָּדוֹל יוֹתֵר: \(f1) אוֹ \(f2)?",
                   answer: f2, options: [f1, f2].shuffled())
    }

    private static func divisionWithRemainder() -> Question {
        let b = Int.random(in: 3...9)
        let q = Int.random(in: 3...9)
        let r = Int.random(in: 1..<b)
        let a = b * q + r
        let answer = "\(q) וּשְׁאֵרִית \(r)"
        let distractors = [
            "\(q) וּשְׁאֵרִית \(r == 1 ? r + 1 : r - 1)",
            "\(q + 1) וּשְׁאֵרִית \(r)",
            "\(q) בְּדִיּוּק",
        ]
        return mcq(prompt: "\(a) ÷ \(b) = ?", answer: answer,
                   options: ([answer] + distractors).shuffled())
    }

    private static func rectanglePerimeterArea() -> Question {
        let w = Int.random(in: 2...9), h = Int.random(in: 2...9)
        if Bool.random() {
            return numericMCQ(prompt: "מַלְבֵּן בְּאֹרֶךְ \(w) ס\"מ וּבְרֹחַב \(h) ס\"מ — מָה הַהֶקֵּף שֶׁלּוֹ?",
                              answer: 2 * (w + h), suffix: " ס\"מ")
        }
        return numericMCQ(prompt: "מַלְבֵּן בְּאֹרֶךְ \(w) ס\"מ וּבְרֹחַב \(h) ס\"מ — מָה הַשֶּׁטַח שֶׁלּוֹ?",
                          answer: w * h, suffix: " סמ\"ר")
    }

    // MARK: - כיתה ה׳ — עשרוניים, שברים במכנים שונים, ממוצע, מבוא לאחוזים

    private static func grade5(_ d: Difficulty) -> Question {
        switch Int.random(in: 0...3) {
        case 0:  return tagged(decimalAddSub(easy: d == .easy), "decimals")
        case 1:  return tagged(fractionToDecimal(), "fractions")
        case 2:  return tagged(average(), "average")
        default: return tagged(percentIntro(), "percent")
        }
    }

    private static func decimalAddSub(easy: Bool) -> Question {
        let a = Double(Int.random(in: 10...(easy ? 60 : 90))) / 10
        let b = Double(Int.random(in: 5...40)) / 10
        let add = Bool.random()
        let answer = add ? a + b : max(a, b) - min(a, b)
        let prompt = add ? "\(fmt(a)) + \(fmt(b)) = ?" : "\(fmt(max(a, b))) − \(fmt(min(a, b))) = ?"
        var opts: Set<String> = [fmt(answer)]
        while opts.count < 4 {
            let delta = Double(Int.random(in: 1...15)) / 10 * (Bool.random() ? 1 : -1)
            let c = answer + delta
            if c > 0 { opts.insert(fmt(c)) }
        }
        return mcq(prompt: prompt, answer: fmt(answer), options: opts.shuffled())
    }

    private static func fractionToDecimal() -> Question {
        let pairs: [(String, String)] = [("1/2", "0.5"), ("1/4", "0.25"), ("3/4", "0.75"),
                                         ("1/5", "0.2"), ("1/10", "0.1"), ("2/5", "0.4")]
        let (frac, dec) = pairs.randomElement()!
        let distractors = pairs.map(\.1).filter { $0 != dec }.shuffled().prefix(3)
        return mcq(prompt: "אֵיךְ כּוֹתְבִים אֶת \(frac) כְּמִסְפָּר עֶשְׂרוֹנִי?",
                   answer: dec, options: ([dec] + distractors).shuffled())
    }

    private static func average() -> Question {
        let m = Int.random(in: 3...12)
        let spread = Int.random(in: 1...4)
        let nums = [m - spread, m, m + spread].shuffled()
        return numericMCQ(prompt: "מָה הַמְמֻצָּע שֶׁל \(nums[0]), \(nums[1]) וְ־\(nums[2])?", answer: m)
    }

    private static func percentIntro() -> Question {
        let base = [40, 60, 80, 100, 200].randomElement()!
        let pct = [10, 25, 50].randomElement()!
        return numericMCQ(prompt: "כַּמָּה הֵם \(pct)% מִ־\(base)?", answer: base * pct / 100)
    }

    // MARK: - כיתה ו׳ — אחוזים, יחס, סדר פעולות, בעיות רב־שלביות

    private static func grade6(_ d: Difficulty) -> Question {
        switch Int.random(in: 0...3) {
        case 0:
            // Only pairs whose result is WHOLE — 150×25% used to show "37"
            // (37.5 truncated), failing kids who computed correctly.
            let base = [60, 120, 150, 200, 300].randomElement()!
            let pct = [10, 20, 25, 30, 50, 75].filter { base * $0 % 100 == 0 }.randomElement()!
            return numericMCQ(prompt: "כַּמָּה הֵם \(pct)% מִ־\(base)?", answer: base * pct / 100)
        case 1:  return orderOfOperations(hard: d == .hard)
        case 2:  return ratio()
        default: return wordProblemTwoStep()
        }
    }

    private static func orderOfOperations(hard: Bool) -> Question {
        let a = Int.random(in: 2...9), b = Int.random(in: 2...9), c = Int.random(in: 2...9)
        if hard {
            // (a + b) × c vs a + b × c — the parentheses matter.
            return numericMCQ(prompt: "(\(a) + \(b)) × \(c) = ?", answer: (a + b) * c,
                              plant: a + b * c)
        }
        return numericMCQ(prompt: "\(a) + \(b) × \(c) = ?", answer: a + b * c,
                          plant: (a + b) * c)
    }

    private static func ratio() -> Question {
        let unit = Int.random(in: 2...6)
        let x = Int.random(in: 2...5), y = Int.random(in: 2...5)
        // x:y must already be fully reduced — (2,4) used to present "2:4" as the
        // "reduced" answer while the real reduction 1:2 wasn't even offered.
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        guard x != y, gcd(x, y) == 1 else { return ratio() }
        let answer = "\(x):\(y)"
        let distractors = ["\(y):\(x)", "\(x * unit):\(y)", "\(x + 1):\(y)"].filter { $0 != answer }
        return mcq(prompt: "בַּכִּתָּה \(x * unit) בָּנִים וְ־\(y * unit) בָּנוֹת. מָה הַיַּחַס בֵּין בָּנִים לְבָנוֹת בְּצוּרָה מְצֻמְצֶמֶת?",
                   answer: answer, options: ([answer] + distractors.prefix(3)).shuffled())
    }

    // MARK: - בעיות מילוליות (תבניות עם שמות מתחלפים)

    private static let kids = ["דָּנָה", "יוֹסִי", "נֹעָה", "אִיתַי", "תָּמָר", "עוֹמֶר"]
    private static let things: [(String, String)] = [("🎈", "בַּלּוֹנִים"), ("📚", "סְפָרִים"),
                                                     ("🍎", "תַּפּוּחִים"), ("⚽", "כַּדּוּרִים"),
                                                     ("🖍️", "צְבָעִים"), ("🐚", "צְדָפִים")]

    private static func wordProblemAddSub(max: Int) -> Question {
        let name = kids.randomElement()!
        let (emoji, item) = things.randomElement()!
        let a = Int.random(in: 3...max)
        if Bool.random() {
            let b = Int.random(in: 2...max)
            return numericMCQ(prompt: "\(emoji) לְ\(name) יֵשׁ \(a) \(item). \(name) קִבֵּל/ה עוֹד \(b). כַּמָּה יֵשׁ עַכְשָׁיו?",
                              answer: a + b)
        }
        let b = Int.random(in: 1..<a)
        return numericMCQ(prompt: "\(emoji) לְ\(name) הָיוּ \(a) \(item), וְ\(name) נָתַן/ה \(b) לְחָבֵר. כַּמָּה נִשְׁאֲרוּ?",
                          answer: a - b)
    }

    private static func wordProblemMultiply(maxFactor: Int) -> Question {
        let name = kids.randomElement()!
        let (emoji, item) = things.randomElement()!
        let packs = Int.random(in: 2...maxFactor), per = Int.random(in: 2...maxFactor)
        return numericMCQ(prompt: "\(emoji) לְ\(name) יֵשׁ \(packs) חֲבִילוֹת שֶׁל \(item), וּבְכָל חֲבִילָה \(per). כַּמָּה יֵשׁ בְּסַךְ הַכֹּל?",
                          answer: packs * per)
    }

    private static func wordProblemTwoStep() -> Question {
        let name = kids.randomElement()!
        let price = Int.random(in: 6...15)
        let count = Int.random(in: 2...4)
        let paid = ((price * count / 10) + 1) * 10 + [0, 10].randomElement()!
        return numericMCQ(prompt: "💰 \(name) קָנָה/תָה \(count) מַחְבָּרוֹת בְּ־\(price) שְׁקָלִים כָּל אַחַת, וְשִׁלֵּם/ה בְּ־\(paid) שְׁקָלִים. כַּמָּה עֹדֶף מַגִּיעַ?",
                          answer: paid - price * count)
    }

    // MARK: - Builders

    private static func fmt(_ d: Double) -> String {
        let r = (d * 100).rounded() / 100
        return r == r.rounded() ? String(Int(r)) : String(r)
    }

    /// Numeric MCQ with plausible numeric distractors. `plant` forces one
    /// specific wrong answer in (e.g. the no-parentheses trap).
    private static func numericMCQ(prompt: String, answer: Int, suffix: String = "",
                                   plant: Int? = nil) -> Question {
        var options: Set<Int> = [answer]
        if let plant, plant != answer, plant >= 0 { options.insert(plant) }
        while options.count < 4 {
            let delta = Int.random(in: 1...Swift.max(3, abs(answer) / 2 + 2))
            let candidate = Bool.random() ? answer + delta : answer - delta
            if candidate >= 0 { options.insert(candidate) }
        }
        let shuffled = options.shuffled()
        return Question(
            topic: .math,
            prompt: prompt,
            options: shuffled.map { "\($0)\(suffix)" },
            correctIndex: shuffled.firstIndex(of: answer) ?? 0
        )
    }

    private static func mcq(prompt: String, answer: String, options: [String]) -> Question {
        var opts = options
        if !opts.contains(answer) { opts[0] = answer; opts.shuffle() }
        return Question(
            topic: .math,
            prompt: prompt,
            options: opts,
            correctIndex: opts.firstIndex(of: answer) ?? 0
        )
    }
}
