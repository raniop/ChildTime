package com.rani.tofy.ui.chores

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.data.Chore

/**
 * 🎨 ChoreArt.swift — the picture of a chore (Rani, 2026-10-13: the chores
 * screens in pictures, not emoji). 49 drawings (`R.drawable.chore_<key>`): the
 * built-in chores have theirs, and a parent who writes a chore picks one from
 * the picture chooser — or any emoji at all, which then shows as itself.
 *
 * A chore keeps only an emoji (the same field as ever — nothing new to sync);
 * the drawing is found from it. Keep this list in step with iOS.
 */
object ChoreArt {
    /** Every drawing, in the order the parent's chooser shows them, with the emoji that stands for it. */
    val library: List<Pair<String, String>> = listOf(
        // around the room
        "bed" to "🛏️", "sweep" to "🧹", "toys" to "🧸", "desk" to "📚", "clothes" to "👕", "laundry" to "🧺",
        "socks" to "🧦", "shoes" to "👟", "coat" to "🧥", "closet" to "🗄️", "lights" to "💡",
        // kitchen and table
        "plate" to "🍽️", "table" to "🍴", "dishes" to "🧽", "cooking" to "🍳", "groceries" to "🛒",
        "lunchbox" to "🥪", "trash" to "🗑️", "recycle" to "♻️",
        // around the house
        "mop" to "🪣", "window" to "🪟", "plants" to "🪴", "garden" to "🍂", "carwash" to "🚗", "mail" to "📬",
        // pets
        "pet" to "🐕", "walkdog" to "🦮", "cat" to "🐈", "fish" to "🐠",
        // me, every day
        "wakeup" to "⏰", "dress" to "👚", "teeth" to "🦷", "hands" to "🧼", "shower" to "🚿", "bath" to "🛁",
        "breakfast" to "🥣", "veggies" to "🥦", "water" to "🥛", "bedtime" to "🌙",
        // school and me
        "bag" to "🎒", "homework" to "✏️", "reading" to "📖", "music" to "🎹", "screens" to "📵",
        // with others, and moving
        "sibling" to "🎲", "baby" to "🍼", "kindness" to "❤️", "ball" to "⚽", "bike" to "🚲",
    )

    /** The same emoji with or without its "emoji style" mark. */
    private fun plain(emoji: String) = emoji.replace("️", "")
    private val byEmoji: Map<String, String> =
        mapOf("👔" to "dress", "📝" to "homework") + library.associate { plain(it.second) to it.first }
    /** Built-in chores whose key is not the name of their drawing. */
    private val presetDrawing = mapOf("outfit" to "dress", "leaves" to "garden")

    /** The drawing that stands for this emoji, if there is one. */
    fun keyFor(emoji: String): String? = byEmoji[plain(emoji)]

    /** The drawing of this chore: a built-in one by its key (`preset-bed_<child>`), else by its emoji. */
    fun keyFor(chore: Chore): String? {
        if (chore.isPreset) {
            val name = chore.id.substringBefore('_').removePrefix("preset-")
            (presetDrawing[name] ?: name).takeIf { n -> library.any { it.first == n } }?.let { return it }
        }
        return keyFor(chore.emoji)
    }

    private val tints = listOf(0xFF3A86FF, 0xFFFF7AB6, 0xFF06D6A0, 0xFFFFB703, 0xFFB15EFF)
    /** A colour of its own for each chore's row — the same one every time. */
    fun tint(chore: Chore): Color {
        var sum = 0
        chore.id.codePoints().forEach { sum = (sum + it) % 9973 }
        return Color(tints[sum % tints.size])
    }
}

/** One drawing by its key (`R.drawable.chore_<key>`), or nothing when there is no such file. */
@Composable
fun ChoreDrawing(key: String, modifier: Modifier = Modifier): Boolean {
    val ctx = LocalContext.current
    val res = remember(key) { ctx.resources.getIdentifier("chore_$key", "drawable", ctx.packageName) }
    if (res == 0) return false
    Image(painterResource(res), null, modifier)
    return true
}

/** The drawing of a chore, or the chore's own emoji where there is none. */
@Composable
fun ChorePicture(chore: Chore, side: Dp = 92.dp, modifier: Modifier = Modifier) {
    Box(modifier.size(side), contentAlignment = Alignment.Center) {
        val key = ChoreArt.keyFor(chore)
        if (key == null || !ChoreDrawing(key, Modifier.size(side))) Text(chore.emoji, fontSize = (side.value * 0.6f).sp)
    }
}
