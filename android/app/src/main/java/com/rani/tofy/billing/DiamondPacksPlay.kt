package com.rani.tofy.billing

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.android.billingclient.api.ProductDetails
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.kid.ui.shop.rememberBoundChild
import com.rani.tofy.kid.ui.shop.tintedPane
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * StarShopView.swift's purchase part for Google Play — the three 💎 packs with
 * Play's prices, the loading / unavailable states, the store line, and the
 * "+200 💎" celebration. Drop-in for the disabled rows + "coming soon" line in
 * kid/ui/shop/StarShop.kt (StarShopScreen), which already sits behind the
 * parent gate (StarShopGate, respectSession:false) and shows the balance card.
 *
 * @param onDone called after a pack landed and its celebration finished
 *        (the shop may stay open, like iOS, or close).
 */
@Composable
fun DiamondPacksPlay(onDone: () -> Unit = {}) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val child = rememberBoundChild()
    val products by PlayDiamonds.products.collectAsState()
    val didLoad by PlayDiamonds.didAttemptLoad.collectAsState()
    val loading by PlayDiamonds.isLoading.collectAsState()
    val purchasing by PlayDiamonds.isPurchasing.collectAsState()
    val error by PlayDiamonds.lastError.collectAsState()
    val granted by PlayDiamonds.lastGrantedDiamonds.collectAsState()
    var celebrate by remember { mutableStateOf<Int?>(null) }

    LaunchedEffect(Unit) {
        PlayDiamonds.lastError.value = null
        if (PlayDiamonds.products.value.isEmpty()) PlayDiamonds.load(ctx)
        // A pack paid earlier but never delivered (app killed) lands now.
        BillingRepository.resume(ctx)
    }
    LaunchedEffect(granted) {
        granted?.let { celebrate = it; PlayDiamonds.lastGrantedDiamonds.value = null }
    }

    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        when {
            products.isNotEmpty() -> products.forEach { d ->
                PackRow(d, PlayDiamonds.isBestValue(d), enabled = !purchasing) {
                    val activity = ctx.findActivity() ?: return@PackRow
                    scope.launch { PlayDiamonds.purchase(activity, d, child?.householdID?.takeIf { it.isNotEmpty() }) }
                }
            }
            !didLoad || loading -> Column(
                Modifier.fillMaxWidth().padding(vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                CircularProgressIndicator(Modifier.size(26.dp), color = Color.White, strokeWidth = 3.dp)
                Text(tr("טוֹעֵן חֲבִילוֹת…"), color = Color.White.copy(alpha = 0.7f), fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 15.sp)
            }
            else -> Column(
                // Loaded but empty — the products aren't set up / available yet.
                Modifier.fillMaxWidth().padding(vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text("🛒", fontSize = 44.sp)
                Text(tr("הַחֲבִילוֹת אֵינָן זְמִינוֹת כָּרֶגַע"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, textAlign = TextAlign.Center)
                Text(com.rani.tofy.kid.ui.social.SocialMe.g(tr("נַסֵּה שׁוּב בְּעוֹד רֶגַע."), tr("נַסִּי שׁוּב בְּעוֹד רֶגַע.")), color = Color.White.copy(alpha = 0.7f), fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.sp)
                Text(
                    com.rani.tofy.kid.ui.social.SocialMe.g(tr("נַסֵּה שׁוּב"), tr("נַסִּי שׁוּב")),
                    Modifier.clip(RoundedCornerShape(50)).background(KidColor.gemPurple).clickable { scope.launch { PlayDiamonds.load(ctx) } }
                        .padding(horizontal = 22.dp, vertical = 10.dp),
                    color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp,
                )
            }
        }
        if (!error.isNullOrEmpty()) Text(
            error!!, Modifier.fillMaxWidth(), color = Color(0xFFFFD23F), fontFamily = Rounded, fontWeight = FontWeight.SemiBold,
            fontSize = 13.sp, textAlign = TextAlign.Center,
        )
        Text(
            tr("הָרְכִישָׁה דּוֹרֶשֶׁת אִישּׁוּר בְּחֶשְׁבּוֹן Google Play. הַיַּהֲלוֹמִים מְשַׁמְּשִׁים לִקְנִיַּת דְּמוּיוֹת בְּתוֹךְ הָאַפְּלִיקַצְיָה בִּלְבַד."),
            Modifier.fillMaxWidth().padding(top = 4.dp), color = Color.White.copy(alpha = 0.6f), fontFamily = Rounded,
            fontWeight = FontWeight.Medium, fontSize = 12.sp, textAlign = TextAlign.Center, lineHeight = 17.sp,
        )
    }

    celebrate?.let { amount -> GrantCelebration(amount) { celebrate = null; onDone() } }
}

@Composable
private fun PackRow(d: ProductDetails, best: Boolean, enabled: Boolean, onBuy: () -> Unit) {
    val diamonds = ProductIds.diamonds(d.productId)
    Row(
        Modifier.fillMaxWidth().then(if (best) Modifier.tintedPane(Color(0xFFFFD23F)) else Modifier.glassPane(22.dp))
            .alpha(if (enabled) 1f else 0.6f).clickable(enabled = enabled, onClick = onBuy).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(58.dp).clip(CircleShape).background(KidColor.gemPurple.copy(alpha = 0.25f)), contentAlignment = Alignment.Center) {
            Text("💎", fontSize = 30.sp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(tr("%lld יַהֲלוֹמִים", diamonds), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
            if (best) Text(tr("הֲכִי מִשְׁתַּלֵּם 🔥"), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp)
        }
        Text(
            d.oneTimePurchaseOfferDetails?.formattedPrice ?: "",
            Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.92f)).padding(horizontal = 16.dp, vertical = 9.dp),
            color = Color(0xFF4B3FBF), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, maxLines = 1,
        )
    }
}

/** StarGrantCelebration — a brief full-screen "+200 💎". */
@Composable
private fun GrantCelebration(amount: Int, onDone: () -> Unit) {
    var shown by remember { mutableStateOf(false) }
    val s by animateFloatAsState(if (shown) 1f else 0.4f, spring(dampingRatio = 0.6f), label = "gem")
    LaunchedEffect(Unit) { shown = true; delay(1600); onDone() }
    Dialog(onDismissRequest = onDone, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f)), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("💎", Modifier.scale(s), fontSize = 90.sp)
                Text("+$amount", color = KidColor.gemPurple, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 44.sp)
                Text(tr("יַהֲלוֹמִים נוֹסְפוּ!"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 20.sp)
            }
        }
    }
}
