package com.rani.tofy.kid.ui.social

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions
import com.rani.tofy.data.Doc
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.content.ContentContext
import com.rani.tofy.kid.content.QuestionGenerator
import com.rani.tofy.kid.content.QuestionSource
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import java.util.UUID
import kotlin.math.roundToInt

/** LiveGameRules — pacing + rewards in one place. */
object LiveGameRules {
    const val QUESTION_DURATION_MS = 12_000
    const val REVEAL_DURATION_MS = 4_000
    const val ROUND_BREAK_MS = 4_500
    const val COUNTDOWN_SECONDS = 3
    const val BASE_POINTS = 100
    const val MIN_PLAYERS = 2
    const val MAX_PLAYERS = 6
    const val WINNER_DIAMONDS = 20
    const val PARTICIPATION_DIAMONDS = 5
    const val WINNER_STARS = 15
    const val PARTICIPATION_STARS = 5
    const val TOTAL_ROUNDS = 3
    const val ROUND_QUESTIONS = 5
    val roundsToWin: Int get() = TOTAL_ROUNDS / 2 + 1

    /** Correct-answer points by SERVER response time: instant ≈ base, slowest-correct ≈ half. */
    fun points(responseMs: Double, durationMs: Double): Int {
        if (durationMs <= 0) return BASE_POINTS
        val frac = (responseMs / durationMs).coerceIn(0.0, 1.0)
        val factor = maxOf(0.5, 1.0 - 0.5 * frac)
        return (BASE_POINTS * factor).roundToInt()
    }
}

enum class LiveGameState(val raw: String) {
    LOBBY("lobby"), COUNTDOWN("countdown"), QUESTION("question"), REVEAL("reveal"),
    ROUND_BREAK("roundBreak"), FINAL("final"), CANCELLED("cancelled");
    companion object { fun of(r: String?) = entries.firstOrNull { it.raw == r } }
}

data class LiveGameQuestion(val prompt: String, val options: List<String>, val spoken: String?)

data class LiveGamePlayer(
    val id: String, val name: String, val character3DID: String?,
    val score: Int = 0, val roundWins: Int = 0,
)

/** liveGames/{id}'s public state. The answer key is NEVER here (the host keeps it). */
data class LiveGame(
    val id: String,
    val hostID: String,
    val hostName: String,
    val state: LiveGameState,
    val topic: String,
    val difficulty: String,
    val totalQuestions: Int,
    val currentIndex: Int,
    val questions: List<LiveGameQuestion>,
    /** Unix seconds; the server timestamp (estimated locally until it resolves). */
    val questionStartedAt: Double?,
    val questionDurationMs: Int,
    val revealCorrectIndex: Int?,
    val scores: Map<String, Int>,
    val invited: List<String>,
    val totalRounds: Int,
    val roundQuestions: Int,
    val roundWins: Map<String, Int>,
    val lastRoundWinnerID: String?,
) {
    val currentQuestion: LiveGameQuestion? get() = questions.getOrNull(currentIndex)
    val currentRound: Int get() = if (roundQuestions > 0) maxOf(0, currentIndex) / roundQuestions else 0
    val questionInRound: Int get() = if (roundQuestions > 0) maxOf(0, currentIndex) % roundQuestions else currentIndex
    val matchWinnerID: String? get() = matchWinnerID(roundWins, scores)
    val topicName: String get() = Topic.of(topic)?.displayName ?: ""
    val topicEmoji: String get() = Topic.of(topic)?.emoji ?: "🎯"

    companion object {
        /** Most rounds won, tie-broken by points; null only on a genuine dead heat. */
        fun matchWinnerID(roundWins: Map<String, Int>, scores: Map<String, Int>): String? {
            val maxWins = roundWins.values.maxOrNull() ?: 0
            val contenders = if (maxWins > 0) roundWins.filter { it.value == maxWins }.keys.toList()
            else {
                val maxScore = scores.values.maxOrNull() ?: 0
                if (maxScore <= 0) return null
                scores.filter { it.value == maxScore }.keys.toList()
            }
            if (contenders.size == 1) return contenders.first()
            val maxScore = contenders.maxOfOrNull { scores[it] ?: 0 } ?: 0
            val top = contenders.filter { (scores[it] ?: 0) == maxScore }
            return if (top.size == 1) top.first() else null
        }

        fun int(v: Any?): Int? = (v as? Number)?.toInt()
        fun intMap(v: Any?): Map<String, Int> =
            (v as? Map<*, *>)?.mapNotNull { (k, x) -> (k as? String)?.let { key -> int(x)?.let { key to it } } }?.toMap() ?: emptyMap()
        private fun secs(v: Any?): Double? = when (v) {
            is Timestamp -> v.seconds + v.nanoseconds / 1e9
            is Number -> v.toDouble()
            else -> null
        }

        fun from(d: Doc?): LiveGame? {
            d ?: return null
            val id = d["id"] as? String ?: return null
            val host = d["hostID"] as? String ?: return null
            val state = LiveGameState.of(d["state"] as? String) ?: return null
            return LiveGame(
                id = id, hostID = host, hostName = d["hostName"] as? String ?: "", state = state,
                topic = d["topic"] as? String ?: "", difficulty = d["difficulty"] as? String ?: "",
                totalQuestions = int(d["totalQuestions"]) ?: 0, currentIndex = int(d["currentIndex"]) ?: -1,
                questions = (d["questions"] as? List<*>).orEmpty().mapNotNull { q ->
                    (q as? Map<*, *>)?.let {
                        LiveGameQuestion(it["prompt"] as? String ?: "", (it["options"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(), it["spoken"] as? String)
                    }
                },
                questionStartedAt = secs(d["questionStartedAt"]),
                questionDurationMs = int(d["questionDurationMs"]) ?: LiveGameRules.QUESTION_DURATION_MS,
                revealCorrectIndex = int(d["revealCorrectIndex"]),
                scores = intMap(d["scores"]),
                invited = (d["invited"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
                totalRounds = int(d["totalRounds"]) ?: LiveGameRules.TOTAL_ROUNDS,
                roundQuestions = int(d["roundQuestions"]) ?: LiveGameRules.ROUND_QUESTIONS,
                roundWins = intMap(d["roundWins"]),
                lastRoundWinnerID = d["lastRoundWinnerID"] as? String,
            )
        }
    }
}

data class LiveGameInvite(val id: String, val hostName: String)

/**
 * LiveGameManager.swift — HOST-AUTHORITATIVE, no Cloud Functions for gameplay:
 * the creator's device runs the state machine on its own clock, while SCORING
 * uses Firestore SERVER timestamps so "fastest" is fair across devices.
 * liveGames/{id} (host writes) · players/{playerID} (own doc) ·
 * answers/{index}_{playerID} (create-once) · nudges/{id} (→ push via onLiveGameNudge).
 */
object LiveGameRepository {
    private val db get() = FirebaseFirestore.getInstance()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private fun games() = db.collection("liveGames")

    var game by mutableStateOf<LiveGame?>(null); private set
    var players by mutableStateOf<List<LiveGamePlayer>>(emptyList()); private set
    var invites by mutableStateOf<List<LiveGameInvite>>(emptyList()); private set
    var myChoiceIndex by mutableStateOf<Int?>(null); private set
    var lastError by mutableStateOf<String?>(null)
    /** The final screen credited this device (so the UI can show the prize it actually got). */
    var rewarded by mutableStateOf(false); private set

    private var isHost = false
    private var answerKey: List<Int> = emptyList()
    private var rosterRaw: List<LiveGamePlayer> = emptyList()
    private var gameReg: ListenerRegistration? = null
    private var playersReg: ListenerRegistration? = null
    private var invitesReg: ListenerRegistration? = null
    private var hostJob: Job? = null

    // MARK: public API

    /**
     * Create a game I host: the whole match up-front (best-of-3 → 3 × 5) so
     * everyone gets the SAME questions; the public doc carries prompt+options only.
     * Questions come from the same generator iOS uses here — grade-less (players
     * span families), in the host's content language.
     */
    suspend fun createGame(topic: Topic, difficulty: Difficulty): String? {
        val myID = SocialMe.id; val uid = SocialMe.uid
        if (myID == null || uid == null) { lastError = tr("צָרִיךְ לְהִתְחַבֵּר כְּדֵי לְשַׂחֵק עִם חֲבֵרִים"); return null }
        val target = LiveGameRules.TOTAL_ROUNDS * LiveGameRules.ROUND_QUESTIONS
        val lang = I18n.language
        runCatching { QuestionSource.preload(lang) }
        val ctx = ContentContext(lang, QuestionSource.memory(myID), QuestionSource.rng)
        val wire = mutableListOf<Map<String, Any>>()
        val seen = HashSet<String>()
        val key = mutableListOf<Int>()
        var safety = 0
        while (wire.size < target && safety < target * 8) {
            safety++
            val q = runCatching { QuestionGenerator.generate(topic, difficulty, null, ctx) }.getOrNull() ?: continue
            if (!seen.add(q.prompt)) continue
            key += q.correctIndex
            val qd = mutableMapOf<String, Any>("prompt" to q.prompt, "options" to q.options)
            q.spoken?.let { qd["spoken"] = it }
            wire += qd
        }
        if (wire.isEmpty()) { lastError = tr("לֹא הִצְלַחְנוּ לְהָכִין שְׁאֵלוֹת"); return null }
        answerKey = key

        // The lobby lists my friends to invite (no auto-invite on create).
        if (FriendsRepository.leaderboard.size <= 1) FriendsRepository.refresh()

        val gameID = UUID.randomUUID().toString().uppercase()
        val doc = mapOf(
            "id" to gameID, "hostID" to myID, "hostName" to SocialMe.name, "hostOwnerUID" to uid,
            "state" to LiveGameState.LOBBY.raw, "topic" to topic.raw,
            // 🌍 Only players showing the same language see the invite / can join.
            "language" to lang.code,
            "difficulty" to difficulty.raw, "totalQuestions" to wire.size, "currentIndex" to -1,
            "questions" to wire, "questionDurationMs" to LiveGameRules.QUESTION_DURATION_MS,
            "scores" to emptyMap<String, Int>(), "invited" to emptyList<String>(),
            "totalRounds" to LiveGameRules.TOTAL_ROUNDS, "roundQuestions" to LiveGameRules.ROUND_QUESTIONS,
            "roundWins" to emptyMap<String, Int>(), "createdAt" to FieldValue.serverTimestamp(),
        )
        return try {
            games().document(gameID).set(doc).await()
            isHost = true
            rewarded = false
            joinAsPlayer(gameID)
            startLive(gameID)
            gameID
        } catch (e: Exception) {
            lastError = e.localizedMessage
            null
        }
    }

    /** Join only while the lobby is open, and only in my language. */
    suspend fun joinGame(gameID: String) {
        if (!SocialMe.isSignedIn) { lastError = tr("צָרִיךְ לְהִתְחַבֵּר"); return }
        val d = runCatching { games().document(gameID).get().await() }.getOrNull()?.data
        val state = d?.get("state") as? String
        if (state != LiveGameState.LOBBY.raw && state != LiveGameState.COUNTDOWN.raw) {
            lastError = tr("הַמִּשְׂחָק כְּבָר הִתְחִיל אוֹ הִסְתַּיֵּם"); return
        }
        if ((d["language"] as? String ?: AppLanguage.HE.code) != I18n.language.code) {
            lastError = tr("הַמִּשְׂחָק הַזֶּה בְּשָׂפָה אַחֶרֶת"); return
        }
        lastError = null
        isHost = false
        rewarded = false
        joinAsPlayer(gameID)
        startLive(gameID)
    }

    /** A direct push invite to one friend from the lobby: invited[] + a nudges doc (onLiveGameNudge). */
    suspend fun invite(friendID: String) {
        val g = game ?: return
        val uid = SocialMe.uid ?: return
        if (!isHost) return
        runCatching { games().document(g.id).set(mapOf("invited" to FieldValue.arrayUnion(friendID)), SetOptions.merge()).await() }
        runCatching {
            games().document(g.id).collection("nudges").document(UUID.randomUUID().toString().uppercase()).set(mapOf(
                "targetID" to friendID, "hostName" to SocialMe.name, "ownerUID" to uid,
                "createdAt" to FieldValue.serverTimestamp(),
            )).await()
        }
    }

    fun startGame() {
        val id = game?.id ?: return
        if (!isHost || hostJob != null) return
        hostJob = scope.launch { runHostLoop(id) }
    }

    /** First answer only — answers are create-once on the server too. */
    suspend fun submitAnswer(choice: Int) {
        val g = game ?: return
        val myID = SocialMe.id ?: return
        val uid = SocialMe.uid ?: return
        if (g.state != LiveGameState.QUESTION || myChoiceIndex != null) return
        myChoiceIndex = choice
        runCatching {
            games().document(g.id).collection("answers").document("${g.currentIndex}_$myID").set(mapOf(
                "index" to g.currentIndex, "playerID" to myID, "choiceIndex" to choice,
                "ownerUID" to uid, "answeredAt" to FieldValue.serverTimestamp(),
            )).await()
        }
    }

    /** Host mid-match → cancelled for everyone (a gentle "the game ended"); a player → leaves the roster. */
    suspend fun leaveGame() {
        val g = game
        hostJob?.cancel(); hostJob = null
        if (g != null && g.state != LiveGameState.FINAL && g.state != LiveGameState.CANCELLED) {
            if (isHost) patch(g.id, mapOf("state" to LiveGameState.CANCELLED.raw))
            else SocialMe.id?.let { me -> runCatching { games().document(g.id).collection("players").document(me).delete().await() } }
        }
        stopLive()
        game = null; players = emptyList(); rosterRaw = emptyList()
        myChoiceIndex = null; isHost = false; answerKey = emptyList()
    }

    // MARK: Firestore

    private suspend fun patch(id: String, fields: Map<String, Any?>) {
        runCatching { games().document(id).set(fields, SetOptions.merge()).await() }
    }

    private suspend fun joinAsPlayer(gameID: String) {
        val myID = SocialMe.id ?: return
        val uid = SocialMe.uid ?: return
        val data = mutableMapOf<String, Any>("id" to myID, "name" to SocialMe.name, "ownerUID" to uid,
            "joinedAt" to FieldValue.serverTimestamp())
        SocialMe.character3DID?.let { data["character3DID"] = it }
        runCatching { games().document(gameID).collection("players").document(myID).set(data, SetOptions.merge()).await() }
    }

    private fun startLive(gameID: String) {
        stopLive()
        gameReg = games().document(gameID).addSnapshotListener { snap, _ ->
            // ESTIMATE: a just-written server timestamp shows the local estimate, so the timer ring runs at once.
            val g = LiveGame.from(snap?.getData(DocumentSnapshot.ServerTimestampBehavior.ESTIMATE)) ?: return@addSnapshotListener
            val prev = game?.currentIndex
            game = g
            if (g.currentIndex != prev) myChoiceIndex = null
            refreshRoster()
            if (g.state == LiveGameState.FINAL) awardFinalRewardOnce()
        }
        playersReg = games().document(gameID).collection("players").addSnapshotListener { snap, _ ->
            rosterRaw = snap?.documents.orEmpty().mapNotNull { d ->
                val data = d.data ?: return@mapNotNull null
                val id = data["id"] as? String ?: return@mapNotNull null
                LiveGamePlayer(id, data["name"] as? String ?: "", data["character3DID"] as? String)
            }
            refreshRoster()
        }
    }

    private fun stopLive() {
        gameReg?.remove(); gameReg = null
        playersReg?.remove(); playersReg = null
    }

    private fun refreshRoster() {
        val scores = game?.scores ?: emptyMap(); val wins = game?.roundWins ?: emptyMap()
        players = rosterRaw.map { it.copy(score = scores[it.id] ?: 0, roundWins = wins[it.id] ?: 0) }
            .sortedWith(compareByDescending<LiveGamePlayer> { it.score }.thenBy { it.name })
    }

    // MARK: host state machine

    private suspend fun runHostLoop(gameID: String) {
        // Every host write first checks the loop is still alive — a host who left must never
        // overwrite the "cancelled" state with the next question.
        suspend fun patch(id: String, fields: Map<String, Any?>) { currentCoroutineContext().ensureActive(); this.patch(id, fields) }
        patch(gameID, mapOf("state" to LiveGameState.COUNTDOWN.raw, "currentIndex" to -1))
        delay(LiveGameRules.COUNTDOWN_SECONDS * 1000L)
        val duration = game?.questionDurationMs ?: LiveGameRules.QUESTION_DURATION_MS
        val rounds = game?.totalRounds ?: LiveGameRules.TOTAL_ROUNDS
        val perRound = maxOf(1, game?.roundQuestions ?: LiveGameRules.ROUND_QUESTIONS)
        val roundWins = HashMap<String, Int>()

        for (r in 0 until rounds) {
            val roundPoints = HashMap<String, Int>()
            for (q in 0 until perRound) {
                val i = r * perRound + q
                if (i !in answerKey.indices) break
                patch(gameID, mapOf(
                    "state" to LiveGameState.QUESTION.raw, "currentIndex" to i,
                    "questionStartedAt" to FieldValue.serverTimestamp(), "revealCorrectIndex" to FieldValue.delete(),
                ))
                // End as soon as EVERYONE answered, else at the timer + a small buzzer grace.
                waitForAnswersOrTimeout(gameID, i, duration + 600L, rosterRaw.size)
                val delta = computeScores(gameID, i)
                for ((pid, pts) in delta) roundPoints[pid] = (roundPoints[pid] ?: 0) + pts
                patch(gameID, mapOf("state" to LiveGameState.REVEAL.raw, "revealCorrectIndex" to answerKey[i]))
                delay(LiveGameRules.REVEAL_DURATION_MS.toLong())
            }
            // Round to its single top scorer (a tie awards no one).
            val winner = roundWinner(roundPoints)
            if (winner != null) roundWins[winner] = (roundWins[winner] ?: 0) + 1
            patch(gameID, mapOf("roundWins" to roundWins.toMap(), "lastRoundWinnerID" to (winner ?: FieldValue.delete())))
            val clinched = (roundWins.values.maxOrNull() ?: 0) >= LiveGameRules.roundsToWin
            if (clinched || r == rounds - 1) break
            patch(gameID, mapOf("state" to LiveGameState.ROUND_BREAK.raw))
            delay(LiveGameRules.ROUND_BREAK_MS.toLong())
        }
        patch(gameID, mapOf("state" to LiveGameState.FINAL.raw))
        hostJob = null
    }

    private fun roundWinner(points: Map<String, Int>): String? {
        val max = points.values.maxOrNull() ?: 0
        if (max <= 0) return null
        val top = points.filter { it.value == max }.keys
        return if (top.size == 1) top.first() else null
    }

    /** Score question `index` from the server-stamped start + answer times, onto the AUTHORITATIVE server scores. */
    private suspend fun computeScores(gameID: String, index: Int): Map<String, Int> {
        if (index !in answerKey.indices) return emptyMap()
        val gameSnap = runCatching { games().document(gameID).get().await() }.getOrNull() ?: return emptyMap()
        val start = gameSnap.getTimestamp("questionStartedAt") ?: return emptyMap()
        val startMs = start.seconds * 1000.0 + start.nanoseconds / 1e6
        val correct = answerKey[index]
        val duration = (game?.questionDurationMs ?: LiveGameRules.QUESTION_DURATION_MS).toDouble()
        val answers = runCatching {
            games().document(gameID).collection("answers").whereEqualTo("index", index).get().await()
        }.getOrNull()
        val scores = LiveGame.intMap(gameSnap.get("scores")).toMutableMap()
        val delta = HashMap<String, Int>()
        for (d in answers?.documents.orEmpty()) {
            val pid = d.getString("playerID") ?: continue
            val choice = LiveGame.int(d.get("choiceIndex")) ?: continue
            if (choice != correct) continue
            val at = d.getTimestamp("answeredAt")?.let { it.seconds * 1000.0 + it.nanoseconds / 1e6 } ?: startMs
            val pts = LiveGameRules.points(maxOf(0.0, at - startMs), duration)
            scores[pid] = (scores[pid] ?: 0) + pts
            delta[pid] = (delta[pid] ?: 0) + pts
        }
        patch(gameID, mapOf("scores" to scores))
        return delta
    }

    private suspend fun waitForAnswersOrTimeout(gameID: String, index: Int, maxMs: Long, expected: Int) {
        if (expected <= 0) { delay(maxMs); return }
        val done = CompletableDeferred<Unit>()
        var graceJob: Job? = null
        val reg = games().document(gameID).collection("answers").whereEqualTo("index", index).addSnapshotListener { snap, _ ->
            val answered = snap?.documents.orEmpty().mapNotNull { it.getString("playerID") }.toSet().size
            if (answered >= expected && graceJob == null) graceJob = scope.launch { delay(600); done.complete(Unit) }
        }
        try { withTimeoutOrNull(maxMs) { done.await() } } finally { reg.remove(); graceJob?.cancel() }
    }

    // MARK: in-app invites

    /** Games my friends start that I'm invited to (array-contains on my id) — the home banner. */
    private var inviteUsers = 0
    private var inviteChild: String? = null

    /** Ref-counted (the home banner and the friends screen both listen). */
    fun startInvitesListener() {
        inviteUsers++
        val myID = SocialMe.id ?: return
        if (invitesReg != null && inviteChild != myID) { invitesReg?.remove(); invitesReg = null }
        if (!SocialMe.isSignedIn || invitesReg != null) return
        inviteChild = myID
        invitesReg = games().whereArrayContains("invited", myID).addSnapshotListener { snap, _ ->
            val open = setOf(LiveGameState.LOBBY.raw, LiveGameState.COUNTDOWN.raw)
            val cutoff = System.currentTimeMillis() / 1000.0 - 30 * 60   // ignore abandoned lobbies
            invites = snap?.documents.orEmpty().mapNotNull { doc ->
                val d = doc.data ?: return@mapNotNull null
                val state = d["state"] as? String
                if (state !in open) return@mapNotNull null
                val host = d["hostID"] as? String ?: return@mapNotNull null
                if (host == myID) return@mapNotNull null
                (d["createdAt"] as? Timestamp)?.let { if (it.seconds < cutoff) return@mapNotNull null }
                if ((d["language"] as? String ?: AppLanguage.HE.code) != I18n.language.code) return@mapNotNull null
                LiveGameInvite(doc.id, d["hostName"] as? String ?: tr("חָבֵר"))
            }
        }
    }

    fun stopInvitesListener() {
        inviteUsers = maxOf(0, inviteUsers - 1)
        if (inviteUsers > 0) return
        invitesReg?.remove(); invitesReg = null
        invites = emptyList()
    }

    // MARK: rewards

    /** Each device credits ITS OWN wallet once at the final screen — everyone earns, the winner more. */
    private fun awardFinalRewardOnce() {
        if (rewarded) return
        val myID = SocialMe.id ?: return
        rewarded = true
        val won = game?.matchWinnerID == myID
        val gems = if (won) LiveGameRules.WINNER_DIAMONDS else LiveGameRules.PARTICIPATION_DIAMONDS
        val stars = if (won) LiveGameRules.WINNER_STARS else LiveGameRules.PARTICIPATION_STARS
        KidSession.edit { it.addDiamonds(gems); it.addStars(stars) }
    }
}
