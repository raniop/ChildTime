package com.rani.tofy.kid.ui.games

import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.child.Topic
import java.util.Locale
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.roundToInt

// 🎮 MiniGameContentMore.swift — content for the second six mini-games:
//   🧺 SortSets · 🧠 PatternGen · 🔢 Board2048 · 🔐 VaultGen · 🛒 GroceryGen · ⚖️ BalanceGen.

private val ids = AtomicLong(1)
internal fun nextId(): Long = ids.getAndIncrement()

// MARK: - 🧺 Sort into baskets

data class SortBasket(val emoji: String, val label: String)

data class SortItem(
    val emoji: String,
    val label: String,
    /** The candidate answer under a true/false statement. */
    val detail: String? = null,
    val basket: Int,
    /** English words and numbers read left-to-right. */
    val ltr: Boolean = false,
    val id: Long = nextId(),
)

data class SortSet(val baskets: List<SortBasket>, val items: List<SortItem>, val topic: Topic)

object SortSets {
    const val ROUND_ITEMS = 10

    private fun i(emoji: String, label: String, basket: Int, ltr: Boolean = false) = SortItem(emoji, label, basket = basket, ltr = ltr)

    /** A world's own baskets, sized to the grade. null → the world sorts true / false. */
    fun make(topic: Topic, grade: Int): SortSet? {
        val g = max(1, grade)
        return when (topic) {
            Topic.MATH -> numbers(g)
            Topic.ENGLISH -> english(g)
            Topic.HEBREW -> hebrew(g)
            Topic.SEA, Topic.ANIMALS -> animals(g, topic)
            Topic.SPACE -> planets(g)
            Topic.DINOSAURS -> dinosaurs(g)
            Topic.SOCCER -> soccer(g)
            Topic.FLAGS, Topic.GEOGRAPHY -> places(g, topic)
            Topic.SCIENCE -> science(g)
            Topic.BODY -> body(g)
            Topic.VEHICLES -> vehicles(g)
            Topic.MUSIC -> music(g)
            Topic.FOOD -> food(g)
            Topic.MONEY -> money(g)
            else -> null
        }
    }

    /** Mix the round: up to ROUND_ITEMS, every basket represented. */
    fun round(set: SortSet, count: Int = ROUND_ITEMS): List<SortItem> {
        val byBasket = set.items.shuffled().groupBy { it.basket }.mapValues { it.value.toMutableList() }
        val out = mutableListOf<SortItem>()
        while (out.size < count) {
            var added = false
            for (b in set.baskets.indices) {
                val list = byBasket[b]
                if (list != null && list.isNotEmpty() && out.size < count) { out += list.removeAt(list.size - 1); added = true }
            }
            if (!added) break
        }
        return out.shuffled()
    }

    /** ✓ / ✗ — a world's own short questions, each with its real answer or a distractor. */
    fun trueFalse(topic: Topic, grade: Int): SortSet? {
        val items = GameContent.items(topic, grade, maxPrompt = 45, maxAnswer = 18, standalone = true)
        if (items.size < 6) return null
        val cards = items.take(ROUND_ITEMS).map { q ->
            val right = kotlin.random.Random.nextBoolean() || q.distractors.isEmpty()
            val wrong = MiniGameDistractors.pick(q.answer, q.distractors, grade)
            SortItem("", q.prompt, detail = if (right) q.answer else (wrong ?: q.answer), basket = if (right) 0 else 1)
        }
        return SortSet(listOf(SortBasket("✓", tr("נָכוֹן")), SortBasket("✗", tr("לֹא נָכוֹן"))), cards, topic)
    }

    private fun numbers(grade: Int): SortSet {
        if (grade >= 4) {
            val pool = (10..99).filter { it % 15 != 0 }.shuffled()
            val by3 = pool.filter { it % 3 == 0 }.take(5).map { i("", "$it", 0, true) }
            val by5 = pool.filter { it % 5 == 0 }.take(5).map { i("", "$it", 1, true) }
            val none = pool.filter { it % 3 != 0 && it % 5 != 0 }.take(5).map { i("", "$it", 2, true) }
            return SortSet(listOf(SortBasket("3️⃣", tr("מִתְחַלֵּק בְּ־3")), SortBasket("5️⃣", tr("מִתְחַלֵּק בְּ־5")), SortBasket("🚫", tr("לֹא בְּ־3 וְלֹא בְּ־5"))), by3 + by5 + none, Topic.MATH)
        }
        val top = if (grade <= 1) 20 else if (grade == 2) 100 else 200
        val pool = (1..top).shuffled()
        val even = pool.filter { it % 2 == 0 }.take(7).map { i("", "$it", 0, true) }
        val odd = pool.filter { it % 2 == 1 }.take(7).map { i("", "$it", 1, true) }
        return SortSet(listOf(SortBasket("👯", tr("זוּגִי")), SortBasket("🧍", tr("אִי־זוּגִי"))), even + odd, Topic.MATH)
    }

    private fun english(grade: Int): SortSet {
        fun w(s: String, b: Int) = i("", s, b, true)
        if (grade <= 3) {
            val animals = listOf("dog", "cat", "horse", "lion", "fish", "bird", "cow", "duck", "frog", "bear", "monkey", "sheep")
            val food = listOf("apple", "bread", "milk", "cake", "egg", "pizza", "rice", "cheese", "banana", "soup", "carrot")
            return SortSet(listOf(SortBasket("🐾", tr("חַיָּה")), SortBasket("🍽️", tr("אֹכֶל"))), animals.map { w(it, 0) } + food.map { w(it, 1) }, Topic.ENGLISH)
        }
        val nouns = listOf("table", "book", "house", "tree", "school", "friend", "chair", "window", "garden", "river")
        val verbs = listOf("eat", "write", "sing", "go", "come", "think", "bring", "speak", "take", "give")
        val adjectives = listOf("happy", "big", "small", "beautiful", "tall", "quiet", "soft", "hungry", "brave", "angry")
        val baskets = mutableListOf(SortBasket("📦", tr("שֵׁם עֶצֶם")), SortBasket("🏃", tr("פֹּעַל")))
        val items = (nouns.map { w(it, 0) } + verbs.map { w(it, 1) }).toMutableList()
        if (grade >= 5) {
            baskets += SortBasket("🎨", tr("שֵׁם תֹּאַר"))
            items += adjectives.map { w(it, 2) }
        }
        return SortSet(baskets, items, Topic.ENGLISH)
    }

    /** Hebrew words are the content itself — the same in every app language. */
    private fun hebrew(grade: Int): SortSet {
        fun w(s: String, b: Int) = i("", s, b)
        return when {
            grade <= 2 -> {
                val male = listOf("שֻׁלְחָן", "כִּסֵּא", "סֵפֶר", "כֶּלֶב", "עֵץ", "בַּיִת", "כַּדּוּר", "עִפָּרוֹן", "חַלּוֹן", "שָׁעוֹן")
                val female = listOf("מְנוֹרָה", "מִטָּה", "חֻלְצָה", "בֻּבָּה", "מַחְבֶּרֶת", "שִׂמְלָה", "דֶּלֶת", "כַּפִּית", "מְכוֹנִית", "עוּגָה")
                SortSet(listOf(SortBasket("👦", tr("זָכָר")), SortBasket("👧", tr("נְקֵבָה"))), male.map { w(it, 0) } + female.map { w(it, 1) }, Topic.HEBREW)
            }
            grade == 3 -> {
                val one = listOf("יֶלֶד", "פֶּרַח", "כּוֹבַע", "יַלְדָּה", "תַּפּוּחַ", "גַּן", "צִפּוֹר", "מַחְבֶּרֶת", "חָבֵר", "עָנָן")
                val many = listOf("יְלָדִים", "פְּרָחִים", "כּוֹבָעִים", "יְלָדוֹת", "תַּפּוּחִים", "גַּנִּים", "צִפֳּרִים", "מַחְבָּרוֹת", "חֲבֵרִים", "עֲנָנִים")
                SortSet(listOf(SortBasket("☝️", tr("יָחִיד")), SortBasket("🙌", tr("רַבִּים"))), one.map { w(it, 0) } + many.map { w(it, 1) }, Topic.HEBREW)
            }
            grade == 4 -> {
                val past = listOf("הָלַךְ", "אָכַל", "כָּתַב", "שִׂחֵק", "שָׁתָה", "צִיֵּר", "קָפַץ", "לָמַד")
                val present = listOf("הוֹלֵךְ", "אוֹכֵל", "כּוֹתֵב", "מְשַׂחֵק", "שׁוֹתֶה", "מְצַיֵּר", "קוֹפֵץ", "לוֹמֵד")
                val future = listOf("יֵלֵךְ", "יֹאכַל", "יִכְתֹּב", "יְשַׂחֵק", "יִשְׁתֶּה", "יְצַיֵּר", "יִקְפֹּץ", "יִלְמַד")
                SortSet(listOf(SortBasket("⏪", tr("עָבָר")), SortBasket("⏺️", tr("הוֹוֶה")), SortBasket("⏩", tr("עָתִיד"))), past.map { w(it, 0) } + present.map { w(it, 1) } + future.map { w(it, 2) }, Topic.HEBREW)
            }
            grade == 5 || grade == 6 -> {
                // ה׳–ו׳: the בִּנְיָן a verb is built in.
                val paal = listOf("הָלַךְ", "כָּתַב", "שָׁמַר", "סָגַר", "לָמַד", "בָּנָה", "קָרָא")
                val piel = listOf("דִּבֵּר", "סִפֵּר", "שִׂחֵק", "לִמֵּד", "צִיֵּר", "בִּקֵּר", "שִׁלֵּם")
                val hifil = listOf("הִדְלִיק", "הִסְבִּיר", "הִכְנִיס", "הִרְגִּישׁ", "הִתְחִיל", "הִזְמִין", "הִשְׁאִיר")
                SortSet(listOf(SortBasket("1️⃣", tr("בִּנְיַן פָּעַל")), SortBasket("2️⃣", tr("בִּנְיַן פִּעֵל")), SortBasket("3️⃣", tr("בִּנְיַן הִפְעִיל"))), paal.map { w(it, 0) } + piel.map { w(it, 1) } + hifil.map { w(it, 2) }, Topic.HEBREW)
            }
            else -> {
                // ז׳–ח׳: שֵׁם פְּעֻלָּה against an adjective against a verb.
                val action = listOf("הֲלִיכָה", "כְּתִיבָה", "שְׁתִיקָה", "חֲשִׁיבָה", "קְרִיאָה", "יְצִירָה", "הַסְבָּרָה")
                val adjective = listOf("מָהִיר", "שָׁקֵט", "עָצוּם", "רָגוּעַ", "נָעִים", "חָרוּץ", "עָמוּק")
                val verb = listOf("הָלַךְ", "כָּתַב", "שָׁתַק", "חָשַׁב", "קָרָא", "יָצַר", "הִסְבִּיר")
                SortSet(listOf(SortBasket("🏃", tr("שֵׁם פְּעֻלָּה")), SortBasket("🎨", tr("שֵׁם תֹּאַר")), SortBasket("⚡", tr("פֹּעַל"))), action.map { w(it, 0) } + adjective.map { w(it, 1) } + verb.map { w(it, 2) }, Topic.HEBREW)
            }
        }
    }

    private fun animals(grade: Int, topic: Topic): SortSet {
        if (grade >= 4) return SortSet(listOf(SortBasket("🐾", tr("יוֹנֵק")), SortBasket("🪶", tr("עוֹף")), SortBasket("🐟", tr("דָּג"))), listOf(i("🐕", tr("כֶּלֶב"), 0), i("🦁", tr("אַרְיֵה"), 0), i("🐘", tr("פִּיל"), 0), i("🐳", tr("לִוְיָתָן"), 0), i("🐬", tr("דּוֹלְפִין"), 0), i("🦇", tr("עֲטַלֵּף"), 0), i("🐄", tr("פָּרָה"), 0), i("🐒", tr("קוֹף"), 0), i("🦅", tr("נֶשֶׁר"), 1), i("🦜", tr("תֻּכִּי"), 1), i("🐧", tr("פִּינְגְּוִין"), 1), i("🦉", tr("יַנְשׁוּף"), 1), i("🐔", tr("תַּרְנְגֹלֶת"), 1), i("🦩", tr("פְּלָמִינְגּוֹ"), 1), i("🕊️", tr("יוֹנָה"), 1), i("🦈", tr("כָּרִישׁ"), 2), i("🐠", tr("דַּג זָהָב"), 2), i("🐡", tr("אַבּוּ נַפְחָא"), 2), i("🐟", tr("טוּנָה"), 2), i("🐟", tr("סַלְמוֹן"), 2)), topic)
        return SortSet(listOf(SortBasket("🌊", tr("חַי בַּמַּיִם")), SortBasket("🌳", tr("חַי בַּיַּבָּשָׁה"))), listOf(i("🐟", tr("דָּג"), 0), i("🐙", tr("תְּמָנוּן"), 0), i("🦈", tr("כָּרִישׁ"), 0), i("🐳", tr("לִוְיָתָן"), 0), i("🐬", tr("דּוֹלְפִין"), 0), i("🪼", tr("מֵדוּזָה"), 0), i("⭐", tr("כּוֹכַב יָם"), 0), i("🐡", tr("אַבּוּ נַפְחָא"), 0), i("🦁", tr("אַרְיֵה"), 1), i("🐘", tr("פִּיל"), 1), i("🦒", tr("גִ'ירָפָה"), 1), i("🐄", tr("פָּרָה"), 1), i("🐎", tr("סוּס"), 1), i("🐒", tr("קוֹף"), 1), i("🐇", tr("אַרְנָב"), 1), i("🐫", tr("גָּמָל"), 1), i("🦓", tr("זֶבְּרָה"), 1)), topic)
    }

    private fun planets(grade: Int): SortSet {
        // ה׳+: gas giant or rocky planet.
        if (MiniGameBand.of(grade) >= MiniGameBand.UPPER) return SortSet(listOf(SortBasket("💨", tr("כּוֹכַב לֶכֶת גַּזִּי")), SortBasket("🪨", tr("כּוֹכַב לֶכֶת סַלְעִי"))), listOf(i("🟠", tr("צֶדֶק"), 0), i("🪐", tr("שַׁבְּתַאי"), 0), i("🟢", tr("אוּרָנוּס"), 0), i("🔵", tr("נֶפְּטוּן"), 0), i("🟤", tr("כּוֹכָב חַמָּה"), 1), i("🟡", tr("נֹגַהּ"), 1), i("🌍", tr("כַּדּוּר הָאָרֶץ"), 1), i("🔴", tr("מַאְדִּים"), 1)), Topic.SPACE)
        val b = BalloonSets.planets()
        return SortSet(listOf(SortBasket("🪐", tr("כּוֹכַב לֶכֶת")), SortBasket("✨", tr("לֹא כּוֹכַב לֶכֶת"))),
            b.targets.map { i(it.emoji, it.label, 0) } + b.others.map { i(it.emoji, it.label, 1) }, Topic.SPACE)
    }

    private fun dinosaurs(grade: Int): SortSet {
        // א׳–ג׳ meet the dinosaurs first; ד׳+ sort them by what they ate.
        if (MiniGameBand.of(grade) <= MiniGameBand.LOWER || grade == 3) {
            val b = BalloonSets.dinosaurs()
            return SortSet(listOf(SortBasket("🦕", tr("דִּינוֹזָאוּר")), SortBasket("🚫", tr("לֹא דִּינוֹזָאוּר"))),
                b.targets.map { i(it.emoji, it.label, 0) } + b.others.map { i(it.emoji, it.label, 1) }, Topic.DINOSAURS)
        }
        return SortSet(listOf(SortBasket("🌿", tr("אוֹכֵל צְמָחִים")), SortBasket("🍖", tr("אוֹכֵל בָּשָׂר"))), listOf(i("🦴", tr("טְרִיצֶרָטוֹפְּס"), 0), i("🦴", tr("סְטֶגוֹזָאוּרוּס"), 0), i("🦕", tr("בְּרָכִיוֹזָאוּרוּס"), 0), i("🦕", tr("דִּיפְּלוֹדוֹקוּס"), 0), i("🦴", tr("אַנְקִילוֹזָאוּרוּס"), 0), i("🦕", tr("פָּרָזָאוּרוֹלוֹפוּס"), 0), i("🦖", tr("טִירָנוֹזָאוּרוּס"), 1), i("🦖", tr("וֶלוֹצִירַפְּטוֹר"), 1), i("🦖", tr("סְפִּינוֹזָאוּרוּס"), 1), i("🦖", tr("אַלוֹזָאוּרוּס"), 1), i("🦖", tr("דִּילוֹפוֹזָאוּרוּס"), 1)), Topic.DINOSAURS)
    }

    private fun soccer(grade: Int): SortSet {
        // ה׳+: the roles on the pitch, defence against attack.
        if (MiniGameBand.of(grade) >= MiniGameBand.UPPER) return SortSet(listOf(SortBasket("🛡️", tr("הֲגָנָה")), SortBasket("🎯", tr("הַתְקָפָה"))), listOf(i("🧤", tr("שׁוֹעֵר"), 0), i("🛡️", tr("בַּלָּם"), 0), i("🛡️", tr("מֵגֵן"), 0), i("🔙", tr("קַשָּׁר הֲגַנָּתִי"), 0), i("🎯", tr("חָלוּץ"), 1), i("🎯", tr("כַּנְפָן"), 1), i("🔜", tr("קַשָּׁר הַתְקָפִי"), 1), i("🥇", tr("חָלוּץ מְרֻכָּז"), 1)), Topic.SOCCER)
        val b = BalloonSets.soccer()
        return SortSet(listOf(SortBasket("⚽", tr("כַּדּוּרֶגֶל")), SortBasket("🏅", tr("עֲנַף סְפּוֹרְט אַחֵר"))),
            b.targets.map { i(it.emoji, it.label, 0) } + b.others.map { i(it.emoji, it.label, 1) }, Topic.SOCCER)
    }

    private fun places(grade: Int, topic: Topic): SortSet {
        val europe = listOf(i("🇫🇷", tr("צָרְפַת"), 0), i("🇮🇹", tr("אִיטַלְיָה"), 0), i("🇪🇸", tr("סְפָרַד"), 0), i("🇩🇪", tr("גֶּרְמַנְיָה"), 0), i("🇬🇷", tr("יָוָן"), 0), i("🇳🇱", tr("הוֹלַנְד"), 0))
        val asia = listOf(i("🇯🇵", tr("יַפָּן"), 1), i("🇨🇳", tr("סִין"), 1), i("🇮🇳", tr("הֹדּוּ"), 1), i("🇹🇭", tr("תָּאִילַנְד"), 1), i("🇰🇷", tr("דְּרוֹם קוֹרֵאָה"), 1))
        val america = listOf(i("🇺🇸", tr("אַרְצוֹת הַבְּרִית"), 2), i("🇨🇦", tr("קָנָדָה"), 2), i("🇧🇷", tr("בְּרָזִיל"), 2), i("🇦🇷", tr("אַרְגֶּנְטִינָה"), 2), i("🇲🇽", tr("מֶקְסִיקוֹ"), 2))
        if (grade >= 4) return SortSet(listOf(SortBasket("🏰", tr("אֵירוֹפָּה")), SortBasket("🏯", tr("אַסְיָה")), SortBasket("🗽", tr("אֲמֶרִיקָה"))), europe + asia + america, topic)
        // An Israeli child sorts cities: here or abroad (an American child gets Europe or not).
        if (grade <= 2 && GameEnv.isIsraeli) {
            val here = listOf(tr("חֵיפָה"), tr("תֵּל אָבִיב"), tr("אֵילַת"), tr("בְּאֵר שֶׁבַע"), tr("נָצְרַת"), tr("עַכּוֹ"), tr("טְבֶרְיָה"), tr("נְתַנְיָה"))
            val away = listOf("🇫🇷" to tr("פָּרִיז"), "🇬🇧" to tr("לוֹנְדוֹן"), "🇮🇹" to tr("רוֹמָא"), "🇯🇵" to tr("טוֹקְיוֹ"), "🇺🇸" to tr("נְיוּ יוֹרְק"), "🇪🇬" to tr("קָהִיר"), "🇪🇸" to tr("מַדְרִיד"), "🇩🇪" to tr("בֶּרְלִין"))
            return SortSet(listOf(SortBasket("🏠", tr("בְּיִשְׂרָאֵל")), SortBasket("✈️", tr("בְּחוּץ לָאָרֶץ"))), here.map { i("🏙️", it, 0) } + away.map { i(it.first, it.second, 1) }, topic)
        }
        return SortSet(listOf(SortBasket("🏰", tr("אֵירוֹפָּה")), SortBasket("🌏", tr("לֹא בְּאֵירוֹפָּה"))), europe + (asia + america).map { i(it.emoji, it.label, 1) }, topic)
    }

    private fun science(grade: Int): SortSet {
        // ז׳–ח׳: element, compound or mixture.
        if (MiniGameBand.of(grade) >= MiniGameBand.TOP) return SortSet(listOf(SortBasket("⚛️", tr("יְסוֹד")), SortBasket("🧪", tr("תַּרְכֹּבֶת")), SortBasket("🥣", tr("תַּעֲרֹבֶת"))), listOf(i("🪙", tr("זָהָב"), 0), i("🫁", tr("חַמְצָן"), 0), i("🧲", tr("בַּרְזֶל"), 0), i("🟠", tr("נְחֹשֶׁת"), 0), i("🎈", tr("הֶלְיוּם"), 0), i("💧", tr("מַיִם"), 1), i("🧂", tr("מֶלַח בִּשּׁוּל"), 1), i("🍬", tr("סֻכָּר"), 1), i("💨", tr("פַּחְמָן דּוּ־חַמְצָנִי"), 1), i("🌬️", tr("אֲוִיר"), 2), i("🌊", tr("מֵי יָם"), 2), i("🥛", tr("חָלָב"), 2), i("🔩", tr("פְּלָדָה"), 2)), Topic.SCIENCE)
        if (grade >= 4) return SortSet(listOf(SortBasket("🧊", tr("מוּצָק")), SortBasket("💧", tr("נוֹזֵל")), SortBasket("💨", tr("גַּז"))), listOf(i("🧊", tr("קֶרַח"), 0), i("🪨", tr("אֶבֶן"), 0), i("🪵", tr("קֶרֶשׁ"), 0), i("🪙", tr("מַטְבֵּעַ"), 0), i("🧱", tr("לְבֵנָה"), 0), i("💧", tr("מַיִם"), 1), i("🥛", tr("חָלָב"), 1), i("🧃", tr("מִיץ"), 1), i("🫒", tr("שֶׁמֶן זַיִת"), 1), i("🍯", tr("דְּבַשׁ"), 1), i("♨️", tr("אֵדִים"), 2), i("🌬️", tr("אֲוִיר"), 2), i("🎈", tr("הֶלְיוּם"), 2), i("🫁", tr("חַמְצָן"), 2)), Topic.SCIENCE)
        return SortSet(listOf(SortBasket("🌱", tr("חַי")), SortBasket("🪨", tr("דּוֹמֵם"))), listOf(i("🐕", tr("כֶּלֶב"), 0), i("🌳", tr("עֵץ"), 0), i("🌸", tr("פֶּרַח"), 0), i("🐦", tr("צִפּוֹר"), 0), i("🐟", tr("דָּג"), 0), i("🍄", tr("פִּטְרִיָּה"), 0), i("🐜", tr("נְמָלָה"), 0), i("🪨", tr("אֶבֶן"), 1), i("🪑", tr("כִּסֵּא"), 1), i("🚗", tr("מְכוֹנִית"), 1), i("⚽", tr("כַּדּוּר"), 1), i("🥤", tr("כּוֹס"), 1), i("✏️", tr("עִפָּרוֹן"), 1), i("☁️", tr("עָנָן"), 1)), Topic.SCIENCE)
    }

    private fun body(grade: Int): SortSet {
        // ד׳+: which SYSTEM each organ belongs to.
        if (MiniGameBand.of(grade) >= MiniGameBand.MIDDLE && grade >= 4) return SortSet(listOf(SortBasket("🫁", tr("מַעֲרֶכֶת הַנְּשִׁימָה")), SortBasket("🫀", tr("מַעֲרֶכֶת הַדָּם")), SortBasket("🍽️", tr("מַעֲרֶכֶת הָעִכּוּל"))), listOf(i("🫁", tr("רֵאוֹת"), 0), i("🌬️", tr("קְנֵה נְשִׁימָה"), 0), i("🍃", tr("סִמְפּוֹנוֹת"), 0), i("👃", tr("אַף"), 0), i("🫀", tr("לֵב"), 1), i("🩸", tr("עוֹרְקִים"), 1), i("💉", tr("וְרִידִים"), 1), i("🫘", tr("טְחוֹל"), 1), i("🍽️", tr("קֵבָה"), 2), i("🌀", tr("מַעַיִם"), 2), i("🟤", tr("כָּבֵד"), 2), i("👄", tr("פֶּה"), 2)), Topic.BODY)
        return SortSet(listOf(SortBasket("🫀", tr("בְּתוֹךְ הַגּוּף")), SortBasket("✋", tr("מִבַּחוּץ"))), listOf(i("🫀", tr("לֵב"), 0), i("🫁", tr("רֵאוֹת"), 0), i("🧠", tr("מֹחַ"), 0), i("🍽️", tr("קֵבָה"), 0), i("🩸", tr("כָּבֵד"), 0), i("🫘", tr("כְּלָיוֹת"), 0), i("✋", tr("יָד"), 1), i("👃", tr("אַף"), 1), i("👂", tr("אֹזֶן"), 1), i("🦶", tr("כַּף רֶגֶל"), 1), i("👁️", tr("עַיִן"), 1), i("🦵", tr("בֶּרֶךְ"), 1)), Topic.BODY)
    }

    private fun vehicles(grade: Int): SortSet {
        val land = listOf(i("🚗", tr("מְכוֹנִית"), 0), i("🚌", tr("אוֹטוֹבּוּס"), 0), i("🚆", tr("רַכֶּבֶת"), 0), i("🚲", tr("אוֹפַנַּיִם"), 0), i("🚚", tr("מַשָּׂאִית"), 0), i("🏍️", tr("אוֹפְנוֹעַ"), 0))
        val air = listOf(i("✈️", tr("מָטוֹס"), 1), i("🚁", tr("מַסּוֹק"), 1), i("🎈", tr("כַּדּוּר פּוֹרֵחַ"), 1), i("🪂", tr("מִצְנָח"), 1), i("🛩️", tr("מָטוֹס קַל"), 1))
        val water = listOf(i("🚢", tr("אֳנִיָּה"), 2), i("⛵", tr("מִפְרָשִׂית"), 2), i("🛶", tr("קָנוּ"), 2), i("🚤", tr("סִירַת מָנוֹעַ"), 2), i("🌊", tr("צוֹלֶלֶת"), 2))
        val baskets = mutableListOf(SortBasket("🛣️", tr("בַּיַּבָּשָׁה")), SortBasket("☁️", tr("בָּאֲוִיר")))
        val items = (land + air).toMutableList()
        if (grade >= 3) { baskets += SortBasket("🌊", tr("בַּמַּיִם")); items += water }
        return SortSet(baskets, items, Topic.VEHICLES)
    }

    private fun music(grade: Int): SortSet {
        val strings = listOf(i("🎸", tr("גִּיטָרָה"), 0), i("🎻", tr("כִּנּוֹר"), 0), i("🪕", tr("בַּנְגּ'וֹ"), 0), i("🎼", tr("נֵבֶל"), 0))
        val drums = listOf(i("🥁", tr("תֻּפִּים"), 1), i("🪘", tr("דַּרְבּוּקָה"), 1), i("🔔", tr("מְצִלְתַּיִם"), 1), i("🎶", tr("קְסִילוֹפוֹן"), 1), i("", tr("מָרָקָס"), 1))
        val wind = listOf(i("🎺", tr("חֲצוֹצְרָה"), 2), i("🎷", tr("סַקְסוֹפוֹן"), 2), i("", tr("חָלִיל"), 2), i("🎵", tr("קְלַרְנִית"), 2))
        // ו׳+: inside the wind family — woodwind against brass.
        if (grade >= 6) return SortSet(listOf(SortBasket("🪵", tr("נְשִׁיפָה מֵעֵץ")), SortBasket("🎺", tr("נְשִׁיפָה מִמַּתֶּכֶת"))), listOf(i("", tr("חָלִיל"), 0), i("🎵", tr("קְלַרְנִית"), 0), i("🪈", tr("אַבּוּב"), 0), i("🎼", tr("בַּסּוּן"), 0), i("🎺", tr("חֲצוֹצְרָה"), 1), i("📢", tr("טְרוֹמְבּוֹן"), 1), i("🎶", tr("טוּבָּה"), 1), i("🔊", tr("קֶרֶן יַעַר"), 1)), Topic.MUSIC)
        val baskets = mutableListOf(SortBasket("🎻", tr("כְּלֵי מֵיתָרִים")), SortBasket("🥁", tr("כְּלֵי הַקָּשָׁה")))
        val items = (strings + drums).toMutableList()
        if (grade >= 3) { baskets += SortBasket("🎺", tr("כְּלֵי נְשִׁיפָה")); items += wind }
        return SortSet(baskets, items, Topic.MUSIC)
    }

    private fun food(grade: Int): SortSet {
        val fruit = listOf(i("🍎", tr("תַּפּוּחַ"), 0), i("🍌", tr("בָּנָנָה"), 0), i("🍇", tr("עֲנָבִים"), 0), i("🍓", tr("תּוּת"), 0), i("🍊", tr("תַּפּוּז"), 0), i("🍉", tr("אֲבַטִּיחַ"), 0), i("🍍", tr("אֲנָנָס"), 0), i("🍒", tr("דֻּבְדְּבָנִים"), 0))
        val veg = listOf(i("🥕", tr("גֶּזֶר"), 1), i("🥦", tr("בְּרוֹקוֹלִי"), 1), i("🥬", tr("חַסָּה"), 1), i("🥔", tr("תַּפּוּחַ אֲדָמָה"), 1), i("🧅", tr("בָּצָל"), 1), i("🧄", tr("שׁוּם"), 1))
        val baskets = mutableListOf(SortBasket("🍎", tr("פְּרִי")), SortBasket("🥕", tr("יָרָק")))
        val items = (fruit + veg).toMutableList()
        // ד׳+: a third basket — legumes.
        if (grade >= 4) {
            baskets += SortBasket("🫘", tr("קִטְנִיּוֹת"))
            items += listOf(i("🫘", tr("עֲדָשִׁים"), 2), i("🫛", tr("אֲפוּנָה"), 2), i("🫘", tr("שְׁעוּעִית"), 2), i("🫘", tr("גַּרְגְּרֵי חֻמּוּס"), 2), i("🫛", tr("פּוֹל"), 2))
        }
        return SortSet(baskets, items, Topic.FOOD)
    }

    private fun money(grade: Int): SortSet {
        // ו׳+: a fixed cost against a variable one.
        if (grade >= 6) return SortSet(listOf(SortBasket("📅", tr("הוֹצָאָה קְבוּעָה")), SortBasket("🎲", tr("הוֹצָאָה מִשְׁתַּנָּה"))), listOf(i("🏠", tr("שְׂכַר דִּירָה"), 0), i("💡", tr("חֶשְׁבּוֹן חַשְׁמַל"), 0), i("📱", tr("מִנּוּי לַטֶּלֶפוֹן"), 0), i("🏫", tr("שְׂכַר לִמּוּד"), 0), i("🚌", tr("כַּרְטִיסִיָּה חֹדְשִׁית"), 0), i("🛒", tr("קְנִיּוֹת בַּסּוּפֶּר"), 1), i("🎬", tr("כַּרְטִיס לַקּוֹלְנוֹעַ"), 1), i("🍦", tr("גְּלִידָה"), 1), i("🎁", tr("מַתָּנָה לְחָבֵר"), 1), i("🩹", tr("תִּקּוּן פַּנְצֶ'ר"), 1)), Topic.MONEY)
        if (grade >= 4) return SortSet(listOf(SortBasket("💰", tr("הַכְנָסָה")), SortBasket("💸", tr("הוֹצָאָה"))), listOf(i("💼", tr("מַשְׂכֹּרֶת"), 0), i("🪙", tr("דְּמֵי כִּיס"), 0), i("🎁", tr("כֶּסֶף שֶׁקִּבַּלְנוּ בְּמַתָּנָה"), 0), i("🍋", tr("מְכִירַת לִימוֹנָדָה"), 0), i("🏆", tr("פְּרָס בְּתַחֲרוּת"), 0), i("🏠", tr("שְׂכַר דִּירָה"), 1), i("🛒", tr("קְנִיּוֹת בַּסּוּפֶּר"), 1), i("💡", tr("חֶשְׁבּוֹן חַשְׁמַל"), 1), i("🎬", tr("כַּרְטִיס לַקּוֹלְנוֹעַ"), 1), i("🧸", tr("קְנִיַּת צַעֲצוּעַ"), 1)), Topic.MONEY)
        return SortSet(listOf(SortBasket("✅", tr("צְרִיכִים")), SortBasket("💭", tr("רַק רוֹצִים"))), listOf(i("🍞", tr("לֶחֶם"), 0), i("💧", tr("מַיִם"), 0), i("🥛", tr("חָלָב"), 0), i("💊", tr("תְּרוּפָה"), 0), i("🎒", tr("תִּיק לְבֵית הַסֵּפֶר"), 0), i("🧥", tr("מְעִיל לַחֹרֶף"), 0), i("🍭", tr("סֻכָּרִיָּה"), 1), i("🧸", tr("דֻּבִּי"), 1), i("🎮", tr("מִשְׂחַק מַחְשֵׁב"), 1), i("🍦", tr("גְּלִידָה"), 1), i("🪀", tr("יוֹ־יוֹ"), 1), i("🎈", tr("בָּלוֹן"), 1)), Topic.MONEY)
    }
}

// MARK: - 🧠 Patterns

data class PatternRound(
    /** The sequence, "?" where the missing piece goes. */
    val cells: List<String>,
    val answer: String,
    val options: List<String>,
    /** Numbers and pictures read left-to-right; Hebrew letters right-to-left. */
    val rtl: Boolean,
    val topic: Topic,
)

object PatternGen {
    const val ROUND_COUNT = 6

    private fun r(a: Int, b: Int) = (a..b).random()
    private fun coin() = kotlin.random.Random.nextBoolean()
    private fun ipow(m: Int, n: Int): Int = m.toDouble().pow(n).toInt()

    /** A theme's own pictures for a picture pattern. */
    fun pictures(topic: Topic?): List<String> = when (topic) {
        Topic.SOCCER -> listOf("⚽", "🥅", "🧤", "🏆")
        Topic.SEA -> listOf("🐟", "🐙", "🦀", "🐬")
        Topic.SPACE -> listOf("🌍", "🪐", "☀️", "🌙")
        Topic.ANIMALS -> listOf("🐶", "🐱", "🐰", "🦁")
        Topic.DINOSAURS -> listOf("🦖", "🦕", "🥚", "🦴")
        Topic.FLAGS -> listOf("🇫🇷", "🇯🇵", "🇧🇷", "🇮🇹")
        else -> listOf("🔴", "🔵", "🟡", "🟢")
    }

    fun make(topic: Topic?, grade: Int): PatternRound {
        // 👶 גן: always pictures, from a pre-reader's own sets.
        if (MiniGameBand.of(grade) == MiniGameBand.PRE_READER) return picture(PreReaderGames.patternSets.random(), 0, Topic.LOGIC)
        val g = max(1, grade)
        return when (topic) {
            Topic.ENGLISH -> letters("ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { it.toString() }, g, false, Topic.ENGLISH)
            Topic.HEBREW -> letters("אבגדהוזחטיכלמנסעפצקרשת".map { it.toString() }, g, true, Topic.HEBREW)
            Topic.MATH, Topic.LOGIC, Topic.GIFTED, Topic.MONEY, null -> {
                val pictureChance = if (g <= 1) 0.5 else if ((topic == Topic.LOGIC || topic == Topic.GIFTED) && g <= 4) 0.3 else 0.0
                if (kotlin.random.Random.nextDouble() < pictureChance) picture(pictures(topic), g, topic ?: Topic.LOGIC)
                else numbers(g, topic ?: Topic.MATH)
            }
            else -> picture(pictures(topic), g, topic)
        }
    }

    private fun options(answer: Int, near: List<Int>): List<String> {
        val set = linkedSetOf(answer)
        for (n in near.shuffled()) if (set.size < 4 && n != answer) set += n
        var d = 1
        while (set.size < 4) { set += answer + if (coin()) d else -d; d++ }
        return set.map { MathFacts.show(it) }.shuffled()
    }

    private fun numbers(g: Int, topic: Topic): PatternRound {
        var seq: List<Int>
        when (g) {
            1 -> { val k = listOf(1, 2, 5, 10).random(); val a = r(0, 10); seq = (0 until 5).map { a + it * k } }
            2 -> { val k = r(2, 10); val a = r(1, 20)
                seq = if (coin()) (0 until 5).map { a + it * k } else (0 until 5).map { a + 4 * k - it * k } }
            3 -> seq = when (r(0, 2)) {
                0 -> { val k = r(3, 12); val a = r(1, 30); (0 until 6).map { a + it * k } }
                1 -> { val a = r(1, 5); (0 until 5).map { a shl it } }
                else -> { val x = r(2, 5); val y = r(1, 4); var v = r(1, 10)
                    val l = mutableListOf(v); for (i in 0 until 5) { v += if (i % 2 == 0) x else y; l += v }; l }
            }
            4 -> seq = when (r(0, 2)) {
                0 -> { val m = listOf(2, 3).random(); val a = r(1, 4); (0 until 5).map { a * ipow(m, it) } }
                1 -> { val s = r(1, 4); (s until s + 5).map { it * it } }
                else -> { val k = r(6, 15); val a = r(20, 120); (0 until 6).map { a - it * k } }
            }
            5 -> seq = when (r(0, 2)) {
                0 -> { var a = r(1, 3); var b = r(2, 5); val l = mutableListOf(a, b)
                    repeat(4) { val c = a + b; l += c; a = b; b = c }; l }
                1 -> { // Two steps that alternate: +k, ×2, +k, ×2 …
                    val k = r(3, 9); var v = r(1, 6); val l = mutableListOf(v)
                    for (n in 0 until 5) { v = if (n % 2 == 0) v + k else v * 2; l += v }; l }
                else -> { val k = r(11, 25); val a = r(60, 250); (0 until 6).map { a - it * k } }
            }
            6 -> seq = when (r(0, 2)) {
                0 -> { // The gaps themselves grow: +2, +4, +6 …
                    val k = r(2, 4); var v = r(1, 9); val l = mutableListOf(v)
                    for (n in 1..5) { v += k * n; l += v }; l }
                1 -> { val s = r(4, 9); (s until s + 5).map { it * it } }
                else -> { val m = listOf(2, 3, 5).random(); val a = r(2, 6); (0 until 5).map { a * ipow(m, it) } }
            }
            7 -> seq = when (r(0, 2)) {
                0 -> { val a = r(1, 3); (0 until 6).map { a * (-2.0).pow(it).toInt() } }
                1 -> { var a = r(2, 5); var b = r(3, 7); val l = mutableListOf(a, b)
                    repeat(4) { val c = a + b; l += c; a = b; b = c }; l }
                else -> { val k = r(4, 9); val a = r(5, 20); (0 until 6).map { a - it * k } }   // into the negatives
            }
            else -> seq = when (r(0, 3)) {
                0 -> { val s = r(1, 4); (s until s + 5).map { it * it * it } }
                1 -> { val s = r(1, 5); (s until s + 6).map { it * it + it } }   // n² + n
                2 -> { val m = listOf(-3, 3, -2).random(); var v = r(1, 4); val l = mutableListOf(v)
                    repeat(5) { v *= m; l += v }; l }   // the sign flips every step
                else -> { val k = r(1, 5); var v = r(2, 6); val l = mutableListOf(v)
                    repeat(5) { v = v * 2 - k; l += v }; l }   // doubled, minus a constant
            }
        }
        // The hole: the end, or (from ג׳) somewhere in the middle.
        val hole = if (g >= 3 && coin()) r(1, seq.size - 2) else seq.size - 1
        val answer = seq[hole]
        val step = if (seq.size > 1) abs(seq[1] - seq[0]) else 1
        var near = listOf(answer + step, answer - step, answer + 1, answer - 1, answer * 2, seq[max(0, hole - 1)])
        if (g < 7) near = near.filter { it >= 0 }
        val cells = seq.map { MathFacts.show(it) }.toMutableList()
        cells[hole] = "?"
        return PatternRound(cells, MathFacts.show(answer), options(answer, near), false, topic)
    }

    private fun letters(abc: List<String>, g: Int, rtl: Boolean, topic: Topic): PatternRound {
        val step = if (g <= 2) 1 else if (g <= 4) 2 else listOf(3, 4).random()
        val length = 5
        val maxStart = abc.size - 1 - step * (length - 1)
        // ה׳+: the run can go the other way through the alphabet.
        val backwards = g >= 5 && coin()
        val start = if (backwards) abc.size - 1 - r(0, max(0, maxStart)) else r(0, max(0, maxStart))
        val dirStep = if (backwards) -step else step
        val seq = (0 until length).map { abc[start + it * dirStep] }
        val hole = if (g >= 3 && coin()) r(1, length - 2) else length - 1
        val answerIndex = start + hole * dirStep
        val opts = linkedSetOf(abc[answerIndex])
        for (d in listOf(1, -1, step + 1, -(step + 1), 2, -2).shuffled()) {
            if (opts.size >= 4) break
            val j = answerIndex + d
            if (j in abc.indices) opts += abc[j]
        }
        val cells = seq.toMutableList(); cells[hole] = "?"
        return PatternRound(cells, abc[answerIndex], opts.shuffled(), rtl, topic)
    }

    private fun picture(set: List<String>, g: Int, topic: Topic): PatternRound {
        val preReader = MiniGameBand.of(g) == MiniGameBand.PRE_READER
        // 👶 Two pictures, not three: 🔴 🔵 🔴 🔵 🔴 ❓ is a גן pattern.
        val shapes = set.shuffled().take(if (preReader) 2 else 3)
        val units: List<List<Int>> = when (MiniGameBand.of(g)) {
            MiniGameBand.PRE_READER -> listOf(listOf(0, 1))
            MiniGameBand.LOWER -> listOf(listOf(0, 1), listOf(0, 0, 1))
            MiniGameBand.MIDDLE -> listOf(listOf(0, 1), listOf(0, 0, 1), listOf(0, 1, 2), listOf(0, 1, 1), listOf(0, 1, 2, 1))
            else -> listOf(listOf(0, 1, 2), listOf(0, 1, 1, 2), listOf(0, 1, 2, 1), listOf(0, 1, 2, 2, 1), listOf(0, 0, 1, 2, 1))
        }
        val unit = units.random()
        val length = if (preReader) 5 else minOf(8, max(6, unit.size * 2 + 1))
        val seq = (0 until length).map { shapes[unit[it % unit.size]] }
        val hole = length - 1
        val cells = seq.toMutableList(); cells[hole] = "?"
        // 👶 Three choices for גן; four for everyone else.
        val outsider = set.firstOrNull { it !in shapes } ?: shapes[0]
        val opts = (shapes + outsider).toSet().toList().shuffled()
        return PatternRound(cells, seq[hole], opts, false, topic)
    }
}

// MARK: - 🔢 2048

data class Tile2048(val id: Long, val value: Int, val r: Int, val c: Int, val merged: Boolean = false)

enum class Move2048 { LEFT, RIGHT, UP, DOWN }

object Board2048 {
    const val SIZE = 4

    data class Slide(val tiles: List<Tile2048>, val consumed: List<Tile2048>, val moved: Boolean, val points: Int)

    /** Slides every tile; equal neighbours merge once. */
    fun slide(tiles: List<Tile2048>, dir: Move2048): Slide {
        val n = SIZE
        val out = mutableListOf<Tile2048>()
        val consumed = mutableListOf<Tile2048>()
        var points = 0
        var moved = false
        for (line in 0 until n) {
            val lineTiles = when (dir) {
                Move2048.LEFT -> tiles.filter { it.r == line }.sortedBy { it.c }
                Move2048.RIGHT -> tiles.filter { it.r == line }.sortedByDescending { it.c }
                Move2048.UP -> tiles.filter { it.c == line }.sortedBy { it.r }
                Move2048.DOWN -> tiles.filter { it.c == line }.sortedByDescending { it.r }
            }
            val placed = mutableListOf<Tile2048>()
            for (t0 in lineTiles) {
                val t = t0.copy(merged = false)
                val last = placed.lastOrNull()
                if (last != null && last.value == t.value && !last.merged) {
                    val grown = last.copy(value = last.value * 2, merged = true)
                    points += grown.value
                    placed[placed.size - 1] = grown
                    consumed += t.copy(r = last.r, c = last.c)
                    moved = true
                } else {
                    val i = placed.size
                    val (r, c) = when (dir) {
                        Move2048.LEFT -> line to i
                        Move2048.RIGHT -> line to n - 1 - i
                        Move2048.UP -> i to line
                        Move2048.DOWN -> n - 1 - i to line
                    }
                    if (t.r != r || t.c != c) moved = true
                    placed += t.copy(r = r, c = c)
                }
            }
            out += placed
        }
        return Slide(out, consumed, moved, points)
    }

    fun emptyCells(tiles: List<Tile2048>): List<Pair<Int, Int>> {
        val taken = tiles.map { it.r * SIZE + it.c }.toSet()
        return (0 until SIZE * SIZE).filter { it !in taken }.map { it / SIZE to it % SIZE }
    }

    fun canMove(tiles: List<Tile2048>): Boolean {
        if (tiles.size < SIZE * SIZE) return true
        for (t in tiles) {
            if (tiles.any { ((it.r == t.r && it.c == t.c + 1) || (it.c == t.c && it.r == t.r + 1)) && it.value == t.value }) return true
        }
        return false
    }

    /** The app's own palette, warming up as the tiles grow (hex). */
    fun colorHex(value: Int): Long = when {
        value <= 2 -> 0xFF48BFE3
        value == 4 -> 0xFF9B5DE5
        value == 8 -> 0xFFFF6B9D
        value == 16 -> 0xFFFFB84D
        value == 32 -> 0xFF06D6A0
        value == 64 -> 0xFF3A86FF
        value == 128 -> 0xFFF15BB5
        value == 256 -> 0xFFFF9F1C
        else -> 0xFFFFD23F
    }

    fun bestKey(): String = "g2048.best.${GameEnv.childKey}"
}

// MARK: - 🔐 The vault

/**
 * 🔐 One hard fact about the vault's code. The code is dealt first, every clue
 * is generated against it, and [holds] proves the round: [VaultGen] brute
 * forces every possible code and only ships a clue set that leaves exactly one.
 */
data class VaultClue(val kind: Kind) {
    sealed class Kind {
        data class DigitIs(val pos: Int, val digit: Int) : Kind()
        data class InCode(val digit: Int) : Kind()
        data class NotInCode(val digit: Int) : Kind()
        data class Greater(val pos: Int, val bound: Int) : Kind()
        data class Less(val pos: Int, val bound: Int) : Kind()
        data class Parity(val pos: Int, val even: Boolean) : Kind()
        data class Divisible(val pos: Int, val by: Int) : Kind()
        data class PairSum(val a: Int, val b: Int, val total: Int) : Kind()
        data class PairDiff(val a: Int, val b: Int, val diff: Int) : Kind()
        /** `b` is `factor` times `a`. */
        data class PairTimes(val a: Int, val b: Int, val factor: Int) : Kind()
        data class Bigger(val a: Int, val b: Int) : Kind()
        data class TotalSum(val total: Int) : Kind()
        data class EvenCount(val n: Int) : Kind()
        data class PrimeCount(val n: Int) : Kind()

        /** The kind of thinking the clue asks for (keeps a round from being five sums). */
        val family: String
            get() = when (this) {
                is DigitIs -> "digitIs"; is InCode -> "inCode"; is NotInCode -> "notInCode"
                is Greater -> "greater"; is Less -> "less"; is Parity -> "parity"; is Divisible -> "divisible"
                is PairSum -> "pairSum"; is PairDiff -> "pairDiff"; is PairTimes -> "pairTimes"; is Bigger -> "bigger"
                is TotalSum -> "totalSum"; is EvenCount -> "evenCount"; is PrimeCount -> "primeCount"
            }
    }

    /** Is this clue true of `c`? The whole game rests on this one function. */
    fun holds(c: List<Int>): Boolean {
        fun has(i: Int) = i in c.indices
        return when (val k = kind) {
            is Kind.DigitIs -> has(k.pos) && c[k.pos] == k.digit
            is Kind.InCode -> k.digit in c
            is Kind.NotInCode -> k.digit !in c
            is Kind.Greater -> has(k.pos) && c[k.pos] > k.bound
            is Kind.Less -> has(k.pos) && c[k.pos] < k.bound
            is Kind.Parity -> has(k.pos) && (c[k.pos] % 2 == 0) == k.even
            is Kind.Divisible -> has(k.pos) && k.by != 0 && c[k.pos] % k.by == 0
            is Kind.PairSum -> has(k.a) && has(k.b) && c[k.a] + c[k.b] == k.total
            is Kind.PairDiff -> has(k.a) && has(k.b) && abs(c[k.a] - c[k.b]) == k.diff
            is Kind.PairTimes -> has(k.a) && has(k.b) && c[k.b] == c[k.a] * k.factor
            is Kind.Bigger -> has(k.a) && has(k.b) && c[k.a] > c[k.b]
            is Kind.TotalSum -> c.sum() == k.total
            is Kind.EvenCount -> c.count { it % 2 == 0 } == k.n
            is Kind.PrimeCount -> c.count { it in VaultGen.primeDigits } == k.n
        }
    }

    /** 🗣️ The sentence the child reads — whole translatable templates, positions interpolated. */
    val text: String
        get() = when (val k = kind) {
            is Kind.DigitIs -> tr("%@ הִיא %lld", VaultGen.positionName(k.pos), k.digit)
            is Kind.InCode -> tr("הַסִּפְרָה %lld מוֹפִיעָה בַּקּוֹד", k.digit)
            is Kind.NotInCode -> tr("הַסִּפְרָה %lld לֹא מוֹפִיעָה בַּקּוֹד", k.digit)
            is Kind.Greater -> tr("%@ גְּדוֹלָה מִ־%lld", VaultGen.positionName(k.pos), k.bound)
            is Kind.Less -> tr("%@ קְטַנָּה מִ־%lld", VaultGen.positionName(k.pos), k.bound)
            is Kind.Parity -> if (k.even) tr("%@ זוּגִית", VaultGen.positionName(k.pos)) else tr("%@ אִי־זוּגִית", VaultGen.positionName(k.pos))
            is Kind.Divisible -> tr("%@ מִתְחַלֶּקֶת בְּ־%lld בְּלִי שְׁאֵרִית", VaultGen.positionName(k.pos), k.by)
            is Kind.PairSum -> tr("%@ וְ%@ מִתְחַבְּרוֹת לְ־%lld", VaultGen.shortName(k.a), VaultGen.shortName(k.b), k.total)
            is Kind.PairDiff -> tr("הַהֶפְרֵשׁ בֵּין %@ וּבֵין %@ הוּא %lld", VaultGen.shortName(k.a), VaultGen.shortName(k.b), k.diff)
            is Kind.PairTimes -> tr("%@ גְּדוֹלָה פִּי %lld מֵ%@", VaultGen.shortName(k.b), k.factor, VaultGen.shortName(k.a))
            is Kind.Bigger -> tr("%@ גְּדוֹלָה מֵ%@", VaultGen.shortName(k.a), VaultGen.shortName(k.b))
            is Kind.TotalSum -> tr("סְכוּם כָּל הַסְּפָרוֹת בַּקּוֹד הוּא %lld", k.total)
            is Kind.EvenCount -> when (k.n) {
                0 -> tr("כָּל הַסְּפָרוֹת בַּקּוֹד אִי־זוּגִיּוֹת")
                1 -> tr("בַּקּוֹד יֵשׁ סִפְרָה זוּגִית אַחַת בִּלְבַד")
                else -> tr("בַּקּוֹד יֵשׁ בְּדִיּוּק %lld סְפָרוֹת זוּגִיּוֹת", k.n)
            }
            is Kind.PrimeCount -> when (k.n) {
                0 -> tr("אַף סִפְרָה בַּקּוֹד אֵינָהּ רִאשׁוֹנִית")
                1 -> tr("בַּקּוֹד יֵשׁ סִפְרָה רִאשׁוֹנִית אַחַת בִּלְבַד")
                else -> tr("בַּקּוֹד יֵשׁ בְּדִיּוּק %lld סְפָרוֹת רִאשׁוֹנִיּוֹת", k.n)
            }
        }
}

object VaultGen {
    val primeDigits: Set<Int> = setOf(2, 3, 5, 7)

    /** 🎚️ 3 digits up to ג׳, 4 from ד׳. */
    fun digits(grade: Int): Int = if (grade >= 4) 4 else 3

    fun positionName(i: Int): String = when (i) {
        0 -> tr("הַסִּפְרָה הָרִאשׁוֹנָה")
        1 -> tr("הַסִּפְרָה הַשְּׁנִיָּה")
        2 -> tr("הַסִּפְרָה הַשְּׁלִישִׁית")
        else -> tr("הַסִּפְרָה הָרְבִיעִית")
    }

    fun shortName(i: Int): String = when (i) {
        0 -> tr("הָרִאשׁוֹנָה")
        1 -> tr("הַשְּׁנִיָּה")
        2 -> tr("הַשְּׁלִישִׁית")
        else -> tr("הָרְבִיעִית")
    }

    /** A dealt vault: the code, and a clue list that provably pins it down. */
    data class Round(val code: List<Int>, val clues: List<VaultClue>, val needed: Int) {
        val spare: Int get() = max(0, clues.size - needed)
    }

    /** Every possible code: `n` different digits 1–9 (zero stays out — the lock's own rule). */
    fun allCodes(n: Int): List<List<Int>> {
        val out = mutableListOf<List<Int>>()
        val current = ArrayList<Int>()
        fun walk() {
            if (current.size >= n) { out += current.toList(); return }
            for (d in 1..9) if (d !in current) { current += d; walk(); current.removeAt(current.size - 1) }
        }
        walk()
        return out
    }

    /** 🎚️ How many direct reveals a band may use. */
    fun reveals(band: MiniGameBand, n: Int): Int = when (band) {
        MiniGameBand.PRE_READER, MiniGameBand.LOWER -> n
        MiniGameBand.MIDDLE -> max(1, n - 2)
        MiniGameBand.UPPER, MiniGameBand.TOP -> 0
    }

    /** 🎚️ How many clues go on the board (at least one is always slack). */
    fun clueCount(band: MiniGameBand, n: Int): Int =
        if (n == 3) (if (band >= MiniGameBand.UPPER) 4 else 5) else (if (band >= MiniGameBand.UPPER) 5 else 6)

    /** Deal a vault — proven unique before it ships. */
    fun round(grade: Int, digits: Int? = null, clues: Int? = null): Round {
        val band = MiniGameBand.of(grade)
        val count = digits ?: digits(grade)
        val universe = allCodes(count)
        val board = clues ?: clueCount(band, count)
        for (attempt in 0 until 90) {
            val code = (1..9).shuffled().take(count)
            val pool = poolKinds(code, band, count, attempt >= 55).shuffled()
            val picked = minimalSet(universe, pool, board - 1) ?: continue
            // Two clues is a lucky deal, not a round — ask for another code.
            if (picked.first.size < 3 && attempt < 80) continue
            val kinds = picked.first + sparesFrom(picked.second, picked.first, universe, max(1, board - picked.first.size))
            val round = Round(code, kinds.map { VaultClue(it) }.shuffled(), picked.first.size)
            // A round that does not pin the code down must never reach a child.
            if (!verify(round)) continue
            return round
        }
        // The floor that can never fail: every digit spelled out.
        val code = (1..9).shuffled().take(count)
        return Round(code, (0 until count).map { VaultClue(VaultClue.Kind.DigitIs(it, code[it])) }.shuffled(), count)
    }

    /** Exactly one code satisfies the whole list, and every clue is true of the round's code. */
    fun verify(round: Round): Boolean {
        if (!round.clues.all { it.holds(round.code) }) return false
        return allCodes(round.code.size).count { c -> round.clues.all { it.holds(c) } } == 1
    }

    /** Greedy cuts, a fresh kind of clue preferred; then drop every clue the others imply. */
    private fun minimalSet(universe: List<List<Int>>, pool: List<VaultClue.Kind>, limit: Int): Pair<List<VaultClue.Kind>, List<VaultClue.Kind>>? {
        var survivors = universe
        val rest = pool.toMutableList()
        var core = mutableListOf<VaultClue.Kind>()
        val used = HashSet<String>()
        while (survivors.size > 1 && core.size < limit) {
            val scored = mutableListOf<Pair<Int, Int>>()   // (index in rest, survivors left)
            for ((i, kind) in rest.withIndex()) {
                val clue = VaultClue(kind)
                val n = survivors.count { clue.holds(it) }
                if (n < survivors.size) scored += i to n
            }
            val best = scored.minOfOrNull { it.second } ?: return null
            // Within 40% of the best cut counts as "good enough" — a fresh kind wins among those.
            val slack = max(best, (best * 1.4).roundToInt())
            val close = scored.filter { it.second <= slack }
            val fresh = close.filter { rest[it.first].family !in used }
            val choice = (if (fresh.isEmpty()) close else fresh).randomOrNull() ?: return null
            val kind = rest.removeAt(choice.first)
            used += kind.family
            core += kind
            val clue = VaultClue(kind)
            survivors = survivors.filter { clue.holds(it) }
        }
        if (survivors.size != 1) return null
        var i = 0
        while (i < core.size) {
            val test = core.toMutableList().also { it.removeAt(i) }
            if (solutions(universe, test) == 1) core = test else i++
        }
        return core to rest
    }

    private fun solutions(universe: List<List<Int>>, kinds: List<VaultClue.Kind>): Int {
        val clues = kinds.map { VaultClue(it) }
        return universe.count { c -> clues.all { it.holds(c) } }
    }

    /** Spares that add something — never one a single core clue already implies. */
    private fun sparesFrom(rest: List<VaultClue.Kind>, core: List<VaultClue.Kind>, universe: List<List<Int>>, want: Int): List<VaultClue.Kind> {
        if (want <= 0) return emptyList()
        fun satisfying(kind: VaultClue.Kind): Set<Int> {
            val clue = VaultClue(kind)
            return universe.indices.filter { clue.holds(universe[it]) }.toSet()
        }
        val coreSets = core.map { satisfying(it) }
        val coreFamilies = core.map { it.family }.toSet()
        val out = mutableListOf<VaultClue.Kind>()
        val outSets = mutableListOf<Set<Int>>()
        var looked = 0
        // A kind the round has not used yet first.
        val order = rest.shuffled().sortedBy { if (it.family !in coreFamilies) 0 else 1 }
        for (kind in order) {
            if (out.size >= want || looked >= 80) break
            looked++
            val set = satisfying(kind)
            if (coreSets.any { set.containsAll(it) }) continue
            if (outSets.any { set.containsAll(it) || it.containsAll(set) }) continue
            out += kind
            outSets += set
        }
        return out
    }

    /** 🎚️ The clue kinds a band may speak in — all true of `code`. */
    private fun poolKinds(code: List<Int>, band: MiniGameBand, n: Int, generous: Boolean): List<VaultClue.Kind> {
        val out = mutableListOf<VaultClue.Kind>()
        val positions = (0 until n).toList()
        val missing = (1..9).filter { it !in code }
        for (p in positions.shuffled().take(reveals(band, n))) out += VaultClue.Kind.DigitIs(p, code[p])
        if (band <= MiniGameBand.MIDDLE || generous) {
            for (d in code.shuffled().take(2)) out += VaultClue.Kind.InCode(d)
            for (d in missing.shuffled().take(3)) out += VaultClue.Kind.NotInCode(d)
        }
        if (band >= MiniGameBand.MIDDLE) {
            for (p in positions) {
                val d = code[p]
                // ז׳–ח׳ only hears a comparison worth something: a bound next to the digit.
                val lowFloor = if (band >= MiniGameBand.TOP) max(1, d - 2) else 1
                val highCeil = if (band >= MiniGameBand.TOP) minOf(9, d + 2) else 9
                if (d > lowFloor) for (b in (lowFloor until d).shuffled().take(if (generous) 8 else 2)) out += VaultClue.Kind.Greater(p, b)
                if (d < highCeil) for (b in ((d + 1)..highCeil).shuffled().take(if (generous) 8 else 2)) out += VaultClue.Kind.Less(p, b)
                out += VaultClue.Kind.Parity(p, d % 2 == 0)
            }
            // ג׳–ד׳ sees at most two sums.
            val pairs = positions.flatMap { a -> positions.filter { it > a }.map { a to it } }
            val sumPairs = if (band == MiniGameBand.MIDDLE) pairs.shuffled().take(2) else pairs
            for ((a, b) in sumPairs) out += VaultClue.Kind.PairSum(a, b, code[a] + code[b])
            for (a in positions) for (b in positions) {
                if (b <= a || band < MiniGameBand.UPPER) continue
                out += VaultClue.Kind.PairDiff(a, b, abs(code[a] - code[b]))
                out += if (code[a] > code[b]) VaultClue.Kind.Bigger(a, b) else VaultClue.Kind.Bigger(b, a)
                if (code[b] % code[a] == 0 && code[b] / code[a] >= 2) out += VaultClue.Kind.PairTimes(a, b, code[b] / code[a])
                if (code[a] % code[b] == 0 && code[a] / code[b] >= 2) out += VaultClue.Kind.PairTimes(b, a, code[a] / code[b])
            }
        }
        if (band >= MiniGameBand.UPPER) {
            for (p in positions) for (k in listOf(3, 4)) if (code[p] % k == 0 && code[p] != k) out += VaultClue.Kind.Divisible(p, k)
            out += VaultClue.Kind.TotalSum(code.sum())
            out += VaultClue.Kind.EvenCount(code.count { it % 2 == 0 })
        }
        if (band >= MiniGameBand.TOP) out += VaultClue.Kind.PrimeCount(code.count { it in primeDigits })
        return out
    }

    /** 🔑 A lock-dial exercise whose answer is a single digit — sized to the grade. */
    fun dialQuestion(grade: Int): GameItem {
        val d = (1..9).random()
        val options = linkedSetOf(d)
        for (x in listOf(d + 1, d - 1, d + 2, d - 2, d + 3).shuffled()) if (options.size < 4 && x in 0..9) options += x
        while (options.size < 4) options += (0..9).random()
        return GameItem(MiniGameText.ltr(expression(d, grade) + " = ?"), "$d", (options - d).map { "$it" }, Topic.MATH)
    }

    /** An exercise whose answer is the digit `d`. */
    fun expression(d: Int, g: Int): String {
        fun r(a: Int, b: Int) = (a..b).random()
        fun coin() = kotlin.random.Random.nextBoolean()
        return when {
            g <= 1 -> { val a = r(0, d); "$a + ${d - a}" }
            g == 2 -> if (coin()) { val b = r(1, 9); "${d + b} − $b" } else { val a = r(0, d); "$a + ${d - a}" }
            g == 3 -> {
                val f = (2..9).filter { d % it == 0 && d / it >= 1 && it < d }.randomOrNull()
                if (f != null) "$f × ${d / f}" else { val b = r(2, 9); "${d + b} − $b" }
            }
            g == 4 || g == 5 -> {
                val k = r(2, 9)
                if (d > 0 && coin()) "${d * k} ÷ $k"
                else { val a = r(2, 5); val c = a * r(2, 5); "$c ÷ $a + ${d - c / a}".replace("+ -", "− ") }
            }
            g == 6 -> when (r(0, 2)) {
                // ו׳: brackets, percentages and a two-step quotient.
                0 -> { val a = r(2, 6); val b = r(1, 6); "($a + $b) × $d ÷ ${a + b}" }
                1 -> "${d * 25} ÷ 25"
                else -> { val k = r(3, 9); "${d * k + k} ÷ $k − 1" }
            }
            g == 7 -> if (d >= 2 && coin()) "√${d * d}" else { val a = r(2, 9); "(−$a) + ${d + a}" }
            else -> {
                val pick = r(0, 2)
                if (pick == 0 && d >= 2) "√${d * d * 4} ÷ 2"
                else if (pick == 1) { val a = r(2, 9); val b = r(2, 9); "(−$a) × (−$b) − ${a * b - d}" }
                else { val a = r(2, 6); "$a² − ${a * a - d}" }
            }
        }
    }
}

// MARK: - 🛒 The grocery

data class GroceryProduct(
    val emoji: String,
    /** The Hebrew name — read as-is in the Hebrew world. */
    val hebrew: String,
    val english: String,
    /** The first band whose reader can be handed this word (the reading worlds only). */
    val reads: MiniGameBand = MiniGameBand.PRE_READER,
)

data class GroceryShelfItem(
    val product: GroceryProduct,
    /** Agorot / cents — exact arithmetic. */
    val price: Int,
    /** "20% הֲנָחָה" — the till price is price × (100 − discount) / 100. */
    val discount: Int = 0,
    val id: Long = nextId(),
) {
    val finalPrice: Int get() = price * (100 - discount) / 100
}

data class GroceryTrip(val budget: Int, val list: List<GroceryShelfItem>, val shelf: List<GroceryShelfItem>, val decimals: Boolean)

object GroceryGen {
    fun products(): List<GroceryProduct> {
        fun p(e: String, h: String, en: String, b: MiniGameBand = MiniGameBand.PRE_READER) = GroceryProduct(e, h, en, b)
        return listOf(
            p("🥛", "חָלָב", "milk"), p("🍞", "לֶחֶם", "bread"), p("🍎", "תַּפּוּחַ", "apple"),
            p("🧀", "גְּבִינָה", "cheese"), p("🥚", "בֵּיצִים", "eggs"), p("🧃", "מִיץ", "juice"),
            p("🍚", "אֹרֶז", "rice"), p("🥕", "גֶּזֶר", "carrot"),
            p("🍌", "בָּנָנָה", "banana", MiniGameBand.MIDDLE), p("🍪", "עוּגִיּוֹת", "cookies", MiniGameBand.MIDDLE),
            p("🍅", "עַגְבָנִיָּה", "tomato", MiniGameBand.MIDDLE), p("🍝", "פַּסְטָה", "pasta", MiniGameBand.MIDDLE),
            p("🍫", "שׁוֹקוֹלָד", "chocolate", MiniGameBand.UPPER), p("🥒", "מְלָפְפוֹן", "cucumber", MiniGameBand.UPPER),
            p("🍉", "אֲבַטִּיחַ", "watermelon", MiniGameBand.UPPER), p("🍦", "גְּלִידָה", "ice cream", MiniGameBand.UPPER),
        )
    }

    /** In the reading worlds the pool opens up band by band (always wide enough for a shelf). */
    fun products(reading: Boolean, grade: Int): List<GroceryProduct> {
        if (!reading) return products()
        val band = MiniGameBand.of(grade)
        val fit = products().filter { it.reads <= band }
        return if (fit.size >= 6) fit else products()
    }

    /** The name on the shelf / list in the child's own language. */
    fun localName(p: GroceryProduct): String = when (p.english) {
        "milk" -> tr("חָלָב"); "bread" -> tr("לֶחֶם"); "apple" -> tr("תַּפּוּחַ"); "banana" -> tr("בָּנָנָה")
        "cheese" -> tr("גְּבִינָה"); "eggs" -> tr("בֵּיצִים"); "chocolate" -> tr("שׁוֹקוֹלָד"); "cookies" -> tr("עוּגִיּוֹת")
        "juice" -> tr("מִיץ"); "cucumber" -> tr("מְלָפְפוֹן"); "tomato" -> tr("עַגְבָנִיָּה"); "watermelon" -> tr("אֲבַטִּיחַ")
        "ice cream" -> tr("גְּלִידָה"); "pasta" -> tr("פַּסְטָה"); "rice" -> tr("אֹרֶז")
        else -> tr("גֶּזֶר")
    }

    /** "4.50 ₪" / "$4.50" / "7 ₪" (Money.answerPrefix/Suffix). */
    fun money(cents: Int): String {
        val whole = cents / 100; val frac = abs(cents % 100)
        val n = if (frac == 0) "$whole" else String.format(Locale.US, "%d.%02d", whole, frac)
        return (if (GameEnv.isIsraeli) "" else "$") + n + (if (GameEnv.isIsraeli) " ₪" else "")
    }

    /** A typed amount ("4.5", "4.50", "12") in cents, or null. */
    fun cents(typed: String): Int? {
        if (typed.isEmpty()) return null
        val parts = typed.split(".")
        if (parts.size > 2) return null
        val whole = (if (parts[0].isEmpty()) "0" else parts[0]).toIntOrNull() ?: return null
        if (parts.size != 2) return whole * 100
        val f = parts[1]
        if (f.length > 2 || (f.isNotEmpty() && f.toIntOrNull() == null)) return null
        val fracCents = if (f.isEmpty()) 0 else if (f.length == 1) f.toInt() * 10 else f.toInt()
        return whole * 100 + fracCents
    }

    /** One trip, sized to the grade (the shelf stays six wide; the arithmetic grows). */
    fun trip(grade: Int, reading: Boolean = false): GroceryTrip {
        val g = grade
        fun r(a: Int, b: Int) = (a..b).random()
        val all = products(reading, g).shuffled()
        val band = MiniGameBand.of(g)
        val listCount = if (g <= 1) 2 else if (band >= MiniGameBand.UPPER) 4 else 3
        val decimals = g >= 4
        fun price(): Int = when {
            g <= 1 -> r(1, 5) * 100
            g == 2 -> r(2, 12) * 100
            g == 3 -> r(3, 25) * 100
            g == 4 || g == 5 -> r(4, 30) * 100 + if (kotlin.random.Random.nextBoolean()) 50 else 0
            else -> r(4, 40) * 100 + listOf(0, 20, 30, 50, 70, 90).random()
        }
        val list = all.take(listCount).map { GroceryShelfItem(it, price()) }.toMutableList()
        // ה׳+: an item is on sale — the till price is the child's to work out.
        fun markDown(idx: Int, tough: Boolean) {
            val (base, off) = if (tough) listOf(
                r(1, 4) * 1000 to listOf(15, 35).random(), r(2, 8) * 500 to 30, r(2, 6) * 1000 to 45,
            ).random() else listOf(
                r(1, 4) * 1000 to listOf(10, 20).random(), listOf(8, 12, 16, 20).random() * 100 to 25, r(2, 15) * 200 to 50,
            ).random()
            list[idx] = GroceryShelfItem(list[idx].product, base, off)
        }
        if (band >= MiniGameBand.UPPER) {
            val order = list.indices.shuffled()
            order.firstOrNull()?.let { markDown(it, band >= MiniGameBand.TOP) }
            // ז׳–ח׳: a second sale.
            if (band >= MiniGameBand.TOP && order.size > 1) markDown(order[1], true)
        }
        val extras = all.drop(listCount).take(max(2, 6 - listCount)).map { GroceryShelfItem(it, price()) }
        val total = list.sumOf { it.finalPrice }
        // A budget the list fits in, with change to work out — never exact.
        val steps = when {
            g <= 1 -> listOf(1000, 2000)
            g == 2 -> listOf(2000, 3000, 5000)
            g == 3 -> listOf(5000, 10000)
            g == 4 || g == 5 -> listOf(5000, 10000, 20000)
            else -> listOf(10000, 15000, 20000, 25000, 30000)
        }
        val budget = steps.firstOrNull { it > total } ?: ((total / 1000 + 1) * 1000)
        return GroceryTrip(budget, list, (list + extras).shuffled(), decimals)
    }
}

// MARK: - ⚖️ The balance

/** One balance: what each pan holds, how heavy each side is for a value of the missing piece. */
class BalancePuzzle(
    val left: String,
    val right: String,
    /** Shown above the pans — the equation's letter, or the world's question. */
    val question: String? = null,
    val answer: String,
    val options: List<String>,
    /** Weights for a value of "?" (fractions and decimals too). */
    val weigh: (Double) -> Pair<Double, Double>,
    /** The value each option string stands for. */
    val value: (String) -> Double?,
    /** Type the answer instead of picking it (older grades, whole numbers). */
    val numberPad: Boolean = false,
    val topic: Topic,
)

object BalanceGen {
    const val ROUND_COUNT = 5

    private fun intOptions(x: Int, allowNegative: Boolean): List<String> {
        val set = linkedSetOf(x)
        for (d in listOf(1, -1, 2, -2, 3, 5, -3, 10).shuffled()) {
            if (set.size >= 4) break
            val c = x + d
            if (allowNegative || c >= 0) set += c
        }
        return set.map { MathFacts.show(it) }.shuffled()
    }

    private fun intValue(s: String): Double? = GameContent.number(s)?.toDouble()

    private fun fmt1(d: Double): String =
        if (abs(d - Math.rint(d)) < 0.001) String.format(Locale.US, "%.0f", d) else String.format(Locale.US, "%.1f", d)

    /** A computed balance, sized to the grade: א׳ "7 + ? | 10" … ח׳ "2x − 5 | x + 3". */
    fun make(grade: Int, topic: Topic): BalancePuzzle {
        val g = grade
        val swap = kotlin.random.Random.nextBoolean()
        fun r(a: Int, b: Int) = (a..b).random()
        fun coin() = kotlin.random.Random.nextBoolean()
        fun puzzle(l: String, rr: String, x: Int, question: String? = null, negative: Boolean = false,
                   pad: Boolean = false, weigh: (Double) -> Pair<Double, Double>): BalancePuzzle {
            // Now and then the missing piece sits in the right pan.
            val (pl, pr) = if (swap) rr to l else l to rr
            return BalancePuzzle(pl, pr, question, MathFacts.show(x), intOptions(x, negative),
                { v -> val w = weigh(v); if (swap) w.second to w.first else w }, ::intValue, pad, topic)
        }
        when {
            g <= 1 -> { val total = r(5, 10); val a = r(1, total - 1); val x = total - a
                return puzzle("$a + ?", "$total", x) { v -> (a + v) to total.toDouble() } }
            g == 2 -> {
                val c = r(3, 15); val d = r(2, 15); val a = r(1, c + d - 1); val x = c + d - a
                if (coin()) return puzzle("$a + ?", "$c + $d", x) { v -> (a + v) to (c + d).toDouble() }
                val big = r(12, 30); val y = r(2, big - 2)
                return puzzle("$big − ?", "${big - y}", y) { v -> (big - v) to (big - y).toDouble() }
            }
            g == 3 -> {
                val a = r(2, 9); val x = r(2, 10)
                if (coin()) return puzzle("$a × ?", "${a * x}", x) { v -> (a * v) to (a * x).toDouble() }
                val c = r(2, 6); val d = r(2, 6); val b = r(1, c * d - 1); val y = c * d - b
                return puzzle("? + $b", "$c × $d", y) { v -> (v + b) to (c * d).toDouble() }
            }
            g == 4 -> {
                val a = r(3, 9); val x = r(3, 12); val extra = r(2, 20)
                if (coin()) return puzzle("? × $a", "${a * x + extra} − $extra", x) { v -> (v * a) to (a * x).toDouble() }
                val k = r(2, 6)
                return puzzle("? × $a", "${a * x * k} ÷ $k", x) { v -> (v * a) to (a * x).toDouble() }
            }
            g == 5 || g == 6 -> when (r(0, if (g >= 6) 3 else 2)) {
                3 -> { // ו׳: the unknown is divided, and both pans carry work.
                    val a = listOf(2, 3, 4, 5, 6).random(); val x = a * r(2, 9); val b = r(2, 9); val c = r(2, 9)
                    return puzzle("? ÷ $a + $b", "${b + x / a + c} − $c", x, pad = true) { v -> (v / a + b) to (b + x / a).toDouble() }
                }
                0 -> { val a = r(2, 6); val b = r(1, 9); val x = r(2, 9)
                    return puzzle("$a × ? + $b", "${a * x + b}", x, pad = g >= 6) { v -> (a * v + b) to (a * x + b).toDouble() } }
                1 -> { // Fractions to one whole.
                    val pairs = listOf(Triple("½", 0.5, "½"), Triple("¼", 0.25, "¾"), Triple("¾", 0.75, "¼"), Triple("⅓", 1.0 / 3, "⅔"))
                    val (shown, sv, missing) = pairs.random()
                    val names = listOf("½" to 0.5, "¼" to 0.25, "¾" to 0.75, "⅓" to 1.0 / 3, "⅔" to 2.0 / 3)
                    val opts = mutableListOf(missing)
                    for (n in names.shuffled()) if (opts.size < 4 && n.first !in opts) opts += n.first
                    val lookup = names.toMap()
                    val (pl, pr) = if (swap) "1" to "$shown + ?" else "$shown + ?" to "1"
                    return BalancePuzzle(pl, pr, null, missing, opts.shuffled(),
                        { v -> if (swap) 1.0 to (sv + v) else (sv + v) to 1.0 }, { lookup[it] }, false, topic)
                }
                else -> { // Decimals.
                    val a = r(1, 9) / 10.0 + r(0, 2)
                    val total = r(a.toInt() + 1, a.toInt() + 3).toDouble()
                    val x = total - a
                    val opts = linkedSetOf(fmt1(x))
                    for (d in listOf(0.1, -0.1, 1.0, -1.0, 0.5).shuffled()) if (opts.size < 4 && x + d > 0) opts += fmt1(x + d)
                    val (pl, pr) = if (swap) fmt1(total) to "${fmt1(a)} + ?" else "${fmt1(a)} + ?" to fmt1(total)
                    return BalancePuzzle(pl, pr, null, fmt1(x), opts.shuffled(),
                        { v -> if (swap) total to (a + v) else (a + v) to total }, { it.toDoubleOrNull() }, false, topic)
                }
            }
            g == 7 -> {
                // ז׳: a one- or two-step equation in x, and signed totals.
                val q = tr("מָה הוּא x?")
                return when (r(0, 2)) {
                    0 -> { val a = r(2, 6); val b = r(1, 12); val x = r(1, 9)
                        puzzle("${a}x + $b", "${a * x + b}", x, q, pad = true) { v -> (a * v + b) to (a * x + b).toDouble() } }
                    1 -> { val a = r(2, 5); val b = r(1, 9); val x = r(2, 10)
                        val c = (a - 1) * x - b   // a·x − b = x + c
                        val right = if (c >= 0) "x + $c" else "x − ${-c}"
                        puzzle("${a}x − $b", right, x, q, pad = true) { v -> (a * v - b) to (v + c) } }
                    else -> { val b = r(3, 12); val total = r(-8, 2); val x = total - b
                        puzzle("x + $b", MathFacts.show(total), x, q, negative = true) { v -> (v + b) to total.toDouble() } }
                }
            }
            else -> {
                // ח׳: brackets, x on both sides, and a square.
                val q = tr("מָה הוּא x?")
                return when (r(0, 2)) {
                    0 -> { val a = r(2, 6); val b = r(1, 9); val x = r(1, 9)
                        puzzle("$a(x + $b)", "${a * (x + b)}", x, q, pad = true) { v -> (a * (v + b)) to (a * (x + b)).toDouble() } }
                    1 -> { val a = r(3, 7); val c = r(1, a - 1); val x = r(2, 9); val b = r(-9, -1)
                        val d = (a - c) * x + b
                        val left = "${a}x ${if (b < 0) "− ${-b}" else "+ $b"}"
                        val right = "${c}x ${if (d < 0) "− ${-d}" else "+ $d"}"
                        puzzle(left, right, x, q, negative = true, pad = true) { v -> (a * v + b) to (c * v + d) } }
                    else -> { val x = r(2, 12)
                        puzzle("x²", "${x * x}", x, q, pad = true) { v -> (v * v) to (x * x).toDouble() } }
                }
            }
        }
    }

    /** The beam's tilt in degrees, clockwise (the heavier pan goes down): 0 when level, ±5…14 otherwise. */
    fun tilt(p: BalancePuzzle, trial: String?): Double {
        val v = trial?.let { p.value(it) } ?: 0.0
        val (l, r) = p.weigh(v)
        val diff = r - l
        if (abs(diff) <= 0.0001) return 0.0
        val rel = abs(diff) / max(1.0, max(abs(l), abs(r)))
        return (if (diff > 0) 1.0 else -1.0) * minOf(14.0, 5 + 12 * rel)
    }

    /** A world question with a number for an answer: the beam says whether a guess is too light or too heavy. */
    fun compare(item: GameItem, grade: Int = 1): BalancePuzzle? {
        val x = GameContent.number(item.answer) ?: return null
        var options = item.shuffledOptions()
        // ה׳+: keep only the options closest to the answer, so the beam has to be read.
        if (MiniGameBand.of(grade) >= MiniGameBand.UPPER && options.size > 3) {
            options = (listOf(item.answer) + item.distractors.sortedBy { d ->
                GameContent.number(d)?.let { abs(it - x) } ?: Int.MAX_VALUE
            }.take(2)).shuffled()
        }
        return BalancePuzzle("?", "🎁", item.prompt, item.answer, options,
            { v -> v to x.toDouble() }, ::intValue, false, item.topic)
    }
}
