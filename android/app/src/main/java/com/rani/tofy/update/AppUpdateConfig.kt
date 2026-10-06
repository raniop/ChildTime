package com.rani.tofy.update

import android.content.Context
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.rani.tofy.BuildConfig
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONArray
import org.json.JSONObject

/**
 * 🔄 AppUpdateConfig.swift — "there is a newer Tofy", read live from
 * `config/appUpdate`, which the founder sets from the admin after every upload.
 *
 * Android reads its OWN numbers: an Android versionCode is the iOS build ×10 + n
 * (2002 vs 200), so comparing against `latestBuild` would always read as "newer"
 * or "older" by accident. Fields:
 * • `latestAndroidBuild` — what we would like everyone on. A dismissible notice.
 * • `minAndroidBuild` — below this the app blocks (0 = off, the normal state).
 * • `androidVersion` — the display name of that build.
 * • `enabled` — the shared kill switch; `notesByLang` / `notes` — what changed.
 *
 * Defaults are "nothing to say", so a device that never reached Firestore — or
 * an offline first launch — behaves exactly as before.
 */
object AppUpdateConfig {
    /** The parent's Play page. Parent-facing only: a kid screen never leaves the app. */
    const val STORE_URL = "https://play.google.com/store/apps/details?id=com.rani.tofy"

    data class Values(
        val latestBuild: Int = 0,
        val minBuild: Int = 0,
        val enabled: Boolean = true,
        val versionName: String = "",
        /** Legacy Hebrew-only list — shown only when the app runs in Hebrew. */
        val notes: List<String> = emptyList(),
        /** {"he": [...], "en": [...], "ru": [...], "ar": [...]} */
        val notesByLang: Map<String, List<String>> = emptyMap(),
        /** The last build the parent said "later" to. */
        val dismissedBuild: Int = 0,
    )

    sealed interface State {
        data object None : State
        /** A newer build exists. Dismissible, and remembered per build. */
        data class Recommended(val build: Int) : State
        /** This build can no longer be trusted against the server. Blocks. */
        data class Required(val build: Int) : State
    }

    private val _values = MutableStateFlow(Values())
    val values: StateFlow<Values> = _values
    private val _state = MutableStateFlow<State>(State.None)
    val state: StateFlow<State> = _state

    /** The kid notice is said once per run — a child is told, not nagged. */
    var kidNoticeShown = false
    /** The parent swiped the sheet away without choosing: quiet until the next launch. */
    var parentSheetHidden = false

    private var app: Context? = null
    private var listener: ListenerRegistration? = null
    private val prefs get() = app?.getSharedPreferences("tofy", Context.MODE_PRIVATE)

    /** Application.onCreate: the cached numbers, then listen whenever someone is signed in (config reads need auth). */
    fun init(context: Context) {
        if (app != null) return
        app = context.applicationContext
        prefs?.let { p ->
            publish(Values(
                latestBuild = p.getInt("update.latestAndroidBuild", 0),
                minBuild = p.getInt("update.minAndroidBuild", 0),
                enabled = p.getBoolean("update.enabled", true),
                versionName = p.getString("update.androidVersion", null).orEmpty(),
                notes = p.getString("update.notes", null)?.let(::decodeList).orEmpty(),
                notesByLang = p.getString("update.notesByLang", null)?.let(::decodeMap).orEmpty(),
                dismissedBuild = p.getInt("update.dismissedBuild", 0),
            ))
        }
        // Fires at once with the current user, and again on every sign-in.
        FirebaseAuth.getInstance().addAuthStateListener { if (it.currentUser != null) start() }
    }

    /** Idempotent; a failed listener (signed out → permission denied) is retried on the next call. */
    fun start() {
        if (listener != null || app == null) return
        listener = FirebaseFirestore.getInstance().collection("config").document("appUpdate")
            .addSnapshotListener { snap, err ->
                if (err != null) { listener?.remove(); listener = null; return@addSnapshotListener }
                val d = snap?.data ?: return@addSnapshotListener
                apply(d)
            }
    }

    private fun apply(d: Map<String, Any?>) {
        val next = AppUpdateLogic.merge(_values.value, d)
        prefs?.edit()?.apply {
            putInt("update.latestAndroidBuild", next.latestBuild)
            putInt("update.minAndroidBuild", next.minBuild)
            putBoolean("update.enabled", next.enabled)
            putString("update.androidVersion", next.versionName)
            putString("update.notes", JSONArray(next.notes).toString())
            putString("update.notesByLang", JSONObject(next.notesByLang.mapValues { JSONArray(it.value) }).toString())
        }?.apply()
        publish(next)
    }

    /** "Later" — quiet until the NEXT build, never for this one again. */
    fun dismissCurrent() {
        val s = _state.value as? State.Recommended ?: return
        prefs?.edit()?.putInt("update.dismissedBuild", s.build)?.apply()
        publish(_values.value.copy(dismissedBuild = s.build))
    }

    /** The notes for the language the app speaks right now (never Hebrew leaking into another language). */
    fun notesFor(langCode: String): List<String> = AppUpdateLogic.notesFor(_values.value, langCode)

    private fun publish(v: Values) {
        _values.value = v
        _state.value = AppUpdateLogic.state(v, BuildConfig.VERSION_CODE)
    }

    private fun decodeList(s: String): List<String> = runCatching {
        val a = JSONArray(s); List(a.length()) { a.getString(it) }
    }.getOrDefault(emptyList())

    private fun decodeMap(s: String): Map<String, List<String>> = runCatching {
        val o = JSONObject(s)
        o.keys().asSequence().associateWith { k -> o.getJSONArray(k).let { a -> List(a.length()) { a.getString(it) } } }
    }.getOrDefault(emptyMap())
}

/** The pure part — unit-tested (AppUpdateLogicTest). */
object AppUpdateLogic {
    /** "🏅 פרס…" → ("🏅", "פרס…"); a line that doesn't open with an emoji stays whole. */
    fun splitEmoji(line: String): Pair<String, String> {
        val space = line.indexOf(' ')
        if (space <= 0) return "" to line
        val head = line.substring(0, space)
        val cp = head.codePointAt(0)
        val isEmoji = Character.getType(cp) == Character.OTHER_SYMBOL.toInt() || cp >= 0x1F000
        return if (isEmoji) head to line.substring(space + 1) else "" to line
    }

    fun state(v: AppUpdateConfig.Values, installed: Int): AppUpdateConfig.State {
        if (!v.enabled) return AppUpdateConfig.State.None
        if (v.minBuild > 0 && installed < v.minBuild) return AppUpdateConfig.State.Required(v.minBuild)
        if (v.latestBuild > installed && v.dismissedBuild < v.latestBuild) return AppUpdateConfig.State.Recommended(v.latestBuild)
        return AppUpdateConfig.State.None
    }

    /**
     * The list for [langCode]; the legacy `notes` (written in Hebrew) only for
     * Hebrew. Any other language with no list of its own gets no list at all —
     * the sheet is then just the offer.
     */
    fun notesFor(v: AppUpdateConfig.Values, langCode: String): List<String> {
        v.notesByLang[langCode]?.filter { it.isNotBlank() }?.takeIf { it.isNotEmpty() }?.let { return it }
        return if (langCode == "he") v.notes.filter { it.isNotBlank() } else emptyList()
    }

    /** Like iOS apply(): only the fields present (and well-typed) overwrite the cached ones. */
    fun merge(cur: AppUpdateConfig.Values, d: Map<String, Any?>): AppUpdateConfig.Values {
        fun strings(x: Any?): List<String>? = (x as? List<*>)?.filterIsInstance<String>()
        return cur.copy(
            latestBuild = (d["latestAndroidBuild"] as? Number)?.toInt() ?: cur.latestBuild,
            minBuild = (d["minAndroidBuild"] as? Number)?.toInt() ?: cur.minBuild,
            enabled = d["enabled"] as? Boolean ?: cur.enabled,
            versionName = d["androidVersion"] as? String ?: cur.versionName,
            notes = strings(d["notes"]) ?: cur.notes,
            notesByLang = (d["notesByLang"] as? Map<*, *>)?.let { m ->
                buildMap { m.forEach { (k, v) -> if (k is String) strings(v)?.let { put(k, it) } } }
            } ?: cur.notesByLang,
        )
    }
}
