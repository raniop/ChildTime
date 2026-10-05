package com.rani.tofy.kid.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Rounded

/**
 * KidPINView (.verify) — the CHILD's own "protect my time" code before
 * spending minutes, so a sibling holding the device can't open them. A kid
 * guarding a treasure, not a lock: a wrong code says "almost!", no lockout.
 * Set/change/remove (PlayPINManageView) live on iOS for now.
 */
@Composable
internal fun KidPinVerify(playPIN: String, onSuccess: () -> Unit, onCancel: () -> Unit, onForgot: () -> Unit) {
    BackHandler(onBack = onCancel)
    var entered by remember { mutableStateOf("") }
    var almost by remember { mutableStateOf(false) }
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text("🔒", fontSize = 54.sp, modifier = Modifier.padding(top = 40.dp))
            KidTitle(tr("פּוֹתְחִים זְמַן מִשְׂחָק"), 27)
            KidBody(if (almost) tr("כִּמְעַט! נַסּוּ שׁוּב 💪") else tr("הַזְּמַן הַזֶּה שֶׁלְּךָ — רַק אַתָּה פּוֹתֵחַ אוֹתוֹ"), 15.5f, alpha = 0.85f)
            PinDots(entered.length)
            VSpace(10)
            PinPad { key ->
                if (key == "⌫") { if (entered.isNotEmpty()) entered = entered.dropLast(1); return@PinPad }
                if (entered.length >= 4) return@PinPad
                entered += key
                if (entered.length == 4) {
                    if (entered == playPIN) onSuccess() else { almost = true; entered = "" }
                }
            }
            Text(
                tr("שָׁכַחְתִּי אֶת הַקּוֹד 🤔"),
                Modifier.padding(top = 8.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.12f))
                    .clickable(onClick = onForgot).padding(horizontal = 16.dp, vertical = 9.dp),
                color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.5.sp,
            )
        }
        Box(Modifier.align(Alignment.TopStart).systemBarsPadding().padding(14.dp)) { CloseCircle(onCancel) }
    }
}

/**
 * PlayPINForgotView: "it's OK, it happens to everyone" — the parents are
 * pinged once, and a parent standing here resets it with the PARENT code.
 */
@Composable
internal fun KidPinForgot(
    childName: String, pinHash: String?, householdLoaded: Boolean, onParentReset: () -> Unit, onClose: () -> Unit,
) {
    var gate by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { KidSession.reportEvent("playPINForgot") }
    if (gate) {
        ParentGate(pinHash, householdLoaded, tr("אִפּוּס קוֹד הֲגַנַּת הַזְּמַן"),
            tr("הַזִּינוּ קוֹד הוֹרֶה כְּדֵי לְאַפֵּס אֶת הַקּוֹד שֶׁל %@", childName),
            onAuthorized = { gate = false; onParentReset() }, onClose = { gate = false })
        return
    }
    BackHandler(onBack = onClose)
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
        ) {
            Text("💌", fontSize = 54.sp)
            KidTitle(tr("זֶה בְּסֵדֶר, קוֹרֶה לְכֻלָּם!"), 25)
            KidBody(tr("שָׁלַחְנוּ עַכְשָׁיו הוֹדָעָה לְאַבָּא וּלְאִמָּא 💌\nהֵם רוֹאִים אֶת הַקּוֹד שֶׁלְּךָ בַּלּוּחַ שֶׁלָּהֶם,\nוְיוֹדְעִים אֵיךְ לַעֲזוֹר."), 16f, alpha = 0.9f)
            Column(Modifier.widthIn(max = 340.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                KidCta(tr("אֲנִי הוֹרֶה · אִפּוּס עִם קוֹד הוֹרֶה"), Color(0xFF5E60CE), Color(0xFF3E8BF0), emoji = "🔑", size = 16) { gate = true }
                Text(tr("סְגִירָה"), Modifier.clickable(onClick = onClose).padding(8.dp), color = Color.White.copy(alpha = 0.8f),
                    fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 15.sp)
            }
        }
    }
}
