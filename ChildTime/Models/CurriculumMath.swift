import Foundation

/// 🎓 Curriculum-aligned math (תוכנית משרד החינוך, בקירוב): the generator picks
/// a MODULE from the child's grade, then renders a question at the requested
/// difficulty — so a 4th grader really meets שברים, שארית, שטח והיקף instead of
/// the one-size "84÷7" the legacy generator produced.
///
/// Difficulty stays WITHIN the grade (the adaptive engine keeps working): easy
/// leans on the grade's entry modules, hard on its heaviest — and peeks one
/// grade up 20% of the time (העשרה). Grade comes from `Profile.effectiveGrade`
/// (parent-set grade, else derived from the age bracket). ז׳–ח׳ are middle
/// school (Rani, 2026-09-11: "עד כיתה ח כולל"); 9+ serves ח׳ material.
enum CurriculumMath {
    /// The highest grade with its own material.
    static let topGrade = 8

    /// Stamp a generated question with the skill it exercises, so the parent
    /// report can tell "strong in multiplication" from "struggling with fractions".
    private static func tagged(_ q: Question, _ skill: String) -> Question {
        var q = q; q.skill = skill; return q
    }

    static func generate(grade: Int, difficulty: Difficulty) -> Question {
        let g = max(1, min(topGrade, grade))
        if difficulty == .hard, g < topGrade, Double.random(in: 0...1) < 0.2 {
            return generate(grade: g + 1, difficulty: .medium)   // העשרה
        }
        switch g {
        case 1:  return grade1(difficulty)
        case 2:  return grade2(difficulty)
        case 3:  return grade3(difficulty)
        case 4:  return grade4(difficulty)
        case 5:  return grade5(difficulty)
        case 6:  return grade6(difficulty)
        case 7:  return grade7(difficulty)
        default: return grade8(difficulty)
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
        return mcq(prompt: tr("אֵיזֶה מִסְפָּר הֲכִי גָּדוֹל?"),
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
        return mcq(prompt: wantEven ? tr("אֵיזֶה מִסְפָּר זוּגִי?") : tr("אֵיזֶה מִסְפָּר אִי־זוּגִי?"),
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
        return mcq(prompt: tr("🍕 חִלַּקְנוּ פִּיצָה לְ־\(parts) חֲלָקִים שָׁוִים וְאָכַלְנוּ \(eaten). אֵיזֶה שֶׁבֶר אָכַלְנוּ?"),
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
        return mcq(prompt: tr("מָה גָּדוֹל יוֹתֵר: \(f1) אוֹ \(f2)?"),
                   answer: f2, options: [f1, f2].shuffled())
    }

    private static func divisionWithRemainder() -> Question {
        let b = Int.random(in: 3...9)
        let q = Int.random(in: 3...9)
        let r = Int.random(in: 1..<b)
        let a = b * q + r
        let answer = tr("\(q) וּשְׁאֵרִית \(r)")
        let distractors = [
            tr("\(q) וּשְׁאֵרִית \(r == 1 ? r + 1 : r - 1)"),
            tr("\(q + 1) וּשְׁאֵרִית \(r)"),
            tr("\(q) בְּדִיּוּק"),
        ]
        return mcq(prompt: "\(a) ÷ \(b) = ?", answer: answer,
                   options: ([answer] + distractors).shuffled())
    }

    private static func rectanglePerimeterArea() -> Question {
        let w = Int.random(in: 2...9), h = Int.random(in: 2...9)
        if Bool.random() {
            return numericMCQ(prompt: tr("מַלְבֵּן בְּאֹרֶךְ \(w) ס\"מ וּבְרֹחַב \(h) ס\"מ — מָה הַהֶקֵּף שֶׁלּוֹ?"),
                              answer: 2 * (w + h), suffix: tr(" ס\"מ"))
        }
        return numericMCQ(prompt: tr("מַלְבֵּן בְּאֹרֶךְ \(w) ס\"מ וּבְרֹחַב \(h) ס\"מ — מָה הַשֶּׁטַח שֶׁלּוֹ?"),
                          answer: w * h, suffix: tr(" סמ\"ר"))
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
        return mcq(prompt: tr("אֵיךְ כּוֹתְבִים אֶת \(frac) כְּמִסְפָּר עֶשְׂרוֹנִי?"),
                   answer: dec, options: ([dec] + distractors).shuffled())
    }

    private static func average() -> Question {
        let m = Int.random(in: 3...12)
        let spread = Int.random(in: 1...4)
        let nums = [m - spread, m, m + spread].shuffled()
        return numericMCQ(prompt: tr("מָה הַמְמֻצָּע שֶׁל \(nums[0]), \(nums[1]) וְ־\(nums[2])?"), answer: m)
    }

    private static func percentIntro() -> Question {
        let base = [40, 60, 80, 100, 200].randomElement()!
        let pct = [10, 25, 50].randomElement()!
        return numericMCQ(prompt: tr("כַּמָּה הֵם \(pct)% מִ־\(base)?"), answer: base * pct / 100)
    }

    // MARK: - כיתה ו׳ — אחוזים, יחס, סדר פעולות, בעיות רב־שלביות

    private static func grade6(_ d: Difficulty) -> Question {
        switch Int.random(in: 0...3) {
        case 0:
            // Only pairs whose result is WHOLE — 150×25% used to show "37"
            // (37.5 truncated), failing kids who computed correctly.
            let base = [60, 120, 150, 200, 300].randomElement()!
            let pct = [10, 20, 25, 30, 50, 75].filter { base * $0 % 100 == 0 }.randomElement()!
            return numericMCQ(prompt: tr("כַּמָּה הֵם \(pct)% מִ־\(base)?"), answer: base * pct / 100)
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
        return mcq(prompt: tr("בַּכִּתָּה \(x * unit) בָּנִים וְ־\(y * unit) בָּנוֹת. מָה הַיַּחַס בֵּין בָּנִים לְבָנוֹת בְּצוּרָה מְצֻמְצֶמֶת?"),
                   answer: answer, options: ([answer] + distractors.prefix(3)).shuffled())
    }

    // MARK: - כיתה ז׳ — מספרים מכוונים, ביטויים ומשוואות, חזקות, אחוזים, זוויות, פרופורציה

    private static func grade7(_ d: Difficulty) -> Question {
        switch Int.random(in: 0...7) {
        case 0:  return tagged(signedArithmetic(hard: d == .hard), "negatives")
        case 1:  return tagged(substitute(), "expressions")
        case 2:  return tagged(oneVariableEquation(twoStep: d != .easy), "equations")
        case 3:  return tagged(power(), "powers")
        case 4:  return tagged(percentChange(), "percent")
        case 5:  return tagged(angles(), "angles")
        case 6:  return tagged(proportion(), "proportion")
        default: return tagged(triangleArea(), "geometry")
        }
    }

    /// (−7) + 4, 5 − 9, (−3) × (−6): the sign is the whole skill, so the planted
    /// wrong answers are exactly the sign slips.
    private static func signedArithmetic(hard: Bool) -> Question {
        let a = Int.random(in: 2...12) * (Bool.random() ? -1 : 1)
        let b = Int.random(in: 2...12) * (Bool.random() ? -1 : 1)
        switch Int.random(in: 0...(hard ? 2 : 1)) {
        case 0:
            return signedMCQ(prompt: ltr("\(paren(a)) + \(paren(b)) = ?"), answer: a + b,
                             plants: [-(a + b), abs(a) + abs(b), a - b])
        case 1:
            return signedMCQ(prompt: ltr("\(paren(a)) − \(paren(b)) = ?"), answer: a - b,
                             plants: [-(a - b), a + b, abs(a) - abs(b)])
        default:
            let x = Int.random(in: 2...9) * (Bool.random() ? -1 : 1), y = Int.random(in: 2...9) * (Bool.random() ? -1 : 1)
            return signedMCQ(prompt: ltr("\(paren(x)) × \(paren(y)) = ?"), answer: x * y,
                             plants: [-(x * y), x + y])
        }
    }

    /// "3x − 5 כש־x = 4" — plants: forgetting the multiplication (3+4−5) and
    /// reading 3x as the digits "34".
    private static func substitute() -> Question {
        let k = Int.random(in: 2...9), x = Int.random(in: 2...9), c = Int.random(in: 1...12)
        let plus = Bool.random()
        let expr = plus ? "\(k)x + \(c)" : "\(k)x − \(c)"
        let answer = plus ? k * x + c : k * x - c
        return signedMCQ(prompt: tr("\(ltr(expr))\nמָה עֵרֶךְ הַבִּטּוּי כְּשֶׁ־\(ltr("x = \(x)"))?"), answer: answer,
                         plants: [plus ? k + x + c : k + x - c, plus ? k * 10 + x + c : k * 10 + x - c])
    }

    /// kx + c = r with a whole answer. Plant: stopping after subtracting c.
    private static func oneVariableEquation(twoStep: Bool) -> Question {
        let x = Int.random(in: -6...12), k = twoStep ? Int.random(in: 2...9) : 1
        let c = Int.random(in: 1...15) * (Bool.random() ? -1 : 1)
        let r = k * x + c
        let left = "\(coef(k))x"
        let eq = c >= 0 ? "\(left) + \(c) = \(signed(r))" : "\(left) − \(-c) = \(signed(r))"
        return signedMCQ(prompt: tr("\(ltr(eq))\nמָה הָעֵרֶךְ שֶׁל x?"), answer: x,
                         plants: [r - c == x ? r + c : r - c, r + c, k > 1 ? r / k : r])
    }

    /// 2⁵, 7², 3⁴ — plant: base × exponent, the classic mix-up.
    private static func power() -> Question {
        let pairs = [(2, 3), (2, 4), (2, 5), (2, 6), (3, 2), (3, 3), (3, 4), (4, 2), (4, 3), (5, 2), (5, 3),
                     (6, 2), (7, 2), (8, 2), (9, 2), (10, 3), (11, 2), (12, 2), (13, 2), (15, 2)]
        let (b, e) = pairs.randomElement()!
        return signedMCQ(prompt: ltr("\(b)\(superscript(e)) = ?"), answer: Int(pow(Double(b), Double(e))),
                         plants: [b * e, b + e], allowNegative: false)
    }

    /// A price goes up or down by a whole percentage. Plants: the change alone,
    /// and the opposite direction.
    private static func percentChange() -> Question {
        let base = [40, 60, 80, 120, 150, 200, 240, 300, 400].randomElement()!
        let pct = [10, 20, 25, 30, 40, 50].filter { base * $0 % 100 == 0 }.randomElement()!
        let change = base * pct / 100, up = Bool.random()
        let answer = up ? base + change : base - change
        return signedMCQ(prompt: tr("🏷️ מְחִיר שֶׁל \(base) ₪ \(up ? tr("עָלָה") : tr("יָרַד")) בְּ־\(pct)%. מָה הַמְּחִיר הֶחָדָשׁ?"),
                         answer: answer, prefix: Money.answerPrefix, suffix: Money.answerSuffix, plants: [change, up ? base - change : base + change],
                         allowNegative: false)
    }

    /// The third angle of a triangle, or the angle next to one on a straight line.
    private static func angles() -> Question {
        if Bool.random() {
            let a = Int.random(in: 3...12) * 5, b = Int.random(in: 3...(30 - a / 5)) * 5
            let answer = 180 - a - b
            guard answer > 0 else { return angles() }
            return signedMCQ(prompt: tr("📐 בִּמְשֻׁלָּשׁ יֵשׁ זָוִית שֶׁל \(a)° וְזָוִית שֶׁל \(b)°. מָה גֹּדֶל הַזָּוִית הַשְּׁלִישִׁית?"),
                             answer: answer, suffix: "°", plants: [a + b, 360 - a - b, 90 - min(a, b) > 0 ? 90 - min(a, b) : a], allowNegative: false)
        }
        let a = Int.random(in: 4...32) * 5
        return signedMCQ(prompt: tr("📐 שְׁתֵּי זָוִיּוֹת צְמוּדוֹת. אַחַת הִיא \(a)°. מָה גֹּדֶל הַשְּׁנִיָּה?"),
                         answer: 180 - a, suffix: "°", plants: [90 - a > 0 ? 90 - a : 360 - a, a], allowNegative: false)
    }

    /// n items cost p — how much do m cost? Plant: scaling by the difference.
    private static func proportion() -> Question {
        let unit = Int.random(in: 3...15), n = Int.random(in: 2...6)
        var m = Int.random(in: 3...12)
        if m == n { m += 1 }
        return signedMCQ(prompt: tr("📒 \(n) מַחְבָּרוֹת עוֹלוֹת \(unit * n) ₪. כַּמָּה יַעֲלוּ \(m) מַחְבָּרוֹת?"),
                         answer: unit * m, prefix: Money.answerPrefix, suffix: Money.answerSuffix, plants: [unit * n + (m - n), unit * n * m], allowNegative: false)
    }

    private static func triangleArea() -> Question {
        let base = Int.random(in: 3...14), height = Int.random(in: 2...12)
        guard base * height % 2 == 0 else { return triangleArea() }
        return signedMCQ(prompt: tr("🔺 מְשֻׁלָּשׁ שֶׁבָּסִיסוֹ \(base) ס\"מ וְהַגֹּבַהּ אֵלָיו \(height) ס\"מ. מָה הַשֶּׁטַח שֶׁלּוֹ?"),
                         answer: base * height / 2, suffix: tr(" סמ\"ר"), plants: [base * height, base + height], allowNegative: false)
    }

    // MARK: - כיתה ח׳ — משוואות, פיתגורס, שורשים, פונקציה קווית, נפח, הסתברות, מעגל

    private static func grade8(_ d: Difficulty) -> Question {
        switch Int.random(in: 0...7) {
        case 0:  return tagged(equationBothSides(brackets: d == .hard || Bool.random()), "equations")
        case 1:  return tagged(pythagoras(), "pythagoras")
        case 2:  return tagged(squareRoot(), "roots")
        case 3:  return tagged(linearFunction(), "linearFunction")
        case 4:  return tagged(boxVolume(), "volume")
        case 5:  return tagged(powerLaws(), "powers")
        case 6:  return tagged(probability(), "probability")
        default: return tagged(d == .easy ? signedArithmetic(hard: true) : circle(), d == .easy ? "negatives" : "circle")
        }
    }

    /// a(x + b) = r   or   ax + b = cx + e — always a whole x.
    private static func equationBothSides(brackets: Bool) -> Question {
        let x = Int.random(in: -5...10)
        if brackets {
            let a = Int.random(in: 2...6), b = Int.random(in: -6...9)
            let r = a * (x + b)
            let inner = b == 0 ? "x" : b > 0 ? "x + \(b)" : "x − \(-b)"
            return signedMCQ(prompt: tr("\(ltr("\(a)(\(inner)) = \(signed(r))"))\nמָה הָעֵרֶךְ שֶׁל x?"), answer: x,
                             // Plants: opening only the first term (ax + b = r), and dividing then adding.
                             plants: [(r - b) / a, r / a + b])
        }
        let a = Int.random(in: 3...9), c = Int.random(in: 1...(a - 1)), b = Int.random(in: -12...12)
        let e = (a - c) * x + b
        func side(_ k: Int, _ n: Int) -> String { n == 0 ? "\(coef(k))x" : n > 0 ? "\(coef(k))x + \(n)" : "\(coef(k))x − \(-n)" }
        return signedMCQ(prompt: tr("\(ltr("\(side(a, b)) = \(side(c, e))"))\nמָה הָעֵרֶךְ שֶׁל x?"), answer: x,
                         // Plants: adding the x terms instead of subtracting, and a sign slip on the numbers.
                         plants: [(e - b) / (a + c), (e + b) / (a - c)])
    }

    /// A right triangle from a Pythagorean triple — the hypotenuse or a leg.
    private static func pythagoras() -> Question {
        let triples = [(3, 4, 5), (6, 8, 10), (5, 12, 13), (8, 15, 17), (9, 12, 15), (7, 24, 25), (12, 16, 20), (9, 40, 41), (15, 20, 25)]
        let (a, b, c) = triples.randomElement()!
        if Bool.random() {
            return signedMCQ(prompt: tr("📐 בִּמְשֻׁלָּשׁ יְשַׁר זָוִית אָרְכֵי הַנִּצָּבִים \(a) ס\"מ וְ־\(b) ס\"מ. מָה אֹרֶךְ הַיֶּתֶר?"),
                             answer: c, suffix: tr(" ס\"מ"), plants: [a + b, a * a + b * b], allowNegative: false)
        }
        return signedMCQ(prompt: tr("📐 בִּמְשֻׁלָּשׁ יְשַׁר זָוִית הַיֶּתֶר \(c) ס\"מ וְאַחַד הַנִּצָּבִים \(a) ס\"מ. מָה אֹרֶךְ הַנִּצָּב הַשֵּׁנִי?"),
                         answer: b, suffix: tr(" ס\"מ"), plants: [c - a, c + a], allowNegative: false)
    }

    private static func squareRoot() -> Question {
        let r = Int.random(in: 4...20)
        return signedMCQ(prompt: ltr("√\(r * r) = ?"), answer: r, plants: [r * r / 2, r * 2], allowNegative: false)
    }

    /// y = mx + b: its value at x, or its slope. Plants: the intercept for the
    /// slope, and a sign slip.
    private static func linearFunction() -> Question {
        let m = Int.random(in: 1...6) * (Bool.random() ? -1 : 1), b = Int.random(in: -9...9)
        let rule = b == 0 ? "y = \(coef(m))x" : (b > 0 ? "y = \(coef(m))x + \(b)" : "y = \(coef(m))x − \(-b)")
        if Bool.random() {
            let x = Int.random(in: -4...6)
            return signedMCQ(prompt: tr("📈 \(ltr(rule))\nמָה הָעֵרֶךְ שֶׁל y כְּשֶׁ־\(ltr("x = \(x)"))?"), answer: m * x + b,
                             plants: [m * x - b, m + x + b])
        }
        return signedMCQ(prompt: tr("📈 \(ltr(rule))\nמָה הַשִּׁפּוּעַ שֶׁל הַיָּשָׁר?"), answer: m,
                         plants: [b == m ? -m : b, -m])
    }

    private static func boxVolume() -> Question {
        let l = Int.random(in: 2...12), w = Int.random(in: 2...9), h = Int.random(in: 2...8)
        return signedMCQ(prompt: tr("📦 תֵּבָה בְּאֹרֶךְ \(l) ס\"מ, רֹחַב \(w) ס\"מ וְגֹבַהּ \(h) ס\"מ. מָה הַנֶּפַח שֶׁלָּהּ?"),
                         answer: l * w * h, suffix: tr(" סמ\"ק"), plants: [l + w + h, 2 * (l * w + l * h + w * h)], allowNegative: false)
    }

    /// aᵐ · aⁿ = a^? — plant: multiplying the exponents.
    private static func powerLaws() -> Question {
        let a = [2, 3, 5, 7, 10].randomElement()!, m = Int.random(in: 2...6), n = Int.random(in: 2...6)
        if Bool.random() {
            return signedMCQ(prompt: tr("\(ltr("\(a)\(superscript(m)) · \(a)\(superscript(n)) = \(a)ⁿ"))\nמָה הָעֵרֶךְ שֶׁל n?"),
                             answer: m + n, plants: [m * n, abs(m - n)], allowNegative: false)
        }
        let big = m + n
        return signedMCQ(prompt: tr("\(ltr("\(a)\(superscript(big)) : \(a)\(superscript(m)) = \(a)ⁿ"))\nמָה הָעֵרֶךְ שֶׁל n?"),
                         answer: n, plants: [big + m, max(1, big / m)], allowNegative: false)
    }

    /// Red and blue marbles: the chance of drawing red, as a reduced fraction.
    private static func probability() -> Question {
        let red = Int.random(in: 1...7), blue = Int.random(in: 1...9)
        func gcd(_ x: Int, _ y: Int) -> Int { y == 0 ? x : gcd(y, x % y) }
        func frac(_ n: Int, _ d: Int) -> String { let g = gcd(n, d); return ltr("\(n / g)/\(d / g)") }
        let answer = frac(red, red + blue)
        // Plants: red out of blue (not out of all), and the chance of blue.
        var options = [answer]
        for cand in [frac(red, blue), frac(blue, red + blue), frac(red + 1, red + blue + 1), frac(1, red + blue), frac(red, red + blue + 2)] {
            if options.count < 4, !options.contains(cand) { options.append(cand) }
        }
        guard options.count == 4 else { return probability() }
        let r = red == 1 ? tr("כַּדּוּר אָדֹם אֶחָד") : tr("\(red) כַּדּוּרִים אֲדֻמִּים")
        let b = blue == 1 ? tr("כַּדּוּר כָּחֹל אֶחָד") : tr("\(blue) כַּדּוּרִים כְּחֻלִּים")
        return mcq(prompt: rtlLines(tr("🎲 בְּשַׂקִּית \(r) וְ־\(b). שׁוֹלְפִים כַּדּוּר אֶחָד בְּלִי לְהִסְתַּכֵּל. מָה הַסִּכּוּי שֶׁהוּא אָדֹם?")),
                   answer: answer, options: options.shuffled())
    }

    /// Circumference or area with π = 3.14. Plants: the other formula, and πr.
    private static func circle() -> Question {
        let r = [1, 2, 3, 4, 5, 10].randomElement()!
        let circumference = fmt(2 * 3.14 * Double(r)), area = fmt(3.14 * Double(r * r)), half = fmt(3.14 * Double(r))
        let askArea = Bool.random()
        let answer = askArea ? area : circumference
        var options = [answer]
        for cand in [askArea ? circumference : area, half, fmt(3.14 * Double(2 * r * 2 * r)), fmt(Double(2 * r) * 2)] {
            if options.count < 4, !options.contains(cand) { options.append(cand) }
        }
        let unit = askArea ? tr(" סמ\"ר") : tr(" ס\"מ")
        return mcq(prompt: rtlLines(tr("⭕ מַעְגָּל שֶׁהָרַדְיוּס שֶׁלּוֹ \(r) ס\"מ. מָה \(askArea ? tr("הַשֶּׁטַח") : tr("הַהֶקֵּף")) שֶׁלּוֹ? (\(ltr("π = 3.14")))")),
                   answer: answer + unit, options: options.map { $0 + unit }.shuffled())
    }

    // MARK: - בעיות מילוליות (תבניות עם שמות מתחלפים)

    // Names are content, not translations: an American word problem gets American names.
    // Each name carries the gender its verbs have to agree with — a learning app
    // cannot ship "יוֹסִי קָנָה/תָה" (Rani), so every sentence below exists twice.
    private static var kids: [(name: String, girl: Bool)] {
        LanguageStore.shared.current == .he
            ? [(tr("דָּנָה"), true), (tr("יוֹסִי"), false), (tr("נֹעָה"), true),
               (tr("אִיתַי"), false), (tr("תָּמָר"), true), (tr("עוֹמֶר"), false)]
            : [("Emma", true), ("Liam", false), ("Olivia", true),
               ("Noah", false), ("Ava", true), ("Mason", false)]
    }
    private static var things: [(String, String)] {
        [("🎈", tr("בַּלּוֹנִים")), ("📚", tr("סְפָרִים")), ("🍎", tr("תַּפּוּחִים")),
         ("⚽", tr("כַּדּוּרִים")), ("🖍️", tr("צְבָעִים")), ("🐚", tr("צְדָפִים"))]
    }

    private static func wordProblemAddSub(max: Int) -> Question {
        let kid = kids.randomElement()!, name = kid.name
        let (emoji, item) = things.randomElement()!
        let a = Int.random(in: 3...max)
        if Bool.random() {
            let b = Int.random(in: 2...max)
            return numericMCQ(prompt: kid.girl
                ? tr("\(emoji) לְ\(name) יֵשׁ \(a) \(item). \(name) קִבְּלָה עוֹד \(b). כַּמָּה יֵשׁ עַכְשָׁיו?")
                : tr("\(emoji) לְ\(name) יֵשׁ \(a) \(item). \(name) קִבֵּל עוֹד \(b). כַּמָּה יֵשׁ עַכְשָׁיו?"),
                              answer: a + b)
        }
        let b = Int.random(in: 1..<a)
        return numericMCQ(prompt: kid.girl
            ? tr("\(emoji) לְ\(name) הָיוּ \(a) \(item), וְ\(name) נָתְנָה \(b) לְחָבֵר. כַּמָּה נִשְׁאֲרוּ?")
            : tr("\(emoji) לְ\(name) הָיוּ \(a) \(item), וְ\(name) נָתַן \(b) לְחָבֵר. כַּמָּה נִשְׁאֲרוּ?"),
                          answer: a - b)
    }

    private static func wordProblemMultiply(maxFactor: Int) -> Question {
        let name = kids.randomElement()!.name
        let (emoji, item) = things.randomElement()!
        let packs = Int.random(in: 2...maxFactor), per = Int.random(in: 2...maxFactor)
        return numericMCQ(prompt: tr("\(emoji) לְ\(name) יֵשׁ \(packs) חֲבִילוֹת שֶׁל \(item), וּבְכָל חֲבִילָה \(per). כַּמָּה יֵשׁ בְּסַךְ הַכֹּל?"),
                          answer: packs * per)
    }

    private static func wordProblemTwoStep() -> Question {
        let kid = kids.randomElement()!, name = kid.name
        let price = Int.random(in: 6...15)
        let count = Int.random(in: 2...4)
        let paid = ((price * count / 10) + 1) * 10 + [0, 10].randomElement()!
        return numericMCQ(prompt: kid.girl
            ? tr("💰 \(name) קָנְתָה \(count) מַחְבָּרוֹת בְּ־\(price) שְׁקָלִים כָּל אַחַת, וְשִׁלְּמָה בְּ־\(paid) שְׁקָלִים. כַּמָּה עֹדֶף מַגִּיעַ?")
            : tr("💰 \(name) קָנָה \(count) מַחְבָּרוֹת בְּ־\(price) שְׁקָלִים כָּל אַחַת, וְשִׁלֵּם בְּ־\(paid) שְׁקָלִים. כַּמָּה עֹדֶף מַגִּיעַ?"),
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

    /// Keeps a math run left-to-right inside a Hebrew line, and in one piece.
    /// Without the isolate "−3" can render as "3−" and "(−7) + 4 = ?" comes out
    /// reversed; without the no-break spaces a wrap split "x = 0" across lines.
    static func ltr(_ s: String) -> String {
        "\u{2066}\(s.replacingOccurrences(of: " ", with: "\u{00A0}"))\u{2069}"
    }

    /// Start every line right-to-left. iOS takes the direction of the whole
    /// prompt from its first letter, so "📈 y = −2x − 9\nמָה הַשִּׁפּוּעַ…" laid the
    /// Hebrew line out left-to-right, words in reverse. The math itself stays
    /// left-to-right inside its `ltr` isolate.
    private static func rtlLines(_ s: String) -> String {
        guard LanguageStore.shared.current == .he else { return s }   // only right-to-left languages need it
        return s.split(separator: "\n", omittingEmptySubsequences: false).map { "\u{200F}" + $0 }.joined(separator: "\n")
    }

    /// −3 with a real minus sign, and parentheses around negatives inside an
    /// expression: "(−7) + 4".
    private static func signed(_ n: Int) -> String { n < 0 ? "−\(-n)" : "\(n)" }
    private static func paren(_ n: Int) -> String { n < 0 ? "(−\(-n))" : "\(n)" }
    /// A coefficient in front of x: "x", "−x", "3x", "−3x" — never "1x".
    private static func coef(_ k: Int) -> String { k == 1 ? "" : k == -1 ? "−" : signed(k) }

    private static func superscript(_ n: Int) -> String {
        let map: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"]
        return String(String(n).map { map[$0] ?? $0 })
    }

    /// Numeric MCQ for middle school: answers may be negative, and `plants` are
    /// the specific mistakes worth testing (sign slips, the wrong formula) —
    /// they go in first, then near misses. `numericMCQ` never offers a negative
    /// option, and with a negative answer it could loop forever.
    private static func signedMCQ(prompt: String, answer: Int, prefix: String = "", suffix: String = "",
                                  plants: [Int] = [], allowNegative: Bool = true) -> Question {
        var options: [Int] = [answer]
        func add(_ v: Int) { if options.count < 4, !options.contains(v), allowNegative || v >= 0 { options.append(v) } }
        for p in plants.shuffled() { add(p) }
        let spread = Swift.max(3, abs(answer) / 4 + 2)
        var tries = 0
        while options.count < 4 && tries < 200 {
            tries += 1
            let delta = Int.random(in: 1...spread)
            add(Bool.random() ? answer + delta : answer - delta)
        }
        var k = 1
        while options.count < 4 { add(answer + k); k += 1 }
        let shuffled = options.shuffled()
        return Question(
            topic: .math,
            prompt: rtlLines(prompt),
            options: shuffled.map { ltr(prefix + signed($0)) + suffix },
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
