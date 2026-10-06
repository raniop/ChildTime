package com.rani.tofy.kid.ui.games

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.rani.tofy.kid.content.AdaptiveDifficultyEngine
import com.rani.tofy.kid.content.ContentAvailability
import com.rani.tofy.kid.content.ContentContext
import com.rani.tofy.kid.content.Question
import com.rani.tofy.kid.content.QuestionGenerator
import com.rani.tofy.kid.content.QuestionSource
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic

/**
 * One-off questions for the classic modes (🎯 QuickQuiz, ⚡ TrueFalseRace, 🧩
 * MatchPairs, 🐉 the boss) — QuestionGenerator.generate with the child's
 * language, anti-repeat memory and adaptive tier, like the iOS views call it.
 */
object GameQuestions {
    private fun ctx() = ContentContext(GameEnv.lang, QuestionSource.memory(GameEnv.childKey), QuestionSource.rng)

    fun generate(topic: Topic, difficulty: Difficulty, grade: Int?): Question = QuestionGenerator.generate(topic, difficulty, grade, ctx())
    fun generateBonus(topic: Topic, grade: Int?): Question = QuestionGenerator.generateBonus(topic, grade, ctx())

    /** Profile.playableTopics (worlds with content in the language). */
    fun playableTopics(): List<Topic> =
        GameEnv.source.playableTopics.filter { ContentAvailability.hasContent(it, GameEnv.lang) }.sortedBy { it.ordinal }

    /** The runner's adaptive tier for a topic: base ± the level the engine learned. */
    fun sampledDifficulty(topic: Topic): Difficulty {
        val base = GameEnv.source.difficulty(topic)
        return AdaptiveDifficultyEngine.sampledDifficulty(GameEnv.adaptiveLevel(topic, base), base)
    }
}

/**
 * Every public entry point: init the sound / speech / prefs seams once and
 * parse the child's content language off the main thread. False until ready
 * (the screens show a spinner meanwhile).
 */
@Composable
fun rememberGamesReady(): Boolean {
    val ctx = LocalContext.current
    remember { GameEnv.init(ctx); 0 }
    var ready by remember { mutableStateOf(false) }
    LaunchedEffect(GameEnv.lang) {
        runCatching { QuestionSource.preload(GameEnv.lang) }
        ready = true
    }
    return ready
}
