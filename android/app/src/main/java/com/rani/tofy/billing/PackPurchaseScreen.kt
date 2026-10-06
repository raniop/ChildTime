package com.rani.tofy.billing

import android.icu.text.ListFormatter
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.firestore.FirebaseFirestore
import com.rani.tofy.data.Child
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.secs
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.ChildAvatar
import com.rani.tofy.ui.home.gradeName
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.tasks.await
import java.util.Locale

/**
 * PackDetailView.swift — the purchase part, on the PARENT's device: the
 * Tofy+-or-just-this-world choice for a pass, the child picker, the price for
 * exactly the children chosen (sibling price after the first), and the one
 * button that buys behind the parent gate and sends it to the children.
 *
 * @param packID a pack ("soccer") or a base world pass ("math") — QuestionPacks.find.
 * @param preselectedChildID the child who asked for it (a request banner), if any.
 */
@Composable
fun PackPurchaseScreen(packID: String, preselectedChildID: String? = null, onClose: () -> Unit) {
    val pack = remember(packID) { PlayPack.packs.firstOrNull { it.id == packID } ?: PlayPack.passes.firstOrNull { it.id == packID } }
    if (pack == null) { LaunchedEffect(Unit) { onClose() }; return }
    BackHandler(onBack = onClose)
    val ctx = LocalContext.current
    val family by FamilyRepository.state.collectAsState()
    val details by PlayPacks.details.collectAsState()
    val didLoad by PlayPacks.didAttemptLoad.collectAsState()
    val plans by PlaySubscriptions.plans.collectAsState()
    val introEligible by PlaySubscriptions.yearlyIntroEligible.collectAsState()
    val kids = family.orderedChildren
    val premium = family.household?.isPremium == true

    var selected by remember { mutableStateOf<Set<String>>(emptySet()) }
    var granted by remember { mutableStateOf<List<String>>(emptyList()) }   // names just sent to
    var gateOpen by remember { mutableStateOf(false) }
    var showTofyPlus by remember { mutableStateOf(false) }
    var choosingTofyPlus by remember { mutableStateOf(false) }
    var purchaseFailed by remember { mutableStateOf<String?>(null) }

    // The "just this world" door is a fallback for a family that will not
    // subscribe — it appears only once their gift has ended (founder knob).
    val oneTimeDoorAllowed by produceState(!pack.isPass, family.household?.id) {
        if (!pack.isPass) { value = true; return@produceState }
        val db = FirebaseFirestore.getInstance()
        val afterGiftOnly = runCatching { db.collection("config").document("conversion").get().await().getBoolean("oneTimeAfterGiftOnly") }.getOrNull() ?: true
        val giftEnded = family.household?.id?.let { hid ->
            runCatching { db.collection("households").document(hid).get().await().data?.secs("giftEndedAt") }.getOrNull()
        } != null
        value = !afterGiftOnly || giftEnded
        if (!value) choosingTofyPlus = true
    }

    LaunchedEffect(Unit) {
        selected = preselectedChildID?.let { setOf(it) } ?: kids.firstOrNull { !it.ownsPlayPack(pack) }?.let { setOf(it.id) } ?: emptySet()
        if (PlayPacks.details.value.isEmpty()) PlayPacks.load(ctx)
        if (pack.isPass && PlaySubscriptions.plans.value.isEmpty()) PlaySubscriptions.load(ctx)
        BillingRepository.resume(ctx)
    }

    val selectedIDs = kids.filter { it.id in selected }.map { it.id }
    @Suppress("UNUSED_VARIABLE") val loaded = details   // recompose when Play's prices arrive
    val priceLabel = PlayPacks.priceLabel(pack, selectedIDs)
    val durationLabel = pack.durationDays?.let { tr("%lld יוֹם", it) } ?: tr("לְתָמִיד")

    when {
        showTofyPlus -> { GatedPaywall(if (pack.isPass) "child_request" else "new_world") { showTofyPlus = false }; return }
        gateOpen -> {
            BillingParentGate(tr("כְּדֵי לִרְכֹּשׁ אֶת הַשְּׁאֵלוֹן — הַזִּינוּ אֶת הַקּוֹד"), onClose = { gateOpen = false }) {
                Purchasing(pack, selectedIDs) { r ->
                    if (r.grantedChildIDs.isNotEmpty()) granted = kids.filter { it.id in r.grantedChildIDs }.map { it.name }
                    else purchaseFailed = PlayPacks.lastError.value ?: tr("בִּטַּלְתֶּם אֶת הָרְכִישָׁה.")
                    gateOpen = false
                }
            }
            return
        }
    }

    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(top = 8.dp, bottom = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.widthIn(max = 680.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Header(pack, onClose)
                when {
                    premium && !pack.isPass -> IncludedInTofyPlus(onClose)
                    granted.isEmpty() -> Column(
                        Modifier.fillMaxWidth().glassPane(22.dp, 0.09f).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        if (pack.isPass && oneTimeDoorAllowed) {
                            // 🌍 Two doors: this world for 30 days, or Tofy+ for everything.
                            Label(tr("אֵיךְ לִפְתֹּחַ?"))
                            val oneName = if (selectedIDs.size == 1 && !choosingTofyPlus) tr(", לְ%@", kids.first { it.id == selectedIDs[0] }.name) else ""
                            OptionRow(
                                title = tr("רַק הָעוֹלָם הַזֶּה") + oneName,
                                price = priceLabel ?: PlayPacks.displayPrice(pack) ?: "",
                                line = tr("%@ · לְיֶלֶד אֶחָד · בְּלִי מִנּוּי · בְּלִי חִדּוּשׁ אוֹטוֹמָטִי", durationLabel),
                                selected = !choosingTofyPlus, gold = false,
                            ) { choosingTofyPlus = false }
                            OptionRow(
                                title = tr("👑 טוֹפִי+ לְכָל הַמִּשְׁפָּחָה"),
                                price = plans.firstOrNull { it.id == ProductIds.MONTHLY }?.pricePerPeriod ?: "",
                                line = tr("כָּל %lld הָעוֹלָמוֹת, מִשְׂחָקִים, זִירָה וּמַטְלוֹת · לְכָל הַיְלָדִים", PlayPack.availablePasses.size) +
                                    (if (introEligible) tr(" · 7 יָמִים חִנָּם") else ""),
                                selected = choosingTofyPlus, gold = true,
                            ) { choosingTofyPlus = true }
                            Spacer(Modifier.height(4.dp))
                        }
                        if (choosingTofyPlus) {
                            // The family door: no child to pick — one subscription for everyone.
                            Cta(if (introEligible) tr("הַתְחִילוּ 7 יָמִים חִנָּם") else tr("לְכָל הַפְּרָטִים שֶׁל טוֹפִי+"), enabled = true) { showTofyPlus = true }
                            FinePrint(tr("מֵאֲחוֹרֵי קוֹד הוֹרֶה · Google Play · נִפְתָּח לְכָל הַיְלָדִים בְּכָל הַמַּכְשִׁירִים"))
                        } else {
                            Label(if (pack.isPass) tr("לְמִי?") else tr("לְמִי לִשְׁלֹחַ?"))
                            kids.forEach { kid ->
                                KidRow(kid, pack, kid.id in selected) {
                                    selected = if (kid.id in selected) selected - kid.id else selected + kid.id
                                }
                            }
                            Row(Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                                val n = selectedIDs.size
                                Text(
                                    if (pack.isPass) (if (n > 1) tr("לְ־%lld יְלָדִים · %@", n, durationLabel) else tr("לְיֶלֶד אֶחָד · %@", durationLabel))
                                    else (if (n > 1) tr("לְ־%lld יְלָדִים · פַּעַם אַחַת", n) else tr("לְיֶלֶד אֶחָד · פַּעַם אַחַת")),
                                    Modifier.weight(1f), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp,
                                )
                                Text(priceLabel ?: if (didLoad) "—" else "…", color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp)
                            }
                            val familyOwns = family.household?.ownedPacks?.contains(pack.id) == true || kids.any { it.hasPackRecord(pack) }
                            if (!pack.isPass && familyOwns && selectedIDs.isNotEmpty()) {
                                Text(tr("הַמִּשְׁפָּחָה כְּבָר רָכְשָׁה — יֶלֶד נוֹסָף בַּחֲצִי מְחִיר"), color = Ink.good, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                            }
                            Cta(ctaTitle(pack, kids.filter { it.id in selected }.map { it.name }, durationLabel), enabled = selectedIDs.isNotEmpty() && priceLabel != null) {
                                gateOpen = true
                            }
                            FinePrint(
                                if (pack.isPass) tr("מֵאֲחוֹרֵי קוֹד הוֹרֶה · Google Play · הָעוֹלָם נִפְתָּח לַיֶּלֶד מִיָּד · בְּלִי חִדּוּשׁ אוֹטוֹמָטִי")
                                else tr("מֵאֲחוֹרֵי קוֹד הוֹרֶה · Google Play · הַשְּׁאֵלוֹן נִכְנָס לַיֶּלֶד מִיָּד"),
                            )
                        }
                    }
                    else -> Success(pack, granted, durationLabel, onClose)
                }
            }
        }
    }

    purchaseFailed?.let { msg ->
        AlertDialog(
            onDismissRequest = { purchaseFailed = null },
            title = { Text(tr("הָרְכִישָׁה לֹא הֻשְׁלְמָה"), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold) },
            text = { Text(msg, fontFamily = Rounded) },
            confirmButton = { TextButton(onClick = { purchaseFailed = null }) { Text(tr("סָגוּר"), fontFamily = Rounded) } },
            containerColor = Ink.sheet, titleContentColor = Ink.primary, textContentColor = Ink.secondary,
        )
    }
}

private fun ctaTitle(pack: PlayPack, names: List<String>, durationLabel: String): String = when (names.size) {
    0 -> tr("בַּחֲרוּ יֶלֶד")
    1 -> if (pack.isPass) tr("פִּתְחוּ %@ לְ%@", durationLabel, names[0]) else tr("רִכְשׁוּ וְשִׁלְחוּ לְ%@", names[0])
    else -> if (pack.isPass) tr("פִּתְחוּ %@ לְ־%lld יְלָדִים", durationLabel, names.size) else tr("רִכְשׁוּ וְשִׁלְחוּ לְ־%lld יְלָדִים", names.size)
}

/** ListFormatter.localizedString(byJoining:) in the app's language. */
private fun joinNames(names: List<String>): String =
    runCatching { ListFormatter.getInstance(Locale(I18n.language.code)).format(names) }.getOrDefault(names.joinToString(", "))

@Composable
private fun Header(pack: PlayPack, onClose: () -> Unit) {
    Column(Modifier.fillMaxWidth().glassPane(22.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(36.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.18f)).clickable(onClick = onClose),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Filled.Close, tr("סְגֹר"), tint = Color.White, modifier = Modifier.size(16.dp)) }
            Spacer(Modifier.weight(1f))
            Text(
                if (pack.isPass) tr("עוֹלָם בְּסִיסִי · כָּלוּל בְּטוֹפִי+") else tr("כָּלוּל בְּטוֹפִי+ · אוֹ רְכִישָׁה חַד־פַּעֲמִית"),
                Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.12f)).padding(horizontal = 10.dp, vertical = 5.dp),
                color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 11.5.sp,
            )
        }
        Box(
            Modifier.fillMaxWidth().height(110.dp).clip(RoundedCornerShape(18.dp))
                .background(Brush.linearGradient(listOf(Color(0xFF8CFFC4).copy(alpha = 0.55f), Color(0xFF37E2D5).copy(alpha = 0.35f)))),
            contentAlignment = Alignment.Center,
        ) { Text(pack.emoji, fontSize = 54.sp) }
        Text(pack.name, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 24.sp)
    }
}

/** A Tofy+ family: nothing to buy — it's already open for every child. */
@Composable
private fun IncludedInTofyPlus(onClose: () -> Unit) {
    Column(Modifier.fillMaxWidth().glassPane(22.dp).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("👑", fontSize = 40.sp)
        Text(tr("כָּלוּל בְּטוֹפִי+ — כְּבָר פָּתוּחַ לְכָל הַיְלָדִים"), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, textAlign = TextAlign.Center)
        Text(tr("הָעוֹלָם מְחַכֶּה בַּמָּסָךְ הָרָאשִׁי שֶׁל כָּל יֶלֶד, עִם סִימוּן \"חָדָשׁ\"."), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.sp, textAlign = TextAlign.Center)
        Cta(tr("מְעוּלֶה"), enabled = true, onClick = onClose)
    }
}

@Composable
private fun KidRow(kid: Child, pack: PlayPack, isSelected: Boolean, onToggle: () -> Unit) {
    // A pass can be renewed — the child stays selectable.
    val owns = kid.ownsPlayPack(pack) && !pack.isPass
    val daysLeft = kid.passDaysLeft(pack)
    Row(
        Modifier.fillMaxWidth().glassInset(12.dp).alpha(if (owns) 0.75f else 1f).clickable(enabled = !owns, onClick = onToggle)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        val checked = isSelected || owns
        Box(
            Modifier.size(22.dp).clip(RoundedCornerShape(6.dp)).background(if (checked) Color.White else Color.Transparent)
                .border(1.5.dp, Color.White.copy(alpha = 0.5f), RoundedCornerShape(6.dp)),
            contentAlignment = Alignment.Center,
        ) { if (checked) Text("✓", color = Ink.indigo, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp) }
        ChildAvatar(kid, 30.dp)
        Text(kid.name, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.5.sp, maxLines = 1)
        Text(gradeName(kid.effectiveGrade), Modifier.weight(1f), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.5.sp, maxLines = 1)
        when {
            owns -> Text(tr("כְּבָר יֵשׁ ✓"), color = Ink.good, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            daysLeft != null && kid.ownsPlayPack(pack) -> Text(tr("עוֹד %lld יוֹם · חִדּוּשׁ", daysLeft), color = Ink.good, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            kid.passExpired(pack) -> Text(tr("נִגְמַר · לְהַמְשִׁיךְ"), color = Ink.warn, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 12.sp)
        }
    }
}

@Composable
private fun OptionRow(title: String, price: String, line: String, selected: Boolean, gold: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(14.dp)
    Column(
        Modifier.fillMaxWidth().clip(shape)
            .background(if (gold) Brush.linearGradient(listOf(Color(0xFFFFE082).copy(alpha = 0.45f), Color(0xFFFFB840).copy(alpha = 0.35f)))
                        else Brush.linearGradient(listOf(Color.White.copy(alpha = if (selected) 0.16f else 0.08f), Color.White.copy(alpha = if (selected) 0.16f else 0.08f))))
            .border(if (selected) 1.5.dp else 1.dp, if (selected) Color.White.copy(alpha = 0.9f) else if (gold) Color(0xFFFFEBAA).copy(alpha = 0.7f) else Color.White.copy(alpha = 0.2f), shape)
            .clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, Modifier.weight(1f), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.5.sp, maxLines = 1)
            Spacer(Modifier.size(6.dp))
            Text(price, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
        }
        Text(line, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 11.5.sp)
    }
}

@Composable
private fun Label(text: String) = Text(text, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)

@Composable
private fun FinePrint(text: String) =
    Text(text, Modifier.fillMaxWidth(), color = Ink.tertiary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 11.5.sp, textAlign = TextAlign.Center)

@Composable
private fun Cta(text: String, enabled: Boolean, onClick: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().padding(top = 4.dp).alpha(if (enabled) 1f else 0.5f).clip(RoundedCornerShape(13.dp))
            .background(Color.White.copy(alpha = 0.92f)).clickable(enabled = enabled, onClick = onClick).padding(vertical = 12.dp),
        contentAlignment = Alignment.Center,
    ) { Text(text, color = Ink.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, textAlign = TextAlign.Center) }
}

/** Inside the gate: runs the Play purchase right away, shows progress. */
@Composable
private fun Purchasing(pack: PlayPack, childIDs: List<String>, onDone: (PlayPacks.Result) -> Unit) {
    val ctx = LocalContext.current
    val busy by PlayPacks.isPurchasing.collectAsState()
    LaunchedEffect(Unit) {
        val activity = ctx.findActivity()
        val r = if (activity == null) PlayPacks.Result(emptyList(), false) else PlayPacks.purchase(activity, pack, childIDs)
        onDone(r)
    }
    GlassBackdrop {
        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically)) {
            Text(pack.emoji, fontSize = 54.sp)
            Text(if (busy) tr("מְאַשְּׁרִים מוּל Google Play…") else tr("פּוֹתְחִים אֶת הָרְכִישָׁה…"), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
            CircularProgressIndicator(Modifier.size(28.dp), color = Color.White, strokeWidth = 3.dp)
        }
    }
}

@Composable
private fun Success(pack: PlayPack, granted: List<String>, durationLabel: String, onClose: () -> Unit) {
    Column(Modifier.fillMaxWidth().glassPane(22.dp).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("🎉", fontSize = 44.sp)
        val names = joinNames(granted)
        Text(
            if (pack.isPass) tr("✓ %@ פָּתוּחַ לְ%@ לְ־%@", pack.name, names, durationLabel) else tr("✓ נִשְׁלַח לְ%@", names),
            color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, textAlign = TextAlign.Center,
        )
        Text(
            tr("%@ כְּבָר מְחַכֶּה בַּמָּסָךְ הָרָאשִׁי שֶׁל הַיֶּלֶד, עִם סִימוּן \"חָדָשׁ\". בַּפְּתִיחָה הַבָּאָה הוּא יְקַבֵּל הַפְתָּעָה קְטַנָּה 🎁", pack.name),
            color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.5.sp, textAlign = TextAlign.Center,
        )
        Cta(tr("סִיַּמְנוּ"), enabled = true, onClick = onClose)
    }
}
