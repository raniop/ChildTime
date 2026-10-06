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
    Box(modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.TopCenter) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(Brush.linearGradient(
                listOf(Color(0xFF7A5CFF), Color(0xFF5E60CE), Color(0xFF3E8BF0)),
                start = Offset(size.width * 0.62f, 0f), end = Offset(size.width * 0.38f, size.height)))
        }
        Canvas(Modifier.fillMaxSize().blur(44.dp)) {
            drawCircle(Color(0xFFFF7BD3).copy(alpha = 0.8f), radius = 140.dp.toPx(), center = Offset(40.dp.toPx(), 250.dp.toPx()))
            drawCircle(Color(0xFF37E2D5).copy(alpha = 0.8f), radius = 160.dp.toPx(), center = Offset(size.width - 30.dp.toPx(), size.height - 200.dp.toPx()))
        }
        if (maxContentWidth == null) content()
        else Box(Modifier.widthIn(max = maxContentWidth).fillMaxSize(),
            contentAlignment = androidx.compose.ui.Alignment.TopCenter, content = content)
    }
}

/**
 * GlassPane.swift: white at `strength` + a top highlight + a light edge.
 * No elevation shadow by default — on a translucent pane Android draws the
 * shadow THROUGH the glass as a grey inner slab.
 */
fun Modifier.glassPane(radius: Dp = 22.dp, strength: Float = 0.14f, shadow: Boolean = false): Modifier {
    val shape = RoundedCornerShape(radius)
    return this
        .then(if (shadow) Modifier.shadow(14.dp, shape, ambientColor = Color.Black.copy(alpha = 0.28f), spotColor = Color.Black.copy(alpha = 0.28f)) else Modifier)
        .clip(shape)
        .background(Color.White.copy(alpha = strength))
        .background(Brush.verticalGradient(0f to Color.White.copy(alpha = 0.28f), 0.12f to Color.Transparent))
        .border(1.dp, Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.5f), Color.White.copy(alpha = 0.22f))), shape)
}

fun Modifier.glassInset(radius: Dp = 12.dp) = glassPane(radius, 0.09f, shadow = false)

val GoldBrush = Brush.horizontalGradient(listOf(Ink.gold1, Ink.gold2))
