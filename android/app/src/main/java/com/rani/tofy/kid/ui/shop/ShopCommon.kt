package com.rani.tofy.kid.ui.shop

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.CompositionLocalProvider
import com.google.firebase.firestore.FirebaseFirestore
import com.rani.tofy.data.Child
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.Household
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.ui.CloseCircle
import com.rani.tofy.kid.ui.play.characterRes
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane

/** The bound child (children/{id}), live from KidSession — with the parent repo as a fallback. */
@Composable
internal fun rememberBoundChild(): Child? {
    val doc by KidSession.childDoc.collectAsState()
    val family by FamilyRepository.state.collectAsState()
    val cid = KidSession.boundChildID ?: return null
    return doc?.let { Child.from(cid, it) } ?: family.children.firstOrNull { it.id == cid }
}

/** households/{hid}.parentPinHash for the gate — the parent repo's copy in Kid Mode, else a listener of our own. */
@Composable
internal fun rememberParentPin(hid: String?): Pair<String?, Boolean> {
    val family by FamilyRepository.state.collectAsState()
    val fromFamily = family.household?.takeIf { it.id == hid }
    var own by remember(hid) { mutableStateOf<Household?>(null) }
    var loaded by remember(hid) { mutableStateOf(false) }
    DisposableEffect(hid, fromFamily != null) {
        if (hid == null || fromFamily != null) return@DisposableEffect onDispose {}
        val reg = FirebaseFirestore.getInstance().collection("households").document(hid).addSnapshotListener { s, err ->
            if (err != null) { loaded = true; return@addSnapshotListener }
            s?.data?.let { own = Household.from(hid, it) }
            if (s != null && !s.metadata.isFromCache) loaded = true
        }
        onDispose { reg.remove() }
    }
    val hh = fromFamily ?: own
    return hh?.parentPinHash to (hh != null || loaded || hid == null)
}

/** A character PNG; a locked one is shown faded and desaturated (CharacterCollectionView). */
@Composable
internal fun ShopCharImage(id: String, modifier: Modifier = Modifier, owned: Boolean = true) {
    val filter = remember(owned) { if (owned) null else ColorFilter.colorMatrix(ColorMatrix().apply { setToSaturation(0.65f) }) }
    Image(painterResource(characterRes(id)), null, modifier.graphicsLayer { alpha = if (owned) 1f else 0.6f }, colorFilter = filter)
}

/** CharacterView(animated:) — a gentle idle bob. */
@Composable
internal fun BobbingCharacter(id: String, modifier: Modifier = Modifier) {
    val t = rememberInfiniteTransition(label = "bob")
    val y by t.animateFloat(0f, -8f, infiniteRepeatable(tween(1300), RepeatMode.Reverse), label = "y")
    ShopCharImage(id, modifier.graphicsLayer { translationY = y * density })
}

/** The tappable 💎 balance (ShopView top bar) — opens the parent-gated diamond shop. */
@Composable
internal fun DiamondPill(diamonds: Int, onClick: () -> Unit) {
    Row(
        Modifier.clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, Color.White.copy(alpha = 0.30f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("💎", fontSize = 16.sp)
                Text(currencyShort(diamonds), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, maxLines = 1)
                Text("⊕", color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

/** Title centred, ✕ at the start, an optional trailing item at the end. */
@Composable
internal fun ShopTopBar(title: String, onClose: () -> Unit, trailing: @Composable () -> Unit = {}) {
    Box(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
        Text(
            title, Modifier.align(Alignment.Center).padding(horizontal = 96.dp), color = Ink.primary, fontFamily = Rounded,
            fontWeight = FontWeight.Black, fontSize = 22.sp, maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
        )
        Box(Modifier.align(Alignment.CenterStart)) { CloseCircle(onClose) }
        Box(Modifier.align(Alignment.CenterEnd)) { trailing() }
    }
}

/** Int.currencyShort — 999 → "999", 1500 → "1.5K", 2M → "2M". */
internal fun currencyShort(v: Int): String {
    val a = kotlin.math.abs(v.toDouble())
    val sign = if (v < 0) "-" else ""
    if (a < 1_000) return v.toString()
    fun fmt(x: Double, suf: String): String {
        if (x < 10) { val t = kotlin.math.floor(x * 10) / 10; val s = "%.1f".format(java.util.Locale.US, t); return sign + s.removeSuffix(".0") + suf }
        return sign + x.toInt() + suf
    }
    return if (a < 1_000_000) fmt(a / 1_000.0, "K") else fmt(a / 1_000_000.0, "M")
}

/** A glass pane with a colour glowing through it (`.glassPane(tint:)`). */
internal fun Modifier.tintedPane(tint: Color, radius: androidx.compose.ui.unit.Dp = 22.dp): Modifier {
    val shape = RoundedCornerShape(radius)
    return this.clip(shape).background(tint.copy(alpha = 0.24f)).glassPane(radius, 0.12f)
}
