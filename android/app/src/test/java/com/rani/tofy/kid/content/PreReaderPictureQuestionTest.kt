package com.rani.tofy.kid.content

import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.child.Difficulty
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

/** 🧠 גן: thinking questions whose answers are all pictures (PreReaderPictureQuestionTests.swift). */
class PreReaderPictureQuestionTest {
    private fun item(prompt: String, answer: String, wrong: List<String>, lo: Int = 0, hi: Int = 0) =
        BankQuestion(prompt, answer, wrong, Difficulty.EASY, lo, hi)
    private val pictures = (0 until 10).map { item("🔬\nמָה נִהְיֶה מִמַּיִם שֶׁשָּׂמִים בַּמַּקְפִּיא? $it", "🧊", listOf("🔥", "🌈", "🍃")) }

    @Test fun aQuestionWithWordsInItsAnswersIsNotAPictureQuestion() {
        assertTrue(PreReaderContent.isPictureOnly(item("🔬\nמָה?", "🧊", listOf("🔥", "🌈", "🍃"))))
        assertTrue(PreReaderContent.isPictureOnly(item("🎨\nאֵיזֶה צֶבַע?", "🟢", listOf("🟣", "🟠", "🔴"))))
        assertFalse(PreReaderContent.isPictureOnly(item("🌋\nמַה יּוֹצֵא מֵהַר גַּעַשׁ?", "לָבָה", listOf("עָנָן", "חוֹל", "מַיִם"))))
        assertFalse(PreReaderContent.isPictureOnly(item("🔢\nכַּמָּה?", "3", listOf("🍎", "🍌", "🍓"))))
        assertFalse(PreReaderContent.isPictureOnly(item("🔬\nמָה?", "🧊", listOf("🔥", "🌈"))))
    }

    @Test fun onlyKindergartenPictureItemsAreUsedAndAThinPoolWaits() {
        val words = (0 until 10).map { item("🔬\nשְׁאֵלָה $it", "לָבָה", listOf("עָנָן", "חוֹל", "מַיִם")) }
        val olderKids = (0 until 10).map { item("🔬\nשְׁאֵלָה $it", "🧊", listOf("🔥", "🌈", "🍃"), 2, 3) }
        assertNull(PreReaderContent.pictureQuestion(words, Topic.SCIENCE))
        assertNull(PreReaderContent.pictureQuestion(olderKids, Topic.SCIENCE))
        assertNull(PreReaderContent.pictureQuestion(pictures.take(PreReaderContent.MIN_PICTURE_POOL - 1), Topic.SCIENCE))
        assertNotNull(PreReaderContent.pictureQuestion(pictures.take(PreReaderContent.MIN_PICTURE_POOL), Topic.SCIENCE))
    }

    @Test fun theQuestionKeepsItsFourPicturesAndIsReadWithoutThePictureLine() {
        repeat(20) { seed ->
            val q = PreReaderContent.pictureQuestion(pictures, Topic.SCIENCE, Random(seed))!!
            assertEquals(setOf("🧊", "🔥", "🌈", "🍃"), q.options.toSet())
            assertEquals("🧊", q.options[q.correctIndex])
            assertTrue(q.spoken!!.startsWith("מָה נִהְיֶה"))
            assertFalse(q.spoken!!.contains("🔬"))
            assertEquals("🔬", q.prompt)          // the question is written once, the picture under it
        }
    }
}
