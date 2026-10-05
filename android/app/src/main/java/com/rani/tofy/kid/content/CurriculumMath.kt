package com.rani.tofy.kid.content

import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import kotlin.math.abs
import kotlin.math.pow
import kotlin.random.Random

/**
 * 🎓 CurriculumMath.swift — curriculum-aligned math (משרד החינוך, בקירוב).
 * The generator picks a MODULE from the child's grade, then renders it at the
 * requested difficulty; hard peeks one grade up 20% of the time (העשרה).
 * ז׳–ח׳ are middle school; 9+ serves ח׳ material.
 *
 * Every user-facing string goes through tr() with the exact iOS catalog key
 * (Swift interpolation → %@ / %lld). `lang` is the CONTENT language: it picks
 * the word-problem names, the countable nouns, ₪ vs $, and the RTL line marks.
 */
object CurriculumMath {
    /** The highest grade with its own material. */
    const val TOP_GRADE = 8

    private fun tagged(q: Question, skill: String) = q.copy(skill = skill)

    fun generate(grade: Int, difficulty: Difficulty, lang: AppLanguage, rng: Random = Random.Default): Question =
        Gen(lang, rng).generate(grade, difficulty)

    /** One generation pass — carries the language and the random source. */
    private class Gen(val lang: AppLanguage, val rng: Random) {
        fun int(range: IntRange) = range.random(rng)
        fun bool() = rng.nextBoolean()
        fun <T> pick(list: List<T>) = list.random(rng)

        fun generate(grade: Int, d: Difficulty): Question {
            val g = maxOf(1, minOf(TOP_GRADE, grade))
            if (d == Difficulty.HARD && g < TOP_GRADE && rng.nextDouble() < 0.2) {
                return generate(g + 1, Difficulty.MEDIUM)   // העשרה
            }
            return when (g) {
                1 -> grade1(d)
                2 -> grade2(d)
                3 -> grade3(d)
                4 -> grade4(d)
                5 -> grade5(d)
                6 -> grade6(d)
                7 -> grade7(d)
                else -> grade8(d)
            }
        }

        // MARK: כיתה א׳ — חיבור/חיסור עד 20, השלמה לעשר, השוואות

        fun grade1(d: Difficulty): Question = when (int(0..3)) {
            0 -> tagged(addSub(if (d == Difficulty.EASY) 10 else 20), "addSub")
            1 -> tagged(completeToTen(), "completeTen")
            2 -> tagged(biggestNumber(if (d == Difficulty.EASY) 10 else 20), "compare")
            else -> wordProblemAddSub(if (d == Difficulty.EASY) 10 else 20)
        }

        fun addSub(max: Int): Question {
            val a = int(1..max); val b = int(1..max)
            if (bool()) return numericMCQ("$a + $b = ?", a + b)
            val big = maxOf(a, b); val small = minOf(a, b)
            return numericMCQ("$big − $small = ?", big - small)
        }

        fun completeToTen(): Question {
            val a = int(1..9)
            return numericMCQ("$a + ? = 10", 10 - a)
        }

        fun biggestNumber(max: Int): Question {
            val nums = LinkedHashSet<Int>()
            while (nums.size < 4) nums.add(int(1..max))
            val sorted = nums.sorted()
            return mcq(tr("אֵיזֶה מִסְפָּר הֲכִי גָּדוֹל?"), sorted.last().toString(), sorted.shuffled(rng).map { it.toString() })
        }

        // MARK: כיתה ב׳ — עד 100, מבוא לכפל (2/5/10), זוגי/אי־זוגי

        fun grade2(d: Difficulty): Question = when (int(0..3)) {
            0 -> tagged(addSub(if (d == Difficulty.EASY) 50 else 100), "addSub")
            1 -> tagged(mulIntro(), "mul")
            2 -> tagged(evenOdd(if (d == Difficulty.EASY) 20 else 100), "evenOdd")
            else -> wordProblemAddSub(if (d == Difficulty.EASY) 50 else 100)
        }

        fun mulIntro(): Question {
            val table = pick(listOf(2, 5, 10)); val b = int(2..9)
            return numericMCQ("$table × $b = ?", table * b)
        }

        fun evenOdd(max: Int): Question {
            val wantEven = bool()
            val pool = LinkedHashSet<Int>()
            // One number of the wanted parity, three of the other.
            val answer = int(1..(max / 2)) * 2 - (if (wantEven) 0 else 1)
            pool.add(answer)
            while (pool.size < 4) {
                val n = int(1..(max / 2)) * 2 - (if (wantEven) 1 else 0)
                if (n != answer) pool.add(n)
            }
            return mcq(if (wantEven) tr("אֵיזֶה מִסְפָּר זוּגִי?") else tr("אֵיזֶה מִסְפָּר אִי־זוּגִי?"),
                answer.toString(), pool.map { it.toString() }.shuffled(rng))
        }

        // MARK: כיתה ג׳ — לוח הכפל, חילוק, דו־שלבי, מבוא לשברים, אומדן

        fun grade3(d: Difficulty): Question {
            val top = if (d == Difficulty.EASY) 6 else 10
            return when (int(0..4)) {
                0 -> { val a = int(2..top); val b = int(2..top); tagged(numericMCQ("$a × $b = ?", a * b), "mul") }
                1 -> { val a = int(2..top); val b = int(2..top); tagged(numericMCQ("${a * b} ÷ $a = ?", b), "div") }
                2 -> {
                    val a = int(2..9); val b = int(2..9); val c = int(3..20)
                    tagged(numericMCQ("$a × $b + $c = ?", a * b + c), "mixedOps")
                }
                3 -> tagged(fractionOfShape(), "fractions")
                else -> tagged(wordProblemMultiply(if (d == Difficulty.EASY) 5 else 9), "wordProblem")
            }
        }

        /** "חילקנו פיצה ל־N חלקים ואכלנו K" — distractors compared by VALUE (2/4 ≠ a second right answer). */
        fun fractionOfShape(): Question {
            val parts = pick(listOf(2, 3, 4))
            val eaten = if (parts == 2) 1 else int(1 until parts)
            val answer = "$eaten/$parts"
            val distractors = mutableListOf<String>()
            val seenValues = hashSetOf(eaten * 840 / parts)   // 840 = lcm(2…8)
            for (p in listOf(2, 3, 4, 5, 6, 8).shuffled(rng)) {
                for (e in (1 until p).shuffled(rng)) {
                    val value = e * 840 / p
                    if (seenValues.add(value)) distractors.add("$e/$p")
                }
            }
            return mcq(tr("🍕 חִלַּקְנוּ פִּיצָה לְ־%lld חֲלָקִים שָׁוִים וְאָכַלְנוּ %lld. אֵיזֶה שֶׁבֶר אָכַלְנוּ?", parts, eaten),
                answer, (listOf(answer) + distractors.shuffled(rng).take(3)).shuffled(rng))
        }

        // MARK: כיתה ד׳ — שברים, מספרים גדולים, כפל דו־ספרתי, שארית, היקף ושטח

        fun grade4(d: Difficulty): Question = when (int(0..5)) {
            0 -> tagged(fractionAddSameDen(), "fractions")
            1 -> tagged(fractionCompare(), "fractions")
            2 -> {
                val a = int(500..(if (d == Difficulty.EASY) 2000 else 8000)); val b = int(100..1900)
                tagged(numericMCQ("$a + $b = ?", a + b), "addSub")
            }
            3 -> {
                val a = int(12..(if (d == Difficulty.EASY) 20 else 40)); val b = int(3..9)
                tagged(numericMCQ("$a × $b = ?", a * b), "mul")
            }
            4 -> tagged(divisionWithRemainder(), "divRemainder")
            else -> tagged(rectanglePerimeterArea(), "geometry")
        }

        fun fractionAddSameDen(): Question {
            val den = pick(listOf(4, 5, 6, 8, 10))
            val a = int(1 until (den - 1))
            val b = int(1..(den - 1 - a))
            val answer = "${a + b}/$den"
            val distractors = listOf("${a + b}/${den * 2}", "${maxOf(1, a + b - 1)}/$den", "${minOf(den, a + b + 1)}/$den")
                .filter { it != answer }
            return mcq("$a/$den + $b/$den = ?", answer, (listOf(answer) + distractors.take(3)).shuffled(rng))
        }

        /** Same numerator, different denominators — the classic ד׳ trap. */
        fun fractionCompare(): Question {
            val dens = LinkedHashSet<Int>()
            while (dens.size < 2) dens.add(pick(listOf(2, 3, 4, 5, 6, 8)))
            val sorted = dens.sorted()
            val small = sorted[1]; val big = sorted[0]   // bigger denominator = smaller fraction
            val f1 = "1/$small"; val f2 = "1/$big"
            return mcq(tr("מָה גָּדוֹל יוֹתֵר: %@ אוֹ %@?", f1, f2), f2, listOf(f1, f2).shuffled(rng))
        }

        fun divisionWithRemainder(): Question {
            val b = int(3..9); val q = int(3..9); val r = int(1 until b)
            val a = b * q + r
            val answer = tr("%lld וּשְׁאֵרִית %lld", q, r)
            val distractors = listOf(
                tr("%lld וּשְׁאֵרִית %lld", q, if (r == 1) r + 1 else r - 1),
                tr("%lld וּשְׁאֵרִית %lld", q + 1, r),
                tr("%lld בְּדִיּוּק", q),
            )
            return mcq("$a ÷ $b = ?", answer, (listOf(answer) + distractors).shuffled(rng))
        }

        fun rectanglePerimeterArea(): Question {
            val w = int(2..9); val h = int(2..9)
            if (bool()) {
                return numericMCQ(tr("מַלְבֵּן בְּאֹרֶךְ %lld ס\"מ וּבְרֹחַב %lld ס\"מ — מָה הַהֶקֵּף שֶׁלּוֹ?", w, h),
                    2 * (w + h), suffix = tr(" ס\"מ"))
            }
            return numericMCQ(tr("מַלְבֵּן בְּאֹרֶךְ %lld ס\"מ וּבְרֹחַב %lld ס\"מ — מָה הַשֶּׁטַח שֶׁלּוֹ?", w, h),
                w * h, suffix = tr(" סמ\"ר"))
        }

        // MARK: כיתה ה׳ — עשרוניים, שברים במכנים שונים, ממוצע, מבוא לאחוזים

        fun grade5(d: Difficulty): Question = when (int(0..3)) {
            0 -> tagged(decimalAddSub(d == Difficulty.EASY), "decimals")
            1 -> tagged(fractionToDecimal(), "fractions")
            2 -> tagged(average(), "average")
            else -> tagged(percentIntro(), "percent")
        }

        fun decimalAddSub(easy: Boolean): Question {
            val a = int(10..(if (easy) 60 else 90)).toDouble() / 10
            val b = int(5..40).toDouble() / 10
            val add = bool()
            val answer = if (add) a + b else maxOf(a, b) - minOf(a, b)
            val prompt = if (add) "${fmt(a)} + ${fmt(b)} = ?" else "${fmt(maxOf(a, b))} − ${fmt(minOf(a, b))} = ?"
            val opts = linkedSetOf(fmt(answer))
            while (opts.size < 4) {
                val delta = int(1..15).toDouble() / 10 * (if (bool()) 1 else -1)
                val c = answer + delta
                if (c > 0) opts.add(fmt(c))
            }
            return mcq(prompt, fmt(answer), opts.shuffled(rng))
        }

        fun fractionToDecimal(): Question {
            val pairs = listOf("1/2" to "0.5", "1/4" to "0.25", "3/4" to "0.75", "1/5" to "0.2", "1/10" to "0.1", "2/5" to "0.4")
            val (frac, dec) = pick(pairs)
            val distractors = pairs.map { it.second }.filter { it != dec }.shuffled(rng).take(3)
            return mcq(tr("אֵיךְ כּוֹתְבִים אֶת %@ כְּמִסְפָּר עֶשְׂרוֹנִי?", frac), dec, (listOf(dec) + distractors).shuffled(rng))
        }

        fun average(): Question {
            val m = int(3..12); val spread = int(1..4)
            val nums = listOf(m - spread, m, m + spread).shuffled(rng)
            return numericMCQ(tr("מָה הַמְמֻצָּע שֶׁל %lld, %lld וְ־%lld?", nums[0], nums[1], nums[2]), m)
        }

        fun percentIntro(): Question {
            val base = pick(listOf(40, 60, 80, 100, 200)); val pct = pick(listOf(10, 25, 50))
            return numericMCQ(tr("כַּמָּה הֵם %lld%% מִ־%lld?", pct, base), base * pct / 100)
        }

        // MARK: כיתה ו׳ — אחוזים, יחס, סדר פעולות, בעיות רב־שלביות

        fun grade6(d: Difficulty): Question = when (int(0..3)) {
            0 -> {
                // Only pairs whose result is WHOLE (150×25% used to show "37").
                val base = pick(listOf(60, 120, 150, 200, 300))
                val pct = pick(listOf(10, 20, 25, 30, 50, 75).filter { base * it % 100 == 0 })
                numericMCQ(tr("כַּמָּה הֵם %lld%% מִ־%lld?", pct, base), base * pct / 100)
            }
            1 -> orderOfOperations(d == Difficulty.HARD)
            2 -> ratio()
            else -> wordProblemTwoStep()
        }

        fun orderOfOperations(hard: Boolean): Question {
            val a = int(2..9); val b = int(2..9); val c = int(2..9)
            if (hard) return numericMCQ("($a + $b) × $c = ?", (a + b) * c, plant = a + b * c)
            return numericMCQ("$a + $b × $c = ?", a + b * c, plant = (a + b) * c)
        }

        fun ratio(): Question {
            while (true) {
                val unit = int(2..6); val x = int(2..5); val y = int(2..5)
                // x:y must already be fully reduced.
                if (x == y || gcd(x, y) != 1) continue
                val answer = "$x:$y"
                val distractors = listOf("$y:$x", "${x * unit}:$y", "${x + 1}:$y").filter { it != answer }
                return mcq(tr("בַּכִּתָּה %lld בָּנִים וְ־%lld בָּנוֹת. מָה הַיַּחַס בֵּין בָּנִים לְבָנוֹת בְּצוּרָה מְצֻמְצֶמֶת?", x * unit, y * unit),
                    answer, (listOf(answer) + distractors.take(3)).shuffled(rng))
            }
        }

        // MARK: כיתה ז׳ — מספרים מכוונים, ביטויים ומשוואות, חזקות, אחוזים, זוויות, פרופורציה

        fun grade7(d: Difficulty): Question = when (int(0..7)) {
            0 -> tagged(signedArithmetic(d == Difficulty.HARD), "negatives")
            1 -> tagged(substitute(), "expressions")
            2 -> tagged(oneVariableEquation(d != Difficulty.EASY), "equations")
            3 -> tagged(power(), "powers")
            4 -> tagged(percentChange(), "percent")
            5 -> tagged(angles(), "angles")
            6 -> tagged(proportion(), "proportion")
            else -> tagged(triangleArea(), "geometry")
        }

        fun sign() = if (bool()) -1 else 1

        /** The sign is the whole skill, so the planted wrong answers are the sign slips. */
        fun signedArithmetic(hard: Boolean): Question {
            val a = int(2..12) * sign()
            val b = int(2..12) * sign()
            return when (int(0..(if (hard) 2 else 1))) {
                0 -> signedMCQ(ltr("${paren(a)} + ${paren(b)} = ?"), a + b, plants = listOf(-(a + b), abs(a) + abs(b), a - b))
                1 -> signedMCQ(ltr("${paren(a)} − ${paren(b)} = ?"), a - b, plants = listOf(-(a - b), a + b, abs(a) - abs(b)))
                else -> {
                    val x = int(2..9) * sign(); val y = int(2..9) * sign()
                    signedMCQ(ltr("${paren(x)} × ${paren(y)} = ?"), x * y, plants = listOf(-(x * y), x + y))
                }
            }
        }

        /** "3x − 5 כש־x = 4" — plants: forgetting the multiplication, and reading 3x as "34". */
        fun substitute(): Question {
            val k = int(2..9); val x = int(2..9); val c = int(1..12)
            val plus = bool()
            val expr = if (plus) "${k}x + $c" else "${k}x − $c"
            val answer = if (plus) k * x + c else k * x - c
            return signedMCQ(tr("%@\nמָה עֵרֶךְ הַבִּטּוּי כְּשֶׁ־%@?", ltr(expr), ltr("x = $x")), answer,
                plants = listOf(if (plus) k + x + c else k + x - c, if (plus) k * 10 + x + c else k * 10 + x - c))
        }

        /** kx + c = r with a whole answer. Plant: stopping after subtracting c. */
        fun oneVariableEquation(twoStep: Boolean): Question {
            val x = int(-6..12); val k = if (twoStep) int(2..9) else 1
            val c = int(1..15) * sign()
            val r = k * x + c
            val left = "${coef(k)}x"
            val eq = if (c >= 0) "$left + $c = ${signed(r)}" else "$left − ${-c} = ${signed(r)}"
            return signedMCQ(tr("%@\nמָה הָעֵרֶךְ שֶׁל x?", ltr(eq)), x,
                plants = listOf(if (r - c == x) r + c else r - c, r + c, if (k > 1) r / k else r))
        }

        /** 2⁵, 7², 3⁴ — plant: base × exponent. */
        fun power(): Question {
            val pairs = listOf(2 to 3, 2 to 4, 2 to 5, 2 to 6, 3 to 2, 3 to 3, 3 to 4, 4 to 2, 4 to 3, 5 to 2, 5 to 3,
                6 to 2, 7 to 2, 8 to 2, 9 to 2, 10 to 3, 11 to 2, 12 to 2, 13 to 2, 15 to 2)
            val (b, e) = pick(pairs)
            return signedMCQ(ltr("$b${superscript(e)} = ?"), b.toDouble().pow(e).toInt(),
                plants = listOf(b * e, b + e), allowNegative = false)
        }

        /** A price goes up or down by a whole percentage. Plants: the change alone, and the opposite direction. */
        fun percentChange(): Question {
            val base = pick(listOf(40, 60, 80, 120, 150, 200, 240, 300, 400))
            val pct = pick(listOf(10, 20, 25, 30, 40, 50).filter { base * it % 100 == 0 })
            val change = base * pct / 100; val up = bool()
            val answer = if (up) base + change else base - change
            return signedMCQ(tr("🏷️ מְחִיר שֶׁל %lld ₪ %@ בְּ־%lld%%. מָה הַמְּחִיר הֶחָדָשׁ?", base, if (up) tr("עָלָה") else tr("יָרַד"), pct),
                answer, prefix = moneyPrefix, suffix = moneySuffix,
                plants = listOf(change, if (up) base - change else base + change), allowNegative = false)
        }

        /** The third angle of a triangle, or the angle next to one on a straight line. */
        fun angles(): Question {
            while (true) {
                if (bool()) {
                    val a = int(3..12) * 5; val b = int(3..(30 - a / 5)) * 5
                    val answer = 180 - a - b
                    if (answer <= 0) continue
                    return signedMCQ(tr("📐 בִּמְשֻׁלָּשׁ יֵשׁ זָוִית שֶׁל %lld° וְזָוִית שֶׁל %lld°. מָה גֹּדֶל הַזָּוִית הַשְּׁלִישִׁית?", a, b),
                        answer, suffix = "°",
                        plants = listOf(a + b, 360 - a - b, if (90 - minOf(a, b) > 0) 90 - minOf(a, b) else a), allowNegative = false)
                }
                val a = int(4..32) * 5
                return signedMCQ(tr("📐 שְׁתֵּי זָוִיּוֹת צְמוּדוֹת. אַחַת הִיא %lld°. מָה גֹּדֶל הַשְּׁנִיָּה?", a),
                    180 - a, suffix = "°", plants = listOf(if (90 - a > 0) 90 - a else 360 - a, a), allowNegative = false)
            }
        }

        /** n items cost p — how much do m cost? Plant: scaling by the difference. */
        fun proportion(): Question {
            val unit = int(3..15); val n = int(2..6)
            var m = int(3..12)
            if (m == n) m += 1
            return signedMCQ(tr("📒 %lld מַחְבָּרוֹת עוֹלוֹת %lld ₪. כַּמָּה יַעֲלוּ %lld מַחְבָּרוֹת?", n, unit * n, m),
                unit * m, prefix = moneyPrefix, suffix = moneySuffix,
                plants = listOf(unit * n + (m - n), unit * n * m), allowNegative = false)
        }

        fun triangleArea(): Question {
            while (true) {
                val base = int(3..14); val height = int(2..12)
                if (base * height % 2 != 0) continue
                return signedMCQ(tr("🔺 מְשֻׁלָּשׁ שֶׁבָּסִיסוֹ %lld ס\"מ וְהַגֹּבַהּ אֵלָיו %lld ס\"מ. מָה הַשֶּׁטַח שֶׁלּוֹ?", base, height),
                    base * height / 2, suffix = tr(" סמ\"ר"), plants = listOf(base * height, base + height), allowNegative = false)
            }
        }

        // MARK: כיתה ח׳ — משוואות, פיתגורס, שורשים, פונקציה קווית, נפח, הסתברות, מעגל

        fun grade8(d: Difficulty): Question = when (int(0..7)) {
            0 -> tagged(equationBothSides(d == Difficulty.HARD || bool()), "equations")
            1 -> tagged(pythagoras(), "pythagoras")
            2 -> tagged(squareRoot(), "roots")
            3 -> tagged(linearFunction(), "linearFunction")
            4 -> tagged(boxVolume(), "volume")
            5 -> tagged(powerLaws(), "powers")
            6 -> tagged(probability(), "probability")
            else -> if (d == Difficulty.EASY) tagged(signedArithmetic(true), "negatives") else tagged(circle(), "circle")
        }

        /** a(x + b) = r   or   ax + b = cx + e — always a whole x. */
        fun equationBothSides(brackets: Boolean): Question {
            val x = int(-5..10)
            if (brackets) {
                val a = int(2..6); val b = int(-6..9)
                val r = a * (x + b)
                val inner = if (b == 0) "x" else if (b > 0) "x + $b" else "x − ${-b}"
                return signedMCQ(tr("%@\nמָה הָעֵרֶךְ שֶׁל x?", ltr("$a($inner) = ${signed(r)}")), x,
                    // Plants: opening only the first term, and dividing then adding.
                    plants = listOf((r - b) / a, r / a + b))
            }
            val a = int(3..9); val c = int(1..(a - 1)); val b = int(-12..12)
            val e = (a - c) * x + b
            fun side(k: Int, n: Int) = if (n == 0) "${coef(k)}x" else if (n > 0) "${coef(k)}x + $n" else "${coef(k)}x − ${-n}"
            return signedMCQ(tr("%@\nמָה הָעֵרֶךְ שֶׁל x?", ltr("${side(a, b)} = ${side(c, e)}")), x,
                // Plants: adding the x terms instead of subtracting, and a sign slip.
                plants = listOf((e - b) / (a + c), (e + b) / (a - c)))
        }

        /** A right triangle from a Pythagorean triple — the hypotenuse or a leg. */
        fun pythagoras(): Question {
            val triples = listOf(Triple(3, 4, 5), Triple(6, 8, 10), Triple(5, 12, 13), Triple(8, 15, 17), Triple(9, 12, 15),
                Triple(7, 24, 25), Triple(12, 16, 20), Triple(9, 40, 41), Triple(15, 20, 25))
            val (a, b, c) = pick(triples)
            if (bool()) {
                return signedMCQ(tr("📐 בִּמְשֻׁלָּשׁ יְשַׁר זָוִית אָרְכֵי הַנִּצָּבִים %lld ס\"מ וְ־%lld ס\"מ. מָה אֹרֶךְ הַיֶּתֶר?", a, b),
                    c, suffix = tr(" ס\"מ"), plants = listOf(a + b, a * a + b * b), allowNegative = false)
            }
            return signedMCQ(tr("📐 בִּמְשֻׁלָּשׁ יְשַׁר זָוִית הַיֶּתֶר %lld ס\"מ וְאַחַד הַנִּצָּבִים %lld ס\"מ. מָה אֹרֶךְ הַנִּצָּב הַשֵּׁנִי?", c, a),
                b, suffix = tr(" ס\"מ"), plants = listOf(c - a, c + a), allowNegative = false)
        }

        fun squareRoot(): Question {
            val r = int(4..20)
            return signedMCQ(ltr("√${r * r} = ?"), r, plants = listOf(r * r / 2, r * 2), allowNegative = false)
        }

        /** y = mx + b: its value at x, or its slope. */
        fun linearFunction(): Question {
            val m = int(1..6) * sign(); val b = int(-9..9)
            val rule = if (b == 0) "y = ${coef(m)}x" else if (b > 0) "y = ${coef(m)}x + $b" else "y = ${coef(m)}x − ${-b}"
            if (bool()) {
                val x = int(-4..6)
                return signedMCQ(tr("📈 %@\nמָה הָעֵרֶךְ שֶׁל y כְּשֶׁ־%@?", ltr(rule), ltr("x = $x")), m * x + b,
                    plants = listOf(m * x - b, m + x + b))
            }
            return signedMCQ(tr("📈 %@\nמָה הַשִּׁפּוּעַ שֶׁל הַיָּשָׁר?", ltr(rule)), m,
                plants = listOf(if (b == m) -m else b, -m))
        }

        fun boxVolume(): Question {
            val l = int(2..12); val w = int(2..9); val h = int(2..8)
            return signedMCQ(tr("📦 תֵּבָה בְּאֹרֶךְ %lld ס\"מ, רֹחַב %lld ס\"מ וְגֹבַהּ %lld ס\"מ. מָה הַנֶּפַח שֶׁלָּהּ?", l, w, h),
                l * w * h, suffix = tr(" סמ\"ק"), plants = listOf(l + w + h, 2 * (l * w + l * h + w * h)), allowNegative = false)
        }

        /** aᵐ · aⁿ = a^? — plant: multiplying the exponents. */
        fun powerLaws(): Question {
            val a = pick(listOf(2, 3, 5, 7, 10)); val m = int(2..6); val n = int(2..6)
            if (bool()) {
                return signedMCQ(tr("%@\nמָה הָעֵרֶךְ שֶׁל n?", ltr("$a${superscript(m)} · $a${superscript(n)} = ${a}ⁿ")),
                    m + n, plants = listOf(m * n, abs(m - n)), allowNegative = false)
            }
            val big = m + n
            return signedMCQ(tr("%@\nמָה הָעֵרֶךְ שֶׁל n?", ltr("$a${superscript(big)} : $a${superscript(m)} = ${a}ⁿ")),
                n, plants = listOf(big + m, maxOf(1, big / m)), allowNegative = false)
        }

        /** Red and blue marbles: the chance of red, as a reduced fraction. */
        fun probability(): Question {
            while (true) {
                val red = int(1..7); val blue = int(1..9)
                fun frac(n: Int, d: Int): String { val g = gcd(n, d); return ltr("${n / g}/${d / g}") }
                val answer = frac(red, red + blue)
                // Plants: red out of blue (not out of all), and the chance of blue.
                val options = mutableListOf(answer)
                for (cand in listOf(frac(red, blue), frac(blue, red + blue), frac(red + 1, red + blue + 1), frac(1, red + blue), frac(red, red + blue + 2))) {
                    if (options.size < 4 && !options.contains(cand)) options.add(cand)
                }
                if (options.size != 4) continue
                val r = if (red == 1) tr("כַּדּוּר אָדֹם אֶחָד") else tr("%lld כַּדּוּרִים אֲדֻמִּים", red)
                val b = if (blue == 1) tr("כַּדּוּר כָּחֹל אֶחָד") else tr("%lld כַּדּוּרִים כְּחֻלִּים", blue)
                return mcq(rtlLines(tr("🎲 בְּשַׂקִּית %@ וְ־%@. שׁוֹלְפִים כַּדּוּר אֶחָד בְּלִי לְהִסְתַּכֵּל. מָה הַסִּכּוּי שֶׁהוּא אָדֹם?", r, b)),
                    answer, options.shuffled(rng))
            }
        }

        /** Circumference or area with π = 3.14. Plants: the other formula, and πr. */
        fun circle(): Question {
            val r = pick(listOf(1, 2, 3, 4, 5, 10))
            val circumference = fmt(2 * 3.14 * r.toDouble()); val area = fmt(3.14 * (r * r).toDouble()); val half = fmt(3.14 * r.toDouble())
            val askArea = bool()
            val answer = if (askArea) area else circumference
            val options = mutableListOf(answer)
            for (cand in listOf(if (askArea) circumference else area, half, fmt(3.14 * (2 * r * 2 * r).toDouble()), fmt((2 * r).toDouble() * 2))) {
                if (options.size < 4 && !options.contains(cand)) options.add(cand)
            }
            val unit = if (askArea) tr(" סמ\"ר") else tr(" ס\"מ")
            return mcq(rtlLines(tr("⭕ מַעְגָּל שֶׁהָרַדְיוּס שֶׁלּוֹ %lld ס\"מ. מָה %@ שֶׁלּוֹ? (%@)", r,
                if (askArea) tr("הַשֶּׁטַח") else tr("הַהֶקֵּף"), ltr("π = 3.14"))),
                answer + unit, options.map { it + unit }.shuffled(rng))
        }

        // MARK: בעיות מילוליות — names are content: each carries the gender its verbs agree with.

        /** `of` is the form after "לְ…"/"У …" (Russian declines names; Hebrew drops the dagesh). */
        class Kid(val name: String, of: String? = null, val girl: Boolean) { val of: String = of ?: name }

        val kids: List<Kid>
            get() = when (lang) {
                AppLanguage.HE -> listOf("דָּנָה" to true, "יוֹסִי" to false, "נֹעָה" to true, "אִיתַי" to false, "תָּמָר" to true, "עוֹמֶר" to false)
                    .map { (n, g) -> Kid(tr(n), afterShvaPrefix(tr(n)), g) }
                AppLanguage.RU -> listOf(Kid("Даша", "Даши", true), Kid("Миша", "Миши", false), Kid("Аня", "Ани", true),
                    Kid("Лёва", "Лёвы", false), Kid("Соня", "Сони", true), Kid("Марк", "Марка", false))
                AppLanguage.AR -> listOf(Kid("ليان", girl = true), Kid("آدم", girl = false), Kid("سارة", girl = true),
                    Kid("كرم", girl = false), Kid("مريم", girl = true), Kid("جاد", girl = false))
                AppLanguage.EN -> listOf(Kid("Emma", girl = true), Kid("Liam", girl = false), Kid("Olivia", girl = true),
                    Kid("Noah", girl = false), Kid("Ava", girl = true), Kid("Mason", girl = false))
            }

        /** Russian needs three plural forms (1 шарик · 2 шарика · 5 шариков); he/en/ar one. */
        class Countable(val emoji: String, val one: String, val few: String, val many: String) {
            fun counted(n: Int): String {
                val hundreds = n % 100; val units = n % 10
                if (hundreds in 11..14) return many
                return when (units) { 1 -> one; in 2..4 -> few; else -> many }
            }
            val afterCount: String get() = many
        }

        fun plural(emoji: String, p: String) = Countable(emoji, p, p, p)

        val things: List<Countable>
            get() = when (lang) {
                AppLanguage.AR -> listOf(plural("🎈", "بالونات"), plural("📚", "كتب"), plural("🍎", "تفّاحات"),
                    plural("⚽", "كرات"), plural("🖍️", "أقلام تلوين"), plural("🐚", "أصداف"))
                AppLanguage.RU -> listOf(Countable("🎈", "шарик", "шарика", "шариков"), Countable("📚", "книга", "книги", "книг"),
                    Countable("🍎", "яблоко", "яблока", "яблок"), Countable("⚽", "мяч", "мяча", "мячей"),
                    Countable("🖍️", "карандаш", "карандаша", "карандашей"), Countable("🐚", "ракушка", "ракушки", "ракушек"))
                else -> listOf(plural("🎈", tr("בַּלּוֹנִים")), plural("📚", tr("סְפָרִים")), plural("🍎", tr("תַּפּוּחִים")),
                    plural("⚽", tr("כַּדּוּרִים")), plural("🖍️", tr("צְבָעִים")), plural("🐚", tr("צְדָפִים")))
            }

        fun wordProblemAddSub(max: Int): Question {
            val kid = pick(kids); val name = kid.name; val owner = kid.of
            val thing = pick(things); val emoji = thing.emoji
            val a = int(3..max)
            val item = thing.counted(a)
            if (bool()) {
                val b = int(2..max)
                return numericMCQ(
                    if (kid.girl) tr("%@ לְ%@ יֵשׁ %lld %@. %@ קִבְּלָה עוֹד %lld. כַּמָּה יֵשׁ עַכְשָׁיו?", emoji, owner, a, item, name, b)
                    else tr("%@ לְ%@ יֵשׁ %lld %@. %@ קִבֵּל עוֹד %lld. כַּמָּה יֵשׁ עַכְשָׁיו?", emoji, owner, a, item, name, b),
                    a + b)
            }
            val b = int(1 until a)
            return numericMCQ(
                if (kid.girl) tr("%@ לְ%@ הָיוּ %lld %@, וְ%@ נָתְנָה %lld לְחָבֵר. כַּמָּה נִשְׁאֲרוּ?", emoji, owner, a, item, name, b)
                else tr("%@ לְ%@ הָיוּ %lld %@, וְ%@ נָתַן %lld לְחָבֵר. כַּמָּה נִשְׁאֲרוּ?", emoji, owner, a, item, name, b),
                a - b)
        }

        fun wordProblemMultiply(maxFactor: Int): Question {
            val owner = pick(kids).of
            val thing = pick(things); val emoji = thing.emoji; val item = thing.afterCount
            val packs = int(2..maxFactor); val per = int(2..maxFactor)
            return numericMCQ(tr("%@ לְ%@ יֵשׁ %lld חֲבִילוֹת שֶׁל %@, וּבְכָל חֲבִילָה %lld. כַּמָּה יֵשׁ בְּסַךְ הַכֹּל?", emoji, owner, packs, item, per),
                packs * per)
        }

        fun wordProblemTwoStep(): Question {
            val kid = pick(kids); val name = kid.name
            val price = int(6..15); val count = int(2..4)
            val paid = ((price * count / 10) + 1) * 10 + pick(listOf(0, 10))
            return numericMCQ(
                if (kid.girl) tr("💰 %@ קָנְתָה %lld מַחְבָּרוֹת בְּ־%lld שְׁקָלִים כָּל אַחַת, וְשִׁלְּמָה בְּ־%lld שְׁקָלִים. כַּמָּה עֹדֶף מַגִּיעַ?", name, count, price, paid)
                else tr("💰 %@ קָנָה %lld מַחְבָּרוֹת בְּ־%lld שְׁקָלִים כָּל אַחַת, וְשִׁלֵּם בְּ־%lld שְׁקָלִים. כַּמָּה עֹדֶף מַגִּיעַ?", name, count, price, paid),
                paid - price * count)
        }

        // MARK: Builders

        /** Money.answerPrefix/Suffix: Israeli languages append " ₪", English puts "$" first. */
        val israeli get() = lang != AppLanguage.EN
        val moneyPrefix get() = if (israeli) "" else "$"
        val moneySuffix get() = if (israeli) " ₪" else ""

        /** Numeric MCQ with plausible near-miss distractors; `plant` forces one specific trap in. */
        fun numericMCQ(prompt: String, answer: Int, suffix: String = "", plant: Int? = null): Question {
            val options = linkedSetOf(answer)
            if (plant != null && plant != answer && plant >= 0) options.add(plant)
            while (options.size < 4) {
                val delta = int(1..maxOf(3, abs(answer) / 2 + 2))
                val candidate = if (bool()) answer + delta else answer - delta
                if (candidate >= 0) options.add(candidate)
            }
            val shuffled = options.shuffled(rng)
            return Question(Topic.MATH, prompt, shuffled.map { "$it$suffix" }, shuffled.indexOf(answer).coerceAtLeast(0))
        }

        /** Start every line right-to-left (only RTL languages need it). */
        fun rtlLines(s: String): String {
            if (!lang.rtl) return s
            return s.split("\n").joinToString("\n") { "\u200F$it" }
        }

        /** Middle-school MCQ: answers may be negative; `plants` (the real mistakes) go in first. */
        fun signedMCQ(prompt: String, answer: Int, prefix: String = "", suffix: String = "",
                      plants: List<Int> = emptyList(), allowNegative: Boolean = true): Question {
            val options = mutableListOf(answer)
            fun add(v: Int) { if (options.size < 4 && !options.contains(v) && (allowNegative || v >= 0)) options.add(v) }
            for (p in plants.shuffled(rng)) add(p)
            val spread = maxOf(3, abs(answer) / 4 + 2)
            var tries = 0
            while (options.size < 4 && tries < 200) {
                tries++
                val delta = int(1..spread)
                add(if (bool()) answer + delta else answer - delta)
            }
            var k = 1
            while (options.size < 4) { add(answer + k); k++ }
            val shuffled = options.shuffled(rng)
            return Question(Topic.MATH, rtlLines(prompt), shuffled.map { ltr(prefix + signed(it)) + suffix },
                shuffled.indexOf(answer).coerceAtLeast(0))
        }

        fun mcq(prompt: String, answer: String, options: List<String>): Question {
            var opts = options
            if (!opts.contains(answer)) opts = (listOf(answer) + opts.drop(1)).shuffled(rng)
            return Question(Topic.MATH, prompt, opts, opts.indexOf(answer).coerceAtLeast(0))
        }
    }

    // MARK: - Pure helpers (shared with the bonus math)

    /** Two decimals at most; whole values print without ".0" (Swift String(Double) style). */
    fun fmt(d: Double): String {
        val r = swiftRound(d * 100) / 100
        return if (r == swiftRound(r)) r.toLong().toString() else r.toString()
    }

    /** Keeps a math run left-to-right and in one piece inside a Hebrew line. */
    fun ltr(s: String): String = "\u2066" + s.replace(" ", "\u00A0") + "\u2069"

    /** −3 with a real minus sign. */
    fun signed(n: Int): String = if (n < 0) "−${-n}" else "$n"
    /** Parentheses around negatives inside an expression: "(−7) + 4". */
    fun paren(n: Int): String = if (n < 0) "(−${-n})" else "$n"
    /** A coefficient in front of x: "x", "−x", "3x", "−3x" — never "1x". */
    fun coef(k: Int): String = if (k == 1) "" else if (k == -1) "−" else signed(k)

    fun superscript(n: Int): String {
        val map = mapOf('0' to '⁰', '1' to '¹', '2' to '²', '3' to '³', '4' to '⁴', '5' to '⁵', '6' to '⁶', '7' to '⁷', '8' to '⁸', '9' to '⁹')
        return n.toString().map { map[it] ?: it }.joinToString("")
    }

    fun gcd(a: Int, b: Int): Int = if (b == 0) a else gcd(b, a % b)

    /**
     * Localization.afterShvaPrefix: after the לְ of "לְדָנָה" a בג״ד כפ״ת letter
     * drops its dagesh — walk the first letter's marks and remove U+05BC.
     */
    fun afterShvaPrefix(word: String): String {
        if (word.isEmpty() || word[0] !in "בגדכפת") return word
        val sb = StringBuilder(word)
        var i = 1
        while (i < sb.length && sb[i].code in 0x0591..0x05C7) {
            if (sb[i].code == 0x05BC) { sb.deleteCharAt(i); break }
            i++
        }
        return sb.toString()
    }
}
