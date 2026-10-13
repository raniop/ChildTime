package com.rani.tofy.ui

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.rani.tofy.data.Child
import com.rani.tofy.data.ChildDevice
import com.rani.tofy.data.ChildReportRepository
import com.rani.tofy.data.DailyStat
import com.rani.tofy.data.Doc
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.FamilyState
import com.rani.tofy.data.Household
import com.rani.tofy.data.Progress
import com.rani.tofy.data.nowAppleSecs
import com.rani.tofy.data.nowSecs
import com.rani.tofy.ui.child.dayKey
import com.rani.tofy.ui.common.CoachTours
import java.util.Calendar

/**
 * 🧪 Debug builds only — a made-up family for looking at the parent's screens
 * on an emulator with no account (`--es demoScreen parenthome|childreport|
 * childsettings|gift|settings`). Nothing here reaches the network: the family
 * is put straight into the repositories' state, and the rules know no such
 * family, so nothing of it could be written either.
 */
internal object DemoFamily {
    const val NONI = "DEMO-CHILD-NONI"
    const val DAN = "DEMO-CHILD-DAN"

    fun seed(ctx: Context) {
        // The home must show itself, not its first-run tour or the notifications ask.
        ctx.getSharedPreferences("tofy", Context.MODE_PRIVATE).edit()
            .putBoolean("notif.autoAsked", true).putInt("whatsNew.seenCode", Int.MAX_VALUE).apply()
        CoachTours.markDone(CoachTours.PARENT_HOME)

        val now = nowSecs()
        val household = Household.from("DEMO-FAMILY", mapOf(
            "parentUIDs" to listOf("demo-parent"), "childIDs" to listOf(NONI, DAN), "createdBy" to "demo-parent",
            "familyName" to "משפחת גולן", "parentPinHash" to "demo", "childOrder" to listOf(NONI, DAN),
        ))
        val noni = Child.from(NONI, mapOf(
            "householdID" to "DEMO-FAMILY", "name" to "נוני", "age" to 10, "gender" to "girl", "avatarPresetID" to "fox",
            "grade" to 6, "gradeSchoolYear" to com.rani.tofy.data.schoolYear(), "dailyCapMinutes" to 60, "language" to "he",
            "difficultyByTopic" to mapOf("math" to "medium", "english" to "medium", "hebrew" to "medium", "science" to "medium"),
            "playPIN" to "2468", "createdAt" to now - 90 * 86400, "learningLevel" to "proficient",
        ))
        val dan = Child.from(DAN, mapOf(
            "householdID" to "DEMO-FAMILY", "name" to "דן", "age" to 8, "gender" to "boy", "avatarPresetID" to "fox",
            "grade" to 3, "gradeSchoolYear" to com.rani.tofy.data.schoolYear(), "language" to "he", "createdAt" to now - 80 * 86400,
        ))
        val devices = listOf(
            ChildDevice.from("${NONI}_ipad", mapOf("childID" to NONI, "householdID" to "DEMO-FAMILY", "deviceID" to "d1", "name" to "האייפד של נוני",
                "kind" to "ipad", "lastSeenAt" to now - 20, "joinedAt" to now - 60 * 86400, "shieldAuthorized" to true)),
            ChildDevice.from("${NONI}_phone", mapOf("childID" to NONI, "householdID" to "DEMO-FAMILY", "deviceID" to "d2", "name" to "iPhone",
                "kind" to "iphone", "lastSeenAt" to now - 3 * 3600, "joinedAt" to now - 30 * 86400, "shieldAuthorized" to true)),
        )
        FamilyRepository.demoSeed(FamilyState(
            loading = false, household = household, children = listOf(noni, dan), devices = devices,
            progress = mapOf(NONI to Progress.from(noniState), DAN to Progress.EMPTY),
            childrenLoaded = true, householdFromServer = true,
        ))
        ChildReportRepository.demoSeed(mapOf(NONI to history()), mapOf(NONI to noniState))
    }

    /** state/current, in its own encoding (Apple-reference dates). */
    private val noniState: Doc get() = mapOf(
        "dailyEarnedDate" to nowAppleSecs(), "answeredToday" to 24, "correctToday" to 20, "minutesEarnedToday" to 16,
        "stars" to 1840, "diamonds" to 35, "dayStreak" to 4, "totalAnswered" to 620, "totalCorrect" to 498,
        "giftSecondsIn" to 2700, "giftSecondsOut" to 1980, "giftGivenToday" to 15, "giftGivenDate" to nowAppleSecs(),
        "topicAnswered" to mapOf("math" to 210, "english" to 150, "hebrew" to 120, "science" to 90, "geography" to 50),
        "topicAccuracy" to mapOf("math" to 0.9, "english" to 0.58, "hebrew" to 0.82, "science" to 0.86, "geography" to 0.7),
        "topicAdaptiveLevel" to mapOf("math" to 1.8, "english" to 0.3, "hebrew" to 1.0, "science" to 1.1),
        "topicAffinity" to mapOf("science" to 0.9, "math" to 0.8), "topicExposure" to mapOf("science" to 40, "math" to 60),
        "worldStage" to mapOf("math_kingdom" to 14, "science_lab" to 6, "english_land" to 3, "hebrew_land" to 9),
        "lastModifiedAt" to nowAppleSecs(),
    )

    /** Five weeks of days: steady learning, English the weak spot, a little better this week. */
    private fun history(): List<DailyStat> = (0 until 35).mapNotNull { back ->
        if (back % 6 == 4) return@mapNotNull null   // a day off now and then
        val day = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -back) }
        val recent = back < 7
        val mathQ = 10 + (back * 7) % 6; val engQ = 8 + (back * 5) % 5; val hebQ = 6 + (back * 3) % 4; val sciQ = 5 + back % 4
        val mathC = (mathQ * (if (recent) 0.92 else 0.84)).toInt(); val engC = (engQ * (if (recent) 0.62 else 0.5)).toInt()
        val hebC = (hebQ * 0.84).toInt(); val sciC = (sciQ * 0.88).toInt()
        val q = mathQ + engQ + hebQ + sciQ; val c = mathC + engC + hebC + sciC
        val earned = minOf(60, q / 2 + 4); val used = (earned * (0.5 + (back % 4) * 0.12)).toInt()
        DailyStat(dayKey(day), q, c, q - c, earned, used, 6, q * 20, 2, 2, 0, if (back % 3 == 0) 3 else 0, mapOf(
            "math" to DailyStat.TopicDay(mathQ, mathC, mapOf("mul" to DailyStat.SkillDay(mathQ / 2, mathC / 2), "fractions" to DailyStat.SkillDay(mathQ - mathQ / 2, mathC - mathC / 2))),
            "english" to DailyStat.TopicDay(engQ, engC, null),
            "hebrew" to DailyStat.TopicDay(hebQ, hebC, null),
            "science" to DailyStat.TopicDay(sciQ, sciC, null),
        ))
    }
}

/** The parent's screens over the made-up family; taps move between them like the real navigation. */
@Composable
internal fun DemoParentScreens(screen: String, page: String?) {
    val state by FamilyRepository.state.collectAsState()
    val noni = state.children.firstOrNull { it.id == DemoFamily.NONI } ?: return
    var gift by remember { mutableStateOf(screen == "gift") }
    var show by remember { mutableStateOf(screen) }
    when (show) {
        "childreport" -> com.rani.tofy.ui.child.ChildDetailScreen(noni.id, onBack = { show = "parenthome" })
        "childsettings" -> com.rani.tofy.ui.child.ChildSettingsScreen(noni.id, onBack = { show = "settings" }, onDeleted = {},
            startOnProfile = page == "profile", onConnect = {}, onLocation = {}, demoPage = page)
        "chores" -> com.rani.tofy.ui.chores.ChoresScreen(onBack = { show = "parenthome" })   // the built-in chores, no cloud
        "settings" -> com.rani.tofy.ui.settings.SettingsScreen(onBack = { show = "parenthome" }, onOpenChild = { show = "childsettings" })
        else -> com.rani.tofy.ui.home.HomeScreen(
            state = state, onOpenChild = { show = "childreport" }, onActions = {}, onGift = { gift = true }, onChildSettings = {},
            onAddChild = {}, onChores = {}, onSettings = { show = "settings" }, onBell = {}, onConnectDevice = {}, sheetOpen = gift,
        )
    }
    if (gift) com.rani.tofy.ui.home.GiftMinutesWindow(noni, state) { gift = false }
}
