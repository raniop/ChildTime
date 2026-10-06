package com.rani.tofy.kid.ui.games

import android.content.Context
import com.rani.tofy.data.Child
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.I18n
import com.rani.tofy.kid.content.AdaptiveDifficultyEngine
import com.rani.tofy.kid.content.ContentPrefs
import com.rani.tofy.kid.content.MemoryContentPrefs
import com.rani.tofy.kid.content.SharedContentPrefs
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.ui.play.KidSounds
import com.rani.tofy.kid.ui.play.KidSpeech
import com.rani.tofy.kid.ui.play.LearningHistoryRecorder
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.child.difficultyFor
import com.rani.tofy.ui.child.interests
import com.rani.tofy.ui.child.playableTopics

/**
 * What iOS reads from its singletons (ProfileStore.shared.active,
 * ProgressStore.shared, LanguageStore.shared) — behind one seam, so every
 * content rule in this package runs in a plain JVM test with [FakeSource].
 * In the app it reads the bound child through [KidSession].
 */
interface GameSource {
    val childID: String?
    /** Profile.effectiveGrade — null when no child is bound. */
    val grade: Int?
    /** LanguageStore.current: the child's content language. */
    val lang: AppLanguage
    val characterID: String?
    /** Gendered.g — the child's own grammatical gender for kid-facing copy. */
    val isGirl: Boolean get() = false
    /** ChildRecord.onlyRegularQuestions — a parent asked for questions only (no chooser). */
    val onlyRegularQuestions: Boolean get() = false
    val interests: List<String>
    val playableTopics: Set<Topic>
    /** Profile.difficulty(for:) — the parent's per-topic base. */
    fun difficulty(topic: Topic): Difficulty
    /** ProgressStore.topicAdaptiveLevel[topic] (null = never moved). */
    fun adaptiveLevel(topic: Topic): Double?
    fun topicAnswered(topic: Topic): Int
    fun affinity(topic: Topic): Double
}

/** The real source: the child bound to [KidSession]. Touched lazily (KidSession needs Android). */
object KidGameSource : GameSource {
    private val child: Child?
        get() {
            val id = KidSession.boundChildID ?: return null
            val doc = KidSession.childDoc.value ?: return null
            return Child.from(id, doc)
        }
    override val childID: String? get() = KidSession.boundChildID
    override val grade: Int? get() = child?.effectiveGrade
    override val lang: AppLanguage get() = child?.language?.let { AppLanguage.of(it) } ?: I18n.language
    override val characterID: String? get() = child?.character3DID
    override val isGirl: Boolean get() = child?.isGirl == true
    override val onlyRegularQuestions: Boolean get() = child?.onlyRegularQuestions == true
    override val interests: List<String> get() = child?.interests ?: emptyList()
    override val playableTopics: Set<Topic> get() = child?.playableTopics ?: Topic.core.toSet()
    override fun difficulty(topic: Topic): Difficulty = child?.difficultyFor(topic) ?: Difficulty.EASY
    override fun adaptiveLevel(topic: Topic): Double? = KidSession.engine()?.snapshot?.topicAdaptiveLevel?.get(topic.raw)
    override fun topicAnswered(topic: Topic): Int = KidSession.engine()?.snapshot?.topicAnswered?.get(topic.raw) ?: 0
    override fun affinity(topic: Topic): Double = KidSession.engine()?.affinity(topic.raw) ?: 0.5
}

/** Tests: a fixed child. */
class FakeSource(
    override var grade: Int? = 2,
    override var lang: AppLanguage = AppLanguage.HE,
    override var childID: String? = "kid",
    override var characterID: String? = "fox",
    override var interests: List<String> = emptyList(),
    override var playableTopics: Set<Topic> = Topic.core.toSet(),
    var levels: Map<Topic, Double> = emptyMap(),
    var base: Difficulty = Difficulty.EASY,
) : GameSource {
    override fun difficulty(topic: Topic) = base
    override fun adaptiveLevel(topic: Topic) = levels[topic]
    override fun topicAnswered(topic: Topic) = 0
    override fun affinity(topic: Topic) = 0.5
}

object GameEnv {
    var source: GameSource = KidGameSource
    /** UserDefaults stand-in (day gates, last surprise, 2048 best). */
    var prefs: ContentPrefs = MemoryContentPrefs()
    private var initialized = false

    /** Idempotent — every public entry point calls it. */
    fun init(context: Context) {
        if (initialized) return
        initialized = true
        prefs = SharedContentPrefs(context, "tofy.games")
        KidSounds.init(context)
        KidSpeech.init(context)
        LearningHistoryRecorder.init(context)
    }

    val lang: AppLanguage get() = source.lang
    /** AppLanguage.isIsraeli — he / ru / ar are the Israeli-school languages. */
    val isIsraeli: Boolean get() = lang != AppLanguage.EN
    val childKey: String get() = source.childID ?: "none"

    /** `profiles.active?.effectiveGrade ?? fallback` */
    fun grade(fallback: Int = 2): Int = source.grade ?: fallback

    /** PreReaderGames.activeChildIsPreReader — the ONE answer to "is this a גן child". */
    val activeChildIsPreReader: Boolean get() = PreReaderGames.isPreReader(source.grade ?: 1)

    /** ProgressStore.adaptiveLevel(for:base:). */
    fun adaptiveLevel(topic: Topic, base: Difficulty = source.difficulty(topic)): Double =
        source.adaptiveLevel(topic) ?: AdaptiveDifficultyEngine.level(base)

    /** Speak in the content language (SpeechReader.shared.speak). */
    fun speak(text: String) = runCatching { KidSpeech.speak(text, lang) }.let { }
    fun stopSpeaking() = runCatching { KidSpeech.stop() }.let { }
}
