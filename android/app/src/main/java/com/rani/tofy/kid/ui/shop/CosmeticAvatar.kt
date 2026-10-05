package com.rani.tofy.kid.ui.shop

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.rani.tofy.kid.ui.CharacterImage
import com.rani.tofy.kid.ui.play.KidColor

/**
 * ProfileAvatarView — the character portrait in a gold ring, with the child's
 * equipped cosmetics layered on it (hat on the crown, glasses on the eyes…).
 * [headItemsOnly] keeps small avatars clean (hat / glasses / accessory only).
 * Note: iOS currently draws the bare portrait — this is the layering it keeps
 * ready (cosmeticLayer); the only live cosmetic source today is the wheel's crown.
 */
@Composable
fun CosmeticAvatar(characterID: String?, childID: String?, size: Dp, modifier: Modifier = Modifier, headItemsOnly: Boolean = false) {
    val ctx = LocalContext.current
    CosmeticStore.init(ctx)
    val equipped by CosmeticStore.equipped.collectAsState()
    val items = (childID?.let { cid -> (equipped[cid] ?: emptyMap()).values.mapNotNull { CosmeticCatalog.item(it) } } ?: emptyList())
        .filter { !headItemsOnly || it.category in setOf(CosmeticCategory.HAT, CosmeticCategory.GLASSES, CosmeticCategory.ACCESSORY) }
        .sortedBy { it.category.zIndex }   // back-to-front: glasses over the face, hat on top
    val density = LocalDensity.current
    // Geometry, not text: the anchor offsets are physical (x>0 = right).
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Box(modifier.size(size), contentAlignment = Alignment.Center) {
            CharacterImage(
                characterID, Modifier.size(size).clip(CircleShape)
                    .border(3.dp, Brush.linearGradient(listOf(KidColor.starGold, KidColor.companionGlow)), CircleShape)
                    .background(Color.White.copy(alpha = 0.18f), CircleShape),
                contentScale = ContentScale.Crop,
            )
            items.forEach { item ->
                val (x, y, scale) = item.category.anchor
                Text(
                    item.emoji, Modifier.offset(size * x, size * y),
                    fontSize = with(density) { (size * scale).toSp() } * 0.85f,
                )
            }
        }
    }
}
