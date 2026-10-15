package com.rani.tofy.kid.ui.play

import android.provider.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.kid.content.TakeAwayScene
import com.rani.tofy.kid.ui.games.Ltr
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 👶➖ TakeAwayPicture.swift — a גן take-away the child can SEE (Sasha,
 * 2026-10-15): all the items appear in a row, then the ones taken lift up,
 * shrink and stay behind as faded ghosts — so "how many are left?" is the
 * bright ones. A tap plays it again. Left to right, like every number line
 * (Rani, 2026-10-15).
 */
@Composable
fun TakeAwayPicture(scene: TakeAwayScene, fontSize: Float = 34f, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    val reduceMotion = remember {
        runCatching { Settings.Global.getFloat(ctx.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f }.getOrDefault(false)
    }
    // One 0→1 per item: 0 = in the row, 1 = lifted away as a ghost.
    val lifts = remember(scene) { List(scene.total) { Animatable(0f) } }
    // Bumped by a tap: the scene plays again.
    var replay by remember(scene) { mutableIntStateOf(0) }
    val first = scene.total - scene.take
    LaunchedEffect(scene, replay) {
        lifts.forEach { it.snapTo(0f) }
        delay(if (replay > 0) 600L else if (reduceMotion) 200L else 900L)
        for (i in first until scene.total) {
            // response 0.55 / damping 0.62, staggered 0.12s — iOS's spring.
            launch {
                delay(((i - first) * 120).toLong())
                lifts[i].animateTo(1f, spring(dampingRatio = 0.62f, stiffness = 130f))
            }
        }
    }
    BoxWithConstraints(
        modifier.fillMaxWidth()
            .clickable(remember { MutableInteractionSource() }, null) { replay++ }
            .clearAndSetSemantics { contentDescription = "${scene.total} ➖ ${scene.take}" },
        contentAlignment = Alignment.Center,
    ) {
        // Seven apples must fit a phone's card on one line.
        val size = minOf(fontSize, maxWidth.value / (scene.total * 1.32f))
        Ltr {
            Row(
                Modifier.padding(top = (size * 0.55f).dp),   // room for the lifted ghosts
                horizontalArrangement = Arrangement.spacedBy((size * 0.12f).dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                for (i in 0 until scene.total) {
                    val t = lifts[i].value
                    Text(scene.emoji, fontSize = size.sp, modifier = Modifier.graphicsLayer {
                        val s = 1f - 0.28f * t
                        scaleX = s; scaleY = s
                        alpha = 1f - 0.7f * t.coerceIn(0f, 1f)
                        translationY = -(size * 0.55f * t).dp.toPx()
                        rotationZ = (if (i % 2 == 0) -14f else 12f) * t
                    })
                }
            }
        }
    }
}
