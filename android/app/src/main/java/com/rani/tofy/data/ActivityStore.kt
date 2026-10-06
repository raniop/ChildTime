package com.rani.tofy.data

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import com.rani.tofy.i18n.tr
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import kotlin.math.abs

/**
 * 🔔 The parent's activity feed — ActivityFeed.swift. Three sources merged into
 * one newest-first list: what THIS phone did (gifts and remote locks it sent,
 * pushes it saw — a capped log in SharedPreferences, never leaves the device),
 * what the server recorded when it pushed (`households/{hid}/activity`,
 * read-only), and rows derived from state the app already holds (chores
 * waiting, devices joined/quiet, today's minutes). First-party only.
 */
object ActivityStore {
    /** ActivityKind — structural, never a sentence; the row renders in the parent's language. */
    enum class Kind(val raw: String, val emoji: String) {
        PLAY_STARTED("playStarted", "🎒"), PLAY_ENDED("playEnded", "🏁"), MINUTES_EARNED("minutesEarned", "⏰"),
        DAILY_CAP_REACHED("dailyCapReached", "🛑"), SCREEN_TIME_START("screenTimeStart", "📱"),
        SCREEN_TIME_END("screenTimeEnd", "🔒"), SCREEN_TIME_MOVED("screenTimeMoved", "🔀"),
        STREAK("streak", "🔥"), PERSONAL_BEST("personalBest", "🏆"), LEVEL_UP("levelUp", "👑"),
        WORLD_UNLOCKED("worldUnlocked", "🗺️"), MILESTONE("milestone", "🌟"), DISCOVERY("discovery", "🔭"),
        WHEEL_WIN("wheelWin", "🎡"), HELP_REQUEST("helpRequest", "🙋"), PREMIUM_REQUEST("premiumRequest", "⭐"),
        PACK_REQUEST("packRequest", "🎁"), TIME_TRANSFER("timeTransfer", "🔁"), CHORE_WAITING("choreWaiting", "🧹"),
        CHORE_APPROVED("choreApproved", "👍"), GIFT("giftSent", "💝"), MINUTES_GRANTED("minutesGranted", "➕"),
        MINUTES_REVOKED("minutesRevoked", "➖"), LOCK("remoteLock", "🔒"), UNLOCK("remoteUnlock", "🔓"),
        DEVICE_JOINED("deviceJoined", "📲"), DEVICE_QUIET("deviceQuiet", "💤"), INVITE_REDEEMED("inviteRedeemed", "🤝"),
        ACCOUNT_LINK("accountLink", "👨‍👩‍👧"), PARENT_GATE("parentGate", "🔑"), GIFT_NOT_OPENED("giftNotOpened", "💝"),
        PIN_RESET("pinReset", "🔢"), SUPPORT_REPLY("supportReply", "💬"), WEEKLY_REPORT("weeklyReport", "📊"),
        PASS_ENDING("passEnding", "⏳"), TOFY_MESSAGE("tofyMessage", "📬"), ALERT("alert", "⚠️"),
        INSIGHT("insight", "💡"), WHATS_NEW("whatsNew", "✨"), PUSH("push", "🔔");

        /** The row's one line — parent Hebrew, no niqqud, no gendered verb (same keys as iOS). */
        fun line(number: Int?, value: String?): String {
            val n = number ?: 0
            val v = value ?: ""
            return when (this) {
                PLAY_STARTED -> tr("התחלת משחק")
                PLAY_ENDED -> tr("סבב הסתיים")
                // Today's running total, not a fresh batch — "עוד 26" read as 26 new minutes (Rani).
                MINUTES_EARNED -> tr("היום נצברו %lld דקות משחק", n)
                DAILY_CAP_REACHED -> tr("המגבלה היומית נגמרה")
                SCREEN_TIME_START -> tr("זמן המשחק נפתח")
                SCREEN_TIME_END -> tr("זמן המשחק נגמר")
                SCREEN_TIME_MOVED -> tr("זמן המשחק עבר למכשיר אחר")
                STREAK -> tr("רצף של %lld תשובות נכונות", n)
                PERSONAL_BEST -> if (n > 0) tr("שיא אישי חדש: רצף של %lld", n) else tr("שיא אישי חדש")
                LEVEL_UP -> if (n > 0) tr("עלייה לרמה %lld", n) else tr("עליית רמה")
                WORLD_UNLOCKED -> if (v.isEmpty()) tr("עולם חדש נפתח") else tr("עולם חדש נפתח: %@", v)
                MILESTONE -> tr("הישג חדש")
                DISCOVERY -> if (v.isEmpty()) tr("גילוי עניין בנושא חדש") else tr("גילוי עניין ב%@", v)
                WHEEL_WIN -> tr("זכייה בגלגל המזל")
                HELP_REQUEST -> tr("בקשת עזרה בשאלה")
                PREMIUM_REQUEST -> tr("בקשה לטופי+")
                PACK_REQUEST -> tr("בקשה לחבילת שאלות")
                TIME_TRANSFER -> tr("בקשה להעברת דקות בין האחים")
                CHORE_WAITING -> tr("מטלה מחכה לאישור שלכם")
                CHORE_APPROVED -> tr("אישרתם מטלה")
                GIFT -> tr("שלחתם %lld דקות מתנה", n)
                MINUTES_GRANTED -> tr("הוספתם %lld דקות משחק", n)
                MINUTES_REVOKED -> tr("הורדתם %lld דקות משחק", n)
                LOCK -> tr("נעלתם את המכשיר מרחוק")
                UNLOCK -> tr("פתחתם את המכשיר מרחוק")
                DEVICE_JOINED -> tr("מכשיר חדש הצטרף למשפחה")
                DEVICE_QUIET -> tr("אין פעילות מהמכשיר כבר %lld ימים", n)
                INVITE_REDEEMED -> tr("ההזמנה למשפחה מומשה")
                ACCOUNT_LINK -> tr("עדכון בחיבור המשפחה")
                PARENT_GATE -> tr("קוד ההורים הוזן במכשיר של הילד")
                GIFT_NOT_OPENED -> tr("המתנה לא נפתחה במכשיר")
                PIN_RESET -> tr("בקשה לאיפוס קוד ההגנה")
                SUPPORT_REPLY -> tr("צוות טופי ענה לכם")
                WEEKLY_REPORT -> tr("הדוח השבועי מוכן")
                PASS_ENDING -> tr("מנוי לעולם עומד להסתיים")
                TOFY_MESSAGE -> tr("הודעה מטופי")
                ALERT -> tr("התראת מערכת")
                INSIGHT -> tr("תובנה על הילדים")
                WHATS_NEW -> tr("גרסה חדשה של טופי")
                PUSH -> tr("עדכון חדש")
            }
        }

        val opensChores: Boolean get() = this == CHORE_WAITING || this == CHORE_APPROVED

        companion object {
            fun of(raw: String?) = entries.firstOrNull { it.raw == raw }

            /** ActivityKind.fromPushType — the push `type` strings the server also records. */
            fun fromPushType(raw: String?): Kind? = when (raw) {
                "sessionStart" -> PLAY_STARTED
                "sessionEnd" -> PLAY_ENDED
                "milestone" -> MILESTONE
                "streak" -> STREAK
                "wheelWin" -> WHEEL_WIN
                "discovery" -> DISCOVERY
                "assistRequest", "parentHelp" -> HELP_REQUEST
                "screenTimeStart" -> SCREEN_TIME_START
                "screenTimeEnd" -> SCREEN_TIME_END
                "screenTimeMoved" -> SCREEN_TIME_MOVED
                "parentGateOpened" -> PARENT_GATE
                "playPINForgot" -> PIN_RESET
                "giftOpenFailed" -> GIFT_NOT_OPENED
                "levelUp" -> LEVEL_UP
                "worldUnlocked" -> WORLD_UNLOCKED
                "personalBest" -> PERSONAL_BEST
                "choreApproval" -> CHORE_WAITING
                "support-chat" -> SUPPORT_REPLY
                "weeklyReport" -> WEEKLY_REPORT
                "premium-request" -> PREMIUM_REQUEST
                "pack-request" -> PACK_REQUEST
                "pass-ending" -> PASS_ENDING
                "gift-start", "gift-day", "campaign", "retention-notice" -> TOFY_MESSAGE
                "dupAlert" -> ALERT
                "timeTransferParent", "timeTransferSeller" -> TIME_TRANSFER
                "childLinkRequest", "childLinkApproved" -> ACCOUNT_LINK
                else -> null
            }
        }
    }

    /** ActivityStatus — how far a parent→child command got. */
    enum class Status(val raw: String) {
        SENDING("sending"), REACHED_CLOUD("reachedCloud"), DEVICE_CONFIRMED("deviceConfirmed"), FAILED("failed");

        val label: String get() = when (this) {
            SENDING -> tr("שולח…")
            REACHED_CLOUD -> tr("☁️ הגיע לענן")
            DEVICE_CONFIRMED -> tr("✅ המכשיר אישר")
            FAILED -> tr("לא נשלח — אפשר לנסות שוב")
        }
    }

    /** ActivityItem. `stamp` = the command stamp a device ack is compared with. */
    data class Item(
        val id: String,
        val at: Double,
        val kind: Kind,
        val childID: String? = null,
        val childName: String? = null,
        val value: String? = null,
        val number: Int? = null,
        val status: Status? = null,
        val stamp: Double? = null,
    ) {
        val title: String get() = kind.line(number, value)

        val detail: String?
            get() {
                status?.let { return it.label }
                val v = value?.takeIf { it.isNotEmpty() } ?: return null
                return if (kind == Kind.WORLD_UNLOCKED || kind == Kind.DISCOVERY) null else v
            }

        /** Same kind + child within 3 minutes = one happening (a push seen here + the server's record of it). */
        fun sameHappening(o: Item): Boolean {
            if (kind != o.kind || childID != o.childID) return false
            if (kind == Kind.PUSH) return id == o.id
            return abs(at - o.at) < 180
        }

        fun toJson() = JSONObject().apply {
            put("id", id); put("at", at); put("kind", kind.raw)
            childID?.let { put("childID", it) }; childName?.let { put("childName", it) }
            value?.let { put("value", it) }; number?.let { put("number", it) }
            status?.let { put("status", it.raw) }; stamp?.let { put("stamp", it) }
        }

        companion object {
            fun fromJson(o: JSONObject): Item? {
                val kind = Kind.of(o.optString("kind")) ?: return null
                return Item(
                    id = o.optString("id").ifEmpty { return null }, at = o.optDouble("at", 0.0), kind = kind,
                    childID = o.optString("childID").ifEmpty { null }, childName = o.optString("childName").ifEmpty { null },
                    value = o.optString("value").ifEmpty { null }, number = if (o.has("number")) o.optInt("number") else null,
                    status = Status.entries.firstOrNull { it.raw == o.optString("status") },
                    stamp = if (o.has("stamp")) o.optDouble("stamp") else null,
                )
            }

            /** households/{hid}/activity/{id} — written by the Cloud Function that sent the push. */
            fun fromCloud(id: String, d: Doc): Item? {
                val at = d.secs("at") ?: return null
                val raw = d.str("kind") ?: d.str("type")
                val kind = Kind.of(raw) ?: Kind.fromPushType(raw) ?: Kind.PUSH
                return Item("hh.$id", at, kind, d.str("childID"), d.str("childName"), d.str("value"), d.int("num"))
            }

            /** Newest first, one row per happening, capped — ActivityItem.merged. */
            fun merged(raw: List<Item>, cap: Int = 120): List<Item> {
                val kept = mutableListOf<Item>()
                val seen = mutableSetOf<String>()
                for (item in raw.sortedByDescending { it.at }) {
                    if (item.id in seen) continue
                    val idx = kept.indexOfLast { it.sameHappening(item) }
                    if (idx >= 0) {
                        val k = kept[idx]
                        kept[idx] = k.copy(value = k.value ?: item.value, number = k.number ?: item.number, status = k.status ?: item.status)
                        continue
                    }
                    seen += item.id
                    kept += item
                    if (kept.size >= cap) break
                }
                return kept
            }
        }
    }

    // MARK: state

    private const val PREFS = "tofy_activity"
    private const val LOG_KEY = "activity.log"
    private const val READ_KEY = "activity.lastReadAt"
    private const val CAP = 160
    private const val CLOUD_LIMIT = 60L
    private const val QUIET_DAYS = 3
    private const val WINDOW = 14 * 86_400.0

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val prefs by lazy { FirebaseApp.getInstance().applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE) }

    private val local = MutableStateFlow<List<Item>>(emptyList())
    private val cloud = MutableStateFlow<List<Item>>(emptyList())
    private val _items = MutableStateFlow<List<Item>>(emptyList())
    val items: StateFlow<List<Item>> = _items
    private val _readAt = MutableStateFlow(0.0)
    /** When the parent last opened the feed (epoch seconds). */
    val readAt: StateFlow<Double> = _readAt
    private val _unread = MutableStateFlow(0)
    val unread: StateFlow<Int> = _unread

    private var started = false
    private var cloudReg: ListenerRegistration? = null
    private var cloudHousehold: String? = null

    /** Idempotent — called by the home's bell; nothing here runs before the home is on screen. */
    fun start() {
        if (started) return
        started = true
        local.value = loadLog()
        // A fresh install starts read: no badge counting history the parent never missed.
        if (prefs.getString(READ_KEY, null) == null) markRead()
        _readAt.value = prefs.getString(READ_KEY, null)?.toDoubleOrNull() ?: nowSecs()
        ChoresRepository.start()
        scope.launch { FamilyRepository.state.map { it.household?.id }.distinctUntilChanged().collect { attachCloud(it) } }
        scope.launch {
            combine(local, cloud, FamilyRepository.state, ChoresRepository.chores, _readAt) { l, c, fam, chores, read ->
                promote(fam)
                val merged = Item.merged(l + c + derived(fam, chores))
                merged to merged.count { it.at > read }
            }.collect { (list, n) -> _items.value = list; _unread.value = n }
        }
    }

    private fun attachCloud(hid: String?) {
        if (hid == cloudHousehold) return
        cloudReg?.remove(); cloudReg = null
        cloudHousehold = hid
        cloud.value = emptyList()
        hid ?: return
        cloudReg = FirebaseFirestore.getInstance().collection("households").document(hid).collection("activity")
            .orderBy("at", Query.Direction.DESCENDING).limit(CLOUD_LIMIT)
            .addSnapshotListener { snap, _ ->
                snap ?: return@addSnapshotListener
                cloud.value = snap.documents.mapNotNull { d -> d.data?.let { Item.fromCloud(d.id, it) } }
            }
    }

    fun markRead() {
        val now = nowSecs()
        prefs.edit().putString(READ_KEY, now.toString()).apply()
        _readAt.value = now
    }

    // MARK: the on-device log

    private fun loadLog(): List<Item> = runCatching {
        val arr = JSONArray(prefs.getString(LOG_KEY, "[]"))
        (0 until arr.length()).mapNotNull { Item.fromJson(arr.getJSONObject(it)) }
    }.getOrDefault(emptyList())

    private fun save(list: List<Item>) {
        val trimmed = list.sortedByDescending { it.at }.take(CAP)
        local.value = trimmed
        prefs.edit().putString(LOG_KEY, JSONArray().apply { trimmed.forEach { put(it.toJson()) } }.toString()).apply()
    }

    private fun put(item: Item) = save(local.value.filter { it.id != item.id } + item)

    /** RemoteSyncManager.giftActivityID / HouseholdManager.commandActivityID — stable per command. */
    private fun commandID(kind: Kind, childID: String, stamp: Double) =
        if (kind == Kind.GIFT) "gift.$childID.${stamp.toLong()}" else "cmd.${if (kind == Kind.LOCK) "lock" else kind.raw}.$childID.${stamp.toLong()}"

    /**
     * A parent command sent from this phone (Commands.kt calls this once the
     * write's outcome is known). A gift that is queued offline still counts as
     * on its way (iOS marks it reachedCloud); a lock only once the server took it.
     */
    fun record(kind: Kind, childID: String, minutes: Int, stamp: Double, outcome: WriteOutcome) {
        if (!started) start()
        val status = when (outcome) {
            WriteOutcome.OK -> Status.REACHED_CLOUD
            WriteOutcome.QUEUED -> if (kind == Kind.GIFT) Status.REACHED_CLOUD else Status.SENDING
            else -> Status.FAILED
        }
        val name = FamilyRepository.state.value.children.firstOrNull { it.id == childID }?.name
        val id = commandID(kind, childID, stamp)
        val existing = local.value.firstOrNull { it.id == id }
        // Never walk a confirmation backwards.
        val finalStatus = if (existing?.status == Status.DEVICE_CONFIRMED && status != Status.FAILED) existing.status else status
        put(Item(id, stamp, kind, childID, name, null, if (kind == Kind.GIFT) minutes else null, finalStatus, stamp))
        promote(FamilyRepository.state.value)
    }

    /** A notification that arrived on this phone (ActivityLog.recordNotification) — for the push handler. */
    fun recordNotification(type: String?, identifier: String, body: String?, at: Double = nowSecs()) {
        if (!started) start()
        val kind = Kind.fromPushType(type) ?: if (identifier.startsWith("insight.")) Kind.INSIGHT else Kind.PUSH
        put(Item("push.$identifier", at, kind, value = body?.takeIf { it.isNotEmpty() }))
    }

    /** A device acked a command we recorded → "✅ המכשיר אישר" (gift: giftAppliedAt; lock: every device's remoteLockAppliedAt). */
    private fun promote(fam: FamilyState) {
        var changed = false
        val next = local.value.map { item ->
            val stamp = item.stamp ?: return@map item
            if (item.status == Status.DEVICE_CONFIRMED || item.status == Status.FAILED) return@map item
            val cid = item.childID ?: return@map item
            val acked = when (item.kind) {
                Kind.GIFT -> (fam.children.firstOrNull { it.id == cid }?.raw?.secs("giftAppliedAt") ?: 0.0) >= stamp
                Kind.LOCK -> fam.devicesOf(cid).let { rows -> rows.isNotEmpty() && rows.all { (it.raw.secs("remoteLockAppliedAt") ?: 0.0) >= stamp } }
                else -> false
            }
            if (acked) { changed = true; item.copy(status = Status.DEVICE_CONFIRMED) } else item
        }
        if (changed) save(next)
    }

    // MARK: rows derived from state the app already holds (ActivityDerived)

    private fun derived(fam: FamilyState, chores: List<Chore>): List<Item> {
        val now = nowSecs()
        val cutoff = now - WINDOW
        val names = fam.children.associate { it.id to it.name }
        val out = mutableListOf<Item>()
        for (c in chores) {
            if (c.archived) continue
            val label = "${c.emoji} ${c.title}"
            c.markedDoneAt?.takeIf { it > cutoff }?.let {
                out += Item("chore.wait.${c.id}.${it.toLong()}", it, Kind.CHORE_WAITING, c.childID, names[c.childID], label, c.rewardMinutes)
            }
            c.lastApprovedAt?.takeIf { it > cutoff }?.let {
                out += Item("chore.ok.${c.id}.${it.toLong()}", it, Kind.CHORE_APPROVED, c.childID, names[c.childID], label, c.rewardMinutes)
            }
        }
        for (child in fam.children) {
            for (d in fam.devicesOf(child.id)) {
                d.raw.secs("joinedAt")?.takeIf { it > cutoff }?.let {
                    out += Item("device.join.${d.id}", it, Kind.DEVICE_JOINED, child.id, child.name, d.name)
                }
                val quiet = (now - d.lastSeenAt) / 86_400
                if (quiet >= QUIET_DAYS && d.lastSeenAt > cutoff) {
                    out += Item("device.quiet.${d.id}", d.lastSeenAt, Kind.DEVICE_QUIET, child.id, child.name, d.name, quiet.toInt())
                }
            }
            val p = fam.progress[child.id] ?: continue
            val day = p.dailyEarnedDate ?: continue
            if (!isToday(day) || p.minutesEarnedToday <= 0) continue
            val at = minOf(p.lastModifiedAt ?: now, now)
            out += Item("earned.${child.id}.${dayKey(day)}", at, Kind.MINUTES_EARNED, child.id, child.name, number = p.minutesEarnedToday)
        }
        return out
    }

    private fun dayKey(t: Double): String {
        val c = Calendar.getInstance().apply { timeInMillis = (t * 1000).toLong() }
        return "${c.get(Calendar.YEAR)}-${c.get(Calendar.MONTH) + 1}-${c.get(Calendar.DAY_OF_MONTH)}"
    }
}
