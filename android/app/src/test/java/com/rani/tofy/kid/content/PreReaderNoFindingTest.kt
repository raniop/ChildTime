package com.rani.tofy.kid.content

import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

/** Ben David, 2026-10-23: "איפה האדום איפה הכתום". Above easy a גן world never asks "where is…" (PreReaderContentTests.noFindingAboveEasy). */
class PreReaderNoFindingTest {
    @Test fun noFindingAboveEasy() {
        for (topic in listOf(Topic.SCIENCE, Topic.HISTORY, Topic.ENGLISH, Topic.SOCCER, Topic.LOGIC)) {
            for (d in listOf(Difficulty.MEDIUM, Difficulty.HARD)) {
                repeat(60) { seed ->
                    val q = PreReaderContent.generate(topic, Random(seed), d)
                    assertFalse("$topic $d: ${q.readAloudText}", q.readAloudText.contains("אֵיפֹה"))
                }
            }
        }
    }

    @Test fun theThinkingRoundsAreSound() {
        repeat(200) { seed ->
            val odd = PreReaderContent.oddOneOut(Topic.LOGIC, Random(seed))
            assertEquals(4, odd.options.toSet().size)
            val p = PreReaderContent.nextInPattern(Topic.LOGIC, Random(seed))
            assertEquals(4, p.options.size)
            assertTrue(p.correctIndex in p.options.indices)
            // The answer continues the shown pattern.
            val shown = p.prompt.split(" ").dropLast(1)
            val unit = if (shown.size == 4) 2 else 3
            assertEquals(shown[shown.size - unit], p.options[p.correctIndex])
        }
    }
}
