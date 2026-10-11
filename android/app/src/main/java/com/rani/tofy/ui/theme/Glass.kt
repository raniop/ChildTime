package com.rani.tofy.ui.theme

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.rani.tofy.R

/** The iOS GlassInk palette — text on glass is white. */
object Ink {
    val primary = Color.White
    val secondary = Color.White.copy(alpha = 0.78f)
    val tertiary = Color.White.copy(alpha = 0.58f)
    val good = Color(0xFF8CFFC4)
    val warn = Color(0xFFFFD98A)
    val weak = Color(0xFFFF9AA0)
    val indigo = Color(0xFF4B3FBF)
    val deep = Color(0xFF2A1E5C)
    val gold1 = Color(0xFFFFB547)
    val gold2 = Color(0xFFFFD84A)
    val live = Color(0xFF5CFF9D)
    val sheet = Color(0xFF4A3AB0)
}

/**
 * @param ask the weight the UI asks for; @param draw the weight Rubik actually
 *   renders. The top weights are capped: iOS draws Hebrew in SF Hebrew Rounded,
 *   whose heavy cuts stay airy, while Rubik at 800–900 turns vowelled Hebrew
 *   into a black smear with the niqqud glued to the letters. Capping here fixes
 *   every screen at once instead of editing a hundred call sites.
 */
@OptIn(ExperimentalTextApi::class)
private fun rubik(ask: Int, draw: Int = ask) =
    Font(R.font.rubik, FontWeight(ask), variationSettings = FontVariation.Settings(FontVariation.weight(draw)))

/** Rubik stands in for SF Rounded: round, friendly, full Hebrew + Cyrillic. Arabic falls back to the system face. */
val Rounded = FontFamily(rubik(400), rubik(500), rubik(600), rubik(700), rubik(800, 730), rubik(900, 780))

/** GlassBackdrop.swift: the brand gradient with a pink and a teal orb. */
/**
 * @param maxContentWidth caps the content column on tablets while the gradient
 *   stays full-bleed — a phone layout stretched over 1280dp throws a card's two
 *   ends to opposite edges. Pass `null` for a screen that must fill the glass.
 */
@Composable
fun GlassBackdrop(modifier: Modifier = Modifier, maxContentWidth: Dp? = 900.dp, content: @Composable BoxScope.() -> Unit) {
    // 🎨 The colours are no longer fixed: each child (and the parent) picks a
    // backdrop — see Backdrop.kt. The default is the one described above.
    val look = rememberBackdropLook(BackdropStore.ownerKey)
    Box(modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.TopCenter) {
        BackdropLayer(look)
        if (maxContentWidth == null) content()
        else Box(Modifier.widthIn(max = maxContentWidth).fillMaxSize(),
            contentAlignment = androidx.compose.ui.Alignment.TopCenter, content = content)
    }
}

/** What to draw: a built-in theme, or a photo (under a dark veil, so white text stays readable). */
data class BackdropLook(
    val theme: BackdropTheme,
    val photo: androidx.compose.ui.graphics.ImageBitmap? = null,
    /** The chosen id — a theme's, a picture's ("pic-…"), or one of their photos' ("photo", "photo-2"…). */
    val id: String = theme.id,
)

/**
 * The look for `ownerKey` — "parent", or a child id. A child's choice comes from
 * the child doc (the kid session's, or the parent app's family list), and their
 * photo is fetched here when another device chose a newer one.
 */
@Composable
fun rememberBackdropLook(ownerKey: String): BackdropLook {
    BackdropStore.photoRevision                     // redraw when a photo file changes
    // A screen on its side gets a built-in picture's wide version.
    val wide = androidx.compose.ui.platform.LocalConfiguration.current.let { it.screenWidthDp > it.screenHeightDp }
    if (ownerKey == BackdropStore.PARENT) {
        val id = BackdropStore.parentID
        return if (id != null && BackdropTheme.isPhoto(id)) BackdropLook(BackdropTheme.tofy, BackdropStore.photo(ownerKey, id), id) else builtInLook(id, wide)
    }
    val kidDoc by com.rani.tofy.kid.core.KidSession.childDoc.collectAsState()
    val family by com.rani.tofy.data.FamilyRepository.state.collectAsState()
    val fromKid = kidDoc?.takeIf { (it["id"] as? String) == ownerKey }
    val docID = (fromKid?.get("backdropID") as? String) ?: family.children.firstOrNull { it.id == ownerKey }?.backdropID
    val docStamp = ((fromKid?.get("backdropUpdatedAt") as? Number)?.toDouble())
        ?: family.children.firstOrNull { it.id == ownerKey }?.backdropUpdatedAt ?: 0.0
    val pending = BackdropStore.pendingChildID?.takeIf { it.first == ownerKey }?.second
    androidx.compose.runtime.LaunchedEffect(ownerKey, docID) { BackdropStore.childEchoed(ownerKey, docID) }
    val id = pending ?: docID
    if (id != null && BackdropTheme.isPhoto(id)) {
        androidx.compose.runtime.LaunchedEffect(ownerKey, id, docStamp) { BackdropStore.fetchPhotoIfNeeded(ownerKey, id, docStamp) }
        return BackdropLook(BackdropTheme.tofy, BackdropStore.photo(ownerKey, id), id)
    }
    return builtInLook(id, wide)
}

/** A built-in backdrop by its id: a picture (drawn like a photo), or a colour theme. */
private fun builtInLook(id: String?, wide: Boolean): BackdropLook {
    val found = BackdropPicture.find(id)
    val picture = found?.let { BackdropStore.picture(it, wide) }
    return if (found != null && picture != null) BackdropLook(BackdropTheme.tofy, picture, found.id) else BackdropLook(BackdropTheme.find(id))
}

/** One backdrop, drawn to fill: the gradient and its two blurred orbs (`scale` shrinks them for a preview), or the photo. */
@Composable
fun BackdropLayer(look: BackdropLook, modifier: Modifier = Modifier, scale: Float = 1f, veil: Float = 0.30f) {
    val photo = look.photo
    if (photo != null) {
        androidx.compose.foundation.Image(photo, null, modifier.fillMaxSize(), contentScale = androidx.compose.ui.layout.ContentScale.Crop)
        Box(modifier.fillMaxSize().background(Color.Black.copy(alpha = veil)))
        return
    }
    val theme = look.theme
    Canvas(modifier.fillMaxSize()) {
        drawRect(Brush.linearGradient(theme.gradient,
            start = Offset(size.width * 0.62f, 0f), end = Offset(size.width * 0.38f, size.height)))
    }
    Canvas(modifier.fillMaxSize().blur((44 * scale).dp)) {
        drawCircle(Color(theme.orbTop).copy(alpha = theme.orbOpacity), radius = (140 * scale).dp.toPx(), center = Offset((40 * scale).dp.toPx(), (250 * scale).dp.toPx()))
        drawCircle(Color(theme.orbBottom).copy(alpha = theme.orbOpacity), radius = (160 * scale).dp.toPx(), center = Offset(size.width - (30 * scale).dp.toPx(), size.height - (200 * scale).dp.toPx()))
    }
}

/**
 * GlassPane.swift: white at `strength` + a top highlight + a light edge.
 * No elevation shadow by default — on a translucent pane Android draws the
 * shadow THROUGH the glass as a grey inner slab.
 */
fun Modifier.glassPane(radius: Dp = 16.dp, strength: Float = 0.14f, shadow: Boolean = false): Modifier {
    val shape = RoundedCornerShape(radius)
    return this
        .then(if (shadow) Modifier.shadow(14.dp, shape, ambientColor = Color.Black.copy(alpha = 0.28f), spotColor = Color.Black.copy(alpha = 0.28f)) else Modifier)
        .clip(shape)
        .background(Color.White.copy(alpha = strength))
        .background(Brush.verticalGradient(0f to Color.White.copy(alpha = 0.28f), 0.12f to Color.Transparent))
        .border(1.dp, Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.5f), Color.White.copy(alpha = 0.22f))), shape)
}

fun Modifier.glassInset(radius: Dp = 16.dp) = glassPane(radius, 0.09f, shadow = false)

val GoldBrush = Brush.horizontalGradient(listOf(Ink.gold1, Ink.gold2))
