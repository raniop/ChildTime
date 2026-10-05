package com.rani.tofy.ui.common

import android.annotation.SuppressLint
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.rani.tofy.R
import com.rani.tofy.data.Child

/** ProfileAvatarView: the child's chosen character, round, with the gold ring. */
@SuppressLint("DiscouragedApi")
@Composable
fun ChildAvatar(child: Child, size: Dp = 56.dp) {
    val ctx = LocalContext.current
    val id = child.character3DID ?: "fox"
    val res = ctx.resources.getIdentifier("char_$id", "drawable", ctx.packageName).takeIf { it != 0 } ?: R.drawable.char_fox
    Image(
        painterResource(res), child.name,
        Modifier.size(size).clip(CircleShape).background(Color.White.copy(alpha = 0.2f))
            .border(3.dp, Brush.linearGradient(listOf(Color(0xFFFFC93C), Color(0xFFFFE08A))), CircleShape),
        contentScale = ContentScale.Crop,
    )
}
