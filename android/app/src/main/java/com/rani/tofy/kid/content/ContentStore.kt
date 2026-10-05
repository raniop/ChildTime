package com.rani.tofy.kid.content

import android.content.Context
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import kotlinx.serialization.json.Json
import java.util.concurrent.ConcurrentHashMap

/**
 * Tiny key–value seam over SharedPreferences (UserDefaults on iOS), so the
 * selection logic runs in plain JVM unit tests with [MemoryContentPrefs].
 */
interface ContentPrefs {
    fun getString(key: String): String?
    fun putString(key: String, value: String?)
}

class SharedContentPrefs(context: Context, name: String = "tofy.content") : ContentPrefs {
    private val prefs = context.applicationContext.getSharedPreferences(name, Context.MODE_PRIVATE)
    override fun getString(key: String): String? = prefs.getString(key, null)
    override fun putString(key: String, value: String?) {
        prefs.edit().apply { if (value == null) remove(key) else putString(key, value) }.apply()
    }
}

class MemoryContentPrefs : ContentPrefs {
    private val map = ConcurrentHashMap<String, String>()
    override fun getString(key: String): String? = map[key]
    override fun putString(key: String, value: String?) { if (value == null) map.remove(key) else map[key] = value }
}

internal val contentJson = Json { ignoreUnknownKeys = true; explicitNulls = false }

/**
 * The built-in content exported from the iOS sources by
 * tools/export-android-content.py (assets/content/…). Parsed lazily per
 * language and kept — the whole Hebrew bank is ~1 MB of JSON, so the first
 * call for a language should happen off the main thread
 * ([QuestionSource.preload]).
 */
object ContentAssets {
    @Volatile private var loader: ((String) -> String?)? = null

    /** Production: read from the APK's assets/content/. */
    fun install(context: Context) {
        val app = context.applicationContext
        install { path -> runCatching { app.assets.open("content/$path").bufferedReader().use { it.readText() } }.getOrNull() }
    }

    /** Tests: any loader (e.g. straight from src/main/assets/content). */
    fun install(loader: (String) -> String?) {
        this.loader = loader
        banks.clear(); passages.clear(); bonusPool = null; tierIndexCache = null
        ContentCache.invalidate()
    }

    private val banks = ConcurrentHashMap<AppLanguage, Map<String, List<BankQuestion>>>()
    private val passages = ConcurrentHashMap<AppLanguage, List<ReadingPassage>>()
    @Volatile private var bonusPool: Map<String, List<BankQuestion>>? = null
    @Volatile private var tierIndexCache: Map<String, Difficulty>? = null

    private fun read(path: String): String? = loader?.invoke(path)

    /** topic raw → built-in items, as the language's own catalog ships them. */
    fun banks(lang: AppLanguage): Map<String, List<BankQuestion>> = banks.getOrPut(lang) {
        val text = read("banks/${lang.code}.json") ?: return@getOrPut emptyMap()
        contentJson.decodeFromString<Map<String, List<BankItem>>>(text)
            .mapValues { (_, items) -> items.map { it.toBankQuestion() } }
    }

    fun passages(lang: AppLanguage): List<ReadingPassage> = passages.getOrPut(lang) {
        val text = read("reading/${lang.code}.json") ?: return@getOrPut emptyList()
        contentJson.decodeFromString<List<PassageItem>>(text).map { p ->
            ReadingPassage(p.id, Difficulty.of(p.tier) ?: Difficulty.MEDIUM, p.gradeLo, p.gradeHi, p.text,
                p.questions.map { it.toBankQuestion() })
        }
    }

    /** 💫 BonusQuestionBank — Hebrew only, like iOS. */
    fun bonus(): Map<String, List<BankQuestion>> = bonusPool ?: run {
        val text = read("bonus/he.json")
        val parsed = if (text == null) emptyMap()
        else contentJson.decodeFromString<Map<String, List<BankItem>>>(text).mapValues { (_, v) -> v.map { it.toBankQuestion() } }
        bonusPool = parsed
        parsed
    }

    /**
     * Stand-in for QuestionDifficultyTags.map when a CLOUD item arrives without
     * a tier: the side-map only ever graded the Hebrew built-ins, and those
     * carry their resolved tier here, keyed the same way ("prompt|answer").
     */
    fun tierIndex(): Map<String, Difficulty> = tierIndexCache ?: run {
        val idx = HashMap<String, Difficulty>()
        banks(AppLanguage.HE).values.forEach { list -> list.forEach { idx[it.key] = it.difficulty } }
        tierIndexCache = idx
        idx
    }
}

internal fun BankItem.toBankQuestion(): BankQuestion = BankQuestion(
    prompt = prompt, correctAnswer = correctAnswer, distractors = distractors,
    difficulty = Difficulty.of(tier) ?: Difficulty.MEDIUM, gradeLo = gradeLo, gradeHi = gradeHi, skill = skill,
)

/**
 * 🧊 ContentCache (ContentLanguage.swift): an assembled bank and a world's
 * availability, worked out once per "topic|language". RemoteQuestionBank
 * clears it after a sync that brought something new. `build` runs outside the
 * lock on purpose (bank ↔ availability call each other).
 */
object ContentCache {
    private class Box(val value: List<BankQuestion>?)
    private val banks = ConcurrentHashMap<String, Box>()
    private val availability = ConcurrentHashMap<String, Boolean>()

    fun bank(key: String, build: () -> List<BankQuestion>?): List<BankQuestion>? {
        banks[key]?.let { return it.value }
        val v = build()
        banks[key] = Box(v)
        return v
    }

    fun available(key: String, build: () -> Boolean): Boolean {
        availability[key]?.let { return it }
        val v = build()
        availability[key] = v
        return v
    }

    fun invalidate() { banks.clear(); availability.clear() }
}

/** QuestionBanks.swift — built-in banks per language, with the cloud merged on top. */
object QuestionBanks {
    /**
     * The Hebrew built-in bank (QuestionBanks.builtInBank). null for the topics
     * that have no bank at all — math is generated, reading is passage-based.
     */
    fun builtInBank(topic: Topic): List<BankQuestion>? = when (topic) {
        Topic.MATH, Topic.READING -> null
        else -> ContentAssets.banks(AppLanguage.HE)[topic.raw] ?: emptyList()
    }

    fun bank(topic: Topic, lang: AppLanguage): List<BankQuestion>? =
        ContentCache.bank("${topic.raw}|${lang.code}") { assemble(topic, lang) }

    /**
     * QuestionBanks.assemble: the language's own built-ins (the Hebrew world is
     * served IN HEBREW to Russian/Arabic speakers — Israeli school), then the
     * approved cloud items for that language, de-duplicated by prompt|answer.
     */
    private fun assemble(topic: Topic, lang: AppLanguage): List<BankQuestion>? {
        val hebrewBuiltIn = builtInBank(topic) ?: return null
        val builtIn = when {
            lang == AppLanguage.HE -> hebrewBuiltIn
            topic == Topic.HEBREW && (lang == AppLanguage.RU || lang == AppLanguage.AR) -> hebrewBuiltIn
            topic == Topic.HEBREW -> emptyList()   // EnglishContent has no Hebrew world
            else -> ContentAssets.banks(lang)[topic.raw] ?: emptyList()
        }
        val cloud = RemoteQuestionBank.questions(topic, lang)
        if (cloud.isEmpty()) return builtIn
        val seen = builtIn.mapTo(HashSet()) { it.key }
        return builtIn + cloud.filter { seen.add(it.key) }
    }
}

/**
 * 🌍 ContentAvailability (ContentLanguage.swift): a world only appears in a
 * language it has real content in.
 */
object ContentAvailability {
    /** Below this a world would repeat itself within a session or two. */
    const val MINIMUM_BANK = 20

    fun hasContent(topic: Topic, lang: AppLanguage): Boolean =
        ContentCache.available("${topic.raw}|${lang.code}") { resolve(topic, lang) }

    private fun resolve(topic: Topic, lang: AppLanguage): Boolean = when {
        // 🎊 الأعياد exists only in Arabic — that audience's own holidays.
        topic == Topic.HOLIDAYS -> lang == AppLanguage.AR
        lang == AppLanguage.HE -> true
        topic == Topic.MATH -> true
        // The Hebrew world: kept for ru/ar children (Israeli school), not for en.
        topic == Topic.HEBREW -> lang == AppLanguage.RU || lang == AppLanguage.AR
        topic == Topic.READING -> ContentAssets.passages(lang).isNotEmpty()
        else -> (QuestionBanks.bank(topic, lang)?.size ?: 0) >= MINIMUM_BANK
    }
}
