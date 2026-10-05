package com.rani.tofy.kid.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/** Ports of ChildTimeTests.swift "Play window lease" + WalletSeconds. */
class PlayWindowLeaseTest {
    private val me = "MY-INSTALL"

    private fun lease(owner: String, granted: Int, startedSecondsAgo: Double,
                      state: PlayWindowLease.State = PlayWindowLease.State.OPEN,
                      kind: PlayWindowLease.Kind = PlayWindowLease.Kind.GIFT) = PlayWindowLease(
        state = state, leaseID = "L1", ownerDeviceID = owner, kind = kind, grantedSeconds = granted,
        startedAt = AppleTime.nowUnix() - startedSecondsAgo,
    )

    @Test fun heldElsewhereBlocks() {
        val l = lease("other-ipad", 3600, 60.0)
        assertTrue(l.isHeld); assertFalse(l.isMine(me)); assertTrue(l.isHeldElsewhere(me = me))
    }

    @Test fun ownWindowDoesNotBlock() {
        val l = lease(me, 3600, 60.0)
        assertTrue(l.isMine(me)); assertFalse(l.isHeldElsewhere(me = me))
    }

    @Test fun remainingIsDerived() {
        assertTrue(abs(lease("other", 600, 200.0).remainingSeconds() - 400) <= 1)
    }

    @Test fun remainingFloorsAtZero() {
        assertEquals(0, lease("other", 600, 5000.0).remainingSeconds())
    }

    @Test fun expiredLeaseReleases() {
        val l = lease("other", 600, (600 + PlayWindowLease.EXPIRY_GRACE_SECONDS + 10).toDouble())
        assertTrue(l.isExpired()); assertFalse(l.isHeldElsewhere(me = me))
    }

    @Test fun graceProtectsAgainstSkew() {
        val l = lease("other", 600, 640.0)
        assertFalse(l.isExpired()); assertTrue(l.isHeldElsewhere(me = me))
    }

    @Test fun idleIsNotHeld() {
        val l = lease("other", 600, 10.0, state = PlayWindowLease.State.IDLE)
        assertFalse(l.isHeld); assertFalse(l.isHeldElsewhere(me = me))
        assertTrue(l.copy(state = PlayWindowLease.State.RELEASING).isHeld)
    }

    @Test fun firestoreRoundTrip() {
        val parsed = PlayWindowLease.from(mapOf(
            "state" to "open", "leaseID" to "abc", "ownerDeviceID" to "dev-1",
            "ownerKind" to "iPad", "ownerName" to "האייפד של נועה",
            "kind" to "gift", "grantedSeconds" to 3600L,
            "startedAt" to AppleTime.nowUnix() - 120, "lastReleasedLeaseID" to "zzz",
        ))
        assertEquals(PlayWindowLease.State.OPEN, parsed.state)
        assertEquals("abc", parsed.leaseID)
        assertEquals(PlayWindowLease.Kind.GIFT, parsed.kind)
        assertEquals(3600, parsed.grantedSeconds)
        assertEquals("האייפד של נועה", parsed.ownerName)
        assertEquals("zzz", parsed.lastReleasedLeaseID)
        assertTrue(abs(parsed.remainingSeconds() - 3480) <= 2)
    }

    @Test fun serverTimestampStartIsRead() {
        val ts = com.google.firebase.Timestamp(1_700_000_000L, 500_000_000)
        val parsed = PlayWindowLease.from(mapOf("state" to "open", "leaseID" to "x", "startedAt" to ts, "grantedSeconds" to 60L))
        assertEquals(1_700_000_000.5, parsed.startedAt!!, 1e-6)
    }

    @Test fun garbageReadsAsIdle() {
        val parsed = PlayWindowLease.from(mapOf("state" to "🤷", "grantedSeconds" to "lots"))
        assertEquals(PlayWindowLease.State.IDLE, parsed.state)
        assertFalse(parsed.isHeld)
    }

    // ── WalletSeconds ───────────────────────────────────────────────────────
    @Test fun handoffKeepsTheSeconds() {
        val s = WalletSeconds.spend(want = 38 * 60 + 50, minutes = 38, carry = 50)
        assertEquals(38 * 60 + 50, s.granted); assertEquals(38, s.minutesOut); assertEquals(0, s.carryLeft)
    }

    @Test fun transferConservesTime() {
        var minutes = 60; var carry = 0
        repeat(12) {
            val s = WalletSeconds.spend(minutes * 60 + carry, minutes, carry)
            minutes -= s.minutesOut; carry = s.carryLeft
            assertTrue(minutes >= 0)
            val r = WalletSeconds.refund(maxOf(0, s.granted - 70), carry)
            minutes += r.minutesIn; carry = r.carryLeft
        }
        assertEquals(3600 - 840, minutes * 60 + carry)
    }

    @Test fun spendIsBounded() {
        val s = WalletSeconds.spend(99 * 60, 3, 20)
        assertEquals(3 * 60 + 20, s.granted); assertEquals(3, s.minutesOut); assertEquals(0, s.carryLeft)
    }

    @Test fun partialMinuteIsCharged() {
        val s = WalletSeconds.spend(30, 5, 0)
        assertEquals(30, s.granted); assertEquals(1, s.minutesOut); assertEquals(30, s.carryLeft)
        assertEquals(5 * 60, (5 - s.minutesOut) * 60 + s.carryLeft + s.granted)
    }
}
