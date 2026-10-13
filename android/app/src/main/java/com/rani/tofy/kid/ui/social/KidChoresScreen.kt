package com.rani.tofy.kid.ui.social

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.layout.offset
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import com.rani.tofy.data.Chore
import com.rani.tofy.kid.ui.CharacterImage
import com.rani.tofy.kid.ui.games.PreReaderSpeakButton
import com.rani.tofy.kid.ui.play.ConfettiOverlay
import com.rani.tofy.ui.chores.ChoreArt
import com.rani.tofy.ui.chores.ChorePicture
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.KidBottomCard
import com.rani.tofy.kid.ui.KidCenterCard
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.KidHaptics
import com.rani.tofy.kid.ui.play.KidSounds
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * ChoresKidView: the parent defined the chores; the kid does one and ticks its
 * box (optionally with a 📸 proof photo). The reward is always 🎮 play minutes,
 * landing only after a parent approves. No failure language anywhere: a
 * returned chore is simply an empty box again, a send that didn't reach the
 * parent is a gentle "let's try again".
 *
 * The look (Rani, 2026-10-13, chosen from nine directions — "ח"): a checklist
 * in pictures. The child's own buddy stands on top holding the day's prize,
 * every chore is one coloured row with a drawing of it ([ChoreArt]) and one
 * big box to tick, and a tick that reaches the parent is a small party.
 */
@Composable
internal fun KidChoresContent(onClose: () -> Unit) {
    val store = KidChoresStore
    val ctx = LocalContext.current
    val haptics = KidHaptics(LocalView.current)
    val scope = rememberCoroutineScope()
    val childID = SocialMe.id
    var pending by remember { mutableStateOf<Chore?>(null) }       // reward picked → photo offer
    var sending by remember { mutableStateOf(setOf<String>()) }
    var justSent by remember { mutableStateOf(setOf<String>()) }
    var retryChore by remember { mutableStateOf<String?>(null) }
    // 🎉 A chore has just reached the parent: confetti, the prize pops out of its row, the buddy cheers.
    var celebrated by remember { mutableStateOf<String?>(null) }
    var confetti by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) { store.startIfNeeded(); KidSounds.init(ctx) }
    BackHandler(onBack = onClose)

    fun send(chore: Chore, photo: ByteArray?) {
        // "שולחים…" while we WAIT for the server — no fake celebration for a write that might not land.
        sending = sending + chore.id
        scope.launch {
            val r = store.markDone(chore, "minutes", photo)
            sending = sending - chore.id
            when (r) {
                KidChoresStore.SendResult.SENT, KidChoresStore.SendResult.QUEUED -> {
                    justSent = justSent + chore.id   // latency bridge until the listener flips isPendingApproval
                    haptics.success(); KidSounds.play(AppSound.PORTAL_APPEAR)
                    launch { delay(4000); justSent = justSent - chore.id }
                    // Only now — the chore really reached the parent.
                    celebrated = chore.id; confetti += 1
                    launch { delay(1800); if (celebrated == chore.id) celebrated = null }
                }
                else -> { retryChore = chore.id; haptics.light() }
            }
        }
    }
    fun finish(photo: ByteArray?) { val c = pending ?: return; pending = null; send(c, photo) }

    // Full-size capture into our cache via the FileProvider (TakePicturePreview is a thumbnail).
    val shotFile = remember { java.io.File(ctx.cacheDir, "photos/chore_proof.jpg") }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        com.rani.tofy.kid.enforce.CameraPass.disarm(ctx)   // back in Tofy — the camera is locked again
        if (!ok || !shotFile.exists()) { pending = null; return@rememberLauncherForActivityResult }
        scope.launch {
            finish(withContext(Dispatchers.IO) {
                decodeProof(ctx, Uri.fromFile(shotFile))?.let { KidChoresStore.compressProof(it) }.also { shotFile.delete() }
            })
        }
    }
    fun launchCamera() {
        val uri = runCatching {
            shotFile.parentFile?.mkdirs(); shotFile.delete()
            androidx.core.content.FileProvider.getUriForFile(ctx, ctx.packageName + ".files", shotFile)
        }.getOrNull()
        if (uri == null) { pending = null; return }
        // 📸 The lock blocks every other app — let the camera through for this one photo.
        com.rani.tofy.kid.enforce.CameraPass.arm(ctx)
        runCatching { camera.launch(uri) }.onFailure { pending = null; com.rani.tofy.kid.enforce.CameraPass.disarm(ctx) }
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (ok) launchCamera() else pending = null
    }
    val library = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) { pending = null; return@rememberLauncherForActivityResult }
        scope.launch { finish(withContext(Dispatchers.IO) { decodeProof(ctx, uri)?.let { KidChoresStore.compressProof(it) } }) }
    }
    val hasCamera = remember { ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY) }

    val mine = childID?.let { store.choresFor(it) } ?: emptyList()
    fun handled(c: Chore) = c.id in sending || c.id in justSent || c.isPendingApproval || (c.isDaily && c.approvedToday)
    // One list: what can be done now on top, what was handled today under it.
    val ordered = mine.filter { !handled(it) } + mine.filter { handled(it) }
    /** How many times a day this chore can be done (a one-off: once). */
    fun turns(c: Chore) = if (c.isDaily) maxOf(1, c.timesPerDay) else 1
    /** Turns already done today — approved ones, plus the one on its way to a parent. */
    fun turnsDone(c: Chore) = minOf(turns(c), (if (c.isDaily) c.doneToday else 0) +
        if (c.isPendingApproval || c.id in sending || c.id in justSent) 1 else 0)
    val preReader = (SocialMe.child?.effectiveGrade ?: 1) <= 1

    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 12.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(40.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.22f))
                    .border(1.dp, Color.White.copy(alpha = 0.32f), RoundedCornerShape(16.dp))
                    .clickable { haptics.light(); onClose() }, contentAlignment = Alignment.Center) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, tr("חזרה"), tint = Color.White, modifier = Modifier.size(20.dp))
                }
                Text(tr("מַטְלוֹת הַבַּיִת 🧹"), Modifier.weight(1f), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.Black,
                    fontSize = 24.sp, textAlign = TextAlign.Center)
                Spacer(Modifier.size(40.dp))
            }
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val cols = if (maxWidth >= 600.dp) 2 else 1
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 14.dp, vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Column(Modifier.widthIn(max = if (cols == 2) 860.dp else 560.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        val minutes = childID?.let { store.totals(it).minutes } ?: 0
                        if (mine.isEmpty()) {
                            // 🏆 Lifetime earnings — alone only while there are no chores.
                            if (minutes > 0) Row(Modifier.fillMaxWidth().glassPane(16.dp).background(SocialColor.starGold.copy(alpha = 0.14f)).padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Text("🏆", fontSize = 30.sp)
                                Column(Modifier.weight(1f)) {
                                    Text(SocialMe.g(tr("סַךְ הַכֹּל הִרְוַחְתָּ מֵהַמַּטְלוֹת:"), tr("סַךְ הַכֹּל הִרְוַחַתְּ מֵהַמַּטְלוֹת:")), color = Color.White.copy(alpha = 0.85f),
                                        fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                                    Text(tr("🎮 %lld דַּקּוֹת מִשְׂחָק", minutes), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                                }
                            }
                            Column(Modifier.fillMaxWidth().padding(top = 60.dp), horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                Text("🧹", fontSize = 56.sp)
                                Text(tr("עוֹד אֵין מַטְלוֹת"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
                                Text(tr("בַּקְּשׁוּ מֵאַבָּא אוֹ אִמָּא לְהוֹסִיף מַטְלוֹת —\nוְתוּכְלוּ לְהַרְוִיחַ דַּקּוֹת מִשְׂחָק אוֹ כֶּסֶף! 💪"), color = Color.White.copy(alpha = 0.9f),
                                    fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, textAlign = TextAlign.Center)
                            }
                        } else {
                            BuddyHero(
                                left = mine.sumOf { maxOf(it.rewardMinutes, 0) * (turns(it) - turnsDone(it)) },
                                total = mine.sumOf { turns(it) }, done = mine.sumOf { turnsDone(it) },
                                lifetime = minutes, cheering = celebrated != null,
                            )
                            Grid(ordered, cols) { c ->
                                ChoreRow(c, handled = handled(c), isSending = c.id in sending, celebrating = celebrated == c.id,
                                    turns = turns(c), turnsDone = turnsDone(c), speak = preReader) { haptics.success(); pending = c }
                            }
                        }
                    }
                }
            }
        }
        ConfettiOverlay(confetti)

        // 📸 Optional proof photo — a picture beats a debate about whether the room is tidy (Rani).
        if (pending != null) KidBottomCard(onDismiss = { pending = null }) {
            Text(tr("רוֹצִים לְצָרֵף תְּמוּנָה שֶׁל מַה שֶּׁעֲשִׂיתֶם? 📸"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
                fontSize = 17.sp, textAlign = TextAlign.Center)
            if (hasCamera) WhiteCapsule(tr("📸 לְצַלֵּם עַכְשָׁו"), Modifier.fillMaxWidth()) {
                if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) launchCamera()
                else cameraPermission.launch(Manifest.permission.CAMERA)
            }
            WhiteCapsule(tr("🖼 לִבְחֹר תְּמוּנָה"), Modifier.fillMaxWidth()) {
                library.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            }
            WhiteCapsule(tr("לִשְׁלֹחַ בְּלִי תְּמוּנָה"), Modifier.fillMaxWidth()) { finish(null) }
            Text(tr("בִּטּוּל"), Modifier.clickable { pending = null }.padding(8.dp), color = Color.White.copy(alpha = 0.85f),
                fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 15.sp)
        }
        // Gentle recovery — the send didn't reach the parent. No blame; the chore is still there.
        if (retryChore != null) KidCenterCard(onDismiss = { retryChore = null }) {
            Text(tr("רֶגַע! ✨"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 22.sp)
            Text(tr("לֹא הִסְפַּקְנוּ לִשְׁלֹחַ לְאַבָּא אוֹ אִמָּא. נַסּוּ שׁוּב עוֹד רֶגַע 🙂"), color = Color.White.copy(alpha = 0.9f),
                fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, textAlign = TextAlign.Center)
            WhiteCapsule(tr("אוֹקֵיי"), Modifier.fillMaxWidth()) { retryChore = null }
        }
    }
}

@Composable
private fun Grid(items: List<Chore>, cols: Int, cell: @Composable (Chore) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        items.chunked(cols).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                row.forEach { c -> Box(Modifier.weight(1f)) { cell(c) } }
                repeat(cols - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** The child's own character holds the day's prize; a segment per turn fills under it; and it is the one who cheers. */
@Composable
private fun BuddyHero(left: Int, total: Int, done: Int, lifetime: Int, cheering: Boolean) {
    val lift by animateFloatAsState(if (cheering) 1.12f else 1f, spring(dampingRatio = 0.5f), label = "buddy")
    val ink = Ink.deep
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            CharacterImage(SocialMe.character3DID, Modifier.size(width = 92.dp, height = 112.dp).scale(lift))
            Column(Modifier.padding(bottom = 26.dp).clip(RoundedCornerShape(16.dp)).background(Color.White).padding(horizontal = 14.dp, vertical = 11.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp)) {
                if (cheering) Text(SocialMe.g(tr("כָּל הַכָּבוֹד, אַלּוּף! 🎉"), tr("כָּל הַכָּבוֹד, אַלּוּפָה! 🎉")), color = ink.copy(alpha = 0.8f),
                    fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.sp, maxLines = 1)
                else if (left > 0) Text(tr("עוֹד אֶפְשָׁר לְהַרְוִיחַ הַיּוֹם"), color = ink.copy(alpha = 0.8f),
                    fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.sp, maxLines = 1)
                if (left > 0) Text(tr("🎮 %lld דַּקּוֹת מִשְׂחָק", left), color = ink, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 22.sp, maxLines = 1)
                else Text(SocialMe.g(tr("כָּל הַכָּבוֹד! סִיַּמְתָּ הַכֹּל לְהַיּוֹם"), tr("כָּל הַכָּבוֹד! סִיַּמְתְּ הַכֹּל לְהַיּוֹם")), color = ink,
                    fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
            }
        }
        // One segment per turn.
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            val shown = total.coerceIn(1, 12)
            val filled = if (total <= 12) done else (done * 12f / total).toInt()
            repeat(shown) { i ->
                Box(Modifier.weight(1f).height(11.dp).clip(RoundedCornerShape(5.dp))
                    .background(if (i < filled) GoldBrush else Brush.linearGradient(listOf(Color.White.copy(alpha = 0.25f), Color.White.copy(alpha = 0.25f)))))
            }
        }
        if (lifetime > 0) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("🏆", fontSize = 13.sp)
            Text(SocialMe.g(tr("סַךְ הַכֹּל הִרְוַחְתָּ מֵהַמַּטְלוֹת:"), tr("סַךְ הַכֹּל הִרְוַחַתְּ מֵהַמַּטְלוֹת:")), color = Color.White.copy(alpha = 0.88f),
                fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.5.sp, maxLines = 1)
            Text(tr("🎮 %lld דַּקּוֹת מִשְׂחָק", lifetime), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.5.sp, maxLines = 1)
        }
    }
}

/**
 * One chore, one row: its picture, its name, the prize in gold (or where it
 * stands, once ticked), and ONE big box to tick.
 */
@Composable
private fun ChoreRow(c: Chore, handled: Boolean, isSending: Boolean, celebrating: Boolean, turns: Int, turnsDone: Int, speak: Boolean, onDone: () -> Unit) {
    val approved = c.isDaily && c.approvedToday
    val tint = ChoreArt.tint(c)
    val strong = tint.copy(alpha = if (handled) 0.3f else 0.72f)
    val soft = tint.copy(alpha = if (handled) 0.14f else 0.36f)
    // The strong end sits where the row starts — on the right in Hebrew.
    val colors = if (LocalLayoutDirection.current == LayoutDirection.Rtl) listOf(soft, strong) else listOf(strong, soft)
    val shape = RoundedCornerShape(16.dp)
    val pop by animateFloatAsState(if (celebrating) 1.18f else 1f, spring(dampingRatio = 0.5f), label = "tick")
    Box {
        Row(Modifier.fillMaxWidth().clip(shape).background(Brush.horizontalGradient(colors)).border(1.dp, Color.White.copy(alpha = 0.4f), shape)
            .padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box {
                ChorePicture(c, 92.dp)
                // 🔊 A child who does not read yet hears what the chore is (Sasha, 12.10).
                if (speak) Box(Modifier.align(Alignment.BottomStart).offset(x = (-6).dp, y = 6.dp).clip(CircleShape).background(Ink.deep.copy(alpha = 0.55f))) {
                    PreReaderSpeakButton(c.title, 32.dp)
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                Text(c.title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp, lineHeight = 23.sp,
                    maxLines = 2, overflow = TextOverflow.Ellipsis)
                if (handled) Text(
                    when {
                        isSending -> tr("שׁוֹלְחִים… 📨")
                        approved -> SocialMe.g(tr("כָּל הַכָּבוֹד, אַלּוּף! 🎉"), tr("כָּל הַכָּבוֹד, אַלּוּפָה! 🎉"))
                        else -> tr("מְחַכִּים לְאִשּׁוּר 🕐")
                    }, color = Color.White.copy(alpha = 0.92f), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp, maxLines = 1)
                else Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    // The prize, in gold — the one thing on the row that shines.
                    Text(tr("🎮 %lld דַּקּוֹת מִשְׂחָק", maxOf(c.rewardMinutes, 0)), Modifier.clip(shape).background(GoldBrush).padding(horizontal = 10.dp, vertical = 5.dp),
                        color = Ink.deep, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.5.sp, maxLines = 1)
                    // A dot per turn today, for a chore done more than once a day.
                    if (turns > 1) Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                        repeat(turns) { i -> Box(Modifier.size(9.dp).clip(CircleShape).background(if (i < turnsDone) SocialColor.starGold else Color.White.copy(alpha = 0.4f))) }
                    }
                }
            }
            val ticked = handled && !isSending
            Box(Modifier.size(60.dp).scale(pop).clip(shape)
                .background(if (ticked) GoldBrush else Brush.linearGradient(listOf(Color.White.copy(alpha = 0.18f), Color.White.copy(alpha = 0.18f))))
                .then(if (ticked) Modifier else Modifier.border(3.dp, Color.White, shape))
                .clickable(enabled = !handled, onClickLabel = tr("עָשִׂיתִי! ✅"), onClick = onDone), contentAlignment = Alignment.Center) {
                if (isSending) CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.5.dp)
                else if (handled) Text("✓", color = Ink.deep, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 30.sp)
            }
        }
        // The prize pops out of the row as it goes to the parent.
        AnimatedVisibility(celebrating, Modifier.align(Alignment.TopCenter).offset(y = (-20).dp), enter = scaleIn() + fadeIn(), exit = fadeOut()) {
            Text(tr("🎮 %lld דַּקּוֹת מִשְׂחָק", maxOf(c.rewardMinutes, 0)), Modifier.shadow(6.dp, shape).clip(shape).background(GoldBrush).padding(horizontal = 14.dp, vertical = 7.dp),
                color = Ink.deep, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 15.sp, maxLines = 1)
        }
    }
}

/** Decode a picked photo upright and already small (the compressor then caps it at 900 px). */
private fun decodeProof(ctx: Context, uri: Uri): Bitmap? = runCatching {
    if (Build.VERSION.SDK_INT >= 28) {
        ImageDecoder.decodeBitmap(ImageDecoder.createSource(ctx.contentResolver, uri)) { dec, info, _ ->
            val s = info.size
            val scale = minOf(1f, 1800f / maxOf(s.width, s.height))
            dec.setTargetSize((s.width * scale).toInt().coerceAtLeast(1), (s.height * scale).toInt().coerceAtLeast(1))
            dec.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        }
    } else {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 900) sample *= 2
        ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample }) }
    }
}.getOrNull()
