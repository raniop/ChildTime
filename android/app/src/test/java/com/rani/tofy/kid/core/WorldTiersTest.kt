package com.rani.tofy.kid.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneId

/** 🏆 World tiers — the ProgressStore stage rules + the worldStage wire format (iOS parity). */
class WorldTiersTest {

    private class FakeClock(override val zone: ZoneId = ZoneId.of("Asia/Jerusalem")) : KidClock {
        val unix = LocalDateTime.of(2026, 10, 7, 10, 0).atZone(zone).toEpochSecond().toDouble()
        override fun nowUnix() = unix
        override fun uptimeSecs() = 1000.0
    }

    private fun engine(snap: ProgressSnapshot? = null): ProgressEngine {
        val e = ProgressEngine(KidSettings(), FakeClock(), "DEV-A")
        if (snap != null) e.apply(snap)
        return e
    }
    private val w = "math_kingdom"

    // ── stage / tier / room ─────────────────────────────────────────────────
    @Test fun freshWorld_isBronzeRoomZero_notVisited() {
        val p = engine()
        assertEquals(0, p.stage(w)); assertEquals(0, p.worldTier(w)); assertEquals(0, p.progress(w))
        assertEquals(0, p.tierGradeOffset(w))
        assertFalse(p.hasVisited(w))
    }

    @Test fun legacyRoomsOnly_readAsBronzeAtThatRoom() {
        val p = engine(ProgressSnapshot(worldProgress = mapOf(w to 6)))
        assertEquals(6, p.stage(w)); assertEquals(0, p.worldTier(w)); assertEquals(6, p.progress(w))
        assertTrue(p.hasVisited(w))
    }

    @Test fun stage_isMaxOfStageAndLegacy_cappedAtChampion() {
        assertEquals(14, engine(ProgressSnapshot(worldStage = mapOf(w to 14), worldProgress = mapOf(w to 9))).stage(w))
        assertEquals(9, engine(ProgressSnapshot(worldStage = mapOf(w to 3), worldProgress = mapOf(w to 9))).stage(w))
        assertEquals(30, engine(ProgressSnapshot(worldStage = mapOf(w to 45))).stage(w))
    }

    @Test fun tiersAndGradeOffsets() {
        for ((stage, tier, room, offset) in listOf(
            listOf(0, 0, 0, 0), listOf(9, 0, 9, 0), listOf(10, 1, 0, 1), listOf(17, 1, 7, 1),
            listOf(20, 2, 0, 2), listOf(29, 2, 9, 2), listOf(30, 3, 9, 2),
        )) {
            val p = engine(ProgressSnapshot(worldStage = mapOf(w to stage)))
            assertEquals("tier@$stage", tier, p.worldTier(w))
            assertEquals("room@$stage", room, p.progress(w))
            assertEquals("offset@$stage", offset, p.tierGradeOffset(w))
        }
    }

    // ── advanceRoom ─────────────────────────────────────────────────────────
    @Test fun advanceRoom_growsStage_andKeepsLegacyCounter() {
        val p = engine()
        repeat(4) { p.advanceRoom(w) }
        assertEquals(4, p.snapshot.worldStage[w]); assertEquals(4, p.snapshot.worldProgress[w])
        repeat(10) { p.advanceRoom(w) }
        // Stops in the boss room of the tier; the legacy counter caps at 9 too.
        assertEquals(9, p.snapshot.worldStage[w]); assertEquals(9, p.snapshot.worldProgress[w])
        assertEquals(9, p.progress(w))
    }

    @Test fun advanceRoom_inSilver_staysInsideTheTier() {
        val p = engine(ProgressSnapshot(worldStage = mapOf(w to 10), worldProgress = mapOf(w to 9)))
        p.advanceRoom(w)
        assertEquals(11, p.snapshot.worldStage[w])
        assertEquals(9, p.snapshot.worldProgress[w])   // legacy stays capped
        repeat(20) { p.advanceRoom(w) }
        assertEquals(19, p.snapshot.worldStage[w])
        assertEquals(1, p.worldTier(w)); assertEquals(9, p.progress(w))
    }

    @Test fun advanceRoom_champion_isUnchanged() {
        val p = engine(ProgressSnapshot(worldStage = mapOf(w to 30)))
        p.advanceRoom(w)
        assertEquals(30, p.snapshot.worldStage[w]); assertEquals(9, p.progress(w))
    }

    // ── markVisited ─────────────────────────────────────────────────────────
    @Test fun markVisited_paysOnce() {
        val p = engine()
        val d0 = p.snapshot.diamonds
        assertEquals(20, p.markVisited(w))
        assertEquals(d0 + 20, p.snapshot.diamonds)
        assertEquals(0, p.snapshot.worldStage[w])
        assertTrue(p.hasVisited(w))
        assertEquals(0, p.markVisited(w))
        assertEquals(d0 + 20, p.snapshot.diamonds)
    }

    @Test fun markVisited_legacyPlayedWorld_paysNothing() {
        val p = engine(ProgressSnapshot(worldProgress = mapOf(w to 2), diamonds = 7))
        assertEquals(0, p.markVisited(w))
        assertEquals(7, p.snapshot.diamonds)
        assertNull(p.snapshot.worldStage[w])
    }

    @Test fun markVisited_isALocalEdit() {
        val p = engine()
        val rev = p.snapshot.revision
        p.markVisited(w)
        assertTrue(p.snapshot.revision > rev)
    }

    // ── completeTier ────────────────────────────────────────────────────────
    @Test fun completeTier_onlyInTheBossRoom() {
        val p = engine(ProgressSnapshot(worldStage = mapOf(w to 5), diamonds = 0))
        assertNull(p.completeTier(w))
        assertEquals(5, p.snapshot.worldStage[w]); assertEquals(0, p.snapshot.diamonds)
    }

    @Test fun completeTier_walksBronzeSilverGold_thenChampion() {
        val p = engine(ProgressSnapshot(diamonds = 0))
        p.markVisited(w)
        var diamonds = 20
        for (tier in 0..2) {
            repeat(9) { p.advanceRoom(w) }
            assertEquals(tier * 10 + 9, p.stage(w))
            assertEquals(tier, p.completeTier(w))
            diamonds += 100
            assertEquals(diamonds, p.snapshot.diamonds)
            assertEquals((tier + 1) * 10, p.snapshot.worldStage[w])
            if (tier < 2) assertEquals(0, p.progress(w))
        }
        assertEquals(30, p.stage(w)); assertEquals(3, p.worldTier(w)); assertEquals(9, p.progress(w))
        assertEquals(2, p.tierGradeOffset(w))
        // A champion's boss is a replay: no tier, no diamonds.
        assertNull(p.completeTier(w))
        assertEquals(diamonds, p.snapshot.diamonds)
    }

    @Test fun completeTier_legacyBossRoom_completesBronze() {
        val p = engine(ProgressSnapshot(worldProgress = mapOf(w to 9), diamonds = 0))
        assertEquals(0, p.completeTier(w))
        assertEquals(10, p.snapshot.worldStage[w]); assertEquals(100, p.snapshot.diamonds)
        assertEquals(1, p.worldTier(w)); assertEquals(0, p.progress(w))
    }

    @Test fun capture_and_apply_carryWorldStage() {
        val p = engine()
        p.markVisited(w); p.advanceRoom(w)
        val q = engine(p.capture())
        assertEquals(1, q.snapshot.worldStage[w]); assertTrue(q.hasVisited(w))
    }

    // ── snapshot merge + wire format ────────────────────────────────────────
    @Test fun merge_worldStage_isMaxPerKey_andUnionOfKeys() {
        val a = ProgressSnapshot(worldStage = mapOf("a" to 12, "b" to 3), revision = 5, deviceID = "A")
        val b = ProgressSnapshot(worldStage = mapOf("a" to 9, "c" to 0), revision = 6, deviceID = "B")
        for (m in listOf(ProgressSnapshot.ratchetMerged(a, b), ProgressSnapshot.ratchetMerged(b, a))) {
            assertEquals(mapOf("a" to 12, "b" to 3, "c" to 0), m.worldStage)
        }
    }

    @Test fun merge_aTierIsNeverUndoneByAStaleDevice() {
        // This device completed bronze (stage 10); the other still has the boss room (9) everywhere.
        val here = ProgressSnapshot(worldStage = mapOf(w to 10), worldProgress = mapOf(w to 9), revision = 3, deviceID = "A")
        val stale = ProgressSnapshot(worldStage = mapOf(w to 9), worldProgress = mapOf(w to 9), revision = 9, deviceID = "B")
        val m = ProgressSnapshot.ratchetMerged(here, stale)
        assertEquals(10, m.worldStage[w])
    }

    @Test fun worldStage_encodeDecodeRoundTrip() {
        val s = ProgressSnapshot(worldStage = mapOf("math_kingdom" to 23, "logic_lab" to 0), worldProgress = mapOf("math_kingdom" to 9), deviceID = "D")
        val wire = s.toFirestore()
        assertEquals(mapOf("math_kingdom" to 23, "logic_lab" to 0), wire["worldStage"])
        val back = ProgressSnapshot.fromFirestore(wire)
        assertEquals(s.worldStage, back.worldStage)
        assertEquals(s, back)
        // Firestore hands numbers back as Long.
        val fromCloud = ProgressSnapshot.fromFirestore(mapOf("worldStage" to mapOf("math_kingdom" to 23L, "logic_lab" to 0L)))
        assertEquals(mapOf("math_kingdom" to 23, "logic_lab" to 0), fromCloud.worldStage)
    }

    @Test fun worldStage_missingKey_decodesEmpty() {
        assertEquals(emptyMap<String, Int>(), ProgressSnapshot.fromFirestore(mapOf("worldProgress" to mapOf("x" to 3L))).worldStage)
    }

    @Test fun worldStage_survivesLocalPersistence() {
        val s = ProgressSnapshot(worldStage = mapOf(w to 17), deviceID = "D")
        val back = KidPersistence.decode(KidPersistence.encode(s, LocalPlayState()))
        assertEquals(mapOf(w to 17), back!!.first.worldStage)
    }

    @Test fun pureStageHelpers_matchTheEngine() {
        assertEquals(30, WorldStage.stage(mapOf(w to 99), emptyMap(), w))
        assertTrue(WorldStage.visited(mapOf(w to 0), emptyMap(), w))
        assertFalse(WorldStage.visited(emptyMap(), mapOf(w to 0), w))
        assertEquals(9, WorldStage.room(30)); assertEquals(2, WorldStage.gradeOffset(30))
    }
}
