package com.rani.tofy.kid.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/** 🎬 The first run (iOS `DemoTourTests`): when the one question is asked. */
class FirstRunTest {
    @Test fun theQuestionComesAfterFourAnswersAndThenEveryFive() {
        assertEquals(listOf(4, 9, 14, 19), (1..20).filter { FirstRun.asks(it) })
    }

    @Test fun nothingIsCountedOutsideAFirstRun() {
        assertFalse(FirstRun.isOn)
        assertFalse(FirstRun.noteAnswer(correct = true))
        assertEquals(0, FirstRun.answered)
    }
}
