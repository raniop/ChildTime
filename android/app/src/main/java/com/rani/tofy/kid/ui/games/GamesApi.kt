package com.rani.tofy.kid.ui.games

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.GlassBackdrop

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  🎮 Mini-games — the entry points the lead wires (everything else in this
 *  package is internal to the games). Port of ChildTime/Views/MiniGames/,
 *  MiniGameContent(+More), MiniGameGrading, PreReaderGames, MiniGameEarning,
 *  BossBattleView, the four classic GamesMenu modes and WorldGameChooserView.
 * ════════════════════════════════════════════════════════════════════════════
 *
 *  All screens are full-bleed, own their BackHandler, init their sounds /
 *  speech / prefs (GameEnv.init) and preload the child's content language
 *  themselves. They read the child bound to KidSession; nothing is passed in.
 *  `topic` is always a Topic raw string ("math", "soccer", …).
 *
 *  GamesMenuScreen(onExit)
 *      GamesMenuView: ⚡ true/false race · 🎯 quick quiz · 🧩 match pairs ·
 *      🧠 memory (pre-readers: memory only). Each pays ⭐ 💎 + ≤2 🎮 minutes.
 *
 *  WorldGameChooser(topic, onPlayQuestions, onExit)
 *      WorldGameChooserView — what a world opens to. `topic` that is not a
 *      Topic (e.g. "bonus_arena") is the 💫 arena. onPlayQuestions = the card
 *      "📝 שְׁאֵלוֹת רְגִילוֹת" → open the runner for that world (earn-time).
 *      Games and 🐉 the boss are hosted inside. Every game opened here earns
 *      screen time per right answer (MiniGameEarnSession → KidSession.miniGameAnswer
 *      with a token bucket), and its end card shows ⭐ 💎 ⏱ (build 198).
 *      worldOpensStraightToQuestions(topic) = iOS WorldEntryView: decide ONCE
 *      on tap whether to skip the chooser (parent's "questions only", or no
 *      game fits and no boss yet).
 *
 *  BossBattleScreen(topic, onExit)
 *      BossBattleView — 5 boss hearts, 3 kid hearts, 20⭐ 30💎 5🎮 once a day.
 *      iOS opens it from the chooser once the world's last room is reached
 *      (bossUnlockedFor(topic)).
 *
 *  SurpriseRoundOverlay(topic, onDone)
 *      The runner's ⚡ surprise round: interstitial (×2 ⭐ 💎, "דִּלּוּג") → the
 *      game (no intro) → onDone. `topic` = the runner's fixed world (ContentMode.World)
 *      raw, or "" for the smart feed / arena — iOS `context: mode.fixedTopic`.
 *      If nothing fits, onDone() is called at once. Pays ⭐/💎 only, never minutes.
 *      For exact iOS bookkeeping call SurpriseRound.plan(grade, context) yourself
 *      and pass the plan to the overload below.
 *
 *  SurpriseRound.shouldTrigger(questionIndex, nextSurpriseAt, surprisesThisSession,
 *      isBonusArena, isPreReader, readingQueueEmpty, currentHasPassage, isBonusQuestion)
 *      Pure QuestionRunnerView.surpriseRoundDue. Runner bookkeeping (iOS):
 *        session start:  surprises = 0; nextAt = SurpriseRound.nextGap()   // 12…15
 *        in nextQuestion(), before choosing the question:
 *          if (shouldTrigger(...)) { nextAt = questionIndex + nextGap()
 *              val plan = SurpriseRound.plan(grade, context)
 *              if (plan != null) { surprises++; KidSpeech.stop(); show overlay(plan); return } }
 *        and the overlay's onDone → nextQuestion().
 */

/** GamesMenuView. */
@Composable
fun GamesMenuScreen(onExit: () -> Unit) = GamesMenu(onExit)

/** WorldGameChooserView for a world's topic raw (anything else = the 💫 arena). */
@Composable
fun WorldGameChooser(topic: String, onPlayQuestions: () -> Unit, onExit: () -> Unit) =
    WorldGameChooserScreen(playWorldFor(topic), onPlayQuestions, onExit)

/** BossBattleView for a world's topic raw (anything else = the 💫 arena boss). */
@Composable
fun BossBattleScreen(topic: String, onExit: () -> Unit) {
    val ready = rememberGamesReady()
    if (!ready) { Loading(); return }
    BossBattle(playWorldFor(topic), onExit)
}

/** The ⚡ surprise round in the runner; computes its own plan (calls onDone at once when nothing fits). */
@Composable
fun SurpriseRoundOverlay(topic: String, onDone: () -> Unit) {
    val ready = rememberGamesReady()
    var plan by remember { mutableStateOf<SurprisePlan?>(null) }
    var resolved by remember { mutableStateOf(false) }
    LaunchedEffect(ready) {
        if (!ready) return@LaunchedEffect
        GameEnv.stopSpeaking()
        plan = SurpriseRound.plan(GameEnv.grade(1), Topic.of(topic))
        resolved = true
        if (plan == null) onDone()
    }
    val p = plan
    if (!resolved || p == null) { Loading(); return }
    SurpriseRoundFlow(p, onDone)
}

/** The ⚡ surprise round for a plan the runner already made with SurpriseRound.plan. */
@Composable
fun SurpriseRoundOverlay(plan: SurprisePlan, onDone: () -> Unit) {
    val ready = rememberGamesReady()
    if (!ready) { Loading(); return }
    SurpriseRoundFlow(plan, onDone)
}

/** WorldEntryView.straight — call once when a world is tapped (needs the content preloaded for exactness). */
fun worldOpensStraightToQuestions(topic: String): Boolean = goesStraightToQuestions(playWorldFor(topic))

/** The boss card shows once the world's final room is reached. */
fun bossUnlockedFor(topic: String): Boolean = bossUnlocked(playWorldFor(topic))

@Composable
private fun Loading() {
    GlassBackdrop { Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Color.White) } }
}
