package com.rani.tofy.kid.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.CompositionLocalProvider
import com.rani.tofy.data.ChildRepository
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * ParentGateView in VERIFY mode with respectSession:false — the device is in
 * the kid's hands, so EVERY open asks for the code again, and this gate never
 * offers to CREATE a parent code (allowSetup:false — whoever holds the device
 * could mint one and walk through). The code is checked against the family's
 * `households/{hid}.parentPinHash` ("salt:hash", sha256), the authoritative
 * one. On a child device each unlock pings the parents (parentGateOpened).
 *
 * @param pinHash null while the family is still loading → spinner, then the
 *        honest "not available here" once [householdLoaded].
 */
@Composable
fun ParentGate(
    pinHash: String?,
    householdLoaded: Boolean,
    title: String? = null,
    reason: String? = null,
    onAuthorized: () -> Unit,
    onClose: () -> Unit,
) {
    BackHandler(onBack = onClose)
    var entered by remember { mutableStateOf("") }
    val shake = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()

    fun verify() {
        if (ChildRepository.verifyPin(pinHash, entered)) {
            entered = ""
            // On a CHILD's device the parent usually isn't there — tell them the
            // parent controls were opened (Kid Mode is the parent's own phone).
            if (!KidSession.kidMode) KidSession.reportEvent("parentGateOpened")
            onAuthorized()
        } else {
            scope.launch {
                for (x in listOf(-10f, 10f, -8f, 8f, -4f, 0f)) shake.animateTo(x, androidx.compose.animation.core.tween(45))
                entered = ""
            }
        }
    }

    GlassBackdrop {
        when {
            pinHash == null && !householdLoaded -> FamilyLoadingGate()
            pinHash == null -> Column(
                Modifier.fillMaxSize().systemBarsPadding().padding(28.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
            ) {
                Text("🔐", fontSize = 56.sp)
                KidTitle(tr("קוֹד הַהוֹרֶה לֹא זָמִין כָּאן"), 26)
                KidBody(tr("קוֹד הַהוֹרֶה שֶׁל הַמִּשְׁפָּחָה עֲדַיִן לֹא הִגִּיעַ לַמַּכְשִׁיר הַזֶּה (בִּדְקוּ חִבּוּר לָאִינְטֶרְנֶט). אֶפְשָׁר תָּמִיד לְאַפֵּס מִלּוּחַ הַהוֹרִים בַּמַּכְשִׁיר שֶׁל אַבָּא אוֹ אִמָּא."), 16f, alpha = 0.85f)
                Text(tr("סְגִירָה"), Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.14f))
                    .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(50)).clickable(onClick = onClose)
                    .padding(horizontal = 34.dp, vertical = 13.dp),
                    color = Color.White, fontFamily = com.rani.tofy.ui.theme.Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
            }
            else -> Column(
                Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text("🔒", fontSize = 48.sp, modifier = Modifier.padding(top = 36.dp))
                KidTitle(title ?: tr("הַגְדָּרוֹת הוֹרֶה"), 28)
                KidBody(reason ?: tr("הַזִּינוּ קוֹד בֶּן 4 סְפָרוֹת"), 16f, alpha = 0.8f, weight = FontWeight.Medium)
                PinDots(entered.length, Modifier.graphicsLayer { translationX = shake.value * density })
                VSpace(14)
                PinPad { key ->
                    if (key == "⌫") { if (entered.isNotEmpty()) entered = entered.dropLast(1) }
                    else if (entered.length < 4) { entered += key; if (entered.length == 4) verify() }
                }
            }
        }
        Box(Modifier.align(Alignment.TopStart).systemBarsPadding().padding(14.dp)) { CloseCircle(onClose) }
    }
}

/** Ten seconds of spinner, then an honest message (ParentGateView.familyLoadingGate). */
@Composable
private fun FamilyLoadingGate() {
    var timedOut by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { delay(10_000); timedOut = true }
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            Modifier.padding(24.dp).widthIn(max = 360.dp).glassPane(24.dp).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (timedOut) {
                Text("📡", fontSize = 44.sp)
                KidTitle(tr("הַמַּכְשִׁיר לֹא הִצְלִיחַ לְהִתְחַבֵּר לַמִּשְׁפָּחָה"), 19)
                KidBody(tr("בִּדְקוּ שֶׁיֵּשׁ אִינְטֶרְנֶט, וְשֶׁהַמַּכְשִׁיר עֲדַיִן מְקֻשָּׁר לַמִּשְׁפָּחָה בְּלוּחַ הַהוֹרִים."), 14f, weight = FontWeight.Medium)
            } else {
                CircularProgressIndicator(color = Color.White)
                KidTitle(tr("טוֹעֲנִים אֶת הַמִּשְׁפָּחָה שֶׁלָּכֶם…"), 20)
                KidBody(tr("רֶגַע אֶחָד…"), 14f, weight = FontWeight.Medium)
            }
        }
    }
}

/** The four code dots. */
@Composable
fun PinDots(count: Int, modifier: Modifier = Modifier) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
        repeat(4) { i ->
            Box(
                Modifier.size(26.dp).clip(CircleShape).background(if (i < count) Color.White else Color.Transparent)
                    .border(2.dp, Color.White.copy(alpha = 0.7f), CircleShape),
            )
        }
    }
}

/** The 3×4 round keypad — always laid out left-to-right, like a phone's. */
@Composable
fun PinPad(keySize: Int = 76, onKey: (String) -> Unit) {
    val rows = listOf(listOf("1", "2", "3"), listOf("4", "5", "6"), listOf("7", "8", "9"), listOf("", "0", "⌫"))
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            rows.forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(22.dp)) {
                    row.forEach { key ->
                        if (key.isEmpty()) Box(Modifier.size(keySize.dp))
                        else Box(
                            Modifier.size(keySize.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f))
                                .border(1.dp, Color.White.copy(alpha = 0.32f), CircleShape).clickable { onKey(key) },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(key, color = Color.White, fontFamily = com.rani.tofy.ui.theme.Rounded, fontWeight = FontWeight.SemiBold,
                                fontSize = (keySize * (if (key == "⌫") 0.34f else 0.42f)).sp)
                        }
                    }
                }
            }
        }
    }
}
