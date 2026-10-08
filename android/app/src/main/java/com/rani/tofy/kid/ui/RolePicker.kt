package com.rani.tofy.kid.ui

import android.content.Intent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.GoldButton
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane

/**
 * WelcomeIntroView → RolePickerView. The welcome shows once (hasSeenWelcome),
 * then "who uses this device?". On a phone the PARENT card comes first with
 * the gold "מַתְחִילִים כָּאן" badge; the child card says it needs a code from
 * the parent's device, and with no family on this device it first asks
 * (the old dead end, iOS 2026-10-05). The iPad-specific copy/confirm is not
 * ported — Android tablets get the phone layout.
 */
@Composable
internal fun RolePickerFlow(onParent: () -> Unit, onChild: () -> Unit) {
    val ctx = LocalContext.current
    remember { KidBinding.init(ctx) }
    val b by KidBinding.state.collectAsState()
    if (!b.hasSeenWelcome) WelcomeIntro { KidBinding.markWelcomeSeen() }
    else RolePicker(onParent, onChild)
}

@Composable
private fun RolePicker(onParent: () -> Unit, onChild: () -> Unit) {
    val ctx = LocalContext.current
    val b by KidBinding.state.collectAsState()
    var childNeedsCode by remember { mutableStateOf(false) }
    // Nothing on this device points at a family: no bound child (and this is
    // not the parent's phone — on Android a parent account lives in the parent flow).
    val hasNoFamilyHere = b.joinedChildID == null

    fun choose(role: String) {
        KidBinding.setRole(role)
        if (role == "parent") onParent() else onChild()
    }

    // 🧒🚫 Every way to "parent" comes through here (AgeGate.kt): Google's age
    // range first, then the year wheel; a child gets the friendly screen instead.
    var ageStep by remember { mutableStateOf<String?>(null) }   // "year" | "minor"
    val scope = rememberCoroutineScope()
    fun requestParent() {
        when (AgeGate.verdict(ctx)) {
            AgeGate.Verdict.ADULT -> choose("parent")
            AgeGate.Verdict.MINOR -> ageStep = "minor"
            null -> scope.launch {
                val v = AgeGate.askGoogle(ctx)
                if (v == null) ageStep = "year"
                else { AgeGate.record(ctx, v); if (v == AgeGate.Verdict.ADULT) choose("parent") else ageStep = "minor" }
            }
        }
    }
    when (ageStep) {
        "year" -> {
            AgeGateYear(onAnswer = { v ->
                AgeGate.record(ctx, v)
                if (v == AgeGate.Verdict.ADULT) { ageStep = null; choose("parent") } else ageStep = "minor"
            }, onCancel = { ageStep = null })
            return
        }
        "minor" -> {
            AgeGateMinor(onHaveCode = { ageStep = null; choose("child") }, onClose = { ageStep = null })
            return
        }
    }

    val isTablet = androidx.compose.ui.platform.LocalConfiguration.current.smallestScreenWidthDp >= 600
    var confirmParentOnTablet by remember { mutableStateOf(false) }

    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            CharacterImage("fox", Modifier.size(124.dp).padding(top = 8.dp))
            // 🖥️ A tablet is usually the CHILD's device (RolePickerView's isPad):
            // child card first with the "recommended" badge, and the parent card
            // asks once "whose tablet is this?" before going on as a parent.
            KidTitle(if (isTablet) tr("מִי מִשְׁתַּמֵּשׁ בַּטַּאבְּלֶט הַזֶּה?") else tr("מִי מִשְׁתַּמֵּשׁ בַּמַּכְשִׁיר הַזֶּה?"), 26)
            KidBody(if (isTablet) tr("אֶת הַמִּשְׁפָּחָה מְנַהֲלִים בְּדֶרֶךְ כְּלָל מֵהַטֶּלֶפוֹן שֶׁלָּכֶם")
                    else tr("פַּעַם רִאשׁוֹנָה בַּמִּשְׁפָּחָה? מַתְחִילִים כָּאן — בַּמַּכְשִׁיר שֶׁלָּכֶם"), 15f, alpha = 0.9f)
            VSpace(14)
            Column(Modifier.widthIn(max = 460.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                val parentCard = @Composable {
                    RoleCard("👨‍👩‍👧", tr("הַמַּכְשִׁיר שֶׁלִּי (הוֹרֶה)"), tr("מַעֲקָב, דּוּחוֹת וְנִיהוּל"), Ink.gold2,
                        if (isTablet) null else tr("מַתְחִילִים כָּאן")) {
                        if (isTablet) confirmParentOnTablet = true else requestParent()
                    }
                }
                val childCard = @Composable {
                    RoleCard("🧒", tr("הַמַּכְשִׁיר שֶׁל הַיֶּלֶד"), tr("לְשַׂחֵק וְלִלְמוֹד · צָרִיךְ קוֹד חִבּוּר מֵהַמַּכְשִׁיר שֶׁל הַהוֹרֶה"),
                        Color(0xFF8C7BFF), if (isTablet) tr("מֻמְלָץ לְטַאבְּלֶט") else null) {
                        if (hasNoFamilyHere) childNeedsCode = true else choose("child")
                    }
                }
                if (isTablet) { childCard(); parentCard() } else { parentCard(); childCard() }
            }
        }

        AnimatedVisibility(confirmParentOnTablet, enter = fadeIn() + slideInVertically { it / 2 }, exit = fadeOut() + slideOutVertically { it / 2 }) {
            KidBottomCard(onDismiss = { confirmParentOnTablet = false }) {
                Box(Modifier.fillMaxWidth()) { Box(Modifier.align(Alignment.TopEnd)) { CloseCircle { confirmParentOnTablet = false } } }
                Text("🤔", fontSize = 42.sp)
                KidTitle(tr("רֶגַע, הַטַּאבְּלֶט הַזֶּה שֶׁל מִי?"), 23)
                KidBody(tr("רֹב הַמִּשְׁפָּחוֹת מְנַהֲלוֹת אֶת טוֹפִי מֵהַטֶּלֶפוֹן שֶׁל הַהוֹרֶה, וּמְחַבְּרוֹת אֶת הַטַּאבְּלֶט כְּמַכְשִׁיר שֶׁל הַיֶּלֶד."), 15f)
                GoldButton(tr("זֶה הַטַּאבְּלֶט שֶׁל הַיֶּלֶד"), Modifier.padding(top = 4.dp)) {
                    confirmParentOnTablet = false
                    if (hasNoFamilyHere) childNeedsCode = true else choose("child")
                }
                Box(
                    Modifier.fillMaxWidth().height(50.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f))
                        .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                        .clickable { confirmParentOnTablet = false; requestParent() },
                    contentAlignment = Alignment.Center,
                ) { Text(tr("זֶה הַטַּאבְּלֶט שֶׁלִּי, לְהַמְשִׁיךְ כְּהוֹרֶה"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 15.sp) }
            }
        }

        AnimatedVisibility(childNeedsCode, enter = fadeIn() + slideInVertically { it / 2 }, exit = fadeOut() + slideOutVertically { it / 2 }) {
            KidBottomCard(onDismiss = { childNeedsCode = false }) {
                Box(Modifier.fillMaxWidth()) { Box(Modifier.align(Alignment.TopEnd)) { CloseCircle { childNeedsCode = false } } }
                Text("🔗", fontSize = 42.sp)
                KidTitle(tr("צָרִיךְ קוֹד חִבּוּר מֵהַהוֹרֶה"), 23)
                KidBody(tr("הַמַּכְשִׁיר שֶׁל הַיֶּלֶד מִתְחַבֵּר לְקוֹד שֶׁנּוֹצָר בַּמַּכְשִׁיר שֶׁל הַהוֹרֶה. יֵשׁ לָכֶם כְּבָר קוֹד?"), 15f)
                GoldButton(tr("יֵשׁ לִי קוֹד — לְהַמְשִׁיךְ"), Modifier.padding(top = 4.dp)) { childNeedsCode = false; choose("child") }
                Box(
                    Modifier.fillMaxWidth().height(50.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f))
                        .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                        .clickable { childNeedsCode = false; requestParent() },
                    contentAlignment = Alignment.Center,
                ) { Text(tr("עוֹד לֹא — נַתְחִיל כָּאן כְּהוֹרֶה"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 15.sp) }
                // The App Store link on iOS; the Android build shares the site, which links both stores.
                Text(
                    tr("לִשְׁלֹחַ קִשּׁוּר לַהוֹרֶה"), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.Bold,
                    fontSize = 14.sp, textDecoration = TextDecoration.Underline,
                    modifier = Modifier.padding(top = 2.dp).clickable {
                        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, "https://tofyapp.com")
                        ctx.startActivity(Intent.createChooser(send, null))
                    },
                )
            }
        }
    }
}

@Composable
private fun RoleCard(emoji: String, title: String, subtitle: String, glow: Color, badge: String?, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().glassPane(16.dp).clickable(onClick = onClick).padding(18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            Modifier.size(64.dp).clip(CircleShape)
                .background(Brush.verticalGradient(listOf(glow.copy(alpha = 0.55f), glow.copy(alpha = 0.18f))))
                .border(1.dp, Color.White.copy(alpha = 0.35f), CircleShape),
            contentAlignment = Alignment.Center,
        ) { Text(emoji, fontSize = 34.sp) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            if (badge != null) Text(
                badge, Modifier.clip(RoundedCornerShape(16.dp)).background(GoldBrush).padding(horizontal = 10.dp, vertical = 3.dp),
                color = Color(0xFF2B1C04), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.sp,
            )
            Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
            Text(subtitle, color = Color.White.copy(alpha = 0.8f), fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 14.sp, lineHeight = 19.sp)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Color.White.copy(alpha = 0.55f))
    }
}

/**
 * WelcomeIntroView: what טופי is, plainly, on the very first screen — and the
 * language switch, before signing up in a language nobody picked. The iOS
 * "Apple Screen Time" notice card is Apple-specific and not shown here.
 */
@Composable
private fun WelcomeIntro(onStart: () -> Unit) {
    var showLanguages by remember { mutableStateOf(false) }
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(Modifier.fillMaxWidth()) {
                Box(Modifier.align(Alignment.TopEnd)) {
                    Row(
                        Modifier.clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.16f))
                            .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                            .clickable { showLanguages = true }.padding(horizontal = 14.dp, vertical = 9.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(I18n.language.native, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
                        Text("🌐", fontSize = 13.sp)
                    }
                    DropdownMenu(showLanguages, onDismissRequest = { showLanguages = false }) {
                        AppLanguage.entries.forEach { l ->
                            DropdownMenuItem(text = { Text(l.native) }, onClick = { I18n.set(l); showLanguages = false })
                        }
                    }
                }
            }
            CharacterImage("lion", Modifier.size(104.dp))
            Text(tr("טופי"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 42.sp)
            KidBody(tr("לוֹמְדִים, מַרְוִיחִים זְמַן מָסָךְ —\nוְהַהוֹרִים תָּמִיד בַּתְּמוּנָה."), 16f, alpha = 0.92f)
            Column(Modifier.widthIn(max = 520.dp).fillMaxWidth().glassPane(16.dp).padding(16.dp)) {
                WelcomeStep("🧠", Color(0xFF9B5DE5), tr("הַיֶּלֶד לוֹמֵד וּמְשַׂחֵק"),
                    tr("שְׁאֵלוֹת מַתְאִימוֹת לְגִיל — חֶשְׁבּוֹן, עִבְרִית, אַנְגְּלִית, מַדָּע וְעוֹד."))
                StepDivider()
                WelcomeStep("🎮", Color(0xFF2ECC9A), tr("כָּל 10 תְּשׁוּבוֹת = 4 דַּקּוֹת מָסָךְ"), tr("מַרְוִיחַ זְמַן מָסָךְ אֲמִתִּי דֶּרֶךְ לְמִידָה."))
                StepDivider()
                WelcomeStep("📊", Ink.gold2, tr("אַתֶּם עוֹקְבִים וּמְקַבְּלִים הַמְלָצוֹת"), tr("דּוּחוֹת, חוֹזֶק וְחוּלְשָׁה, וְהַתְרָאוֹת — בְּמַכְשִׁיר נִפְרָד."))
            }
            GoldButton(tr("בּוֹאוּ נַתְחִיל 🚀"), Modifier.widthIn(max = 520.dp), onClick = onStart)
        }
    }
}

@Composable
private fun StepDivider() = Box(Modifier.fillMaxWidth().padding(vertical = 2.dp).height(1.dp).background(Color.White.copy(alpha = 0.12f)))

@Composable
private fun WelcomeStep(emoji: String, tint: Color, title: String, body: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 7.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(
            Modifier.size(48.dp).clip(CircleShape).background(Brush.linearGradient(listOf(tint.copy(alpha = 0.9f), tint.copy(alpha = 0.5f)))),
            contentAlignment = Alignment.Center,
        ) { Text(emoji, fontSize = 22.sp) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
            Text(body, color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.sp,
                lineHeight = 18.sp, textAlign = TextAlign.Start, modifier = Modifier.alpha(1f))
        }
    }
}
