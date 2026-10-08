package com.rani.tofy.ui.onboarding

import com.rani.tofy.ui.common.contentColumn

import android.content.Context
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.data.ChildRepository
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.H
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Device-local copy of the family parent code (PINManager's stored blob) for a later parent gate. */
object LocalParentPin {
    private const val KEY = "parentPinBlob"
    private fun prefs(ctx: Context) = ctx.applicationContext.getSharedPreferences("tofy", Context.MODE_PRIVATE)
    fun blob(ctx: Context): String? = prefs(ctx).getString(KEY, null)
    fun store(ctx: Context, blob: String) { prefs(ctx).edit().putString(KEY, blob).apply() }
}

/** ParentGateView.isWeakPIN: 0000, 1234 / 4321, 1212. */
fun isWeakPIN(pin: String): Boolean {
    val d = pin.mapNotNull { it.digitToIntOrNull() }
    if (d.size != 4) return false
    if (d.toSet().size == 1) return true
    val steps = d.zipWithNext { a, b -> b - a }
    if (steps.all { it == 1 } || steps.all { it == -1 }) return true
    return d[0] == d[2] && d[1] == d[3]
}

/**
 * ParentGateView.swift setup mode, as step ① of the new-parent flow
 * (`onboardingSetup`): choose 4 digits, type them again, then the code becomes
 * the household's `parentPinHash` (the same salted blob the child's iPad
 * verifies). The household listener then moves AppNav on by itself.
 */
@Composable
fun ParentPinSetupScreen(onDone: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var entered by remember { mutableStateOf("") }
    var first by remember { mutableStateOf<String?>(null) }
    var weak by remember { mutableStateOf(false) }
    var mismatch by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf(false) }
    val shake = remember { Animatable(0f) }

    fun save(pin: String) {
        busy = true; error = false
        scope.launch {
            // A household write: on a permission error re-add ourselves to
            // parentUIDs and try once more (the command-delivery rule).
            val ok = runCatching { ChildRepository.setHouseholdPIN(pin) }.isSuccess || run {
                FamilyRepository.reassertMembership()
                runCatching { ChildRepository.setHouseholdPIN(pin) }.isSuccess
            }
            if (ok) {
                LocalParentPin.store(ctx, ChildRepository.pinBlob(pin))
                onDone()
            } else {
                busy = false; error = true
                entered = ""; first = null; weak = false
            }
        }
    }

    fun verify() {
        val f = first
        if (f == null) {
            // This code guards the screen-time controls and the child watches it typed.
            weak = isWeakPIN(entered); mismatch = false; first = entered; entered = ""
        } else if (entered == f) {
            save(entered)
        } else {
            scope.launch {
                repeat(3) { shake.animateTo(-10f, tween(40)); shake.animateTo(10f, tween(40)) }
                shake.animateTo(0f, tween(40))
                delay(300)
                entered = ""; first = null; weak = false; mismatch = true
            }
        }
    }

    fun key(k: String) {
        if (busy) return
        if (k == "⌫") { entered = entered.dropLast(1); return }
        if (entered.length >= 4) return
        entered += k
        if (entered.length == 4) verify()
    }

    val subtitle = when {
        first == null -> if (mismatch) tr("הקודים לא תאמו — בוחרים קוד שוב") else tr("4 ספרות")
        weak -> tr("⚠️ קוד קל לניחוש — הילד רואה אתכם מקלידים אותו. אפשר לאשר בכל זאת, או לחזור ולבחור אחר.")
        else -> tr("מקלידים שוב, לאישור")
    }

    GlassBackdrop {
        Column(
            Modifier.contentColumn().fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            StepsHeader(step = 1)
            Spacer(Modifier.height(20.dp))
            Column(Modifier.widthIn(max = 460.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("🔒", fontSize = 44.sp)
                H(tr("בוחרים קוד הורה"), 28, align = TextAlign.Center)
                P(
                    tr("קוד שרק אתם יודעים — כך הילדים לא ישנו הגדרות ולא יפתחו לעצמם זמן מסך. תצטרכו אותו גם בטלפון של הילד."),
                    14.5f, Modifier.fillMaxWidth().glassPane(16.dp).padding(12.dp), color = Color.White.copy(alpha = 0.92f),
                    weight = FontWeight.SemiBold, align = TextAlign.Center,
                )
                P(if (error) tr("נסו שוב") else subtitle, 16f, color = if (error) Ink.warn else Color.White.copy(alpha = 0.8f), align = TextAlign.Center)
                // A code fills left to right, like every number (Rani).
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                    Row(Modifier.offset(x = shake.value.dp).padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                        repeat(4) { i ->
                            Box(Modifier.size(26.dp).clip(CircleShape).background(if (i < entered.length) Color.White else Color.Transparent)
                                .border(2.dp, Color.White.copy(alpha = 0.7f), CircleShape))
                        }
                    }
                }
                // Always laid out (hidden until the confirm step) so the keypad never jumps under the thumb.
                Text(
                    "↩︎ " + tr("בחירת קוד אחר"),
                    Modifier.alpha(if (first != null) 1f else 0f).clickable(enabled = first != null) {
                        entered = ""; first = null; weak = false; mismatch = false
                    },
                    color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp,
                )
            }
            Spacer(Modifier.height(24.dp))
            Keypad(::key)
        }
    }
}

/** 1–9, 0, ⌫ — always left-to-right like a phone keypad, in every language. */
@Composable
fun Keypad(onKey: (String) -> Unit) {
    val rows = listOf(listOf("1", "2", "3"), listOf("4", "5", "6"), listOf("7", "8", "9"), listOf("", "0", "⌫"))
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            rows.forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(22.dp)) {
                    row.forEach { k ->
                        if (k.isEmpty()) Spacer(Modifier.size(74.dp))
                        else Box(
                            Modifier.size(74.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f))
                                .border(1.dp, Color.White.copy(alpha = 0.32f), CircleShape).clickable { onKey(k) },
                            contentAlignment = Alignment.Center,
                        ) { Text(k, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = if (k == "⌫") 24.sp else 31.sp) }
                    }
                }
            }
        }
    }
}
