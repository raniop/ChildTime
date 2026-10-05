package com.rani.tofy.kid.ui.home

import androidx.compose.ui.graphics.Color
import com.google.firebase.firestore.FirebaseFirestore
import com.rani.tofy.data.Child
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.child.BaseWorlds
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.child.ownsPack
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.time.LocalDate
import java.time.ZoneId

/*
 * The kid home's tiles — WorldMapView.enabledWorlds / freeTier / homeTiles /
 * orderForToday / homeOrder / rotated, with the SAME seeded shuffles (FNV-1a
 * over the child's id + SplitMix64), so a child's Android and iPhone show the
 * same order on the same day.
 */

/** World.swift — one world tile (base world, pack world, or the 💫 arena). */
data class KidWorld(
    val id: String,
    val name: String,
    val emoji: String,
    /** null for the arena (it mixes every topic). */
    val topic: Topic?,
    val glow: Color,
    val rooms: Int = 10,
) {
    val isArena: Boolean get() = topic == null
}

private val glowByID = mapOf(
    "math_kingdom" to Color(0xFFFF7A3D), "english_land" to Color(0xFFFF5252), "hebrew_land" to Color(0xFFFF8FAB),
    "logic_lab" to Color(0xFF7C4DFF), "science_lab" to Color(0xFF00C853), "history_museum" to Color(0xFFFFC107),
    "geo_journey" to Color(0xFF00ACC1), "money_market" to Color(0xFF43A047), "story_forest" to Color(0xFFAB47BC),
    "holidays" to Color(0xFFFFB300),
)

/** Worlds.all: base worlds, then one world per pack, the arena last. */
fun allWorlds(): List<KidWorld> {
    val base = BaseWorlds.map { KidWorld(it.id, it.name, it.emoji, it.topic, glowByID[it.id] ?: Color(0xFF8C7BFF)) }
    val packs = Topic.entries.filter { it.isPack }.map { KidWorld("${it.raw}_world", it.displayName, it.emoji, it, Color(0xFF2ECC71)) }
    return base + packs + KidWorld("bonus_arena", tr("זִירַת הָעֲנָקִים"), "💫", null, Color(0xFFFF7A3D))
}

/** WorldSuitability.minGrade — base worlds only (locked pack worlds aren't offered on Android yet). */
private fun minGrade(t: Topic): Int = when (t) {
    Topic.READING, Topic.GEOGRAPHY -> 1
    Topic.HISTORY, Topic.MONEY -> 2
    else -> 0
}

/** ConversionConfig.swift — the founder's knobs for the free tier (config/conversion). */
object ConversionConfig {
    data class Values(
        val lockedShown: Int = 5,
        val lockedRotateDays: Int = 3,
        val guestWorlds: Int = 0,
        val guestRotateDays: Int = 7,
        val guestTopics: List<String> = emptyList(),
    )

    private val _values = MutableStateFlow(Values())
    val values: StateFlow<Values> = _values
    private var started = false

    fun start() {
        if (started) return
        started = true
        FirebaseFirestore.getInstance().collection("config").document("conversion").addSnapshotListener { snap, err ->
            if (err != null) { started = false; return@addSnapshotListener }
            val d = snap?.data ?: return@addSnapshotListener
            fun int(k: String, def: Int) = (d[k] as? Number)?.toInt() ?: def
            val cur = _values.value
            _values.value = Values(
                lockedShown = int("lockedShown", cur.lockedShown),
                lockedRotateDays = maxOf(1, int("lockedRotateDays", cur.lockedRotateDays)),
                guestWorlds = int("guestWorlds", cur.guestWorlds),
                guestRotateDays = maxOf(1, int("guestRotateDays", cur.guestRotateDays)),
                guestTopics = (d["guestTopics"] as? List<*>)?.filterIsInstance<String>() ?: cur.guestTopics,
            )
        }
    }
}

/** A tile on the home grid. */
sealed class HomeTile {
    abstract val key: String
    data object TofyTime : HomeTile() { override val key = "tofy_time" }
    data class WorldTile(
        val world: KidWorld,
        /** Playable now (Tofy+, a bought pack/pass, or this week's guest). */
        val open: Boolean,
        val guest: Boolean = false,
    ) : HomeTile() { override val key = world.id }
}

// ── seeded shuffles (WorldMapView.SeededRandom & friends) ───────────────────

private const val APPLE_EPOCH = 978_307_200L

private class SeededRandom(private var state: ULong) {
    fun next(): ULong {
        state += 0x9E3779B97F4A7C15uL
        var z = state
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9uL
        z = (z xor (z shr 27)) * 0x94D049BB133111EBuL
        return z xor (z shr 31)
    }
}

private fun fnv(childID: String?): ULong {
    var h = 0xCBF29CE484222325uL
    for (b in (childID ?: "-").toByteArray(Charsets.UTF_8)) h = (h xor b.toUByte().toULong()) * 0x100000001B3uL
    return h
}

/** Day index since the Apple reference date, at LOCAL midnight (Calendar.current.startOfDay). */
private fun daySeed(childID: String?, zone: ZoneId = ZoneId.systemDefault()): ULong {
    val start = LocalDate.now(zone).atStartOfDay(zone).toEpochSecond()
    val day = (start - APPLE_EPOCH) / 86_400
    return fnv(childID) xor (day * 0x9E3779B1L).toULong()
}

private fun <T> shuffled(items: List<T>, rng: SeededRandom): List<T> {
    val out = items.toMutableList()
    for (i in out.size - 1 downTo 1) {
        val j = (rng.next() % (i + 1).toULong()).toInt()
        val t = out[i]; out[i] = out[j]; out[j] = t
    }
    return out
}

/** WorldMapView.rotated — a stable shuffle that changes every `everyDays` days. */
fun rotated(worlds: List<KidWorld>, childID: String?, everyDays: Int, salt: Long): List<KidWorld> {
    if (worlds.size <= 1) return worlds
    val sinceRef = System.currentTimeMillis() / 1000.0 - APPLE_EPOCH
    val window = (sinceRef / 86_400).toLong() / maxOf(1, everyDays)
    val seed = fnv(childID) xor (window * 0x9E3779B1L).toULong() xor (salt.toULong() * 0x9E3779B97F4A7C15uL)
    return shuffled(worlds, SeededRandom(seed))
}

/** WorldMapView.orderForToday — the topics reshuffle once a day; the arena keeps its slot. */
fun orderForToday(worlds: List<KidWorld>, childID: String?): List<KidWorld> {
    val topics = worlds.filter { !it.isArena }
    if (topics.size <= 1) return worlds
    val it = shuffled(topics, SeededRandom(daySeed(childID))).iterator()
    return worlds.map { w -> if (w.isArena) w else (if (it.hasNext()) it.next() else w) }
}

/**
 * Everything on the home grid, in order (WorldMapView.enabledWorlds + homeTiles).
 *
 * @param playable the child's playable topics (Profile.playableTopics — parent
 *        toggles + content in the language + pack access).
 * @param progress world id → rooms done (ProgressSnapshot.worldProgress).
 */
fun homeTiles(
    child: Child?,
    childID: String,
    grade: Int,
    premium: Boolean,
    playable: Set<Topic>,
    progress: Map<String, Int>,
    conv: ConversionConfig.Values,
): List<HomeTile> {
    val all = allWorlds()
    fun owned(w: KidWorld) = w.topic != null && child?.ownsPack(w.topic) == true
    var shown = all.filter { w -> if (w.isArena) grade >= 1 else w.topic in playable }
    var guestIDs = emptySet<String>()
    if (!premium) {
        // The free tier: what the parent bought stays; of the rest the child sees
        // `lockedShown` locked worlds for their grade, rotating every few days,
        // ones they already played first. Guests only if the founder turns them on.
        val candidates = all.filter { w ->
            val t = w.topic ?: return@filter false
            !t.isPack && !owned(w) && grade >= minGrade(t) && t in playable
        }
        val ownedWorlds = all.filter { !it.isArena && owned(it) && it.topic in playable }
        var guests = emptyList<KidWorld>()
        if (conv.guestWorlds > 0) {
            val fixed = conv.guestTopics.mapNotNull { Topic.of(it) }
            val pick = if (fixed.isEmpty()) rotated(candidates, childID, conv.guestRotateDays, 2) else candidates.filter { it.topic in fixed }
            guests = pick.take(conv.guestWorlds)
        }
        guestIDs = guests.map { it.id }.toSet()
        val pool = candidates.filter { it.id !in guestIDs }
        val played = pool.filter { (progress[it.id] ?: 0) > 0 }.sortedByDescending { progress[it.id] ?: 0 }
        val rest = rotated(pool.filter { p -> played.none { it.id == p.id } }, childID, conv.lockedRotateDays, 1)
        val locked = (played + rest).take(maxOf(0, conv.lockedShown))
        shown = ownedWorlds + guests + locked + shown.filter { it.isArena }
    }
    val ordered = orderForToday(shown, childID)
    val tiles = ordered.map { w ->
        HomeTile.WorldTile(w, open = premium || owned(w) || w.id in guestIDs, guest = !premium && w.id in guestIDs)
    }.toMutableList<HomeTile>()
    // homeOrder: without Tofy+ טופי טיים is the one open thing — first, always.
    // With Tofy+ it takes its turn in the daily shuffle (never after the arena).
    if (!premium || tiles.isEmpty()) { tiles.add(0, HomeTile.TofyTime); return tiles }
    val rng = SeededRandom(daySeed(childID) + 0x51EDuL)
    rng.next()
    val lastTopic = tiles.indexOfLast { it is HomeTile.WorldTile && !it.world.isArena }.coerceAtLeast(0)
    val slot = (rng.next() % (lastTopic + 2).toULong()).toInt()
    tiles.add(minOf(slot, tiles.size), HomeTile.TofyTime)
    return tiles
}
