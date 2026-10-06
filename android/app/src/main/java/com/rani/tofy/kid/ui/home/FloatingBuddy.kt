package com.rani.tofy.kid.ui.home

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.kid.ui.CharacterImage
import kotlinx.coroutines.delay
import kotlin.random.Random

/**
 * FloatingCompanion.swift on the kid home: the child's own character wanders
 * the free band between the header and the minutes panel (by design — it may
 * pass over cards), bobbing as it goes. Tap → the shop (iOS onTap). When the
 * daily chest is ready a 🎁 rides on its head; tapping the gift opens the chest.
 */
@Composable
internal fun FloatingBuddy(
    characterID: String?,
    showGift: Boolean,
    topInset: Dp,
    bottomInset: Dp,
    size: Dp,
    onTap: () -> Unit,
    onGift: () -> Unit,
    modifier: Modifier = Modifier,
) {
    BoxWithConstraints(modifier.fillMaxSize()) {
        val w = size
        val h = size * 1.3f
        val gift = 34.dp
        val side = 16.dp
        val minX = side
        val maxX = (maxWidth - w - side).coerceAtLeast(minX)
        val minY = topInset
        val maxY = (maxHeight - bottomInset - h).coerceAtLeast(minY)
        // Starts low at the end edge (iOS defaultPosition), then roams.
        var tx by remember { mutableStateOf(maxX) }
        var ty by remember { mutableStateOf(maxY) }
        LaunchedEffect(minX, maxX, minY, maxY) {
            tx = tx.coerceIn(minX, maxX); ty = ty.coerceIn(minY, maxY)
            while (true) {
                delay(Random.nextLong(4500, 7500))
                tx = minX + (maxX - minX) * Random.nextFloat()
                ty = minY + (maxY - minY) * Random.nextFloat()
            }
        }
        val x by animateDpAsState(tx, tween(4000, easing = FastOutSlowInEasing), label = "buddyX")
        val y by animateDpAsState(ty, tween(4000, easing = FastOutSlowInEasing), label = "buddyY")
        val bob by rememberInfiniteTransition(label = "bob")
            .animateFloat(-4f, 4f, infiniteRepeatable(tween(1400, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "bob")

        Box(Modifier.offset(x, y - gift)) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.size(w, gift), contentAlignment = Alignment.Center) {
                    androidx.compose.animation.AnimatedVisibility(showGift, enter = scaleIn() + fadeIn(), exit = scaleOut() + fadeOut()) {
                        Text("🎁", fontSize = 26.sp, modifier = Modifier
                            .graphicsLayer { translationY = bob * 1.5f * density }
                            .clickable(remember { MutableInteractionSource() }, null, onClick = onGift))
                    }
                }
                CharacterImage(characterID ?: "fox", Modifier.size(w, h)
                    .graphicsLayer { translationY = bob * density }
                    .clickable(remember { MutableInteractionSource() }, null, onClick = onTap))
            }
        }
    }
}
