package com.rani.tofy.kid.content

import android.content.Context
import com.rani.tofy.data.Child
import com.rani.tofy.data.Doc
import com.rani.tofy.data.Household
import com.rani.tofy.data.map
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.child.disabledPacks
import com.rani.tofy.ui.child.enabledTopicSet
import com.rani.tofy.ui.child.learningLevel
import com.rani.tofy.ui.child.ownsPack
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.ConcurrentHashMap
import kotlin.random.Random

/**
 * Everything the content layer needs to know about the child at the device:
 * the snapshot of Profile + ProgressSnapshot fields that steer question choice.
 * Immutable — hand the session a fresh one ([QuestionSession.updateChild]) when
 * the adaptive levels move after an answer.
 */
data class ChildContentProfile(
    val profileId: String,
    /** Profile.effectiveGrade — ≤0 is גן: picture questions (pre-reader). */
    val grade: Int,
    /** The content language (the child's device language). */
    val language: AppLanguage,
    /** Parent-set per-topic base difficulty (topic raw → "easy"/"medium"/"hard"). */
    val difficultyByTopic: Map<String, String> = emptyMap(),
    /** LearningLevel.seedDifficulty — the base for topics the parent never set. */
    val seedDifficulty: Difficulty = Difficulty.EASY,
    /** Base worlds the parent left on (Profile.enabledTopics, with the topicsVersion fill-ins). */
    val enabledTopics: Set<Topic> = Topic.core.toSet(),
    /** Pack ids this child may play: bought (and in date) — or every pack under Tofy+. */
    val packAccess: Set<String> = emptySet(),
    val disabledPacks: Set<String> = emptySet(),
    /** ProgressSnapshot.topicAdaptiveLevel (continuous 0…2 per topic). */
    val topicAdaptiveLevel: Map<String, Double> = emptyMap(),
    /** The Smart Feed's per-topic signals from the snapshot. */
    val signals: LearningSignals = LearningSignals(),
) {
    /** Profile.difficulty(for:) — the anchor the adaptive level floats around. */
    fun baseDifficulty(t: Topic): Difficulty = Difficulty.of(difficultyByTopic[t.raw]) ?: seedDifficulty

    /** ProgressStore.adaptiveLevel(for:base:). */
    fun adaptiveLevel(t: Topic): Double = topicAdaptiveLevel[t.raw] ?: AdaptiveDifficultyEngine.level(baseDifficulty(t))

    val isPreReader: Boolean get() = grade < 1

    /**
     * Profile.allows: a world with no content in the language is never offered;
     * a pack needs access + not disabled by the parent + switched on in the
     * cloud; a base world must be enabled by the parent.
     */
    fun allows(t: Topic, livePacks: Set<String> = QuestionPacks.liveIDs()): Boolean {
        if (!ContentAvailability.hasContent(t, language)) return false
        if (t.isPack) return t.raw in packAccess && t.raw !in disabledPacks && t.raw in livePacks
        return t in enabledTopics
    }

    /** Profile.playableTopics — the smart feed / arena / home-grid universe. */
    fun playableTopics(livePacks: Set<String> = QuestionPacks.liveIDs()): Set<Topic> =
        Topic.entries.filter { allows(it, livePacks) }.toSet()

    companion object {
        /**
         * Build from the parent-side models: the child record, its household
         * (Tofy+ opens every pack) and the raw `state/current` snapshot doc.
         */
        fun from(child: Child, household: Household?, snapshot: Doc?, fallbackLanguage: AppLanguage = AppLanguage.HE,
                 isPremium: Boolean = household?.isPremium ?: false): ChildContentProfile {
            fun dmap(k: String) = snapshot?.map(k)?.mapNotNull { (key, v) -> (v as? Number)?.let { key to it.toDouble() } }?.toMap() ?: emptyMap()
            fun imap(k: String) = snapshot?.map(k)?.mapNotNull { (key, v) -> (v as? Number)?.let { key to it.toInt() } }?.toMap() ?: emptyMap()
            val access = if (isPremium) QuestionPacks.all.map { it.raw }.toSet()
            else QuestionPacks.all.filter { child.ownsPack(it) }.map { it.raw }.toSet()
            return ChildContentProfile(
                profileId = child.id,
                grade = child.effectiveGrade,
                language = AppLanguage.of(child.language) ?: fallbackLanguage,
                difficultyByTopic = child.difficultyByTopic,
                seedDifficulty = child.learningLevel.seed,
                enabledTopics = child.enabledTopicSet,
                packAccess = access,
                disabledPacks = child.disabledPacks,
                topicAdaptiveLevel = dmap("topicAdaptiveLevel"),
                signals = LearningSignals(
                    topicAccuracy = dmap("topicAccuracy"), topicAnswered = imap("topicAnswered"),
                    topicAffinity = dmap("topicAffinity"), topicExposure = imap("topicExposure"),
                    topicAbandon = imap("topicAbandon"), topicResponseMs = dmap("topicResponseMs"),
                ),
            )
        }
    }
}

/** SessionMode.swift — how a session sources its topics. */
sealed interface ContentMode {
    /** One world's topic (classic practice, and pack worlds). */
    data class World(val topic: Topic) : ContentMode
    /** The personalized feed — LearningFeedEngine picks each topic. */
    data object SmartFeed : ContentMode
    /** 💫 The bonus arena — extra-hard questions across ALL playable topics. */
    data object BonusArena : ContentMode
}

/** A served question + what the runner needs around it. */
data class ServedQuestion(
    val question: Question,
    val topic: Topic,
    /** The sampled tier this question was asked at. */
    val difficulty: Difficulty,
    /**
     * +1 / −1 when the adaptive BAND for this topic changed since the last
     * question of the topic in this session — the runner's "מִתְקַדֵּם שָׁלָב! 🚀" /
     * "בּוֹא נַעֲשֶׂה חִימּוּם קָטָן 🌟" moment (never on sampling noise). null otherwise.
     */
    val bandChange: Int? = null,
)

/**
 * The question-selection half of QuestionRunnerView.createQuestion: topic pick,
 * adaptive tier sampling, reading-passage groups, pre-reader pictures, bonus
 * pool, no repeats in the session, parent-hidden prompts skipped.
 * (The runner keeps the re-ask queue and the super-question frame: put a wrong
 * question back with [allowReask] and re-show it yourself.)
 */
class QuestionSession internal constructor(
    child: ChildContentProfile,
    val mode: ContentMode,
    private val memory: QuestionMemory,
    private val rng: Random,
) {
    var child: ChildContentProfile = child
        private set
    private val history = mutableListOf<Topic>()
    private val readingQueue = ArrayDeque<Question>()
    private val lastBand = HashMap<Topic, Int>()
    /** Questions created so far (the runner's questionIndex when it doesn't pass its own). */
    var served: Int = 0
        private set

    val topicHistory: List<Topic> get() = history

    init { memory.beginSession() }

    private val ctx get() = ContentContext(child.language, memory, rng)

    /** New adaptive levels / settings arrived (e.g. after each answer). */
    fun updateChild(fresh: ChildContentProfile) { child = fresh }

    /**
     * The next question. `bonus` = the rare 💫 event fired (EventEngine);
     * `questionIndex` = the runner's 0-based position (drives the feed's
     * explore cadence), defaulting to the count served by this session.
     */
    fun next(bonus: Boolean = false, questionIndex: Int = served): ServedQuestion {
        served++
        val preReader = child.isPreReader
        val arena = mode is ContentMode.BonusArena
        // 📖 Finish the CURRENT passage before choosing a new topic.
        if (!bonus && !preReader && readingQueue.isNotEmpty()) {
            val rq = readingQueue.removeFirst()
            history.add(Topic.READING)
            memory.markServedThisSession(rq.sessionKey)
            return ServedQuestion(rq, Topic.READING, levelTier(Topic.READING))
        }

        val topic = pickTopic(questionIndex)
        history.add(topic)

        val base = child.baseDifficulty(topic)
        val level = child.adaptiveLevel(topic)
        val effective = AdaptiveDifficultyEngine.sampledDifficulty(level, base, rng)
        val band = AdaptiveDifficultyEngine.band(level)
        val change = lastBand[topic]?.let { prev -> if (prev != band) (if (band > prev) 1 else -1) else null }
        lastBand[topic] = band

        if (topic == Topic.READING && !preReader && !bonus && !arena) {
            if (readingQueue.isEmpty()) {
                ReadingContent.nextGroup(effective, child.grade, child.language, memory, rng)
                    .filter { !QuestionReporter.isHidden(it.prompt) }
                    .let { readingQueue.addAll(it) }
            }
            if (readingQueue.isNotEmpty()) {
                val rq = readingQueue.removeFirst()
                memory.markServedThisSession(rq.sessionKey)
                return ServedQuestion(rq, topic, effective, change)
            }
        }

        fun make(): Question = when {
            bonus || arena -> QuestionGenerator.generateBonus(topic, child.grade, ctx)
            preReader -> PreReaderContent.generate(topic, rng)
            else -> QuestionGenerator.generate(topic, effective, child.grade, ctx)
        }
        var q = make()
        // Generated questions (math + pre-reader pictures) can repeat — re-roll a few times.
        if (preReader || topic == Topic.MATH) {
            var tries = 0
            while (memory.wasServedThisSession(q.sessionKey) && tries < 8) { q = make(); tries++ }
        }
        // Skip questions a parent reported.
        var hideTries = 0
        while (QuestionReporter.isHidden(q.prompt) && hideTries < 12) { q = make(); hideTries++ }
        memory.markServedThisSession(q.sessionKey)
        return ServedQuestion(q, topic, effective, change)
    }

    /** A wrong answer may come back later (the runner's spaced re-ask). */
    fun allowReask(q: Question) = memory.allowReask(q.sessionKey)

    /** The runner re-showed a question itself (re-ask) — keep the session ledger honest. */
    fun markShown(q: Question) = memory.markServedThisSession(q.sessionKey)

    private fun levelTier(t: Topic) = AdaptiveDifficultyEngine.difficulty(child.adaptiveLevel(t))

    private fun pickTopic(index: Int): Topic = when (val m = mode) {
        is ContentMode.World -> m.topic
        ContentMode.BonusArena -> child.playableTopics().toList().sortedBy { it.ordinal }.randomOrNull(rng) ?: Topic.LOGIC
        ContentMode.SmartFeed -> {
            val profile = LearningProfile(child.signals, child.playableTopics())
            LearningFeedEngine(profile).nextTopic(history.toList(), index, rng)
        }
    }
}

/**
 * 🎯 The content facade for the child UI.
 *
 *   QuestionSource.init(context)                 // once (Application/Activity)
 *   QuestionSource.preload(lang)                 // off the main thread, before the first round
 *   val s = QuestionSource.session(child, ContentMode.World(Topic.MATH))
 *   s.next() / s.next(bonus = true)              // one question at a time, like the iOS runner
 *   QuestionSource.nextRound(child, ContentMode.SmartFeed, 10)
 *   QuestionSource.bonus(child, topic) · bossQuestion(child, topic) · hasContent(topic, lang)
 *   QuestionSource.refreshCloud()                // on foreground / after sign-in
 */
object QuestionSource {
    @Volatile private var prefs: ContentPrefs = MemoryContentPrefs()
    private val memories = ConcurrentHashMap<String, QuestionMemory>()
    @Volatile var rng: Random = Random.Default

    fun init(context: Context) {
        ContentAssets.install(context)
        prefs = SharedContentPrefs(context)
        memories.clear()
        RemoteQuestionBank.init(context)
        QuestionReporter.init(prefs)
        refreshCloud()
    }

    /** Tests: no Android, explicit assets + prefs + seeded random. */
    fun initForTest(loader: (String) -> String?, prefs: ContentPrefs = MemoryContentPrefs(), rng: Random = Random(1)) {
        ContentAssets.install(loader)
        this.prefs = prefs
        this.rng = rng
        memories.clear()
        QuestionReporter.init(prefs)
    }

    /** Pull new cloud questions (10-min throttle) and (re)attach the pack switch. */
    fun refreshCloud(force: Boolean = false) {
        RemoteQuestionBank.syncIfNeeded(force)
        runCatching { QuestionPacks.start() }
    }

    /** Parse a language's banks + passages (and the Hebrew bank the ru/ar Hebrew world uses). */
    suspend fun preload(lang: AppLanguage) = withContext(Dispatchers.Default) {
        ContentAssets.banks(lang); ContentAssets.passages(lang)
        if (lang != AppLanguage.HE) ContentAssets.banks(AppLanguage.HE)
        ContentAssets.tierIndex()
        Unit
    }

    /** The per-profile anti-repeat memory (persisted under the iOS key "questionMemory.<id>"). */
    fun memory(profileId: String): QuestionMemory = memories.getOrPut(profileId) { QuestionMemory(prefs, profileId) }

    /** Start a session (clears the in-session no-repeat ledger, like QuestionMemory.beginSession). */
    fun session(child: ChildContentProfile, mode: ContentMode): QuestionSession =
        QuestionSession(child, mode, memory(child.profileId), rng)

    /** A whole round at once (reading passages come as consecutive groups). */
    fun nextRound(child: ChildContentProfile, mode: ContentMode, size: Int): List<Question> {
        val s = session(child, mode)
        return List(size) { s.next().question }
    }

    /** 💫 One bonus question for a topic (outside a session). */
    fun bonus(child: ChildContentProfile, topic: Topic): Question =
        QuestionGenerator.generateBonus(topic, child.grade, ContentContext(child.language, memory(child.profileId), rng))

    /**
     * 👹 BossBattleView: a boss must BITE — at the top adaptive band (≥ 1.75)
     * the boss draws from one grade up. The arena boss mixes every playable topic.
     */
    fun bossQuestion(child: ChildContentProfile, topic: Topic, arena: Boolean = false): Question {
        val ctx = ContentContext(child.language, memory(child.profileId), rng)
        if (arena) {
            val t = child.playableTopics().toList().sortedBy { it.ordinal }.randomOrNull(rng) ?: Topic.LOGIC
            return QuestionGenerator.generateBonus(t, child.grade, ctx)
        }
        val grade = if (child.adaptiveLevel(topic) >= 1.75) child.grade + 1 else child.grade
        return QuestionGenerator.generate(topic, Difficulty.HARD, grade, ctx)
    }

    /** ContentAvailability — hide worlds with fewer than 20 items in the language. */
    fun hasContent(topic: Topic, lang: AppLanguage): Boolean = ContentAvailability.hasContent(topic, lang)

    /** The grade pool behind a world's mini-games (QuestionGenerator.effectivePool). */
    fun effectivePool(child: ChildContentProfile, topic: Topic): List<BankQuestion> =
        QuestionGenerator.effectivePool(topic, child.grade, child.language, rng)
}
