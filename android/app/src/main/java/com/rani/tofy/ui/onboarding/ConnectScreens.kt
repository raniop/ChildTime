package com.rani.tofy.ui.onboarding

import com.rani.tofy.ui.common.contentColumn

import android.content.Context
import android.content.Intent
import android.text.format.DateFormat
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.data.ChildRepository
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.nowSecs
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.GoldButton
import com.rani.tofy.ui.common.H
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.common.WhiteButton
import com.rani.tofy.ui.theme.*
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.ceil

// MARK: shared invite plumbing

/** HouseholdManager.makeChildJoinCode — a per-child invite; on a permission error re-assert membership once. */
private suspend fun makeJoinCode(childID: String): String? =
    runCatching { ChildRepository.createInvite(childID) }.getOrElse {
        FamilyRepository.reassertMembership()
        runCatching { ChildRepository.createInvite(childID) }.getOrNull()
    }

/**
 * The invite for `childID` (null while it is made, or when it could not be),
 * plus a live watch on its redemption. `enabled = false` skips both — a child
 * whose device is already connected needs no new code.
 */
@Composable
private fun rememberJoinInvite(childID: String, enabled: Boolean = true, onRedeemed: () -> Unit): Pair<String?, () -> Unit> {
    var code by remember(childID) { mutableStateOf<String?>(null) }
    var attempt by remember(childID) { mutableIntStateOf(0) }
    var failed by remember(childID) { mutableStateOf(false) }
    LaunchedEffect(childID, attempt, enabled) {
        if (!enabled || code != null) return@LaunchedEffect
        failed = false
        code = makeJoinCode(childID)
        failed = code == null
    }
    val latest by rememberUpdatedState(onRedeemed)
    DisposableEffect(code) {
        val reg = code?.let { ChildRepository.watchRedemption(it) { latest() } }
        onDispose { reg?.remove() }
    }
    return (if (failed) "" else code) to { attempt++ }
}

private fun shareJoinLink(ctx: Context, url: String) {
    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, url)
    ctx.startActivity(Intent.createChooser(send, null))
}

/** The glass "share" capsule under the QR (iOS ShareLink). */
@Composable
private fun ShareCapsule(text: String, onClick: () -> Unit) {
    Text(
        "⤴︎  $text",
        Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(50)).clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, textAlign = TextAlign.Center,
    )
}

/** QR + code, or a retry when the invite could not be made (`code == ""`). */
@Composable
private fun QRBlock(childID: String, code: String?, size: Int, retryLabel: String, onRetry: () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (code == "") {
            Box(Modifier.size((size + 24).dp), contentAlignment = Alignment.Center) { WhiteButton(retryLabel, Modifier.padding(horizontal = 24.dp)) { onRetry() } }
        } else {
            // Encodes the Universal Link, so the iPhone's own Camera opens Tofy straight into joining.
            JoinQRCard(code?.let { ChildRepository.joinURL(it, childID) }, size.dp)
            if (code != null) CodeText(code)
        }
    }
}

// MARK: ③ the one question

/**
 * SetupChecklist.swift DeviceQuestionView. On Android only "own device" is
 * offered — the parent's Android phone cannot be a play device yet (no kid
 * mode here), so the iOS "plays on my phone" answer is left out; "later" is
 * the way past it.
 */
@Composable
fun DeviceQuestionScreen(name: String, girl: Boolean, showSteps: Boolean, onOwnDevice: () -> Unit, onPlaysHere: () -> Unit, onLater: () -> Unit) {
    GlassBackdrop {
        Column(
            Modifier.contentColumn().fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            if (showSteps) StepsHeader(step = 3)
            Spacer(Modifier.height(24.dp))
            if (!showSteps) P(tr("שאלה אחת"), 14f, color = Ink.gold2, weight = FontWeight.ExtraBold)
            H(if (girl) tr("ל%@ יש מכשיר משלה?", name) else tr("ל%@ יש מכשיר משלו?", name), 30, align = TextAlign.Center)
            P(if (girl) tr("זה מגדיר באיזה מכשיר %@ משחקת", name) else tr("זה מגדיר באיזה מכשיר %@ משחק", name),
                16f, color = Color.White.copy(alpha = 0.85f), weight = FontWeight.SemiBold, align = TextAlign.Center)
            Row(
                Modifier.fillMaxWidth().glassPane(20.dp).clickable(onClick = onOwnDevice).padding(16.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text("📱", fontSize = 30.sp)
                Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(if (girl) tr("כן, יש לה טלפון או אייפד") else tr("כן, יש לו טלפון או אייפד"),
                        color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
                    P(tr("נחבר אותו עכשיו בסריקת קוד"), 14f, color = Color.White.copy(alpha = 0.8f))
                }
            }
            // "plays on my phone" → Kid Mode here (screen pinning), the Android
            // counterpart of iOS's Kid Mode.
            Row(
                Modifier.fillMaxWidth().glassPane(20.dp).clickable(onClick = onPlaysHere).padding(16.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text("🧒", fontSize = 30.sp)
                Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(if (girl) tr("לא, היא תשחק בטלפון שלי") else tr("לא, הוא ישחק בטלפון שלי"),
                        color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
                    P(if (girl) tr("%@ תשחק כאן, במצב ילד", name) else tr("%@ ישחק כאן, במצב ילד", name),
                        14f, color = Color.White.copy(alpha = 0.8f))
                }
            }
            Spacer(Modifier.height(24.dp))
            P(tr("ניתן לחבר מכשיר של ילד במועד מאוחר יותר"), 13f, color = Color.White.copy(alpha = 0.7f), weight = FontWeight.SemiBold, align = TextAlign.Center)
            OnboardingFooter(null, link = tr("אחבר אחר כך"), onLink = onLater)
        }
    }
}

// MARK: ③ → ④ the QR, then waiting for the lock

/**
 * OnboardingConnectView.swift: the QR for the child's phone and a live "waiting
 * for the scan" line; the moment the child's phone joins the same screen turns
 * into "✓ connected" and waits for Screen Time to be approved there
 * (ChildLockSetupView runs on the child's device). A device reporting
 * `shieldAuthorized` ends the flow by itself.
 */
@Composable
fun OnboardingConnectScreen(childID: String, name: String, girl: Boolean, onLocked: () -> Unit, onLater: () -> Unit) {
    val ctx = LocalContext.current
    val state by FamilyRepository.state.collectAsState()
    val devices = state.devicesOf(childID)
    val alreadyLinked = remember(childID) { devices.isNotEmpty() }
    var redeemed by remember(childID) { mutableStateOf(false) }
    val linked = alreadyLinked || redeemed || devices.isNotEmpty()
    val lockApproved = devices.any { it.shieldAuthorized == true }
    var ended by remember(childID) { mutableStateOf(false) }
    val (code, retry) = rememberJoinInvite(childID, enabled = !alreadyLinked) { redeemed = true }

    LaunchedEffect(lockApproved) {
        if (lockApproved && !ended) { ended = true; delay(400); onLocked() }
    }
    val later = { if (!ended) { ended = true; onLater() } }

    GlassBackdrop {
        Column(
            Modifier.contentColumn().fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            StepsHeader(step = if (linked) 4 else 3)
            if (!linked) {
                H(tr("מחברים את הטלפון של %@", name), 24, align = TextAlign.Center)
                Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(12.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                    NumberedStep(1, tr("בטלפון של %@: מורידים את טופי מה-App Store או מ-Google Play", name))
                    NumberedStep(2, tr("פותחים, בוחרים \"המכשיר של הילד\" וסורקים את הקוד"))
                }
                QRBlock(childID, code, 190, tr("נסו שוב"), retry)
                WaitingPill(tr("מחכים שתסרקו בטלפון של %@…", name))
                if (!code.isNullOrEmpty()) ShareCapsule(tr("שליחת טופי לטלפון של %@", name)) { shareJoinLink(ctx, ChildRepository.joinURL(code, childID)) }
                Spacer(Modifier.height(4.dp))
                OnboardingFooter(null, link = tr("אחבר אחר כך"), onLink = later)
            } else {
                Spacer(Modifier.height(24.dp))
                Text("✓", Modifier.size(96.dp).clip(RoundedCornerShape(50)).background(Ink.good).wrapContentSize(),
                    color = Ink.deep, fontWeight = FontWeight.Black, fontSize = 56.sp)
                H(if (girl) tr("%@ מחוברת!", name) else tr("%@ מחובר!", name), 30, align = TextAlign.Center)
                P(tr("צעד אחרון, בטלפון של %@:\nלאשר זמן מסך כדי שהנעילה תעבוד", name), 16f, color = Color.White.copy(alpha = 0.9f),
                    weight = FontWeight.SemiBold, align = TextAlign.Center)
                WaitingPill(tr("מחכים לאישור בטלפון של %@…", name))
                P(tr("המסך הזה יתעדכן לבד כשתסיימו שם"), 13f, color = Color.White.copy(alpha = 0.75f), align = TextAlign.Center)
                Spacer(Modifier.height(24.dp))
                OnboardingFooter(null, link = tr("אמשיך אחר כך"), onLink = later)
            }
        }
    }
}

// MARK: 🎉 done, and the gift

/** OnboardingSteps.swift OnboardingDoneView (the child has their own device). */
@Composable
fun OnboardingDoneScreen(name: String, girl: Boolean, onDone: () -> Unit) {
    val state by FamilyRepository.state.collectAsState()
    val gift = GiftWelcome.until(state.household) != null
    GlassBackdrop {
        Column(
            Modifier.contentColumn().fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            StepsHeader(step = 5)
            Spacer(Modifier.height(16.dp))
            Text("🎉", fontSize = 72.sp)
            H(tr("הכל מוכן!"), 34, align = TextAlign.Center)
            P(if (girl) tr("הטלפון של %@ נעול, והיא מרוויחה זמן מסך על כל תשובה נכונה", name)
              else tr("הטלפון של %@ נעול, והוא מרוויח זמן מסך על כל תשובה נכונה", name),
                16f, color = Color.White.copy(alpha = 0.9f), weight = FontWeight.SemiBold, align = TextAlign.Center)
            if (gift) Column(
                Modifier.fillMaxWidth().glassPane(22.dp, 0.18f).border(1.dp, Ink.gold2.copy(alpha = 0.5f), RoundedCornerShape(22.dp)).padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text("🎁", fontSize = 38.sp)
                H(tr("ובונוס: 30 יום טופי+ במתנה"), 18, align = TextAlign.Center)
                P(tr("כל העולמות פתוחים לכל הילדים"), 13f, color = Color.White.copy(alpha = 0.8f), weight = FontWeight.SemiBold, align = TextAlign.Center)
            }
            Spacer(Modifier.height(16.dp))
            OnboardingFooter(tr("לבית של המשפחה"), action = onDone)
        }
    }
}

/** GiftWelcomeView.swift: "קיבלתם את טופי+ במתנה" — once per gift. */
@Composable
fun GiftWelcomeScreen(until: Double, onDone: () -> Unit) {
    val daysLeft = maxOf(1, ceil((until - nowSecs()) / 86_400).toInt())
    val endDate = remember(until, I18n.language) {
        val loc = Locale(I18n.language.code)
        SimpleDateFormat(DateFormat.getBestDateTimePattern(loc, "d MMMM"), loc).format(Date((until * 1000).toLong()))
    }
    GlassBackdrop {
        Column(
            Modifier.contentColumn().fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 26.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Spacer(Modifier.height(10.dp))
            Text("🎁", fontSize = 96.sp)
            H(tr("קיבלתם את טופי+ במתנה!"), 32, align = TextAlign.Center)
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("$daysLeft", style = TextStyle(brush = GoldBrush, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 76.sp))
                Text(if (daysLeft >= 29) tr("ימים של כל העולמות") else tr("ימים נשארו במתנה"),
                    color = Color.White.copy(alpha = 0.92f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
            }
            Column(Modifier.fillMaxWidth().glassPane(22.dp).padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Perk("🌍", tr("כל העולמות פתוחים לכל הילדים במשפחה"))
                Perk("💳", tr("בלי כרטיס אשראי, ולא מתחדש אוטומטית"))
                Perk("📅", tr("המתנה מסתיימת ב-%@", endDate))
            }
            Spacer(Modifier.height(10.dp))
            GoldButton(tr("יאללה, מתחילים"), Modifier.padding(bottom = 12.dp), onClick = onDone)
        }
    }
}

@Composable
private fun Perk(emoji: String, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(emoji, fontSize = 22.sp)
        Text(text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 16.sp)
    }
}

// MARK: the dashboard's QR sheet

/**
 * ParentDashboardView.swift childQRSheet: a per-child join QR, the code big, the
 * three steps, share, close. The moment the child's device redeems the invite
 * it turns into "connected 🎉" and closes itself two seconds later.
 * (iOS's "this iPad is the child's" convert button is iPad-only — not here.)
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConnectDeviceSheet(childID: String, onDismiss: () -> Unit) {
    val ctx = LocalContext.current
    val state by FamilyRepository.state.collectAsState()
    val name = state.children.firstOrNull { it.id == childID }?.name ?: ""
    var linked by remember(childID) { mutableStateOf(false) }
    val (code, retry) = rememberJoinInvite(childID) { linked = true }
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val close by rememberUpdatedState(onDismiss)
    LaunchedEffect(linked) { if (linked) { delay(2000); close() } }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = Ink.sheet) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(bottom = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            if (linked) {
                Spacer(Modifier.height(30.dp))
                Text("✓", Modifier.size(96.dp).clip(RoundedCornerShape(50)).background(Ink.good).wrapContentSize(),
                    color = Ink.deep, fontWeight = FontWeight.Black, fontSize = 56.sp)
                H(tr("הַמַּכְשִׁיר שֶׁל %@ חוּבַּר! 🎉", name), 24, align = TextAlign.Center)
                Spacer(Modifier.height(30.dp))
            } else {
                H(tr("חַבְּרוּ אֶת הַמַּכְשִׁיר שֶׁל %@", name), 24, align = TextAlign.Center)
                Box(Modifier.glassPane(24.dp).padding(16.dp)) { QRBlock(childID, code, 210, tr("נַסּוּ שׁוּב"), retry) }
                Column(Modifier.fillMaxWidth().glassInset(16.dp).padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    P(tr("1️⃣  הוֹרִידוּ אֶת טוֹפִי בַּמַּכְשִׁיר שֶׁל %@ — מֵה־App Store אוֹ מִ־Google Play", name), 14f, color = Color.White, weight = FontWeight.SemiBold)
                    P(tr("2️⃣  פִּתְחוּ שָׁם אֶת טוֹפִי וּבַחֲרוּ \"הַמַּכְשִׁיר שֶׁל הַיֶּלֶד\""), 14f, color = Color.White, weight = FontWeight.SemiBold)
                    P(tr("3️⃣  סִרְקוּ אֶת הַקּוֹד — וְ%@ נִכְנָס יְשִׁירוֹת לְשַׂחֵק 🎉", name), 14f, color = Color.White, weight = FontWeight.SemiBold)
                }
                if (!code.isNullOrEmpty()) ShareCapsule(tr("שִׁלְחוּ אֶת טוֹפִי לַמַּכְשִׁיר שֶׁל %@", name)) { shareJoinLink(ctx, ChildRepository.joinURL(code, childID)) }
                WhiteButton(tr("סְגוֹר"), Modifier.widthIn(min = 140.dp).padding(horizontal = 8.dp)) { onDismiss() }
                P(tr("אֶפְשָׁר לְדַלֵּג וּלְחַבֵּר אֶת הַמַּכְשִׁיר אַחַר כָּךְ — מֵהַמָּסָךְ הָרָאשִׁי."), 12f, align = TextAlign.Center)
            }
        }
    }
}
