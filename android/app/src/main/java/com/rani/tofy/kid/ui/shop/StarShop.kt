package com.rani.tofy.kid.ui.shop

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.data.Child
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.ui.ParentGate
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import com.rani.tofy.kid.ui.social.SocialMe

/** StarPackStore's three consumables — the 💎 each grants (60 / 200 / 500, the middle one "best value"). */
internal object StarPacks {
    val diamonds = listOf(60, 200, 500)
    const val BEST = 200
}

/**
 * Kids Category (guideline 1.3): the real-money packs sit behind the parent
 * gate with respectSession:false — every open asks for the code again.
 */
@Composable
internal fun StarShopGate(child: Child?, onClose: () -> Unit) {
    val (pinHash, loaded) = rememberParentPin(child?.householdID?.takeIf { it.isNotEmpty() })
    var authorized by remember { mutableStateOf(false) }
    if (!authorized) {
        ParentGate(pinHash, loaded, tr("אֵזוֹר הוֹרִים"), tr("כְּדֵי לִקְנוֹת יַהֲלוֹמִים — בַּקְּשׁוּ מֵהוֹרֶה לְהַזִּין אֶת הַקּוֹד"),
            onAuthorized = { authorized = true }, onClose = onClose)
    } else StarShopScreen(onClose)
}

/**
 * StarShopView.swift — the 💎 balance and the packs. Android has no Play
 * Billing yet: the packs are shown, disabled, as "coming soon on Android".
 * Nothing here can charge money.
 */
@Composable
private fun StarShopScreen(onClose: () -> Unit) {
    BackHandler(onBack = onClose)
    val state by KidSession.state.collectAsState()
    val diamonds = state?.snapshot?.diamonds ?: 0
    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            ShopTopBar(tr("חֲנוּת יַהֲלוֹמִים"), onClose)
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp).widthIn(max = 480.dp).align(Alignment.CenterHorizontally),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                // Balance card.
                Row(
                    Modifier.fillMaxWidth().glassPane(22.dp).padding(vertical = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("💎", fontSize = 26.sp)
                    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                        Text(currencyShort(diamonds), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 30.sp, maxLines = 1)
                    }
                    Text(SocialMe.g(tr("יַהֲלוֹמִים שֶׁלְּךָ"), tr("יַהֲלוֹמִים שֶׁלָּךְ")), color = Color.White.copy(alpha = 0.8f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                }
                // Google Play Billing: verified on the server, then credited + consumed.
                com.rani.tofy.billing.DiamondPacksPlay()
            }
        }
    }
}

@Composable
private fun PackRow(diamonds: Int, best: Boolean) {
    Row(
        Modifier.fillMaxWidth().then(if (best) Modifier.tintedPane(KidColor.starGold) else Modifier.glassPane(22.dp)).padding(12.dp)
            .graphicsLayer { alpha = 0.75f },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(58.dp).clip(CircleShape).background(KidColor.gemPurple.copy(alpha = 0.25f)), contentAlignment = Alignment.Center) {
            Text("💎", fontSize = 30.sp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(tr("%lld יַהֲלוֹמִים", diamonds), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
            if (best) Text(tr("הֲכִי מִשְׁתַּלֵּם 🔥"), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp)
        }
        // Disabled — no Play Billing on Android yet.
        Text(
            tr("בְּקָרוֹב בְּאַנְדְּרוֹאִיד"),
            Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.18f))
                .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(50)).padding(horizontal = 12.dp, vertical = 8.dp),
            color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp, textAlign = TextAlign.Center, maxLines = 2,
        )
    }
}
