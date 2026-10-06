package com.rani.tofy.billing

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.rani.tofy.DeviceRole
import com.rani.tofy.data.ChildRepository
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.FamilyState
import com.rani.tofy.data.nowSecs
import com.rani.tofy.data.secs
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.ui.AskParent
import com.rani.tofy.kid.ui.CharacterImage
import com.rani.tofy.kid.ui.shop.rememberBoundChild
import com.rani.tofy.ui.child.BaseWorlds
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlin.math.ceil
import kotlin.math.roundToInt

private val Mint = Color(0xFF8CFFC4)
private val SuccessMint = Color(0xFF2ECC9A)
private val StarGold = Color(0xFFFFD23F)

/**
 * The paywall as the parent dashboard opens it on iOS (gatedPaywall): behind
 * the parent gate, every time — Kids Category keeps commerce gated.
 */
@Composable
fun GatedPaywall(source: String = "card", onClose: () -> Unit) {
    BillingParentGate(tr("כְּדֵי לִפְתּוֹחַ אֶת הַמִּנּוּי לַמִּשְׁפָּחָה — הַזִּינוּ אֶת הַקּוֹד"), onClose) {
        PaywallScreen(source, onClose)
    }
}

/**
 * PaywallView.swift — "טופי+", the family subscription. Bought ONCE on a
 * parent's phone and unlocking every child device through the household; a
 * CHILD device never shows prices — it asks a parent instead (AskParentView).
 *
 * Prices come from Play (ProductDetails), the billing line under the button
 * carries Play's required disclosure (price, period, auto-renew, how to
 * cancel), and success is the SERVER's: verifyPlayPurchase wrote the family's
 * premiumUntil before this screen celebrates.
 *
 * @param source where the parent came from (card, gift_card, child_request, new_world).
 */
@Composable
fun PaywallScreen(source: String = "card", onClose: () -> Unit) {
    if (DeviceRole.role == DeviceRole.Role.CHILD || DeviceRole.kidModeChildID != null) {
        // Kids Category: never a price or a store on the child's surface.
        val child = rememberBoundChild()
        val cid = KidSession.boundChildID
        if (cid != null) AskParent(child, cid, child?.householdID, null, onClose)
        else LaunchedEffect(Unit) { onClose() }
        return
    }
    PaywallBody(source, onClose)
}

@Composable
private fun PaywallBody(source: String, onClose: () -> Unit) {
    BackHandler(onBack = onClose)
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val plans by PlaySubscriptions.plans.collectAsState()
    val loading by PlaySubscriptions.isLoading.collectAsState()
    val purchasing by PlaySubscriptions.isPurchasing.collectAsState()
    val error by PlaySubscriptions.lastError.collectAsState()
    val introEligible by PlaySubscriptions.yearlyIntroEligible.collectAsState()
    val family by FamilyRepository.state.collectAsState()
    var selectedID by remember { mutableStateOf(ProductIds.YEARLY) }   // year highlighted by default
    var appeared by remember { mutableStateOf(false) }
    var celebrating by remember { mutableStateOf(false) }
    val pitch = rememberPitch(family)

    LaunchedEffect(Unit) {
        PlaySubscriptions.lastError.value = null
        PlaySubscriptions.notePaywallSource(source)
        appeared = true
        if (PlaySubscriptions.plans.value.isEmpty()) PlaySubscriptions.load(ctx)
        // A purchase paid earlier but never confirmed (app killed) is finished now.
        BillingRepository.resume(ctx)
    }

    fun succeeded() {
        celebrating = true
        // RemoteSyncManager.clearPremiumRequests — the asks are answered.
        scope.launch {
            FamilyRepository.state.value.children.filter { it.raw.secs("premiumRequestedAt") != null }.forEach {
                ChildRepository.update(it.id, mapOf("premiumRequestedAt" to FieldValue.delete(), "premiumRequestedTopic" to FieldValue.delete()))
            }
        }
    }
    LaunchedEffect(celebrating) { if (celebrating) { delay(2000); onClose() } }

    val heroScale by animateFloatAsState(if (appeared) 1f else 0.5f, spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessLow), label = "hero")

    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp).padding(top = 6.dp, bottom = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.widthIn(max = 720.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                // Hero
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    CharacterImage("fox", Modifier.size(76.dp))
                    Text(tr("טופי+"), Modifier.scale(heroScale), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 34.sp)
                    Text(tr("חוויה מלאה — לכל הילדים בבית"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.5.sp, textAlign = TextAlign.Center)
                }
                pitch?.let { PersonalCard(it) }
                BenefitsCard()
                // Plan picker
                if (plans.isEmpty()) PlaceholderPlans(loading) { scope.launch { PlaySubscriptions.load(ctx) } }
                else Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    plans.forEach { p -> PlanCard(p, selectedID == p.id, introEligible) { selectedID = p.id } }
                }
                // Primary CTA + Play's required billing line, right next to the purchase action.
                val yearlySelected = selectedID == ProductIds.YEARLY
                val selected = plans.firstOrNull { it.id == selectedID }
                val disabled = plans.isEmpty() || purchasing
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(
                        Modifier.widthIn(max = 480.dp).fillMaxWidth().clip(RoundedCornerShape(22.dp))
                            .background(Color.White.copy(alpha = if (disabled) 0.5f else 0.92f))
                            .clickable(enabled = !disabled) {
                                val plan = selected ?: return@clickable
                                val activity = ctx.findActivity() ?: return@clickable
                                PlaySubscriptions.notePurchaseStarted()
                                scope.launch { if (PlaySubscriptions.purchase(activity, plan)) succeeded() }
                            }
                            .padding(vertical = 16.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (purchasing) CircularProgressIndicator(Modifier.size(24.dp), color = Ink.indigo, strokeWidth = 3.dp)
                        else Text(
                            "✨ " + if (yearlySelected && introEligible) tr("התחל ניסיון 7 ימים חינם") else tr("המשך לתשלום"),
                            color = Ink.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp,
                        )
                    }
                    selected?.let { plan ->
                        val line = when {
                            plan.id == ProductIds.YEARLY && introEligible -> tr("בתום הניסיון: %@ / שנה · מתחדש אוטומטית — ניתן לבטל בכל עת ב-Google Play", plan.price)
                            plan.id == ProductIds.YEARLY -> tr("%@ / שנה · מתחדש אוטומטית — ניתן לבטל בכל עת ב-Google Play", plan.price)
                            else -> tr("%@ / חודש · מתחדש אוטומטית — ניתן לבטל בכל עת ב-Google Play", plan.price)
                        }
                        Text(line, Modifier.padding(horizontal = 16.dp), color = Color.White.copy(alpha = 0.7f), fontFamily = Rounded,
                            fontWeight = FontWeight.Medium, fontSize = 11.sp, textAlign = TextAlign.Center)
                    }
                    if (!error.isNullOrEmpty()) Text(
                        error!!, Modifier.padding(horizontal = 16.dp).padding(top = 4.dp), color = StarGold, fontFamily = Rounded,
                        fontWeight = FontWeight.SemiBold, fontSize = 13.sp, textAlign = TextAlign.Center,
                    )
                }
                pitch?.let { FreeForeverLine(it) }
                // Footer
                Column(Modifier.padding(top = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        tr("שחזר רכישה קיימת"),
                        Modifier.clickable { scope.launch { if (PlaySubscriptions.restore()) succeeded() } },
                        color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp,
                        textDecoration = TextDecoration.Underline,
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(18.dp), verticalAlignment = Alignment.CenterVertically) {
                        FooterLink(tr("תנאי שימוש"), "https://tofyapp.com/terms")
                        Text("•", color = Color.White.copy(alpha = 0.4f), fontSize = 12.sp)
                        FooterLink(tr("מדיניות פרטיות"), "https://tofyapp.com/privacy")
                    }
                }
            }
        }
        // The ✕ floats over the top corner instead of taking a row of its own.
        Box(Modifier.fillMaxSize().systemBarsPadding().padding(horizontal = 20.dp, vertical = 8.dp)) {
            Box(
                Modifier.align(Alignment.TopEnd).size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f))
                    .border(1.dp, Color.White.copy(alpha = 0.32f), CircleShape).clickable(onClick = onClose),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Filled.Close, tr("סְגֹר"), tint = Color.White, modifier = Modifier.size(18.dp)) }
        }
        if (celebrating) Celebration()
    }
}

@Composable
private fun FooterLink(text: String, url: String) {
    val ctx = LocalContext.current
    Text(
        text, Modifier.clickable { runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) } },
        color = Color.White.copy(alpha = 0.7f), fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 12.sp,
    )
}

@Composable
private fun BenefitsCard() {
    Column(Modifier.fillMaxWidth().glassPane(22.dp).padding(horizontal = 10.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
        val rows = listOf(
            Triple("🧠", tr("כל הנושאים"), tr("מתמטיקה, עברית, אנגלית, מדעים ועוד")),
            Triple("🌍", tr("כל העולמות"), tr("כולל כל עולם חדש שנוסיף")),
            Triple("⏱", tr("זמן פרס על למידה"), tr("כל תשובה נכונה מזכה בזמן משחק")),
            Triple("👨‍👩‍👧‍👦", tr("כל הילדים במשפחה"), tr("פרופיל והתקדמות לכל ילד")),
            Triple("📊", tr("דוחות הורה שבועיים"), tr("איפה הילד חזק, איפה צריך עזרה")),
            Triple("☁️", tr("סנכרון בין מכשירים"), tr("טלפון + טאבלט, אותה התקדמות")),
        )
        rows.forEachIndexed { i, (emoji, title, sub) ->
            if (i > 0) Box(Modifier.fillMaxWidth().padding(horizontal = 8.dp).height(1.dp).background(Color.White.copy(alpha = 0.12f)))
            Row(Modifier.padding(horizontal = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(emoji, Modifier.width(28.dp), fontSize = 20.sp, textAlign = TextAlign.Center)
                Column(Modifier.weight(1f)) {
                    Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, maxLines = 1)
                    Text(sub, color = Color.White.copy(alpha = 0.75f), fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 11.5.sp, maxLines = 1)
                }
                Box(Modifier.clip(CircleShape).background(SuccessMint.copy(alpha = 0.2f)).padding(4.dp)) {
                    Text("✓", color = SuccessMint, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                }
            }
        }
    }
}

@Composable
private fun PlanCard(plan: PlaySubscriptions.Plan, selected: Boolean, introEligible: Boolean, onSelect: () -> Unit) {
    val shape = RoundedCornerShape(22.dp)
    Row(
        Modifier.fillMaxWidth()
            .then(if (selected) Modifier.glassPane(22.dp, 0.18f).background(Mint.copy(alpha = 0.10f)).border(2.dp, Mint.copy(alpha = 0.9f), shape)
                  else Modifier.glassPane(22.dp, 0.10f))
            .clickable(onClick = onSelect).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // Radio
        Box(Modifier.size(24.dp).clip(CircleShape).border(2.dp, if (selected) SuccessMint else Color.White.copy(alpha = 0.4f), CircleShape), contentAlignment = Alignment.Center) {
            if (selected) Box(Modifier.size(14.dp).clip(CircleShape).background(SuccessMint))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(plan.name, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp)
                PlaySubscriptions.savingsBadge(plan)?.let {
                    Text(it, Modifier.clip(RoundedCornerShape(50)).background(SuccessMint).padding(horizontal = 8.dp, vertical = 3.dp),
                        color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                }
            }
            Text(plan.pricePerPeriod, color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            if (plan.id == ProductIds.YEARLY && introEligible) {
                Text(tr("כולל ניסיון 7 ימים חינם"), color = StarGold, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 12.sp)
            }
        }
    }
}

@Composable
private fun PlaceholderPlans(loading: Boolean, retry: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().heightIn(min = 120.dp).glassPane(22.dp).padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
    ) {
        if (loading) {
            CircularProgressIndicator(Modifier.size(26.dp), color = Color.White, strokeWidth = 3.dp)
            Text(tr("טוֹעֵן מַסְלוּלִים…"), color = Color.White.copy(alpha = 0.7f), fontFamily = Rounded, fontSize = 13.sp)
        } else {
            // Finished loading but got nothing — almost always a store setup or network issue.
            Text(tr("הַמַּסְלוּלִים לֹא נִטְעֲנוּ"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
            Text(tr("בִּדְקוּ אֶת חִבּוּר הָאִינְטֶרְנֶט וְנַסּוּ שׁוּב."), Modifier.padding(horizontal = 16.dp), color = Color.White.copy(alpha = 0.8f),
                fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 12.sp, textAlign = TextAlign.Center)
            Text(
                "↻ " + tr("נַסּוּ שׁוּב"),
                Modifier.padding(top = 4.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.14f))
                    .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(50)).clickable(onClick = retry)
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp,
            )
        }
    }
}

@Composable
private fun Celebration() {
    var shown by remember { mutableStateOf(false) }
    val s by animateFloatAsState(if (shown) 1f else 0.5f, spring(dampingRatio = 0.5f), label = "yay")
    LaunchedEffect(Unit) { shown = true }
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f)).clickable(enabled = false) {}, contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.scale(s)) {
            Text("🎉", fontSize = 80.sp)
            CharacterImage("fox", Modifier.size(110.dp))
            Text(tr("יששש!"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 34.sp)
        }
    }
}

// MARK: - 🎁 The personal pitch: the child's own data above the prices, shown
// while the gift is ending or after it ended (PaywallView.pitch).

private data class Pitch(
    val name: String, val girl: Boolean,
    val favorite: Triple<Pair<String, String>, Int, Int>?,   // (emoji, world name), questions, accuracy
    val others: List<String>,
    val worlds: Int, val questions: Int, val accuracy: Int,
    val ending: String,
)

private fun worldOf(t: Topic): Pair<String, String> =
    BaseWorlds.firstOrNull { it.topic == t }?.let { it.emoji to it.name } ?: (t.emoji to t.displayName)

@Composable
private fun rememberPitch(family: FamilyState): Pitch? {
    val hh = family.household ?: return null
    // giftEndedAt isn't on the shared Household model — one read of the doc.
    val giftEndedAt by produceState<Double?>(null, hh.id) {
        value = runCatching { FirebaseFirestore.getInstance().collection("households").document(hh.id).get().await().data?.secs("giftEndedAt") }.getOrNull()
    }
    val until = hh.giftUntil ?: hh.premiumUntil
    val giftActive = hh.premiumSource == "gift" && (until?.let { it > nowSecs() } ?: false)
    if (!giftActive && giftEndedAt == null) return null
    // The child who answered the most.
    val star = family.children.map { it to (family.progress[it.id]?.totalAnswered ?: 0) }.maxByOrNull { it.second } ?: return null
    if (star.second <= 0) return null
    val (child, _) = star
    val p = family.progress[child.id] ?: return null
    // Per-topic correct counts live only in the state doc (Progress keeps accuracy).
    val topicCorrect by produceState<Map<String, Int>?>(null, child.id) {
        value = runCatching {
            val d = FirebaseFirestore.getInstance().collection("children").document(child.id).collection("state").document("current").get().await()
            (d.get("topicCorrect") as? Map<*, *>)?.mapNotNull { (k, v) -> (k as? String)?.let { kk -> (v as? Number)?.let { kk to it.toInt() } } }?.toMap()
        }.getOrNull() ?: emptyMap()
    }
    val correct = topicCorrect ?: return null
    val ranked = p.topicAnswered.filter { it.value > 0 }.entries.sortedByDescending { it.value }.mapNotNull { (k, n) ->
        val t = Topic.of(k) ?: return@mapNotNull null
        Triple(worldOf(t), n, ((correct[k] ?: 0).toDouble() / n * 100).roundToInt())
    }
    val ending = if (giftActive) {
        val d = maxOf(0, ceil(((until ?: 0.0) - nowSecs()) / 86_400).toInt())
        when (d) {
            0 -> tr("הַמַּתָּנָה מִסְתַּיֶּמֶת הַיּוֹם")
            1 -> tr("הַמַּתָּנָה מִסְתַּיֶּמֶת מָחָר")
            2 -> tr("הַמַּתָּנָה מִסְתַּיֶּמֶת בְּעוֹד יוֹמַיִם")
            else -> tr("הַמַּתָּנָה מִסְתַּיֶּמֶת בְּעוֹד %lld יָמִים", d)
        }
    } else tr("הַמַּתָּנָה הִסְתַּיְּמָה · הַהִתְקַדְּמוּת שֶׁל %@ שְׁמוּרָה", child.name)
    return Pitch(
        name = child.name, girl = child.isGirl,
        favorite = ranked.firstOrNull(),
        others = ranked.drop(1).take(2).map { it.first.second },
        worlds = ranked.size, questions = p.totalAnswered,
        accuracy = (p.totalCorrect.toDouble() / maxOf(1, p.totalAnswered) * 100).roundToInt(),
        ending = ending,
    )
}

@Composable
private fun PersonalCard(p: Pitch) {
    Column(Modifier.fillMaxWidth().glassPane(22.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        val fav = p.favorite
        if (fav != null) {
            val (world, questions, accuracy) = fav
            Text(
                if (p.girl) tr("%@ %@ מָצְאָה עוֹלָם שֶׁהִיא אוֹהֶבֶת", world.first, p.name) else tr("%@ %@ מָצָא עוֹלָם שֶׁהוּא אוֹהֵב", world.first, p.name),
                color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp,
            )
            val body = (if (p.girl) tr("הִיא עָנְתָה בְּ%@ עַל %lld שְׁאֵלוֹת, בְּ%lld%% הַצְלָחָה.", world.second, questions, accuracy)
                        else tr("הוּא עָנָה בְּ%@ עַל %lld שְׁאֵלוֹת, בְּ%lld%% הַצְלָחָה.", world.second, questions, accuracy)) +
                (if (p.others.isEmpty()) "" else tr(" גַּם %@ בִּפְנִים.", p.others.joinToString(tr(" וְ"))))
            Text(body, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.5.sp, lineHeight = 19.sp)
        } else {
            Text(
                if (p.girl) tr("🎉 %@ כְּבָר עָנְתָה עַל %lld שְׁאֵלוֹת בְּטוֹפִי+", p.name, p.questions) else tr("🎉 %@ כְּבָר עָנָה עַל %lld שְׁאֵלוֹת בְּטוֹפִי+", p.name, p.questions),
                color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp,
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PitchStat("${p.worlds}", if (p.worlds == 1) tr("עוֹלָם") else tr("עוֹלָמוֹת"))
            PitchStat("${p.questions}", tr("שְׁאֵלוֹת"))
            PitchStat("${p.accuracy}%", tr("הַצְלָחָה"))
        }
        Text(p.ending, color = StarGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.PitchStat(value: String, label: String) {
    Column(Modifier.weight(1f).glassInset(12.dp).padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
        Text(label, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 11.sp)
    }
}

/** What stays free, in one honest line. */
@Composable
private fun FreeForeverLine(p: Pitch) {
    Text(
        if (p.girl) tr("טוֹפִי טַיים וְהַזְּמַן שֶׁ%@ מַרְוִיחָה נִשְׁאָרִים חִנָּם תָּמִיד. מָה שֶׁנִּסְגָּר: הָעוֹלָמוֹת, הַמִּשְׂחָקִים, הַזִּירָה וְהַמַּטְלוֹת.", p.name)
        else tr("טוֹפִי טַיים וְהַזְּמַן שֶׁ%@ מַרְוִיחַ נִשְׁאָרִים חִנָּם תָּמִיד. מָה שֶׁנִּסְגָּר: הָעוֹלָמוֹת, הַמִּשְׂחָקִים, הַזִּירָה וְהַמַּטְלוֹת.", p.name),
        Modifier.padding(horizontal = 16.dp), color = Color.White.copy(alpha = 0.8f), fontFamily = Rounded,
        fontWeight = FontWeight.Medium, fontSize = 12.5.sp, textAlign = TextAlign.Center,
    )
}
