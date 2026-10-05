package com.rani.tofy.kid.content

import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.ui.child.Topic
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File

class ContentAssetsTest {
    @Before fun setUp() = ContentTestSupport.install()

    private val manifest by lazy {
        Json.parseToJsonElement(File(ContentTestSupport.assetsDir, "content/manifest.json").readText()).jsonObject
    }

    @Test fun bankCountsMatchTheManifestForEveryLanguageAndTopic() {
        for (lang in AppLanguage.entries) {
            val expected = manifest["banks"]!!.jsonObject[lang.code]!!.jsonObject
            val banks = ContentAssets.banks(lang)
            assertEquals("topics in $lang", expected.keys, banks.keys)
            for ((topic, n) in expected) assertEquals("$lang/$topic", n.jsonPrimitive.int, banks[topic]!!.size)
            val reading = manifest["reading"]!!.jsonObject[lang.code]!!.jsonObject
            val passages = ContentAssets.passages(lang)
            assertEquals("$lang passages", reading["passages"]!!.jsonPrimitive.int, passages.size)
            assertEquals("$lang reading questions", reading["questions"]!!.jsonPrimitive.int, passages.sumOf { it.questions.size })
        }
    }

    @Test fun exportCrossCheckHasNoSilentDrops() {
        val cc = manifest["crossCheck"]!!.jsonObject
        assertEquals(cc["swiftLiterals"]!!.jsonPrimitive.int, cc["exportedItems"]!!.jsonPrimitive.int)
    }

    @Test fun everyTopicKeyIsAKnownTopicId() {
        for (lang in AppLanguage.entries) for (k in ContentAssets.banks(lang).keys) assertTrue("$lang:$k", Topic.of(k) != null)
        for (k in ContentAssets.bonus().keys) assertTrue(k, Topic.of(k) != null)
    }

    @Test fun everyBuiltInItemIsPlayable() {
        for (lang in AppLanguage.entries) {
            val all = ContentAssets.banks(lang).values.flatten() + ContentAssets.passages(lang).flatMap { it.questions }
            for (q in all) {
                assertTrue("${q.key} distractors", q.distractors.size >= 3)
                assertFalse("${q.key} answer among distractors", q.distractors.contains(q.correctAnswer))
                assertEquals("${q.key} duplicate distractors", q.distractors.size, q.distractors.toSet().size)
                assertTrue("${q.key} grades", q.gradeLo in 0..8 && q.gradeHi in q.gradeLo..8)
            }
        }
    }

    @Test fun languageRoutingMatchesIos() {
        // The Hebrew world is served IN HEBREW to ru/ar children, hidden in English.
        val heHebrew = QuestionBanks.bank(Topic.HEBREW, AppLanguage.HE)!!
        assertEquals(heHebrew, QuestionBanks.bank(Topic.HEBREW, AppLanguage.RU))
        assertEquals(heHebrew, QuestionBanks.bank(Topic.HEBREW, AppLanguage.AR))
        assertTrue(QuestionBanks.bank(Topic.HEBREW, AppLanguage.EN)!!.isEmpty())
        // Generated / passage topics have no bank at all.
        assertNull(QuestionBanks.bank(Topic.MATH, AppLanguage.HE))
        assertNull(QuestionBanks.bank(Topic.READING, AppLanguage.EN))
        // English space is the US-adapted catalog, not Hebrew.
        assertTrue(QuestionBanks.bank(Topic.SPACE, AppLanguage.EN)!!.first().prompt.contains("Sun"))
    }

    @Test fun contentAvailabilityHidesThinOrForeignWorlds() {
        assertTrue(ContentAvailability.hasContent(Topic.HOLIDAYS, AppLanguage.AR))
        assertFalse(ContentAvailability.hasContent(Topic.HOLIDAYS, AppLanguage.HE))
        assertFalse(ContentAvailability.hasContent(Topic.HEBREW, AppLanguage.EN))
        assertTrue(ContentAvailability.hasContent(Topic.HEBREW, AppLanguage.RU))
        assertFalse("no Israel pack in English", ContentAvailability.hasContent(Topic.ISRAEL, AppLanguage.EN))
        assertFalse("no Tishrei pack in Arabic", ContentAvailability.hasContent(Topic.TISHREI, AppLanguage.AR))
        for (lang in AppLanguage.entries) {
            assertTrue(ContentAvailability.hasContent(Topic.MATH, lang))
            assertTrue(ContentAvailability.hasContent(Topic.READING, lang))
        }
    }

    @Test fun bonusPoolIsHebrewOnlyAndHard() {
        val pools = ContentAssets.bonus()
        assertEquals(setOf("english", "hebrew", "logic", "science", "history", "geography", "money"), pools.keys)
        assertTrue(pools.values.flatten().all { it.difficulty == com.rani.tofy.ui.child.Difficulty.HARD })
    }
}
