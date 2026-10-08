package com.rani.tofy.kid.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.play.agesignals.AgeSignalsAccessRequest
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.model.AgeSignalsStatus
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.GoldButton
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.tasks.await
import java.util.Calendar

/**
 * 🧒🚫 Before a device becomes a PARENT device: is a grown-up holding it?
 * Twice a child installed Tofy and opened a family as its "parent" (Rani,
 * 2026-10-08). iOS twin: AgeGateView.swift. First Google Play is asked (Play
 * Age Signals — live only where the law requires it so far, so usually no
 * answer); no answer → a neutral birth-year wheel that starts on a child's
 * year; under 18 → a friendly screen with the ways forward. Only the verdict
 * is kept, never the year or the range.
 */
object AgeGate {
    enum class Verdict { ADULT, MINOR }

    private const val KEY = "ageGate.verdict"

    /** The wheel opens on a CHILD's year (Rani: "שיבלבל את הילדים"). */
    const val WHEEL_START = 2016

    fun verdict(ctx: Context): Verdict? =
        ctx.getSharedPreferences("tofy", Context.MODE_PRIVATE).getString(KEY, null)
            ?.let { runCatching { Verdict.valueOf(it) }.getOrNull() }

    fun record(ctx: Context, v: Verdict) {
        ctx.getSharedPreferences("tofy", Context.MODE_PRIVATE).edit().putString(KEY, v.name).apply()
    }

    fun verdictForBirthYear(year: Int): Verdict =
        if (Calendar.getInstance().get(Calendar.YEAR) - year >= 18) Verdict.ADULT else Verdict.MINOR

    /** Google's answer, or null when there is none (region, declined, error). */
    suspend fun askGoogle(ctx: Context): Verdict? = try {
        val manager = AgeSignalsManagerFactory.create(ctx.applicationContext)
        val activity = ctx.findActivity()
        val access = manager.requestAgeSignalsAccess(
            AgeSignalsAccessRequest.builder().apply { if (activity != null) setActivity(activity) }.build()
        ).await()
        if (access.ageSignalsStatus() != AgeSignalsStatus.SHARED) null
        else {
            val r = manager.checkAgeSignals(AgeSignalsRequest.builder().build()).await()
            val low = r.ageLower(); val high = r.ageUpper()
            when {
                low != null && low >= 18 -> Verdict.ADULT
                high != null && high < 18 -> Verdict.MINOR
                else -> null
            }
        }
    } catch (e: Exception) {
        Log.i("AgeGate", "Play age signals unavailable: ${e.message}")
        null
    }

    private fun Context.findActivity(): Activity? {
        var c: Context? = this
        while (c is ContextWrapper) { if (c is Activity) return c; c = c.baseContext }
        return null
    }
}

/** "מָה שְׁנַת הַלֵּידָה שֶׁלָּכֶם?" — the neutral question, when Google gave no answer. */
@Composable
internal fun AgeGateYear(onAnswer: (AgeGate.Verdict) -> Unit, onCancel: () -> Unit) {
    val years = remember { (1930..Calendar.getInstance().get(Calendar.YEAR)).reversed().toList() }
    val rowH = 40.dp
    val state = rememberLazyListState(initialFirstVisibleItemIndex = years.indexOf(AgeGate.WHEEL_START).coerceAtLeast(0))
    val selected by remember { derivedStateOf { years.getOrElse(state.firstVisibleItemIndex) { AgeGate.WHEEL_START } } }
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(Modifier.fillMaxWidth()) { Box(Modifier.align(Alignment.TopEnd)) { CloseCircle(onCancel) } }
            CharacterImage("lion", Modifier.size(104.dp))
            KidTitle(tr("שְׁאֵלָה קְטַנָּה לִפְנֵי שֶׁמַּתְחִילִים"), 25)
            KidBody(tr("מָה שְׁנַת הַלֵּידָה שֶׁלָּכֶם?"), 17f, alpha = 0.9f)
            // A wheel: five rows, the middle one is the answer, flings snap to a row.
            Box(
                Modifier.widthIn(max = 440.dp).fillMaxWidth().padding(top = 8.dp).height(rowH * 5)
                    .clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.12f))
                    .border(1.dp, Color.White.copy(alpha = 0.28f), RoundedCornerShape(16.dp)),
            ) {
                Box(
                    Modifier.align(Alignment.Center).padding(horizontal = 10.dp).fillMaxWidth().height(rowH)
                        .clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.18f)),
                )
                LazyColumn(
                    Modifier.fillMaxSize(), state = state, flingBehavior = rememberSnapFlingBehavior(state),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = rowH * 2),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    itemsIndexed(years) { i, y ->
                        val d = kotlin.math.abs(i - state.firstVisibleItemIndex)
                        Box(Modifier.height(rowH).fillMaxWidth(), contentAlignment = Alignment.Center) {
                            Text(
                                y.toString(), color = Color.White, fontFamily = Rounded,
                                fontWeight = if (d == 0) FontWeight.Black else FontWeight.Bold,
                                fontSize = if (d == 0) 24.sp else 20.sp,
                                modifier = Modifier.alpha(if (d == 0) 1f else if (d == 1) 0.6f else 0.35f),
                            )
                        }
                    }
                }
            }
            Text("🔒 " + tr("הַשָּׁנָה לֹא נִשְׁמֶרֶת וְלֹא נִשְׁלַחַת לְשׁוּם מָקוֹם"),
                color = Color.White.copy(alpha = 0.78f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            Box(Modifier.weight(1f))
            GoldButton(tr("הַמְשֵׁךְ"), Modifier.widthIn(max = 440.dp)) { onAnswer(AgeGate.verdictForBirthYear(selected)) }
        }
    }
}

/** Under 18: no sign-up, no scolding — the two ways forward instead. */
@Composable
internal fun AgeGateMinor(onHaveCode: () -> Unit, onClose: () -> Unit) {
    val ctx = LocalContext.current
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(Modifier.fillMaxWidth()) { Box(Modifier.align(Alignment.TopEnd)) { CloseCircle(onClose) } }
            CharacterImage("fox", Modifier.size(130.dp))
            KidTitle(tr("נִרְאֶה שֶׁזֶּה הַמַּכְשִׁיר שֶׁל הַיֶּלֶד 😊"), 25)
            KidBody(tr("אֶת הַמִּשְׁפָּחָה בְּטוֹפִי פּוֹתְחִים מֵהַטֶּלֶפוֹן שֶׁל אַבָּא אוֹ אִמָּא — וּמִשָּׁם מְחַבְּרִים גַּם אֶת הַמַּכְשִׁיר הַזֶּה, וּמַתְחִילִים לְשַׂחֵק וּלְהַרְוִיחַ דַּקּוֹת!"), 16f, alpha = 0.9f)
            Box(Modifier.weight(1f))
            Column(Modifier.widthIn(max = 440.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                // The site links both stores.
                GoldButton(tr("📨 לִשְׁלֹחַ קִשּׁוּר לְאַבָּא אוֹ לְאִמָּא")) {
                    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, "https://tofyapp.com")
                    ctx.startActivity(Intent.createChooser(send, null))
                }
                Box(
                    Modifier.fillMaxWidth().height(50.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.16f))
                        .border(1.dp, Color.White.copy(alpha = 0.32f), RoundedCornerShape(16.dp)).clickable(onClick = onHaveCode),
                    contentAlignment = Alignment.Center,
                ) { Text(tr("🔑 יֵשׁ לִי קוֹד מֵהַהוֹרֶה"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 16.sp) }
            }
        }
    }
}
