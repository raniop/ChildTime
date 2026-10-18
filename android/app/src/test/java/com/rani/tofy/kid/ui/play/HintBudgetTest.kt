package com.rani.tofy.kid.ui.play

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** 💡 Three hints a round (QuestionRunnerView.maxHintsPerRound, 2026-10-18). */
class HintBudgetTest {
    @Test fun theFourthHintInARoundIsRefused() {
        val h = HintBudget()
        repeat(3) { assertTrue(h.tryUse()) }
        assertEquals(0, h.left)
        assertFalse(h.tryUse())
        assertEquals(3, h.used)
    }

    @Test fun aNewRoundStartsFull() {
        val h = HintBudget()
        repeat(3) { h.tryUse() }
        h.reset()
        assertEquals(HintBudget.MAX_PER_ROUND, h.left)
        assertTrue(h.tryUse())
    }
}
