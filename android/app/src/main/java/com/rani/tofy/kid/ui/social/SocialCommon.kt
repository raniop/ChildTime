package com.rani.tofy.kid.ui.social

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.zxing.BarcodeFormat
import com.journeyapps.barcodescanner.BarcodeCallback
import com.journeyapps.barcodescanner.DecoratedBarcodeView
import com.journeyapps.barcodescanner.DefaultDecoderFactory
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.CharacterImage
import com.rani.tofy.kid.ui.KidBody
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded

/** AppColor tokens the social screens use (Theme.swift). */
internal object SocialColor {
    val starGold = Color(0xFFFFD23F)
    val successMint = Color(0xFF06D6A0)
    val almostWarm = Color(0xFFFF9F1C)
    val gemPurple = Color(0xFF9B5DE5)
    val diamondBlue = Color(0xFF4CC9F0)
    val indigo = Color(0xFF4B3FBF)
    /** AppGradient.purpleDream / .gold */
    val purpleDream = Brush.linearGradient(listOf(Color(0xFF9B5DE5), Color(0xFF7C4DFF)))
    val gold = Brush.linearGradient(listOf(Color(0xFFFFD23F), Color(0xFFFFB84D)))
}

/** A round 2D character portrait (CharacterView portrait). */
@Composable
internal fun Portrait(characterID: String?, size: Dp, glow: Boolean = false) {
    Box(
        Modifier.size(size).then(if (glow) Modifier.border(3.dp, SocialColor.starGold.copy(alpha = 0.85f), CircleShape) else Modifier)
            .clip(CircleShape).background(Color.White.copy(alpha = 0.16f)),
        contentAlignment = Alignment.Center,
    ) { CharacterImage(characterID ?: "fox", Modifier.size(size)) }
}

/** The ⭐ count capsule on board rows. */
@Composable
internal fun StarsPill(n: Int) {
    Row(
        Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(50)).padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Text("⭐", fontSize = 13.sp)
        Text("$n", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
    }
}

/** The header circle buttons (✕, inbox, add) with an optional count badge. */
@Composable
internal fun HeaderCircle(emoji: String, badge: Int = 0, onClick: () -> Unit) {
    Box {
        Box(
            Modifier.size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f))
                .border(1.dp, Color.White.copy(alpha = 0.32f), CircleShape).clickable(onClick = onClick),
            contentAlignment = Alignment.Center,
        ) { Text(emoji, fontSize = 17.sp, color = Color.White) }
        if (badge > 0) Box(
            Modifier.align(Alignment.TopEnd).padding(start = 0.dp).size(18.dp).clip(CircleShape)
                .background(SocialColor.almostWarm).border(1.5.dp, Color.White, CircleShape),
            contentAlignment = Alignment.Center,
        ) { Text("$badge", color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Black) }
    }
}

/** A white capsule CTA with indigo ink (iOS `.background(Capsule().fill(.white.opacity(0.92)))`). */
@Composable
internal fun WhiteCapsule(text: String, modifier: Modifier = Modifier, size: Int = 17, enabled: Boolean = true, onClick: () -> Unit) {
    Box(
        modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = if (enabled) 0.92f else 0.5f))
            .clickable(enabled = enabled, onClick = onClick).padding(horizontal = 22.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) { Text(text, color = SocialColor.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = size.sp, maxLines = 2) }
}

/** A gradient capsule CTA (AppGradient.gold / .purpleDream). */
@Composable
internal fun BrushCapsule(text: String, brush: Brush, modifier: Modifier = Modifier, size: Int = 17, enabled: Boolean = true, busy: Boolean = false, onClick: () -> Unit) {
    Box(
        modifier.clip(RoundedCornerShape(50)).background(brush).then(if (enabled) Modifier else Modifier.background(Color.Black.copy(alpha = 0.3f)))
            .clickable(enabled = enabled && !busy, onClick = onClick).padding(horizontal = 20.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (busy) androidx.compose.material3.CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.5.dp)
        else Text(text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = size.sp, maxLines = 2)
    }
}

/** 🎉 "you're friends now" — the dimmed celebration with the friend's character. */
@Composable
internal fun FriendCelebration(card: FriendCard?) {
    AnimatedVisibility(card != null, enter = fadeIn() + scaleIn(initialScale = 0.6f), exit = fadeOut()) {
        Box(
            Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.6f))
                .clickable(remember { MutableInteractionSource() }, null) {},
            contentAlignment = Alignment.Center,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("🎉", fontSize = 56.sp)
                CharacterImage(card?.character3DID ?: "fox", Modifier.size(130.dp))
                Text(card?.displayName ?: "", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 24.sp)
                Text(tr("אַתֶּם חֲבֵרִים עַכְשָׁיו! 🤝"), color = SocialColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
            }
        }
    }
}

/**
 * QRScannerView — the ZXing embedded scanner, on-device only (no ML Kit: the
 * Kids no-analytics promise). Asks for the camera the first time.
 */
@Composable
internal fun FriendQrScanner(title: String, onScanned: (String) -> Unit, onCancel: () -> Unit) {
    val ctx = LocalContext.current
    var granted by remember { mutableStateOf(ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    var denied by remember { mutableStateOf(false) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> granted = ok; denied = !ok }
    LaunchedEffect(Unit) { if (!granted) ask.launch(Manifest.permission.CAMERA) }
    BackHandler(onBack = onCancel)

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        if (granted) {
            val owner = LocalLifecycleOwner.current
            var delivered by remember { mutableStateOf(false) }
            val view = remember {
                DecoratedBarcodeView(ctx).apply {
                    barcodeView.decoderFactory = DefaultDecoderFactory(listOf(BarcodeFormat.QR_CODE))
                    setStatusText("")
                    decodeContinuous(BarcodeCallback { r ->
                        val t = r?.text ?: return@BarcodeCallback
                        if (!delivered) { delivered = true; pause(); onScanned(t) }
                    })
                }
            }
            DisposableEffect(owner) {
                val obs = LifecycleEventObserver { _, e ->
                    if (e == Lifecycle.Event.ON_RESUME) view.resume() else if (e == Lifecycle.Event.ON_PAUSE) view.pause()
                }
                owner.lifecycle.addObserver(obs)
                if (owner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) view.resume()
                onDispose { owner.lifecycle.removeObserver(obs); view.pause() }
            }
            AndroidView({ view }, Modifier.fillMaxSize())
        } else if (denied) {
            Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically)) {
                Text("📷", fontSize = 48.sp)
                KidBody(tr("כְּדֵי לִסְרֹק צָרִיךְ לְאַשֵּׁר לְטוֹפִי גִּישָׁה לַמַּצְלֵמָה — אוֹ מַקְלִידִים אֶת הַקּוֹד"), 16f)
            }
        }
        Row(
            Modifier.fillMaxWidth().systemBarsPadding().background(Color.Black.copy(alpha = 0.5f)).padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(title, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 17.sp)
            Text(tr("בִּטּוּל"), Modifier.clip(RoundedCornerShape(50)).border(1.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(50))
                .clickable(onClick = onCancel).padding(horizontal = 14.dp, vertical = 6.dp),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 15.sp)
        }
    }
}
