package com.rani.tofy.update

import com.rani.tofy.update.AppUpdateConfig.State
import com.rani.tofy.update.AppUpdateConfig.Values
import org.junit.Assert.assertEquals
import org.junit.Test

/** "There is a newer Tofy" — the Android numbers (versionCode = iOS build ×10 + n). */
class AppUpdateLogicTest {
    private val mine = 2002

    @Test fun defaultsSayNothing() {
        assertEquals(State.None, AppUpdateLogic.state(Values(), mine))
    }

    @Test fun newerBuildIsRecommended() {
        assertEquals(State.Recommended(2010), AppUpdateLogic.state(Values(latestBuild = 2010), mine))
    }

    @Test fun sameOrOlderBuildSaysNothing() {
        assertEquals(State.None, AppUpdateLogic.state(Values(latestBuild = mine), mine))
        assertEquals(State.None, AppUpdateLogic.state(Values(latestBuild = 2001), mine))
    }

    @Test fun laterIsRememberedPerBuild() {
        // "Later" on 2010 silences 2010 …
        assertEquals(State.None, AppUpdateLogic.state(Values(latestBuild = 2010, dismissedBuild = 2010), mine))
        // … but the NEXT build asks again.
        assertEquals(State.Recommended(2020), AppUpdateLogic.state(Values(latestBuild = 2020, dismissedBuild = 2010), mine))
    }

    @Test fun belowMinBuildIsRequired() {
        assertEquals(State.Required(2005), AppUpdateLogic.state(Values(latestBuild = 2010, minBuild = 2005), mine))
        // "Later" never escapes a required update.
        assertEquals(State.Required(2005), AppUpdateLogic.state(Values(latestBuild = 2010, minBuild = 2005, dismissedBuild = 2010), mine))
    }

    @Test fun minBuildZeroOrMetIsOff() {
        assertEquals(State.None, AppUpdateLogic.state(Values(minBuild = 0), mine))
        assertEquals(State.None, AppUpdateLogic.state(Values(minBuild = mine), mine))
    }

    @Test fun killSwitchSilencesEverything() {
        assertEquals(State.None, AppUpdateLogic.state(Values(latestBuild = 9999, minBuild = 9999, enabled = false), mine))
    }

    @Test fun notesFollowTheAppLanguage() {
        val v = Values(
            notes = listOf("עברית ישנה"),
            notesByLang = mapOf("he" to listOf("עברית"), "en" to listOf("English"), "ru" to emptyList()),
        )
        assertEquals(listOf("עברית"), AppUpdateLogic.notesFor(v, "he"))
        assertEquals(listOf("English"), AppUpdateLogic.notesFor(v, "en"))
        // An empty list for a language is "no list", and Hebrew never leaks into it.
        assertEquals(emptyList<String>(), AppUpdateLogic.notesFor(v, "ru"))
        assertEquals(emptyList<String>(), AppUpdateLogic.notesFor(v, "ar"))
    }

    @Test fun legacyNotesOnlyForHebrew() {
        val v = Values(notes = listOf("תיקון באג", " "))
        assertEquals(listOf("תיקון באג"), AppUpdateLogic.notesFor(v, "he"))
        assertEquals(emptyList<String>(), AppUpdateLogic.notesFor(v, "en"))
    }

    @Test fun mergeReadsTheAndroidFieldsOnly() {
        val d = mapOf<String, Any?>(
            "latestBuild" to 205L, "minBuild" to 204L, "version" to "iOS",       // iOS numbers: ignored
            "latestAndroidBuild" to 2050L, "minAndroidBuild" to 0L, "androidVersion" to "2026.10.20",
            "enabled" to true, "notes" to listOf("א", 3),
            "notesByLang" to mapOf("en" to listOf("A"), "ru" to "not a list", 7 to listOf("x")),
        )
        val v = AppUpdateLogic.merge(Values(dismissedBuild = 2010), d)
        assertEquals(2050, v.latestBuild)
        assertEquals(0, v.minBuild)
        assertEquals("2026.10.20", v.versionName)
        assertEquals(listOf("א"), v.notes)
        assertEquals(mapOf("en" to listOf("A")), v.notesByLang)
        assertEquals(2010, v.dismissedBuild)
    }

    @Test fun mergeKeepsCachedValuesForMissingFields() {
        val cur = Values(latestBuild = 2010, versionName = "x", enabled = false, notes = listOf("n"))
        assertEquals(cur, AppUpdateLogic.merge(cur, emptyMap()))
    }
}
