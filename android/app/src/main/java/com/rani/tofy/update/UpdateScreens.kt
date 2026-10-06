package com.rani.tofy.update

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.BuildConfig
import com.rani.tofy.data.SettingsRepository
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.CharacterImage
import com.rani.tofy.kid.ui.KidBody
import com.rani.tofy.kid.ui.KidCenterCard
import com.rani.tofy.kid.ui.KidCta
import com.rani.tofy.kid.ui.KidTitle
import com.rani.tofy.ui.common.GoldButton
import com.rani.tofy.ui.settings.openUrl
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded

/**
 * 🔄 UpdateAvailableView.swift — the three faces of "there is a newer Tofy".
 *
 * The parent sheet (and the forced screen on a PARENT surface) are the only
 * places that may leave for Google Play. A child is told, and pointed at a
 * grown-up — the kid notice has one button and it only closes.
 */

// MARK: - The lion, at whatever size the moment deserves

@Composable
private fun UpdateHero(size: Dp = 112.dp) {
    val bob by rememberInfiniteTransition(label = "bob").animateFloat(
        -3f, 3f, infiniteRepeatable(tween(1900), RepeatMode.Reverse), label = "bob",
    )
    // The image owns the layout size; the halo is drawn behind it and takes no space.
    Box(Modifier.size(size), contentAlignment = Alignment.Center) {
        Box(
            Modifier.requiredSize(size * 1.5f).blur(12.dp).clip(CircleShape)
                .background(Brush.radialGradient(listOf(
                    Color(0xFF7CF3FF).copy(alpha = 0.50f), Color(0xFF8CFFC4).copy(alpha = 0.18f), Color.Transparent,
                ))),
        )
        CharacterImage("lion", Modifier.fillMaxSize().graphicsLayer { translationY = bob * density })
    }
}

// MARK: - Parent: what changed, and a way to get it

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UpdateAvailableSheet(onUpdate: () -> Unit, onLater: () -> Unit, onDismiss: () -> Unit) {
    val v by AppUpdateConfig.values.collectAsState()
    val notes = AppUpdateLogic.notesFor(v, I18n.language.code)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Color(0xFF4B3AA8),
    ) {
        Column(
            Modifier.fillMaxWidth()
                .background(Brush.verticalGradient(listOf(Color(0xFF4B3AA8), Color(0xFF3B3277))))
                .navigationBarsPadding().padding(horizontal = 18.dp).padding(bottom = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(bottom = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Box(Modifier.padding(top = 4.dp)) { UpdateHero() }
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(tr("יֵשׁ גִּרְסָה חֲדָשָׁה שֶׁל טוֹפִי"), color = Color.White, fontFamily = Rounded,
                        fontWeight = FontWeight.ExtraBold, fontSize = 22.sp, textAlign = TextAlign.Center, lineHeight = 28.sp)
                    if (v.versionName.isNotEmpty()) {
                        Text(tr("%@ מְחַכָּה לָכֶם בְּ-Google Play", v.versionName), color = Color.White.copy(alpha = 0.72f),
                            fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 14.sp, textAlign = TextAlign.Center)
                    }
                }
                if (notes.isNotEmpty()) Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    notes.forEach { line ->
                        // The emoji sits in a fixed column so every line's text starts
                        // at the same edge (🏅 / ⏱ / 🛠 differ in width).
                        val (icon, text) = AppUpdateLogic.splitEmoji(line)
                        androidx.compose.foundation.layout.Row(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.10f))
                                .border(1.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(16.dp))
                                .padding(vertical = 13.dp, horizontal = 14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            if (icon.isNotEmpty()) Text(icon, Modifier.width(24.dp), fontSize = 17.sp, textAlign = TextAlign.Center)
                            Text(text, color = Color.White.copy(alpha = 0.92f), fontFamily = Rounded, fontWeight = FontWeight.Medium,
                                fontSize = 14.5.sp, lineHeight = 21.sp)
                        }
                    }
                }
            }
            GoldButton(tr("עַדְכְּנוּ עַכְשָׁיו"), onClick = onUpdate)
            Text(tr("אַחַר כָּךְ"), Modifier.clip(RoundedCornerShape(12.dp)).clickable(onClick = onLater)
                .padding(horizontal = 16.dp).padding(top = 12.dp, bottom = 6.dp),
                color = Color.White.copy(alpha = 0.80f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            Text(tr("מֻתְקָן אֶצְלְכֶם: %@ (%@)", BuildConfig.VERSION_NAME, BuildConfig.VERSION_CODE.toString()),
                color = Color.White.copy(alpha = 0.48f), fontFamily = Rounded, fontSize = 12.sp, textAlign = TextAlign.Center)
        }
    }
}

/** ParentDashboardView: the sheet on the home, unless something else already owns the screen. */
@Composable
fun ParentUpdateHost(blocked: Boolean) {
    val state by AppUpdateConfig.state.collectAsState()
    var hidden by remember { mutableStateOf(AppUpdateConfig.parentSheetHidden) }
    if (state !is AppUpdateConfig.State.Recommended || hidden || blocked) return
    val ctx = LocalContext.current
    UpdateAvailableSheet(
        onUpdate = {
            // Not "later": the parent may come back without updating, and should be asked again next launch.
            AppUpdateConfig.parentSheetHidden = true; hidden = true
            openUrl(ctx, AppUpdateConfig.STORE_URL)
        },
        onLater = { AppUpdateConfig.dismissCurrent() },   // quiet until the NEXT build
        onDismiss = { AppUpdateConfig.parentSheetHidden = true; hidden = true },
    )
}

// MARK: - Child: tell them, and send them to a grown-up — not to the store

@Composable
fun UpdateKidNotice(onOK: () -> Unit) {
    BackHandler(onBack = onOK)
    KidCenterCard(onOK) {
        UpdateHero()
        KidTitle(tr("יֵשׁ טוֹפִי חָדָשׁ! ✨"), 21)
        KidBody(tr("בִּקְשׁוּ מֵאַבָּא אוֹ מֵאִמָּא לְעַדְכֵּן,\nוְיִהְיוּ דְּבָרִים חֲדָשִׁים לְשַׂחֵק בָּהֶם 💛"), 15f)
        // One button, and it closes the card. No path out of the app.
        GoldButton(tr("סַבָּבָּה! 👍"), Modifier.padding(top = 4.dp), onClick = onOK)
    }
}

// MARK: - Below minAndroidBuild: this copy can no longer be trusted against the server

/**
 * @param parent the store button — only on a parent surface. A child device (or
 *   a phone in Kid Mode) is told to ask a grown-up instead.
 * @param onKidExit Kid Mode only: the parent-gated way out, so a parent's own
 *   phone is never stuck pinned behind this screen.
 */
@Composable
fun ForcedUpdateScreen(parent: Boolean, onKidExit: (() -> Unit)? = null) {
    val ctx = LocalContext.current
    Box(
        Modifier.fillMaxSize()
            // Swallows every touch: nothing behind it may be reached.
            .clickable(remember { MutableInteractionSource() }, null) {},
    ) {
        GlassBackdrop(maxContentWidth = 480.dp) {
            Column(
                Modifier.fillMaxSize().systemBarsPadding().padding(horizontal = 22.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.weight(1f))
                UpdateHero(136.dp)
                KidTitle(tr("צָרִיךְ לְעַדְכֵּן כְּדֵי לְהַמְשִׁיךְ"), 25, Modifier.padding(top = 20.dp))
                KidBody(tr("הַגִּרְסָה שֶׁמֻּתְקֶנֶת כָּאן כְּבָר לֹא מְדַבֶּרֶת עִם הַשֵּׁרֵת שֶׁל טוֹפִי. הָעִדְכּוּן לוֹקֵחַ רֶגַע — וְכָל הַזְּמַן, הַכּוֹכָבִים וְהַיַּהֲלוֹמִים נִשְׁמָרִים בַּמָּקוֹם."),
                    15f, Modifier.padding(top = 10.dp).padding(horizontal = 8.dp), alpha = 0.78f, weight = FontWeight.Medium)
                if (!parent) KidBody(tr("בִּקְשׁוּ מֵאַבָּא אוֹ מֵאִמָּא לְעַדְכֵּן,\nוְיִהְיוּ דְּבָרִים חֲדָשִׁים לְשַׂחֵק בָּהֶם 💛"),
                    15f, Modifier.padding(top = 14.dp))
                Spacer(Modifier.weight(1f))
                if (parent) GoldButton(tr("עַדְכְּנוּ עַכְשָׁיו")) { openUrl(ctx, AppUpdateConfig.STORE_URL) }
                onKidExit?.let {
                    KidCta(tr("יְצִיאָה מִמַּצַּב יֶלֶד וְשִׁחְרוּר נְעִילַת הַמַּכְשִׁיר"), Color(0xFFFF7A3D), Color(0xFFFF9F1C),
                        emoji = "🔓", size = 15, onClick = it)
                }
                Text(SettingsRepository.versionLine, Modifier.padding(top = 11.dp, bottom = 10.dp),
                    color = Ink.secondary.copy(alpha = 0.7f), fontFamily = Rounded, fontSize = 12.5.sp)
            }
        }
    }
}
