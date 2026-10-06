package com.rani.tofy.kid.content

import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.rani.tofy.BuildConfig
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.ui.child.Topic
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.tasks.await
import kotlinx.serialization.encodeToString

/**
 * 📦 The remote launch switch for question packs (PackStore.swift): the
 * questions ship with the build, `packs/{id}.enabled == true` turns a pack ON,
 * `packs/{id}.launchedAt` makes it "new" for its first day. Pack id == topic raw.
 * Debug builds show every bundled pack, like iOS DEBUG.
 */
object QuestionPacks {
    /** Every pack topic, in catalog order (QuestionPacks.all). */
    val all: List<Topic> = listOf(
        Topic.SOCCER, Topic.DINOSAURS, Topic.SPACE, Topic.ANIMALS, Topic.SEA, Topic.GIFTED, Topic.FOOD,
        Topic.ISRAEL, Topic.TISHREI, Topic.MUSIC, Topic.BODY, Topic.VEHICLES, Topic.FLAGS,
    )

    private val _live = MutableStateFlow<Set<String>>(emptySet())
    /** Pack ids switched on in the cloud. */
    val live: StateFlow<Set<String>> = _live
    private val _launchedAt = MutableStateFlow<Map<String, Long>>(emptyMap())
    val launchedAt: StateFlow<Map<String, Long>> = _launchedAt
    private var listener: ListenerRegistration? = null

    /** Start listening to `packs` where enabled == true (idempotent). */
    fun start() {
        if (listener != null) return
        listener = FirebaseFirestore.getInstance().collection("packs").whereEqualTo("enabled", true)
            .addSnapshotListener { snap, error ->
                // A denied read (not signed in yet) ends the listener — let the
                // next QuestionSource.refreshCloud() attach a fresh one.
                if (error != null) { listener?.remove(); listener = null; return@addSnapshotListener }
                val docs = snap?.documents ?: return@addSnapshotListener
                _live.value = docs.map { it.id }.toSet()
                _launchedAt.value = docs.mapNotNull { d -> (d.get("launchedAt") as? Timestamp)?.let { d.id to it.toDate().time } }.toMap()
            }
    }

    fun stop() { listener?.remove(); listener = null }

    /** Test seam. */
    fun setLiveForTest(ids: Set<String>) { _live.value = ids }

    /** Pack ids live right now (all of them in a debug build). */
    fun liveIDs(): Set<String> = if (isDebugBuild()) all.map { it.raw }.toSet() else _live.value

    /** PackStore.visiblePacks — live AND with questions in the language. */
    fun visiblePacks(lang: AppLanguage): List<Topic> =
        liveIDs().let { ids -> all.filter { it.raw in ids && ContentAvailability.hasContent(it, lang) } }

    /** A pack switched on within the last day — "new" for the child too. */
    fun isFirstDay(packID: String, nowMs: Long = System.currentTimeMillis()): Boolean {
        val at = _launchedAt.value[packID] ?: return false
        return nowMs - at < 86_400_000L
    }

    // Only against the local emulators. A debug build on a real family (Rani's
    // tablet, testing against production) must show exactly what that family
    // gets — otherwise every unbought pack shows up as an open world.
    private fun isDebugBuild(): Boolean =
        runCatching { BuildConfig.DEBUG && BuildConfig.USE_EMULATORS }.getOrDefault(false) && !forceCloudSwitch
    /** Tests (and anyone wanting the release behaviour in a debug build). */
    @Volatile var forceCloudSwitch = false
}

/**
 * 🚩 QuestionReporter.swift — a parent flags a bad question: it is hidden on
 * THIS device at once (UserDefaults "reportedHiddenPrompts" → a local prefs set,
 * keyed by prompt, exactly like iOS — the hidden list is device-local and never
 * synced) and a report goes to `questionReports` so it's fixed for everyone.
 */
object QuestionReporter {
    private const val KEY = "reportedHiddenPrompts"
    private var prefs: ContentPrefs = MemoryContentPrefs()
    @Volatile private var hidden: Set<String> = emptySet()

    fun init(prefs: ContentPrefs) {
        this.prefs = prefs
        hidden = runCatching { prefs.getString(KEY)?.let { contentJson.decodeFromString<List<String>>(it).toSet() } }.getOrNull() ?: emptySet()
    }

    fun isHidden(prompt: String): Boolean = hidden.contains(prompt)
    val hiddenPrompts: Set<String> get() = hidden

    /**
     * Hide locally, then send the report. `childName` = the child that was
     * playing (the Cloud Function falls back to a parents/{uid} lookup).
     * Returns whether the report reached Firestore; the local hide happens either way.
     */
    suspend fun report(question: Question, childName: String? = null, reason: String? = null): Boolean {
        synchronized(this) {
            hidden = hidden + question.prompt
            prefs.putString(KEY, contentJson.encodeToString(hidden.toList()))
        }
        val user = runCatching { FirebaseAuth.getInstance().currentUser }.getOrNull()
        val payload = mutableMapOf<String, Any>(
            "prompt" to question.prompt,
            "correctAnswer" to question.correctAnswer,
            "topic" to question.topic.raw,
            "createdAt" to System.currentTimeMillis() / 1000.0,
            "reportedBy" to (user?.uid ?: "anonymous"),
        )
        childName?.takeIf { it.isNotEmpty() }?.let { payload["childName"] = it }
        user?.email?.takeIf { it.isNotEmpty() }?.let { payload["reporterEmail"] = it }
        user?.displayName?.takeIf { it.isNotEmpty() }?.let { payload["reporterName"] = it }
        reason?.takeIf { it.isNotEmpty() }?.let { payload["reason"] = it }
        return runCatching { FirebaseFirestore.getInstance().collection("questionReports").add(payload).await() }.isSuccess
    }
}
