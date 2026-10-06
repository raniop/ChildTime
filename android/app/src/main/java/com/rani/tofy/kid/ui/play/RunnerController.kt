package com.rani.tofy.kid.ui.play

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.rani.tofy.data.Child
import com.rani.tofy.data.Household
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.content.ChildContentProfile
import com.rani.tofy.kid.content.ContentMode
import com.rani.tofy.kid.content.EventEngine
import com.rani.tofy.kid.content.LearningSignals
import com.rani.tofy.kid.content.Question
import com.rani.tofy.kid.content.QuestionReporter
import com.rani.tofy.kid.content.QuestionSession
import com.rani.tofy.kid.content.QuestionSource
import com.rani.tofy.kid.core.AnswerContext
import com.rani.tofy.kid.core.ChestKind
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.core.RewardEngine
import com.rani.tofy.kid.ui.games.MiniGameLedger
import com.rani.tofy.kid.ui.games.SurprisePlan
import com.rani.tofy.kid.ui.games.SurpriseRound
import com.rani.tofy.kid.ui.shop.CharacterCatalog
import com.rani.tofy.kid.ui.shop.CharacterTier
import com.rani.tofy.ui.child.Topic
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * The game logic of ChildTime/Views/QuestionRunnerView.swift, one round:
 * events (💫 bonus / 🌀 portal / ⭐ golden), spaced re-ask of missed questions,
 * hints, ask-a-parent, companion lines, and the end-of-round handoff.
 *
 * Every answer goes through KidSession.answerCorrect / answerWrong (stars, 💎,
 * minutes, topic stats, sync) — the runner only decides WHAT was answered and
 * what to say about it. Questions come from QuestionSource (topic pick, adaptive
 * tier, reading passages, pre-reader pictures, no repeats in the session).
 *
 * Purpose is always earn-time: every iOS entry point opens the runner with
 * `.earnTime` (WorldMapView / WorldGameChooserView).
 */
class RunnerController(
    val mode: ContentMode,
    private val scope: CoroutineScope,
    private val haptics: () -> KidHaptics?,
) {
    enum class Phase { LOADING, PLAYING, REWARD }

    val companion = CompanionController(scope, haptics)

    var phase by mutableStateOf(Phase.LOADING); private set
    var child by mutableStateOf<Child?>(null); private set
    private var household: Household? = null
    var contentLang by mutableStateOf(I18n.language); private set
    private lateinit var profile: ChildContentProfile
    private lateinit var session: QuestionSession

    // ── question state ──────────────────────────────────────────────────────
    var current by mutableStateOf<Question?>(null); private set
    /** Bumps on every new question — the fresh subtree + the stale-tap guard (iOS `.id(q.id)`). */
    var serial by mutableIntStateOf(0); private set
    var currentTopic by mutableStateOf(Topic.MATH); private set
    var questionIndex by mutableIntStateOf(0); private set
    var correctInSession = 0; private set
    val feedback = mutableStateMapOf<Int, OptionFeedback>()
    var showFeedback by mutableStateOf(false); private set
    var isSuperQuestion by mutableStateOf(false); private set
    var isInPortal by mutableStateOf(false); private set
    var isBonusQuestion by mutableStateOf(false); private set
    var showBonusIntro by mutableStateOf(false); private set
    var showPortalIntro by mutableStateOf(false); private set
    var consecutiveWrong by mutableIntStateOf(0); private set
    var receivedHelpThisQuestion by mutableStateOf(false); private set
    private var lastBonusIndex = -100
    private var hadMistakeThisQuestion = false
    private var usedHintThisQuestion = false
    private var questionShownAt = 0L
    private var capMessageShown = false
    /** Missed questions, back no earlier than `readyAt` (never as the very next one). */
    private val reAskQueue = mutableListOf<Pair<Question, Int>>()
    private val reAskSpacing = 3

    // ── ⚡ surprise round (QuestionRunnerView.surprisePlan / surprisesThisSession / nextSurpriseAt) ──
    /** Non-null = the surprise round is on screen (the runner shows SurpriseRoundOverlay, then [surpriseDone]). */
    var surprisePlan by mutableStateOf<SurprisePlan?>(null); private set
    private var surprisesThisSession = 0
    private var nextSurpriseAt = SurpriseRound.nextGap()

    // ── effects ─────────────────────────────────────────────────────────────
    var burstTrigger by mutableIntStateOf(0); private set
    var confettiTrigger by mutableIntStateOf(0); private set
    var rumbleTrigger by mutableIntStateOf(0); private set
    var earnedPopupTrigger by mutableIntStateOf(0); private set
    var lastEarnedMinutes by mutableIntStateOf(0); private set
    var secondsFlash by mutableStateOf<Pair<String, Boolean>?>(null); private set
    private var secondsFlashID = 0

    // ── end of round ────────────────────────────────────────────────────────
    var startedLevel = 1; private set
    var chestKind = ChestKind.WOOD; private set
    /**
     * ⏱ The exact screen time this round was worth, in seconds (build 198,
     * MiniGameLedger.roundSeconds): every "+24 שניות" the child watched, minus
     * every "−12", plus any bonus minutes this round paid. The chest adds its own.
     */
    var roundSeconds = 0; private set

    // ── derived ─────────────────────────────────────────────────────────────
    val isArena: Boolean get() = mode is ContentMode.BonusArena
    val isFeed: Boolean get() = mode is ContentMode.SmartFeed
    val isPreReader: Boolean get() = (child?.effectiveGrade ?: 1) < 1
    val isGirl: Boolean get() = child?.isGirl == true
    fun g(boy: String, girl: String) = if (isGirl) girl else boy

    /** Earn mode: the parent's session length, hard-capped at 30. */
    val totalQuestions: Int get() = minOf(KidSession.engine()?.settings?.questionsPerSession ?: 15, 30)
    private val secondsPerCorrect: Int get() = KidSession.engine()?.settings?.secondsPerCorrect ?: 24
    val world: PlayWorld get() = PlayWorlds.forMode(mode, currentTopic)
    /** CharacterTier.help from the shop's catalog (one price table for the shop and the runner). */
    val helperLevel: HelpLevel get() = when (CharacterCatalog.help(child?.character3DID)) {
        CharacterTier.Help.ENCOURAGE -> HelpLevel.ENCOURAGE
        CharacterTier.Help.HINT -> HelpLevel.HINT
        CharacterTier.Help.EXPLAIN -> HelpLevel.EXPLAIN
    }
    val hintCost: Int get() = if (helperLevel == HelpLevel.EXPLAIN) 0 else (KidSession.engine()?.hintCostSeconds ?: 0)

    // ── setup ───────────────────────────────────────────────────────────────
    /** Load the child + content, then start. False = nothing bound (the caller closes the screen). */
    suspend fun prepare(): Boolean {
        val cid = KidSession.boundChildID ?: return false
        val doc = withTimeoutOrNull(4000) { KidSession.childDoc.filterNotNull().first() } ?: emptyMap()
        val c = Child.from(cid, doc)
        child = c
        household = c.householdID.takeIf { it.isNotEmpty() }?.let { withTimeoutOrNull(3000) { HelpRequestSender.household(it) } }
        contentLang = AppLanguage.of(c.language) ?: I18n.language
        QuestionSource.preload(contentLang)
        profile = ChildContentProfile.from(c, household, KidSession.engine()?.snapshot?.toFirestore(), I18n.language)
        session = QuestionSource.session(profile, mode)
        phase = Phase.PLAYING
        startSession()
        return true
    }

    private fun startSession() {
        startedLevel = KidSession.engine()?.companionLevel ?: 1
        KidSession.startSession()
        KidSession.boundChildID?.let { LearningHistoryRecorder.recordSessionStart(it) }
        questionIndex = 0; correctInSession = 0; consecutiveWrong = 0; roundSeconds = 0
        capMessageShown = false
        reAskQueue.clear()
        surprisesThisSession = 0
        nextSurpriseAt = SurpriseRound.nextGap()
        scope.launch {
            delay(300)
            companion.cheer(if (isFeed) tr("טוֹפִי טַיים — קָדִימָה! 🧠") else tr("מוּכָן? קָדִימָה!"))
        }
        nextQuestion()
    }

    /** The adaptive levels moved after an answer — the session picks with the fresh ones. */
    private fun refreshProfile() {
        val s = KidSession.engine()?.snapshot ?: return
        profile = profile.copy(
            topicAdaptiveLevel = s.topicAdaptiveLevel ?: emptyMap(),
            signals = LearningSignals(s.topicAccuracy, s.topicAnswered, s.topicAffinity, s.topicExposure, s.topicAbandon, s.topicResponseMs),
        )
        session.updateChild(profile)
    }

    // ── flow ────────────────────────────────────────────────────────────────
    private fun nextQuestion() {
        if (questionIndex >= totalQuestions) {
            scope.launch { delay(400); finishRound() }
            return
        }
        // ⚡ A surprise round is due — show it; the next question follows when it's
        // over (surpriseDone). `current` is still the PREVIOUS question here, like iOS.
        // The session's reading queue is private: a passage question in progress is
        // the signal (its follow-ups are queued exactly while one is on screen).
        val passage = current?.passage != null
        if (SurpriseRound.shouldTrigger(questionIndex, nextSurpriseAt, surprisesThisSession, isArena, isPreReader,
                readingQueueEmpty = !passage, currentHasPassage = passage, isBonusQuestion = isBonusQuestion)) {
            nextSurpriseAt = questionIndex + SurpriseRound.nextGap()
            val plan = runCatching { SurpriseRound.plan(child?.effectiveGrade ?: 1, (mode as? ContentMode.World)?.topic) }.getOrNull()
            if (plan != null) {
                surprisesThisSession++
                KidSpeech.stop()
                MiniGameLedger.surpriseEarnsTime = true   // the Android runner always earns time
                surprisePlan = plan
                return
            }
        }

        // A cooldown keeps ≥3 normal questions between bonuses; none in the arena.
        val cooldownOK = !isArena && (questionIndex - lastBonusIndex) >= 3
        val atCap = KidSession.edit { it.atDailyCap() } ?: false
        val servedToday = KidSession.engine()?.bonusQuestionServedToday ?: true
        val bonusQ = cooldownOK && !isPreReader && !atCap && !servedToday &&
            EventEngine.shouldFireBonusQuestion(questionIndex, totalQuestions)
        val mystery = cooldownOK && !bonusQ && EventEngine.shouldFireMysteryPortal(questionIndex, totalQuestions)
        val superQ = cooldownOK && !bonusQ && !mystery && EventEngine.shouldFireSuperQuestion(questionIndex, totalQuestions)
        if (bonusQ || mystery || superQ) lastBonusIndex = questionIndex

        when {
            bonusQ -> {
                KidSession.edit { it.markBonusQuestionServed() }
                isInPortal = false
                showBonusIntro = true
                KidSounds.play(AppSound.PORTAL_APPEAR)
                companion.wow(tr("שְׁאֵלַת עֲנָק! 💫 שָׁוָה %lld דַּקּוֹת", RewardEngine.bonusQuestionMinutes))
                scope.launch { delay(2200); showBonusIntro = false; createQuestion(false, bonus = true) }
            }
            mystery -> {
                isInPortal = true
                showPortalIntro = true
                KidSounds.play(AppSound.PORTAL_APPEAR)
                companion.wow(tr("שְׁאֵלַת בּוֹנוּס! 🌟 פִּי 3 כּוֹכָבִים"))
                scope.launch { delay(2000); showPortalIntro = false; createQuestion(false) }
            }
            else -> { isInPortal = false; createQuestion(superQ) }
        }
    }

    /** The surprise round ended (played or skipped) — on to the next question. */
    fun surpriseDone() {
        if (surprisePlan == null) return
        MiniGameLedger.surpriseEarnsTime = false
        surprisePlan = null
        if (phase == Phase.PLAYING) nextQuestion()
    }

    private fun createQuestion(isSuper: Boolean, bonus: Boolean = false) {
        KidSpeech.stop()
        isSuperQuestion = isSuper
        isBonusQuestion = bonus
        feedback.clear()
        showFeedback = false
        hadMistakeThisQuestion = false
        usedHintThisQuestion = false
        receivedHelpThisQuestion = false
        // A request still open for the previous question is closed.
        HelpRequestSender.expireActiveRequest()

        // Re-ask a missed question every 3rd question — the only repeat allowed.
        if (!isSuper && !bonus && questionIndex > 0 && questionIndex % 3 == 0) {
            val slot = reAskQueue.indexOfFirst { it.second <= questionIndex && it.first.id != current?.id }
            if (slot >= 0) {
                val q = reAskQueue.removeAt(slot).first
                show(q, q.topic)
                if (isPreReader) KidSpeech.speak(q.readAloudText, contentLang)
                return
            }
        }

        val served = session.next(bonus = bonus, questionIndex = questionIndex)
        // Celebrate / soften only a real band change (never "it got hard").
        when (served.bandChange) {
            1 -> companion.hype(g(tr("מִתְקַדֵּם שָׁלָב! 🚀"), tr("מִתְקַדֶּמֶת שָׁלָב! 🚀")))
            -1 -> companion.cheer(tr("בּוֹא נַעֲשֶׂה חִימּוּם קָטָן 🌟"))
        }
        show(served.question, served.topic)
        // Early readers hear the instruction automatically.
        if (isPreReader) KidSpeech.speak(served.question.readAloudText, contentLang)
    }

    private fun show(q: Question, topic: Topic) {
        currentTopic = topic
        current = q
        serial++
        questionShownAt = System.currentTimeMillis()
    }

    private fun advance(afterMs: Long, onlyIfSerial: Int? = null) {
        scope.launch {
            delay(afterMs)
            if (onlyIfSerial != null && onlyIfSerial != serial) return@launch
            if (phase != Phase.PLAYING) return@launch
            questionIndex += 1
            nextQuestion()
        }
    }

    // ── picking ─────────────────────────────────────────────────────────────
    fun pickOption(idx: Int, forSerial: Int) {
        KidSpeech.stop()
        val q = current ?: return
        if (forSerial != serial) return          // a stale tile from the previous question
        if (showFeedback) return
        if ((feedback[idx] ?: OptionFeedback.NORMAL) != OptionFeedback.NORMAL) return

        if (idx == q.correctIndex) {
            for (i in q.options.indices) {
                if (i == idx) feedback[i] = OptionFeedback.CORRECT
                else if ((feedback[i] ?: OptionFeedback.NORMAL) == OptionFeedback.NORMAL) feedback[i] = OptionFeedback.DIMMED
            }
            showFeedback = true
            handleCorrect(q)
            if (hadMistakeThisQuestion && reAskQueue.none { it.first.prompt == q.prompt }) reAskQueue += q to (questionIndex + reAskSpacing)
            advance(1500)
        } else if (isBonusQuestion) {
            // 💫 The rare event is its own challenge — keep trying THIS question.
            feedback[idx] = OptionFeedback.WRONG
            handleWrong(q)
            val s = serial
            scope.launch { delay(700); if (s == serial) feedback[idx] = OptionFeedback.DIMMED }
        } else {
            // Flash, then MOVE ON — the miss returns fresh a few questions later.
            // The correct answer is NOT revealed.
            feedback[idx] = OptionFeedback.WRONG
            handleWrong(q)
            if (reAskQueue.none { it.first.prompt == q.prompt }) reAskQueue += q to (questionIndex + reAskSpacing)
            companion.cheer(tr("נַחְזֹר לָזוֹ עוֹד מְעַט 💪"))
            showFeedback = true
            advance(1000, onlyIfSerial = serial)
        }
    }

    private fun handleCorrect(q: Question) {
        KidSounds.play(if (isSuperQuestion) AppSound.CORRECT_BIG else AppSound.CORRECT_SMALL)
        haptics()?.success()
        burstTrigger++
        correctInSession++
        consecutiveWrong = 0

        val e = KidSession.engine() ?: return
        val responseMs = (System.currentTimeMillis() - questionShownAt).toDouble()
        val ctx = AnswerContext(q.topic.raw, e.snapshot.currentStreak, isSuperQuestion, isInPortal, isBonusQuestion)
        val cappedBefore = KidSession.edit { it.atDailyCap() } ?: false
        val minutesBefore = e.pendingMinutes
        val out = KidSession.answerCorrect(
            ctx, responseMs, hadMistakeThisQuestion, usedHintThisQuestion, grantsScreenTime = true,
            cycleMultiplier = if (isArena) 2.0 else 1.0, affectsAdaptive = !isArena && !isBonusQuestion,
        )
        // 🌈 Topic balance: celebrate the variety bonus, or nudge (positively) to another world.
        if (out != null && out.varietyBonusMinutes > 0) {
            companion.hype(tr("קֶסֶם הַגִּוּוּן! 🌈 +%lld דַּקּוֹת בּוֹנוּס!", out.varietyBonusMinutes))
            roundSeconds += out.varietyBonusMinutes * 60
        } else if (out?.balanceNudge == true) {
            companion.cheer(g(tr("אַלּוּף בָּזֶה! 🌟 בּוֹא נְגַלֶּה גַּם עוֹלָם אַחֵר — יֵשׁ בּוֹנוּס גִּוּוּן 🌈"),
                tr("אַלּוּפָה בָּזֶה! 🌟 בּוֹאִי נְגַלֶּה גַּם עוֹלָם אַחֵר — יֵשׁ בּוֹנוּס גִּוּוּן 🌈")))
        }
        // 💫 The bonus question pays its minutes on top of the cycle (cap-aware, overflow banked).
        if (isBonusQuestion) {
            val grant = KidSession.edit { it.grantBonusMinutes(RewardEngine.bonusQuestionMinutes) }
            if (grant != null) roundSeconds += (grant.addedToday + grant.bankedForTomorrow) * 60
        }
        KidSession.edit { it.clearOneShots() }
        refreshProfile()
        val minutesGranted = maxOf(0, (KidSession.engine()?.pendingMinutes ?: minutesBefore) - minutesBefore)
        KidSession.boundChildID?.let {
            LearningHistoryRecorder.recordAnswer(it, q.topic.raw, true, responseMs, minutesGranted,
                KidSession.engine()?.snapshot?.currentStreak ?: 0, voluntary = cappedBefore, skill = q.skill)
        }

        // "+24 שניות" rising into the timer (doubled in the arena).
        if (!cappedBefore) {
            val secs = secondsPerCorrect * (if (isArena) 2 else 1)
            roundSeconds += secs
            flashSeconds(tr("+%lld שְׁנִיּוֹת", secs), positive = true)
        }
        if (minutesGranted > 0) { lastEarnedMinutes = minutesGranted; earnedPopupTrigger++ }

        val atCapNow = KidSession.edit { it.atDailyCap() } ?: false
        if (!cappedBefore && atCapNow && !capMessageShown) {
            capMessageShown = true
            companion.wow(g(tr("הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי! 🎉 מִכָּאן מַמְשִׁיכִים לִלְמוֹד בְּלִי דַּקּוֹת נוֹסָפוֹת"),
                tr("הִגַּעַתְּ לַמַּקְסִימוּם הַיּוֹמִי! 🎉 מִכָּאן מַמְשִׁיכִים לִלְמוֹד בְּלִי דַּקּוֹת נוֹסָפוֹת")))
            confettiTrigger++
            return
        }
        if (cappedBefore) {
            if (isBonusQuestion) {
                // The promised minutes were banked — never silence a prize.
                companion.wow(tr("אַלּוּפִים! 💫 הַדַּקּוֹת נִשְׁמְרוּ לְמָחָר 🏦"))
                confettiTrigger++
            } else {
                companion.cheer(listOf(tr("יָפֶה! לוֹמְדִים בִּשְׁבִיל הַכֵּיף 🌟"), tr("כָּל הַכָּבוֹד! עוֹד נְקוּדּוֹת וְכוֹכָבִים"),
                    g(tr("אַלּוּף! מַמְשִׁיכִים לְהִתְקַדֵּם"), tr("אַלּוּפָה! מַמְשִׁיכִים לְהִתְקַדֵּם"))).random())
            }
            return
        }
        // Risk & Recovery payoff.
        if (out != null && out.recoveredMinutes > 0) {
            companion.wow(g(tr("הֶחְזַרְתָּ %lld דַּק'! ⭐", out.recoveredMinutes), tr("הֶחְזַרְתְּ %lld דַּק'! ⭐", out.recoveredMinutes)))
            confettiTrigger++
            return
        }
        val streak = KidSession.engine()?.snapshot?.currentStreak ?: 0
        if (out?.newStreakRecord == true) {
            companion.wow(tr("שִׂיא חָדָשׁ! 🏆 %lld בָּרֶצֶף!", streak))
            confettiTrigger++; rumbleTrigger++
            KidSounds.play(AppSound.LEVEL_UP)
            return
        }
        when {
            isBonusQuestion -> {
                companion.wow(tr("עֲנָקִים! 💫 +%lld דַּקּוֹת!", RewardEngine.bonusQuestionMinutes))
                confettiTrigger++; rumbleTrigger++
                KidSounds.play(AppSound.LEVEL_UP)
            }
            isSuperQuestion -> { companion.wow(tr("שְׁאֵלַת זָהָב! ⭐")); confettiTrigger++ }
            isInPortal -> { companion.wow(tr("שְׁאֵלַת בּוֹנוּס — פִּי 3 כּוֹכָבִים! 🌀")); confettiTrigger++ }
            EventEngine.shouldFireComboEvent(streak) -> {
                companion.hype(tr("🔥 %lld בָּרֶצֶף!", streak))
                confettiTrigger++; rumbleTrigger++
            }
            else -> companion.cheer(listOf(tr("יֵשׁ!"), tr("טוֹב!"), tr("כֵּן!"), tr("וָואוּ!"), g(tr("אַלּוּף!"), tr("אַלּוּפָה!"))).random())
        }
    }

    private fun handleWrong(q: Question) {
        KidSounds.play(AppSound.WRONG_SOFT)
        haptics()?.warning()
        consecutiveWrong++
        hadMistakeThisQuestion = true
        // Neither the arena nor a 💫 bonus question (hard by design) may lower the adaptive level.
        val lost = KidSession.answerWrong(q.topic.raw, usedHintThisQuestion, grantsScreenTime = true,
            affectsAdaptive = !isArena && !isBonusQuestion)
        refreshProfile()
        KidSession.boundChildID?.let { LearningHistoryRecorder.recordAnswer(it, q.topic.raw, false, 0.0, 0, 0, skill = q.skill) }
        if (lost > 0) {
            roundSeconds = maxOf(0, roundSeconds - lost)
            flashSeconds(tr("−%lld שְׁנִיּוֹת · כִּמְעַט!", lost), positive = false)
            companion.console(listOf(tr("💡 כִּמְעַט! תְּשׁוּבָה נְכוֹנָה תַּחֲזִיר אֶת הַזְּמַן"),
                tr("✨ קָרוֹב! אֶפְשָׁר לְהַחֲזִיר מִיָּד בַּשְּׁאֵלָה הַבָּאָה"), tr("⭐ עוֹד תְּשׁוּבָה נְכוֹנָה וְחוֹזְרִים לְהִתְקַדֵּם")).random())
        } else {
            companion.console(listOf(tr("כִּמְעַט!"), tr("מַמָּשׁ קָרוֹב"), tr("בּוֹא נְנַסֶּה שׁוּב"), tr("נְנַסֶּה אֶת הַבָּאָה")).random())
        }
    }

    private fun flashSeconds(text: String, positive: Boolean) {
        secondsFlashID++
        val id = secondsFlashID
        secondsFlash = text to positive
        scope.launch { delay(1100); if (secondsFlashID == id) secondsFlash = null }
    }

    // ── 💡 hint · 🪄 wand · 🚩 report ────────────────────────────────────────
    fun canUseHint(q: Question): Boolean =
        !showFeedback && q.options.indices.any { it != q.correctIndex && (feedback[it] ?: OptionFeedback.NORMAL) == OptionFeedback.NORMAL }

    /**
     * A hint costs what a mistake costs (half a step off the cycle, never a banked
     * minute). A legendary/mythic helper's hint is labelled free — and is free here.
     */
    fun useHint(forSerial: Int) {
        val q = current ?: return
        if (forSerial != serial || !canUseHint(q)) return
        if (hintCost > 0) {
            val lost = KidSession.edit { it.chargeHint() } ?: 0
            roundSeconds = maxOf(0, roundSeconds - lost)
        }
        usedHintThisQuestion = true
        val candidates = q.options.indices.filter { it != q.correctIndex && (feedback[it] ?: OptionFeedback.NORMAL) == OptionFeedback.NORMAL }
        val pick = candidates.randomOrNull() ?: return
        feedback[pick] = OptionFeedback.ELIMINATED
        KidSounds.play(AppSound.STREAK_UP)
        haptics()?.medium()
        burstTrigger++
        when (helperLevel) {
            HelpLevel.ENCOURAGE -> companion.cheer(tr("הֵסַרְתִּי לְךָ אוֹפְּצְיָה! אַתָּה יָכוֹל 💪"))
            HelpLevel.HINT -> companion.cheer(tr("הֵסַרְתִּי אוֹפְּצְיָה. %@", HintContent.hint(q.topic)))
            HelpLevel.EXPLAIN -> companion.cheer(HintContent.explain(q.topic))
        }
    }

    /** 🪄 "Swap question" — after two misses in a row. Replacing is an abandon signal. */
    fun magicWand() {
        companion.cheer(tr("בּוֹא נְנַסֶּה אַחֶרֶת"))
        KidSession.edit { it.recordAbandon(currentTopic.raw) }
        createQuestion(isSuperQuestion)
        consecutiveWrong = 0
    }

    fun reportCurrent() {
        val q = current ?: return
        val name = child?.name
        scope.launch { QuestionReporter.report(q, name) }
        haptics()?.success()
        createQuestion(false)   // replace with a fresh question
    }

    // ── 🙋 ask a parent ──────────────────────────────────────────────────────
    /** Returns true when the sheet should open; otherwise the buddy says why not. */
    fun askParentTapped(q: Question, waiting: Boolean): Boolean {
        if (waiting) { companion.console(tr("💌 הַבַּקָּשָׁה בַּדֶּרֶךְ — אֶפְשָׁר לְהַמְשִׁיךְ לַחְשֹׁב בֵּינְתַיִם")); return false }
        if (showFeedback) return false
        if (receivedHelpThisQuestion) { companion.console(tr("כְּבָר קִבַּלְנוּ עֶזְרָה בַּשְּׁאֵלָה הַזֹּאת 💛")); return false }
        val cid = KidSession.boundChildID ?: ""
        if (HelpRequestSender.cooldownRemaining(cid) > 0) {
            companion.console(g(tr("⏳ עוֹד רֶגַע תּוּכַל לְבַקֵּשׁ שׁוּב — נַסֵּה לְבַד בֵּינְתַיִם"), tr("⏳ עוֹד רֶגַע תּוּכְלִי לְבַקֵּשׁ שׁוּב — נַסִּי לְבַד בֵּינְתַיִם")))
            return false
        }
        haptics()?.light()
        return true
    }

    val linkedParents: List<Pair<String, String>> get() = HelpRequestSender.linkedParents(household)

    /** `uid` = a linked parent, or "all" for every parent device. */
    fun askParent(q: Question, topic: Topic, uid: String) {
        haptics()?.light()
        val cid = KidSession.boundChildID
        val hid = child?.householdID?.takeIf { it.isNotEmpty() }
        if (cid == null || hid == null) {
            // No household at all — the legacy generic nudge.
            KidSession.reportEvent("assistRequest")
            return
        }
        val correct = q.options.getOrElse(q.correctIndex) { "" }
        val distractor = q.options.filterIndexed { i, _ -> i != q.correctIndex }.randomOrNull() ?: ""
        HelpRequestSender.requestHelp(
            childID = cid, childName = child?.name?.takeIf { it.isNotEmpty() } ?: tr("הילד"), parentUID = uid,
            householdID = hid, topic = topic.raw, question = q.prompt, correctAnswer = correct, distractor = distractor,
            gender = if (isGirl) "girl" else "boy",
        )
    }

    /** The parent answered: remove the WRONG one of the two they saw (never the correct answer). */
    fun applyParentHelp(reply: HelpReply) {
        val q = current
        val active = HelpRequestSender.activeQuestion.value
        HelpRequestSender.consumeReply()
        HelpRequestSender.stopListening()
        if (q == null || showFeedback || (active != null && active != q.prompt)) {
            companion.wow(tr("💌 הָעֶזְרָה הִגִּיעָה — אֲבָל כְּבָר הִתְקַדַּמְנוּ הָלְאָה!"))
            return
        }
        val toRemove = listOf(reply.kept, reply.removed).firstOrNull { it != q.correctAnswer }
        val idx = toRemove?.let { q.options.indexOf(it) } ?: -1
        if (idx < 0 || (feedback[idx] ?: OptionFeedback.NORMAL) != OptionFeedback.NORMAL) {
            companion.wow(tr("💌 הָעֶזְרָה הִגִּיעָה! הַתְּשׁוּבָה הַזֹּאת כְּבָר יְרוּקָה 😉"))
            return
        }
        feedback[idx] = OptionFeedback.ELIMINATED
        KidSounds.play(AppSound.STREAK_UP)
        haptics()?.success()
        burstTrigger++
        companion.wow(tr("✨ קִבַּלְתָּ רֶמֶז מֵהוֹרֶה!"))
        receivedHelpThisQuestion = true
    }

    fun readAloud(q: Question) {
        haptics()?.light()
        // A passage question reads the passage first — one utterance, so they don't cut each other off.
        val spoken = (q.passage?.let { "$it. " } ?: "") + q.readAloudText
        KidSpeech.readQuestion(spoken, q.options, contentLang)
    }

    // ── end ─────────────────────────────────────────────────────────────────
    private fun finishRound() {
        if (phase != Phase.PLAYING) return
        KidSpeech.stop()
        HelpRequestSender.expireActiveRequest()
        chestKind = RewardEngine.endOfSessionChestKind(correctInSession, totalQuestions)
        phase = Phase.REWARD
    }

    /** ✕ / back mid-round: every answer is already saved; push it now and close any open help request. */
    fun leave() {
        KidSpeech.stop()
        HelpRequestSender.expireActiveRequest()
        KidSession.pushNow()
    }
}
