package com.rani.tofy.kid.ui

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.firestore.FieldValue
import com.rani.tofy.data.Child
import com.rani.tofy.data.dbl
import com.rani.tofy.data.map
import com.rani.tofy.data.nowSecs
import com.rani.tofy.data.schoolYear
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidIdentity
import com.rani.tofy.kid.ui.social.SocialMe
import com.rani.tofy.kid.ui.home.KidWorld
import com.rani.tofy.ui.common.GoldButton
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import com.rani.tofy.kid.core.ProgressEngine

// ── 🎓 ChildGradePickerView ────────────────────────────────────────────────

/**
 * Shown once on a child whose profile has no grade (families from before
 * grades): the kid picks; it syncs to the parent flagged gradeSetByChild for
 * verification and anchors the September auto-advance (gradeSchoolYear).
 */
@Composable
internal fun ChildGradePicker(name: String, isGirl: Boolean, onPicked: (Int) -> Unit) {
    var chosen by remember { mutableStateOf<Int?>(null) }
    val scope = rememberCoroutineScope()
    val letters = listOf("א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ז׳", "ח׳")
    fun pick(g: Int) {
        if (chosen != null) return
        chosen = g
        scope.launch { delay(900); onPicked(g) }   // a beat of celebration first
    }
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text("🎓", fontSize = 76.sp, modifier = Modifier.padding(top = 20.dp))
            KidTitle(tr("הַיי %@!", name), 26)
            KidTitle(tr("בְּאֵיזוֹ כִּתָּה %@?", if (isGirl) tr("אַתְּ") else tr("אַתָּה")), 30)
            KidBody((if (isGirl) tr("כָּךְ טוֹפִי יַתְאִים אֶת הַשְּׁאֵלוֹת בְּדִיּוּק בִּשְׁבִילֵךְ 🎯") else tr("כָּךְ טוֹפִי יַתְאִים אֶת הַשְּׁאֵלוֹת בְּדִיּוּק בִּשְׁבִילְךָ 🎯")), 15f, alpha = 0.9f, weight = FontWeight.Bold)
            Column(Modifier.widthIn(max = 560.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    GradeChip(tr("גַּן טְרוֹם־חוֹבָה"), "🧸", chosen == -1, Modifier.weight(1f)) { pick(-1) }
                    GradeChip(tr("גַּן חוֹבָה"), "🎒", chosen == 0, Modifier.weight(1f)) { pick(0) }
                }
                (1..8).chunked(4).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { g -> GradeChip(tr("כִּתָּה %@", tr(letters[g - 1])), null, chosen == g, Modifier.weight(1f)) { pick(g) } }
                    }
                }
            }
            KidBody(tr("לֹא בְּטוּחִים? אֶפְשָׁר לִשְׁאֹל אֶת אַבָּא אוֹ אִמָּא 😊"), 13f, alpha = 0.75f)
        }
    }
}

@Composable
private fun GradeChip(label: String, emoji: String?, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier.clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = if (selected) 0.35f else 0.14f))
            .border(if (selected) 2.5.dp else 1.dp, if (selected) Ink.good else Color.White.copy(alpha = 0.25f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick).padding(vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        if (emoji != null) Text(emoji, fontSize = 24.sp)
        Text(label, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, maxLines = 1)
    }
}

// ── 💌 AskParentView ───────────────────────────────────────────────────────

/**
 * What a CHILD's device shows where a parent's shows the paywall: no prices,
 * no store — what Tofy+ opens, and a nudge to the parent's phone
 * (children/{id}.premiumRequestedAt/By/Topic, confirmed write).
 */
@Composable
internal fun AskParent(child: Child?, childID: String, householdID: String?, world: KidWorld?, onClose: () -> Unit) {
    BackHandler(onBack = onClose)
    val scope = rememberCoroutineScope()
    var sending by remember { mutableStateOf(false) }
    var sent by remember { mutableStateOf(false) }
    val girl = child?.isGirl == true
    fun g(m: String, f: String) = if (girl) f else m
    // The arena's nominal topic is logic (World.swift).
    val topic = world?.topic ?: if (world != null) com.rani.tofy.ui.child.Topic.LOGIC else null
    val passEnded = topic != null && child != null && child.packs.contains(topic.raw) &&
        (child.raw.map("packExpiry")?.dbl(topic.raw)?.let { it < nowSecs() } ?: false)

    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Box(Modifier.fillMaxWidth()) { CloseCircle(onClose) }
            Text(world?.emoji ?: "👑", fontSize = 72.sp)
            KidTitle(
                when {
                    topic == null -> tr("טוֹפִי+")
                    passEnded -> tr("%@ לְהַמְשִׁיךְ לִלְמֹד %@?", g(tr("רוֹצֶה"), tr("רוֹצָה")), topic.displayName)
                    else -> tr("%@ לִלְמֹד %@?", g(tr("רוֹצֶה"), tr("רוֹצָה")), topic.displayName)
                },
                if (world == null) 34 else 27,
            )
            KidBody(
                world?.let { tr("%@ וְכָל הָעוֹלָמוֹת נִפְתָּחִים עִם טוֹפִי+ לְכָל הַמִּשְׁפָּחָה — וְאַבָּא אוֹ אִמָּא פּוֹתְחִים אֶת זֶה מֵהַטֶּלֶפוֹן שֶׁלָּהֶם.", it.name) }
                    ?: tr("הַמִּשְׂחָקִים, הַזִּירָה, הַמַּטְלוֹת וְכָל הָעוֹלָמוֹת נִפְתָּחִים לְכָל הַמִּשְׁפָּחָה — וְאַבָּא אוֹ אִמָּא פּוֹתְחִים אֶת זֶה מֵהַטֶּלֶפוֹן שֶׁלָּהֶם."),
                16f, alpha = 0.9f,
            )
            Column(Modifier.widthIn(max = 520.dp).fillMaxWidth().glassPane(16.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                listOf(
                    "🎮" to tr("מִשְׂחָקִים וְזִירַת הָעֲנָקִים"), "🌍" to tr("כָּל הָעוֹלָמוֹת — בְּלִי גְּבוּלוֹת"),
                    "🧹" to tr("מַטְלוֹת הַבַּיִת עִם פְּרָסִים"), "👨‍👩‍👧" to tr("פַּעַם אַחַת — לְכָל הַמַּכְשִׁירִים בַּמִּשְׁפָּחָה"),
                ).forEach { (e, t) ->
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(e, fontSize = 22.sp)
                        Text(t, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
                    }
                }
            }
            Row(
                Modifier.widthIn(max = 520.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.92f))
                    .clickable(enabled = !sent && !sending) {
                        sending = true
                        scope.launch {
                            val fields = mapOf(
                                "premiumRequestedAt" to nowSecs(),
                                "premiumRequestedBy" to KidIdentity.friendlyName,
                                // Which world the child wanted — the parent's banner and push say it.
                                "premiumRequestedTopic" to (topic?.raw ?: FieldValue.delete()),
                            )
                            JoinRepository.childWrite(childID, householdID, fields)
                            sending = false; sent = true
                        }
                    }.padding(vertical = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically,
            ) {
                if (sending) CircularProgressIndicator(Modifier.size(20.dp), color = Ink.indigo, strokeWidth = 2.5.dp)
                Text(if (sent) tr("נִשְׁלַח לְאַבָּא וּלְאִמָּא ✅") else tr("%@ מֵאַבָּא אוֹ אִמָּא 💌", g(tr("בַּקֵּשׁ"), tr("בַּקְּשִׁי"))),
                    color = Ink.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp)
            }
            Text(if (sent) tr("הֵם יְקַבְּלוּ הוֹדָעָה בַּטֶּלֶפוֹן 📱") else tr("הַבַּקָּשָׁה מַגִּיעָה יָשָׁר לַטֶּלֶפוֹן שֶׁל הַהוֹרֶה"),
                color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.sp)
        }
    }
}

// ── ⚙️ ChildDeviceControlsView (behind the parent gate) ────────────────────

/**
 * The parent's corner on the kid's device. iOS keeps the Screen Time pickers
 * here; Android has no app blocking yet, so it holds what is real today:
 * which child this device is, stop the open window, leave Kid Mode, and
 * disconnect the device. Everything else is managed on the parent's phone.
 */
@Composable
internal fun KidDeviceControls(
    child: Child?, kidMode: Boolean, windowOpen: Boolean, secondsLeft: Int,
    onLockNow: () -> Unit, onExitKidMode: () -> Unit, onDisconnect: () -> Unit, onClose: () -> Unit,
    /** 🛡 The app lock's manage screen (child devices only — Kid Mode pins the screen instead). */
    onAppLock: (() -> Unit)? = null,
) {
    BackHandler(onBack = onClose)
    var confirm by remember { mutableStateOf(false) }
    val rtl = androidx.compose.ui.platform.LocalLayoutDirection.current == androidx.compose.ui.unit.LayoutDirection.Rtl
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Text("⚙️", fontSize = 44.sp)
            KidTitle(tr("בקרת המכשיר"), 28)
            Column(Modifier.widthIn(max = 520.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                if (kidMode) KidCta(tr("יציאה ממצב ילד ושחרור נעילת המכשיר"), Color(0xFFFF7A3D), Color(0xFFFF9F1C),
                    emoji = "🔓", size = 17, onClick = onExitKidMode)

                Row(Modifier.fillMaxWidth().glassPane(16.dp).padding(16.dp), verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    CharacterImage(child?.character3DID ?: "fox", Modifier.size(52.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f)),
                        contentScale = ContentScale.Crop)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(tr("המכשיר הזה מחובר ל%@", child?.name ?: ""), color = Color.White, fontFamily = Rounded,
                            fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                        Text(KidIdentity.friendlyName, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.sp)
                    }
                }

                if (windowOpen) Row(
                    Modifier.fillMaxWidth().glassPane(16.dp, 0.18f).padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text("🔓", fontSize = 22.sp)
                    Column(Modifier.weight(1f)) {
                        Text(tr("פתוח עכשיו"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                        Text(tr("נשארו כ-%lld דקות", maxOf(1, secondsLeft / 60)), color = Ink.secondary, fontFamily = Rounded, fontSize = 12.sp)
                    }
                    Text(tr("נעל"), Modifier.clip(RoundedCornerShape(16.dp)).background(Color(0xFFFF7A3D).copy(alpha = 0.55f))
                        .border(1.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(16.dp)).clickable(onClick = onLockNow)
                        .padding(horizontal = 14.dp, vertical = 8.dp),
                        color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
                }

                // ⏱ The child's daily limit, right here on the child's device (Rani).
                if (child != null) KidDailyCapRow(child)

                // iOS's "מָה פָּתוּחַ וּמָה נָעוּל" section → Android's guard manage screen.
                if (!kidMode && onAppLock != null) Row(
                    Modifier.fillMaxWidth().glassPane(16.dp, 0.18f).clickable(onClick = onAppLock).padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text("🔒", fontSize = 22.sp)
                    Text(tr("מה פתוח ומה נעול"), Modifier.weight(1f), color = Color.White, fontFamily = Rounded,
                        fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                    Text("›", color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 22.sp,
                        modifier = Modifier.graphicsLayer { scaleX = if (rtl) -1f else 1f })
                }

                if (!kidMode) Text(
                    tr("התנתקו מהמשפחה"),
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.12f))
                        .border(1.dp, Ink.weak.copy(alpha = 0.6f), RoundedCornerShape(16.dp)).clickable { confirm = true }.padding(vertical = 14.dp),
                    color = Ink.weak, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                )
            }
            KidBody(tr("שאר ההגדרות — פרסים, דוחות, רמת קושי והתראות — מנוהלות במכשיר ההורה."), 14f, alpha = 0.75f, weight = FontWeight.Medium)
            Text(tr("סגירה"), Modifier.clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f))
                .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp)).clickable(onClick = onClose)
                .padding(horizontal = 28.dp, vertical = 12.dp),
                color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        }
    }
    if (confirm) AlertDialog(
        onDismissRequest = { confirm = false },
        title = { Text(tr("לנתק את המכשיר?")) },
        text = { Text(tr("המכשיר יתנתק מהילד ויחזור למצב התחלתי (כאילו הותקן מחדש). ההתקדמות בענן נשמרת — אפשר תמיד לחבר שוב בסריקת הקוד.")) },
        confirmButton = { TextButton({ confirm = false; onDisconnect() }) { Text(tr("נתק ואפס"), color = Color(0xFFE53950)) } },
        dismissButton = { TextButton({ confirm = false }) { Text(tr("ביטול")) } },
    )
}

/** ⏱ Daily screen-time limit on the child's own device — one tap, saved at once. */
@Composable
private fun KidDailyCapRow(child: Child) {
    var cap by remember(child.id) { mutableStateOf(child.dailyCapMinutes) }
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    fun set(v: Int) {
        cap = v
        scope.launch {
            runCatching {
                com.google.firebase.firestore.FirebaseFirestore.getInstance().collection("children").document(child.id)
                    .set(mapOf("dailyCapMinutes" to v), com.google.firebase.firestore.SetOptions.merge()).await()
            }
        }
    }
    Column(Modifier.fillMaxWidth().glassPane(16.dp, 0.18f).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("⏱", fontSize = 22.sp)
            Column(Modifier.weight(1f)) {
                Text(tr("זמן מסך יומי"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                Text(cap?.takeIf { it > 0 }?.let { tr("עד %lld דקות ביום", it) } ?: tr("בלי הגבלה יומית"),
                    color = Ink.secondary, fontFamily = Rounded, fontSize = 13.sp)
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(30, 60, 90, 120, 0).forEach { v ->
                val on = (cap ?: -1) == v
                Text(if (v == 0) tr("ללא הגבלה") else "$v",
                    Modifier.weight(if (v == 0) 1.6f else 1f).clip(RoundedCornerShape(16.dp))
                        .background(if (on) Color.White else Color.White.copy(alpha = 0.14f))
                        .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp)).clickable { set(v) }
                        .padding(vertical = 10.dp),
                    color = if (on) Color(0xFF4B3FBF) else Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
                    fontSize = 15.sp, textAlign = androidx.compose.ui.text.style.TextAlign.Center, maxLines = 1)
            }
        }
    }
}

// ── 🔒 Kid Mode: the parent's phone becomes the child's ─────────────────────

/**
 * KidModeEntryView, Android: no app picker — the screen is PINNED to Tofy
 * (Activity.startLockTask), so the child plays only in Tofy, and leaving
 * needs the parent code. Shown to the parent before handing the phone over.
 */
@Composable
internal fun KidModeIntro(child: Child?, onStart: () -> Unit, onCancel: () -> Unit) {
    BackHandler(onBack = onCancel)
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Box(Modifier.fillMaxWidth()) { CloseCircle(onCancel) }
            KidTitle(tr("מַצַּב יֶלֶד"), 26)
            CharacterImage(child?.character3DID ?: "fox", Modifier.size(84.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.2f))
                .border(3.dp, GoldBrush, CircleShape), contentScale = ContentScale.Crop)
            if (child != null) Text(child.name, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
            Column(Modifier.widthIn(max = 480.dp).fillMaxWidth().glassPane(16.dp).padding(18.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("📌", fontSize = 34.sp)
                KidBody(tr("הַמָּסָךְ נִנְעָל עַל טוֹפִי — הַיֶּלֶד לוֹמֵד וּמְשַׂחֵק רַק בְּטוֹפִי. כְּדֵי לָצֵאת: קוֹד הוֹרֶה."), 15f, alpha = 0.9f)
            }
            Spacer(Modifier.weight(1f))
            GoldButton("🔒  " + tr("הַתְחִילוּ מַצַּב יֶלֶד"), Modifier.widthIn(max = 480.dp), onClick = onStart)
        }
    }
}

// ── explainers ─────────────────────────────────────────────────────────────

/** ChallengeInfoView for the daily challenge. */
@Composable
internal fun ChallengeInfo(done: Int, target: Int, prize: Int, ready: Boolean, claimed: Boolean, onCta: () -> Unit, onClose: () -> Unit) {
    BackHandler(onBack = onClose)
    KidCenterCard(onClose) {
        Box(Modifier.fillMaxWidth()) { CloseCircle(onClose) }
        Text("🔥", fontSize = 60.sp)
        KidTitle(tr("אֶתְגָּר יוֹמִי"), 26)
        KidBody(
            if (claimed) SocialMe.g(tr("הִשְׁלַמְתָּ אֶת הָאֶתְגָּר הַיּוֹם — כָּל הַכָּבוֹד! 🎉\nאֶפְשָׁר לְהַמְשִׁיךְ לְשַׂחֵק וְלִצְבֹּר עוֹד."), tr("הִשְׁלַמְתְּ אֶת הָאֶתְגָּר הַיּוֹם — כָּל הַכָּבוֹד! 🎉\nאֶפְשָׁר לְהַמְשִׁיךְ לְשַׂחֵק וְלִצְבֹּר עוֹד."))
            else SocialMe.g(tr("עֲנֵה נָכוֹן עַל %lld שְׁאֵלוֹת הַיּוֹם וְזָכֵה בִּ-%lld 💎!\nכָּל יוֹם רָצוּף שֶׁמְּשַׂחֲקִים — הַפְּרָס גָּדֵל. 🔥", target, prize), tr("עֲנִי נָכוֹן עַל %lld שְׁאֵלוֹת הַיּוֹם וּזְכִי בִּ-%lld 💎!\nכָּל יוֹם רָצוּף שֶׁמְּשַׂחֲקִים — הַפְּרָס גָּדֵל. 🔥", target, prize)),
            16f, alpha = 0.92f,
        )
        Text("$done/$target", color = Ink.gold2, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 22.sp)
        GoldButton(if (ready) tr("אִסְפוּ אֶת הַפְּרָס 🎁") else tr("קָדִימָה, נְעַנֶּה! 🚀"), onClick = onCta)
    }
}

/** The level sheet (WorldMapView.levelInfoSheet). */
@Composable
internal fun LevelInfo(level: Int, untilNext: Int, onClose: () -> Unit) {
    BackHandler(onBack = onClose)
    KidCenterCard(onClose) {
        Text("⭐", fontSize = 54.sp)
        KidTitle(tr("רָמַת טוֹפִי"), 28)
        KidBody(tr("כָּל תְּשׁוּבָה נְכוֹנָה נוֹתֶנֶת נְקוּדּוֹת. כְּשֶׁהַפַּס מִתְמַלֵּא עוֹלִים רָמָה — וּמְקַבְּלִים 💎 בּוֹנוּס לַחֲנוּת (10 עַל כָּל רָמָה). מֵרָמָה 5 הָאַוָּטָאר מְקַבֵּל מִסְגֶּרֶת בְּרוֹנְזָה, מֵ־10 כֶּסֶף, וּמֵ־20 זָהָב!"), 16f, alpha = 0.92f)
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.12f)).padding(14.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("רָמָה נוֹכְחִית: %lld", level), color = Ink.gold2, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
            KidBody(tr("עוֹד %lld תְּשׁוּבוֹת נְכוֹנוֹת לָרָמָה הַבָּאָה", untilNext), 15f, alpha = 0.85f)
        }
        GoldButton(tr("הֵבַנְתִּי!"), onClick = onClose)
    }
}

/** Grade-pick write: grade + the school year it was set in + "picked by the child" (Profile sync fields). */
internal suspend fun saveChildGrade(childID: String, householdID: String?, grade: Int) {
    JoinRepository.childWrite(childID, householdID, mapOf("grade" to grade, "gradeSchoolYear" to schoolYear(), "gradeSetByChild" to true))
}

/** Which header number the child tapped (WorldMapView.StatInfo). */
internal enum class StatInfoKind { MINUTES, STARS, DIAMONDS, GIFT, TODAY, CORRECT }

/**
 * ⏱ / ⭐ / 💎 explained — WorldMapView.statInfoCard + statInfoContent. Every
 * number on the kid's header opens one (Rani, on the tablet: nothing explained
 * itself). Diamonds → the shop, stars → the leaderboard, straight from it.
 */
@Composable
internal fun StatInfoSheet(kind: StatInfoKind, engine: ProgressEngine, onClose: () -> Unit,
                           onShop: () -> Unit, onLeaderboard: () -> Unit) {
    BackHandler(onBack = onClose)
    val emoji: String; val title: String; val subtitle: String; val body: String; val tip: String
    when (kind) {
        StatInfoKind.MINUTES -> {
            val cap = engine.settings.dailyCap
            val lines = ArrayList<String>()
            when {
                engine.canRedeemNow -> {
                    lines += tr("אֶפְשָׁר לִפְתּוֹחַ עַכְשָׁיו %lld דַּקּוֹת מִשְׂחָק! 🎮", engine.redeemableMinutesNow)
                    if (engine.pendingMinutes > engine.redeemableMinutesNow)
                        lines += tr("בָּאַרְנָק יֵשׁ %lld — הַשְּׁאָר נִשְׁמָר לְיָמִים הַבָּאִים.", engine.pendingMinutes)
                }
                engine.dailyScreenTimeMaxedOut ->
                    lines += SocialMe.g(tr("הִגַּעְתָּ לַמַּקְסִימוּם 🌙 — שִׂחַקְתָּ הַיּוֹם %lld מִתּוֹךְ %lld דַּקּוֹת. %lld דַּקּוֹת שְׁמוּרוֹת לְךָ לְמָחָר!",
                        engine.minutesPlayedToday, cap.max, engine.pendingMinutes), tr("הִגַּעַתְּ לַמַּקְסִימוּם 🌙 — שִׂחַקְתְּ הַיּוֹם %lld מִתּוֹךְ %lld דַּקּוֹת. %lld דַּקּוֹת שְׁמוּרוֹת לָךְ לְמָחָר!",
                        engine.minutesPlayedToday, cap.max, engine.pendingMinutes))
                engine.pendingMinutes > 0 ->
                    lines += SocialMe.g(tr("יֵשׁ לְךָ %lld דַּקּוֹת. פּוֹתְחִים זְמַן מִשְׂחָק מִ-%lld דַּקּוֹת — עֲנוּ עַל עוֹד שְׁאֵלוֹת! 😊",
                        engine.pendingMinutes, ProgressEngine.MINIMUM_UNLOCK_MINUTES), tr("יֵשׁ לָךְ %lld דַּקּוֹת. פּוֹתְחִים זְמַן מִשְׂחָק מִ-%lld דַּקּוֹת — עֲנוּ עַל עוֹד שְׁאֵלוֹת! 😊",
                        engine.pendingMinutes, ProgressEngine.MINIMUM_UNLOCK_MINUTES))
                cap.enabled && engine.snapshot.minutesEarnedToday >= cap.max -> {
                    lines += SocialMe.g(tr("וָואוּ — נִצַּלְתָּ אֶת כָּל %lld הַדַּקּוֹת שֶׁל הַיּוֹם! 🏆", cap.max), tr("וָואוּ — נִצַּלְתְּ אֶת כָּל %lld הַדַּקּוֹת שֶׁל הַיּוֹם! 🏆", cap.max))
                    lines += SocialMe.g(tr("כָּל מַה שֶּׁתַּרְוִיחַ עַכְשָׁיו נִשְׁמָר לְמָחָר."), tr("כָּל מַה שֶּׁתַּרְוִיחִי עַכְשָׁיו נִשְׁמָר לְמָחָר."))
                    if (engine.parentGiftMinutes > 0)
                        lines += SocialMe.g(tr("וְיֵשׁ לְךָ %lld דַּקּוֹת מַתָּנָה 💝 שֶׁאֶפְשָׁר לִפְתּוֹחַ גַּם עַכְשָׁיו!", engine.parentGiftMinutes), tr("וְיֵשׁ לָךְ %lld דַּקּוֹת מַתָּנָה 💝 שֶׁאֶפְשָׁר לִפְתּוֹחַ גַּם עַכְשָׁיו!", engine.parentGiftMinutes))
                }
                else -> lines += tr("עֲדַיִן אֵין דַּקּוֹת. עֲנוּ עַל שְׁאֵלוֹת כְּדֵי לְהַרְוִיחַ דַּקּוֹת מִשְׂחָק! 🎮")
            }
            if (cap.enabled && !engine.dailyScreenTimeMaxedOut)
                lines += SocialMe.g(tr("הַיּוֹם הִרְוַחְתָּ %lld מִתּוֹךְ %lld דַּקּוֹת.", engine.snapshot.minutesEarnedToday, cap.max), tr("הַיּוֹם הִרְוַחַתְּ %lld מִתּוֹךְ %lld דַּקּוֹת.", engine.snapshot.minutesEarnedToday, cap.max))
            val carry = engine.snapshot.carryOverMinutes ?: 0
            if (carry > 0) lines += tr("🎁 %lld דַּקּוֹת נִשְׁמְרוּ לְמָחָר.", carry)
            emoji = "🎮"; title = tr("דַּקּוֹת מִשְׂחָק"); subtitle = SocialMe.g(tr("זְמַן הַמִּשְׂחָק שֶׁלְּךָ"), tr("זְמַן הַמִּשְׂחָק שֶׁלָּךְ"))
            body = lines.joinToString("\n"); tip = tr("עוֹנִים נָכוֹן — מַרְוִיחִים עוֹד דַּקּוֹת!")
        }
        StatInfoKind.STARS -> {
            emoji = "⭐"; title = tr("%@ כּוֹכָבִים", "%,d".format(engine.snapshot.stars)); subtitle = tr("הַדֵּרוּג שֶׁלָּכֶם")
            body = tr("אוֹסְפִים כּוֹכָב עַל כָּל תְּשׁוּבָה נְכוֹנָה. הַכּוֹכָבִים אַף פַּעַם לֹא יוֹרְדִים — הֵם הַנִּקּוּד שֶׁלָּכֶם בְּטַבְלַת הַחֲבֵרִים!")
            tip = tr("כָּל מַה שֶּׁאַתֶּם לוֹמְדִים מְטַפֵּס בַּדֵּרוּג 🏆")
        }
        StatInfoKind.GIFT -> {
            val gift = engine.parentGiftMinutes
            emoji = "💝"; title = tr("%lld דַּקּוֹת מַתָּנָה", gift); subtitle = tr("מֵהַהוֹרִים 💝")
            body = if (gift > 0)
                tr("אֶת הַדַּקּוֹת הָאֵלֶּה הַהוֹרִים נָתְנוּ לָכֶם בְּמַתָּנָה — לֹא צָרִיךְ לַעֲנוֹת עַל שְׁאֵלוֹת כְּדֵי לִפְתּוֹחַ אוֹתָן.") +
                    "\n" + tr("פּוֹתְחִים אוֹתָן בַּכַּפְתּוֹר הַוָּרוֹד לְמַטָּה 🎁")
            else tr("כָּרֶגַע אֵין דַּקּוֹת מַתָּנָה. כְּשֶׁהַהוֹרִים יִשְׁלְחוּ מַתָּנָה — הִיא תּוֹפִיעַ כָּאן 💝")
            tip = tr("דַּקּוֹת מַתָּנָה נִשְׁמָרוֹת בִּנְפָרָד מֵהַדַּקּוֹת שֶׁהִרְוַחְתֶּם 😊")
        }
        StatInfoKind.TODAY -> {
            val cap = engine.settings.dailyCap
            val earned = engine.snapshot.minutesEarnedToday
            val lines = ArrayList<String>()
            if (cap.enabled) {
                lines += SocialMe.g(tr("הַיּוֹם הִרְוַחְתָּ %lld מִתּוֹךְ %lld דַּקּוֹת.", earned, cap.max), tr("הַיּוֹם הִרְוַחַתְּ %lld מִתּוֹךְ %lld דַּקּוֹת.", earned, cap.max))
                lines += tr("כְּשֶׁמַּגִּיעִים לַמַּקְסִימוּם הַיּוֹמִי (%lld דַּקּוֹת), מַה שֶּׁמַּרְוִיחִים אַחַר כָּךְ נִשְׁמָר לְמָחָר 🎁", cap.max)
            } else lines += tr("הַיּוֹם הִרְוַחְתֶּם %lld דַּקּוֹת.", earned)
            lines += tr("הַמִּסְפָּר הַזֶּה לֹא יוֹרֵד כְּשֶׁמְּשַׂחֲקִים — הוּא סוֹפֵר כַּמָּה הִרְוַחְתֶּם הַיּוֹם. כַּמָּה נִשְׁאַר לְשַׂחֵק? אֶת זֶה רוֹאִים לְיַד ⏱ דַּקּ׳ לְשַׂחֵק.")
            emoji = "⏱"; title = tr("%lld דַּקּוֹת הַיּוֹם", earned); subtitle = tr("כַּמָּה הִרְוַחְתֶּם הַיּוֹם")
            body = lines.joinToString("\n"); tip = tr("עוֹנִים נָכוֹן — מַרְוִיחִים עוֹד דַּקּוֹת!")
        }
        StatInfoKind.CORRECT -> {
            val correct = engine.snapshot.correctToday
            val left = maxOf(0, ProgressEngine.DAILY_CHALLENGE_TARGET - correct)
            emoji = "✅"; title = tr("%lld תְּשׁוּבוֹת נְכוֹנוֹת", correct); subtitle = tr("הַיּוֹם")
            body = tr("כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחָה %lld שְׁנִיּוֹת מִשְׂחָק, כּוֹכָבִים ⭐ וְיַהֲלוֹמִים 💎.", engine.settings.secondsPerCorrect) + "\n" +
                (if (left > 0) tr("עוֹד %lld תְּשׁוּבוֹת נְכוֹנוֹת וְהָאֶתְגָּר הַיּוֹמִי נִפְתָּח! 🔥", left) else tr("הָאֶתְגָּר הַיּוֹמִי הֻשְׁלַם! 🔥"))
            tip = tr("מָחָר מַתְחִילִים מֵאֶפֶס — וְהַכּוֹכָבִים נִשְׁאָרִים לְתָמִיד ⭐")
        }
        StatInfoKind.DIAMONDS -> {
            emoji = "💎"; title = tr("%@ יַהֲלוֹמִים", "%,d".format(engine.snapshot.diamonds)); subtitle = tr("הָאַרְנָק שֶׁלָּכֶם")
            body = tr("מַרְוִיחִים יַהֲלוֹמִים עַל תְּשׁוּבוֹת נְכוֹנוֹת, מִמַּתָּנוֹת וּמִגַּלְגַּל הַמַּזָּל — וְקוֹנִים בָּהֶם בַּחֲנוּת.")
            tip = tr("קְנִיָּה לֹא פּוֹגַעַת בַּדֵּרוּג שֶׁלָּכֶם 😊")
        }
    }
    KidCenterCard(onClose) {
        Text(emoji, fontSize = 54.sp)
        KidTitle(title, 26)
        KidBody(subtitle, 14f, alpha = 0.75f)
        KidBody(body, 17f, alpha = 0.95f)
        KidBody("💡 $tip", 14f, alpha = 0.8f)
        when (kind) {
            StatInfoKind.DIAMONDS -> KidCta(tr("לַחֲנוּת"), Color(0xFFFFD23F), Color(0xFFFF9F1C), emoji = "🛍️", size = 18) { onClose(); onShop() }
            StatInfoKind.STARS -> KidCta(tr("לַדֵּרוּג"), Color(0xFF10B981), Color(0xFF0E9E72), emoji = "🏆", size = 18) { onClose(); onLeaderboard() }
            else -> GoldButton(tr("הֵבַנְתִּי!"), onClick = onClose)
        }
    }
}
