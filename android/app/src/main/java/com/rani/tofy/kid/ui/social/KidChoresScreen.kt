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
import com.rani.tofy.data.Chore
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
 * ChoresKidView: the parent defined the chores; the kid does one and taps
 * "עשיתי!" (optionally with a 📸 proof photo). The reward is always 🎮 play
 * minutes, landing only after a parent approves. No failure language anywhere:
 * a returned chore is simply available again, a send that didn't reach the
 * parent is a gentle "let's try again".
 */
@Composable
internal fun KidChoresContent(onClose: () -> Unit) {
    val store = KidChoresStore
    val ctx = LocalContext.current
    val haptics = KidHaptics(LocalView.current)
    val scope = rememberCoroutineScope()
    val childID = SocialMe.id
    // 👦👧 Gendered accent for the approved "champion" card (Rani).
    val accent = when (SocialMe.child?.gender) { "girl" -> Color(0xFFFF5FA2); "boy" -> Color(0xFF3A86FF); else -> Color(0xFF06D6A0) }

    var pending by remember { mutableStateOf<Chore?>(null) }       // reward picked → photo offer
    var sending by remember { mutableStateOf(setOf<String>()) }
    var justSent by remember { mutableStateOf(setOf<String>()) }
    var retryChore by remember { mutableStateOf<String?>(null) }

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
                }
                else -> { retryChore = chore.id; haptics.light() }
            }
        }
    }
    fun finish(photo: ByteArray?) { val c = pending ?: return; pending = null; send(c, photo) }

    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bmp ->
        if (bmp == null) { pending = null; return@rememberLauncherForActivityResult }
        scope.launch { finish(withContext(Dispatchers.Default) { KidChoresStore.compressProof(bmp) }) }
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (ok) camera.launch(null) else pending = null
    }
    val library = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) { pending = null; return@rememberLauncherForActivityResult }
        scope.launch { finish(withContext(Dispatchers.IO) { decodeProof(ctx, uri)?.let { KidChoresStore.compressProof(it) } }) }
    }
    val hasCamera = remember { ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY) }

    val mine = childID?.let { store.choresFor(it) } ?: emptyList()
    fun handled(c: Chore) = c.id in sending || c.id in justSent || c.isPendingApproval || (c.isDaily && c.approvedToday)
    val todo = mine.filter { !handled(it) }
    val done = mine.filter { handled(it) }

    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 12.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f)).border(1.dp, Color.White.copy(alpha = 0.32f), CircleShape)
                    .clickable { haptics.light(); onClose() }, contentAlignment = Alignment.Center) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, tr("חזרה"), tint = Color.White, modifier = Modifier.size(20.dp))
                }
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(tr("מַטְלוֹת הַבַּיִת 🧹"), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 24.sp)
                    Text(tr("עוֹזְרִים בַּבַּיִת — וּבוֹחֲרִים פְּרָס!"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp)
                }
                Spacer(Modifier.size(40.dp))
            }
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val cols = if (maxWidth >= 600.dp) 3 else 2
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Column(Modifier.widthIn(max = if (cols == 3) 860.dp else 560.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        // 🏆 Lifetime earnings — "how much have I made, ever".
                        val minutes = childID?.let { store.totals(it).minutes } ?: 0
                        if (minutes > 0) Row(Modifier.fillMaxWidth().glassPane(22.dp).background(SocialColor.starGold.copy(alpha = 0.14f)).padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text("🏆", fontSize = 30.sp)
                            Column(Modifier.weight(1f)) {
                                Text(SocialMe.g(tr("סַךְ הַכֹּל הִרְוַחְתָּ מֵהַמַּטְלוֹת:"), tr("סַךְ הַכֹּל הִרְוַחַתְּ מֵהַמַּטְלוֹת:")), color = Color.White.copy(alpha = 0.85f),
                                    fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                                Text(tr("🎮 %lld דַּקּוֹת מִשְׂחָק", minutes), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                            }
                        }
                        when {
                            mine.isEmpty() -> Column(Modifier.fillMaxWidth().padding(top = 60.dp), horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                Text("🧹", fontSize = 56.sp)
                                Text(tr("עוֹד אֵין מַטְלוֹת"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
                                Text(tr("בַּקְּשׁוּ מֵאַבָּא אוֹ אִמָּא לְהוֹסִיף מַטְלוֹת —\nוְתוּכְלוּ לְהַרְוִיחַ דַּקּוֹת מִשְׂחָק אוֹ כֶּסֶף! 💪"), color = Color.White.copy(alpha = 0.9f),
                                    fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, textAlign = TextAlign.Center)
                            }
                            else -> {
                                if (todo.isNotEmpty()) Grid(todo, cols) { c -> ActiveCard(c) { haptics.success(); pending = c } }
                                else Column(Modifier.fillMaxWidth().glassPane(22.dp).background(Color(0xFF8CFFC4).copy(alpha = 0.14f)).padding(16.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text("🎉", fontSize = 46.sp)
                                    Text(SocialMe.g(tr("כָּל הַכָּבוֹד! סִיַּמְתָּ הַכֹּל לְהַיּוֹם"), tr("כָּל הַכָּבוֹד! סִיַּמְתְּ הַכֹּל לְהַיּוֹם")),
                                        color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, textAlign = TextAlign.Center)
                                }
                                if (done.isNotEmpty()) {
                                    Text(tr("בּוֹצְעוּ הַיּוֹם 🎉"), Modifier.fillMaxWidth().padding(top = 8.dp), color = Color.White.copy(alpha = 0.9f),
                                        fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, textAlign = TextAlign.Center)
                                    Grid(done, cols) { c -> DoneCard(c, c.id in sending, accent) }
                                }
                            }
                        }
                    }
                }
            }
        }

        // 📸 Optional proof photo — a picture beats a debate about whether the room is tidy (Rani).
        if (pending != null) KidBottomCard(onDismiss = { pending = null }) {
            Text(tr("רוֹצִים לְצָרֵף תְּמוּנָה שֶׁל מַה שֶּׁעֲשִׂיתֶם? 📸"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
                fontSize = 17.sp, textAlign = TextAlign.Center)
            if (hasCamera) WhiteCapsule(tr("📸 לְצַלֵּם עַכְשָׁו"), Modifier.fillMaxWidth()) {
                if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) camera.launch(null)
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

/** A chore the kid can DO now: emoji, name, ONE reward line, the same-day counter, "עשיתי!". */
@Composable
private fun ActiveCard(c: Chore, onDone: () -> Unit) {
    Column(Modifier.fillMaxWidth().glassPane(22.dp).background(Color(0xFF48BFE3).copy(alpha = 0.12f)).padding(10.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(c.emoji, fontSize = 38.sp)
        Box(Modifier.heightIn(min = 38.dp), contentAlignment = Alignment.Center) {
            Text(c.title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, textAlign = TextAlign.Center, maxLines = 2, lineHeight = 19.sp)
        }
        Text(tr("🎮 %lld דַּקּוֹת מִשְׂחָק", maxOf(c.rewardMinutes, 0)), Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(50)).padding(horizontal = 9.dp, vertical = 4.dp),
            color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 12.sp, maxLines = 1)
        // Reserved even when absent so every card in a row keeps the same height.
        Text(if (c.timesPerDay > 1) tr("הַיּוֹם: %lld/%lld ✔️", c.doneToday, c.timesPerDay) else " ", Modifier.height(15.dp),
            color = Color.White.copy(alpha = 0.8f), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 10.5.sp, maxLines = 1)
        Text(tr("עָשִׂיתִי! ✅"), Modifier.fillMaxWidth().clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.92f)).clickable(onClick = onDone)
            .padding(vertical = 10.dp), color = SocialColor.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp,
            textAlign = TextAlign.Center, maxLines = 1)
    }
}

/** "בוצעו היום": approved → the gendered 👑 champion card; in flight → a plain status. */
@Composable
private fun DoneCard(c: Chore, isSending: Boolean, accent: Color) {
    val approved = c.isDaily && c.approvedToday
    val waiting = !approved && !isSending
    Column(Modifier.fillMaxWidth().glassPane(18.dp, if (approved) 0.14f else 0.09f).then(if (approved) Modifier.background(accent.copy(alpha = 0.35f)) else Modifier).padding(10.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(if (approved) "👑" else c.emoji, fontSize = 30.sp)
        Text(c.title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp, textAlign = TextAlign.Center, maxLines = 1)
        when {
            isSending -> StatusCapsule(tr("שׁוֹלְחִים… 📨"), Color.White.copy(alpha = 0.18f))
            waiting -> StatusCapsule(tr("מְחַכִּים לְאִשּׁוּר 🕐"), Color(0xFFFFD98A).copy(alpha = 0.35f))
            else -> Text(SocialMe.g(tr("כָּל הַכָּבוֹד, אַלּוּף! 🎉"), tr("כָּל הַכָּבוֹד, אַלּוּפָה! 🎉")), color = Color.White, fontFamily = Rounded,
                fontWeight = FontWeight.ExtraBold, fontSize = 11.5.sp, maxLines = 1)
        }
    }
}

@Composable
private fun StatusCapsule(text: String, bg: Color) {
    Text(text, Modifier.fillMaxWidth().clip(RoundedCornerShape(50)).background(bg).padding(vertical = 10.dp), color = Color.White,
        fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp, textAlign = TextAlign.Center, maxLines = 1)
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
