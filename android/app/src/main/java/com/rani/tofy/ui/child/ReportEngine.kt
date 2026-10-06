package com.rani.tofy.ui.child

import com.rani.tofy.data.DailyStat
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import java.text.DateFormatSymbols
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

/** ChildReport.swift SkillCatalog — keys are stable ids written into dailyStats. */
private val skillKeys = mapOf(
    "addSub" to "חִבּוּר וְחִסּוּר", "completeTen" to "הַשְׁלָמָה לְעֶשֶׂר", "compare" to "הַשְׁוָאַת מִסְפָּרִים",
    "evenOdd" to "זוּגִי וְאִי־זוּגִי", "mul" to "כֶּפֶל", "div" to "חִלּוּק", "mixedOps" to "פְּעֻלּוֹת מְשֻׁלָּבוֹת",
    "wordProblem" to "בְּעָיוֹת מִלּוּלִיּוֹת", "fractions" to "שְׁבָרִים פְּשׁוּטִים", "divRemainder" to "חִלּוּק עִם שְׁאֵרִית",
    "geometry" to "הֶקֵּף וְשֶׁטַח", "decimals" to "מִסְפָּרִים עֶשְׂרוֹנִיִּים", "average" to "מְמֻצָּע", "percent" to "אֲחוּזִים",
    "negatives" to "מִסְפָּרִים מְכֻוָּנִים", "expressions" to "בִּטּוּיִים אַלְגֶּבְּרִיִּים", "equations" to "מִשְׁוָאוֹת",
    "powers" to "חֶזְקוֹת", "roots" to "שׁוֹרָשִׁים", "angles" to "זָוִיּוֹת", "proportion" to "יַחַס וּפְרוֹפּוֹרְצְיָה",
    "pythagoras" to "מִשְׁפַּט פִּיתָגוֹרַס", "linearFunction" to "פוּנְקְצִיָּה קַוִּית", "volume" to "נֶפַח",
    "probability" to "הִסְתַּבְּרוּת", "circle" to "מַעְגָּל",
)

fun skillName(key: String): String = skillKeys[key]?.let { tr(it) } ?: key

enum class ReportPeriod(val days: Int) {
    TODAY(1), WEEK(7), MONTH(30);
    val title: String get() = when (this) { TODAY -> tr("הַיּוֹם"); WEEK -> tr("הַשָּׁבוּעַ"); MONTH -> tr("הַחֹדֶשׁ") }
}

data class TopicReport(val topic: Topic, val answered: Int, val correct: Int) {
    val wrong get() = answered - correct
    val accuracy get() = if (answered > 0) correct.toDouble() / answered else 0.0
    enum class Verdict { STRONG, OK, WEAK, TOO_FEW }
    /** Generous toward the child: under 6 answers we say nothing. */
    val verdict: Verdict get() = when {
        answered < 6 -> Verdict.TOO_FEW
        accuracy >= 0.80 -> Verdict.STRONG
        accuracy >= 0.60 -> Verdict.OK
        else -> Verdict.WEAK
    }
}

data class SkillReport(val key: String, val answered: Int, val correct: Int) {
    val name get() = skillName(key)
    val accuracy get() = if (answered > 0) correct.toDouble() / answered else 0.0
}

data class TopicDelta(val topic: Topic, val deltaPoints: Double)
data class DailyInsight(val emoji: String, val title: String, val body: String, val recommendation: String?)
data class Named(val name: String, val detail: String)

data class PeriodSummary(
    val questions: Int = 0, val correct: Int = 0, val minutesEarned: Int = 0, val minutesUsed: Int = 0,
    val voluntaryAnswers: Int = 0, val activeDays: Int = 0,
) {
    val accuracy get() = if (questions > 0) correct.toDouble() / questions else 0.0
    val voluntaryLearningRate get() = if (questions > 0) voluntaryAnswers.toDouble() / questions else 0.0
}

data class DayPoint(val date: String, val questions: Int, val accuracy: Double, val earned: Int, val used: Int) {
    /** Short weekday; Hebrew spells Saturday out, other languages take the calendar's own. */
    val weekday: String get() {
        val d = parseKey(date) ?: return ""
        val i = Calendar.getInstance().apply { time = d }.get(Calendar.DAY_OF_WEEK)  // 1 = Sunday
        if (I18n.language != AppLanguage.HE) return DateFormatSymbols(Locale(I18n.language.code)).shortWeekdays[i]
        return listOf("א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "שַׁבָּת")[i - 1]
    }
}

fun dayKey(c: Calendar): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(c.time)
private fun parseKey(k: String) = runCatching { SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(k) }.getOrNull()
private fun startOfToday() = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
fun pct(x: Double) = "${(x * 100).roundToInt()}%"

/**
 * InsightsEngine.swift + the ChildReport.swift extension — pure functions over
 * the child's dailyStats, computed on the parent's device (no third party).
 */
class ReportEngine(history: List<DailyStat>) {
    private val history = history.sortedBy { it.date }

    private fun summarize(stats: List<DailyStat>) = stats.fold(PeriodSummary()) { s, d ->
        s.copy(questions = s.questions + d.questionsAnswered, correct = s.correct + d.correct,
            minutesEarned = s.minutesEarned + d.minutesEarned, minutesUsed = s.minutesUsed + d.minutesUsed,
            voluntaryAnswers = s.voluntaryAnswers + d.voluntaryAnswers,
            activeDays = s.activeDays + if (d.questionsAnswered > 0) 1 else 0)
    }

    /** InsightsEngine.daysInRange: date within [today-from, today-to] (inclusive of the upper day). */
    private fun daysInRange(from: Int, to: Int): List<DailyStat> {
        val lower = startOfToday().apply { add(Calendar.DAY_OF_YEAR, -from) }.time
        val upper = startOfToday().apply { add(Calendar.DAY_OF_YEAR, -to) }.time.time + 1000
        return history.filter { s -> parseKey(s.date)?.let { it >= lower && it.time < upper } == true }
    }

    fun summary(p: ReportPeriod): PeriodSummary = when (p) {
        ReportPeriod.TODAY -> summarize(history.filter { it.date == dayKey(startOfToday()) })
        ReportPeriod.WEEK -> summarize(daysInRange(7, 0))
        ReportPeriod.MONTH -> summarize(daysInRange(30, 0))
    }

    private fun stats(p: ReportPeriod, offset: Int = 0): List<DailyStat> {
        val end = startOfToday().apply { add(Calendar.DAY_OF_YEAR, -(p.days * offset)) }
        val keys = (0 until p.days).map { i -> dayKey((end.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -(p.days - 1) + i) }) }.toSet()
        return history.filter { it.date in keys }
    }

    /** Every topic touched in the period, best first. */
    fun topicReports(p: ReportPeriod, offset: Int = 0): List<TopicReport> {
        val ans = mutableMapOf<Topic, Int>(); val cor = mutableMapOf<Topic, Int>()
        for (day in stats(p, offset)) for ((raw, t) in day.perTopic) {
            val topic = Topic.of(raw) ?: continue
            ans[topic] = (ans[topic] ?: 0) + t.answered; cor[topic] = (cor[topic] ?: 0) + t.correct
        }
        return ans.keys.map { TopicReport(it, ans[it]!!, cor[it] ?: 0) }
            .sortedWith(compareByDescending<TopicReport> { it.accuracy }.thenByDescending { it.answered })
    }

    /** Skills inside a topic, weakest first (≥ 3 answers). */
    fun skillReports(t: Topic, p: ReportPeriod): List<SkillReport> {
        val ans = mutableMapOf<String, Int>(); val cor = mutableMapOf<String, Int>()
        for (day in stats(p)) {
            val skills = day.perTopic[t.raw]?.perSkill ?: continue
            for ((k, s) in skills) { ans[k] = (ans[k] ?: 0) + s.answered; cor[k] = (cor[k] ?: 0) + s.correct }
        }
        return ans.keys.map { SkillReport(it, ans[it]!!, cor[it] ?: 0) }.filter { it.answered >= 3 }.sortedBy { it.accuracy }
    }

    fun topicDeltas(p: ReportPeriod): List<TopicDelta> {
        val before = topicReports(p, 1).associateBy { it.topic }
        return topicReports(p).mapNotNull { cur ->
            val prev = before[cur.topic] ?: return@mapNotNull null
            if (cur.answered < 6 || prev.answered < 6) null else TopicDelta(cur.topic, (cur.accuracy - prev.accuracy) * 100)
        }.sortedByDescending { it.deltaPoints }
    }

    fun overallDelta(p: ReportPeriod): Double? {
        val cur = summarize(stats(p)); val prev = summarize(stats(p, 1))
        if (cur.questions < 10 || prev.questions < 10) return null
        return (cur.accuracy - prev.accuracy) * 100
    }

    fun mastered(p: ReportPeriod): List<Named> {
        val out = mutableListOf<Pair<Named, Double>>()
        for (t in topicReports(p).filter { it.answered >= 8 }) {
            val skills = skillReports(t.topic, p)
            for (s in skills) if (s.answered >= 5 && s.accuracy >= 0.85) out += Named(s.name, pct(s.accuracy)) to s.accuracy
            if (skills.isEmpty() && t.accuracy >= 0.85) out += Named(t.topic.displayName, tr("%@ · %lld שְׁאֵלוֹת", pct(t.accuracy), t.answered)) to t.accuracy
        }
        return out.sortedByDescending { it.second }.take(4).map { it.first }
    }

    fun toPractice(p: ReportPeriod): List<Named> {
        val out = mutableListOf<Pair<Named, Double>>()
        for (t in topicReports(p).filter { it.answered >= 6 }) {
            val skills = skillReports(t.topic, p)
            for (s in skills.take(3)) if (s.answered >= 4 && s.accuracy < 0.7) out += Named(s.name, tr("%@ בְּ%@", pct(s.accuracy), t.topic.displayName)) to s.accuracy
            if (skills.isEmpty() && t.accuracy < 0.7) out += Named(t.topic.displayName, tr("%@ · %lld טְעֻיּוֹת", pct(t.accuracy), t.wrong)) to t.accuracy
        }
        return out.sortedBy { it.second }.take(4).map { it.first }
    }

    /** One point per calendar day, oldest first, empty days as zeros. */
    fun dayPoints(days: Int): List<DayPoint> {
        val byKey = history.associateBy { it.date }
        return (days - 1 downTo 0).map { back ->
            val key = dayKey(startOfToday().apply { add(Calendar.DAY_OF_YEAR, -back) })
            val d = byKey[key]; val q = d?.questionsAnswered ?: 0
            DayPoint(key, q, if (q > 0) d!!.correct.toDouble() / q else 0.0, d?.minutesEarned ?: 0, d?.minutesUsed ?: 0)
        }
    }

    /** The one most useful thing to tell the parent — rules in priority order. */
    /** [minutesToday]: for TODAY, the same live count the "דקות" tile shows — history holds only answer minutes. */
    fun dailyInsight(name: String, isGirl: Boolean, p: ReportPeriod, minutesToday: Int? = null): DailyInsight? {
        fun g(m: String, f: String) = if (isGirl) f else m
        val topics = topicReports(p).filter { it.answered >= 8 }
        val deltas = topicDeltas(p)
        val best = topics.firstOrNull(); val worst = topics.lastOrNull()
        if (best != null && worst != null && best.topic != worst.topic && best.accuracy - worst.accuracy >= 0.30 && worst.accuracy < 0.6) {
            val weakSkill = skillReports(worst.topic, p).firstOrNull()
            val focus = weakSkill?.let { tr(" הַפַּעַר נִפְתָּח בְּעִקָּר בְּ%@.", it.name) } ?: ""
            return DailyInsight("💡", tr("פַּעַר גָּדוֹל בֵּין נוֹשְׂאִים"),
                tr("%@ %@ עַל %@ בְּ-%@ לְעֻמַּת %@ בְּ%@ — הַפַּעַר הַגָּדוֹל בְּיוֹתֵר בֵּין הַנּוֹשְׂאִים %@.%@",
                    name, g(tr("עוֹנֶה"), tr("עוֹנָה")), worst.topic.displayName, pct(worst.accuracy), pct(best.accuracy),
                    best.topic.displayName, g(tr("שֶׁלּוֹ"), tr("שֶׁלָּהּ")), focus),
                tr("10 דַּקּוֹת שֶׁל %@ בְּיַחַד, פַּעַם־פַּעֲמַיִם בַּשָּׁבוּעַ. %@ כְּבָר %@ בְּ%@ — יֵשׁ עַל מָה לִבְנוֹת.",
                    weakSkill?.name ?: worst.topic.displayName, g(tr("הוּא"), tr("הִיא")), g(tr("חָזָק"), tr("חֲזָקָה")), best.topic.displayName))
        }
        deltas.firstOrNull()?.takeIf { it.deltaPoints >= 10 }?.let { up ->
            return DailyInsight("🌟", tr("%@ הוֹפֶכֶת לְחוֹזְקָה", up.topic.displayName),
                tr("%@ %@ בְּ%@ בְּ-%lld נְקֻדּוֹת לְעֻמַּת הַתְּקוּפָה הַקּוֹדֶמֶת.", name, g(tr("הִשְׁתַּפֵּר"), tr("הִשְׁתַּפְּרָה")), up.topic.displayName, up.deltaPoints.roundToInt()),
                tr("שָׁוֶה לְצַיֵּן אֶת זֶה בְּקוֹל — יְלָדִים מַמְשִׁיכִים לְהִשְׁתַּפֵּר בְּמַה שֶׁמְּשַׁבְּחִים אוֹתָם עָלָיו."))
        }
        deltas.lastOrNull()?.takeIf { it.deltaPoints <= -8 }?.let { down ->
            return DailyInsight("🔎", tr("יְרִידָה קַלָּה בְּ%@", down.topic.displayName),
                tr("הַדִּיּוּק שֶׁל %@ בְּ%@ יָרַד בְּ-%lld נְקֻדּוֹת לְעֻמַּת הַתְּקוּפָה הַקּוֹדֶמֶת. לִפְעָמִים זֶה פָּשׁוּט חֹמֶר חָדָשׁ שֶׁנִּכְנַס.", name, down.topic.displayName, abs(down.deltaPoints).roundToInt()),
                tr("%@ מָה הָיָה קָשֶׁה הַשָּׁבוּעַ — לָרוֹב זוֹ שְׁאֵלָה אַחַת שֶׁפּוֹתַחַת הַכֹּל.", g(tr("שַׁאֲלוּ אוֹתוֹ"), tr("שַׁאֲלוּ אוֹתָהּ"))))
        }
        val s = summary(p)
        if (s.activeDays >= 5 && p != ReportPeriod.TODAY) {
            return DailyInsight("🔥", tr("%lld יָמִים שֶׁל לְמִידָה", s.activeDays),
                tr("%@ %@ בְּ-%lld יָמִים %@, %lld שְׁאֵלוֹת בְּסַךְ הַכֹּל בְּ-%@ הַצְלָחָה.", name, g(tr("לָמַד"), tr("לָמְדָה")), s.activeDays,
                    if (p == ReportPeriod.WEEK) tr("הַשָּׁבוּעַ") else tr("הַחֹדֶשׁ"), s.questions, pct(s.accuracy)),
                tr("הָרְצִיפוּת שָׁוָה יוֹתֵר מֵהַכַּמּוּת — גַּם 10 דַּקּוֹת בְּיוֹם שׁוֹמְרוֹת עָלֶיהָ."))
        }
        if (s.voluntaryLearningRate >= 0.3 && s.questions >= 20) {
            return DailyInsight("💛", tr("%@ גַּם בְּלִי פְּרָס", g(tr("לוֹמֵד"), tr("לוֹמֶדֶת"))),
                tr("%lld%% מֵהַתְּשׁוּבוֹת שֶׁל %@ נִתְּנוּ אַחֲרֵי שֶׁהַדַּקּוֹת שֶׁל הַיּוֹם כְּבָר נִגְמְרוּ — כְּלוֹמַר סְתָם כִּי %@.",
                    (s.voluntaryLearningRate * 100).roundToInt(), name, g(tr("רָצָה"), tr("רָצְתָה"))), null)
        }
        if (s.questions <= 0) return null
        val mins = (if (p == ReportPeriod.TODAY) minutesToday else null) ?: s.minutesEarned
        return DailyInsight("📚", tr("%lld שְׁאֵלוֹת %@", s.questions, p.title.lowercase()),
            tr("%@ הַצְלָחָה", pct(s.accuracy)) + (if (mins > 0) tr(" · %lld דַּקּוֹת שֶׁ%@", mins, g(tr("הִרְוִיחַ"), tr("הִרְוִיחָה"))) else ""),
            null)
    }
}
