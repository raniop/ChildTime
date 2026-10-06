package com.rani.tofy.kid.ui.home

import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.ui.child.Topic
import kotlinx.coroutines.flow.MutableStateFlow

/**
 * 🏆 WorldRouter + WorldTiers.suggestedNewWorld (iOS WorldTiers.swift): opens a
 * world from anywhere inside one — the "אוֹ עוֹלָם חָדָשׁ" button after a boss.
 * KidExperience closes whatever world is on screen and opens [pending].
 */
object WorldRouter {
    /** A KidWorld id to open next; KidExperience consumes it (sets it back to null). */
    val pending = MutableStateFlow<String?>(null)

    /** What this child can open right now — KidExperience keeps it current. */
    data class Access(val premium: Boolean = false, val playable: Set<Topic> = emptySet(), val owned: Set<Topic> = emptySet())

    @Volatile var access = Access()

    /**
     * An unvisited world this child can open right now: Tofy+ opens every base
     * world, a pack (or a world pass) only when it was bought for this child.
     * [a] defaults to what KidExperience last published; the home passes its own
     * (fresh) access, since that publish happens after composition.
     */
    fun suggestedNewWorld(excluding: String, a: Access = access): KidWorld? {
        val engine = KidSession.engine() ?: return null
        return allWorlds().firstOrNull { w ->
            val t = w.topic ?: return@firstOrNull false   // never the 💫 arena
            if (w.id == excluding || t !in a.playable || engine.hasVisited(w.id)) return@firstOrNull false
            t in a.owned || (a.premium && !t.isPack)
        }
    }
}
