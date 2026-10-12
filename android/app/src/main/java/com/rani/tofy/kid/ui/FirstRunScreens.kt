package com.rani.tofy.kid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.content.ContentMode
import com.rani.tofy.kid.core.FirstRun
import com.rani.tofy.kid.ui.play.QuestionRunnerScreen
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Rounded

/**
 * 🎬 The whole first run (see `FirstRun`): Tofy Time's questions, and over them —
 * after four answers, then every five — the one question: create a child's
 * profile, or play on. These words speak to the parent: no niqqud.
 */
@Composable
fun FirstRunQuiz() {
    val ctx = LocalContext.current
    Box(Modifier.fillMaxSize()) {
        // ✕ (or the end of the round) leaves to "who uses this device" — the way
        // out for a family that already exists, or a child's phone with a code.
        QuestionRunnerScreen(ContentMode.SmartFeed) { FirstRun.end(ctx, signUp = false) }
        if (FirstRun.asking) FirstRunAsk(onCreate = { FirstRun.end(ctx, signUp = true) }, onPlay = { FirstRun.asking = false })
    }
}

@Composable
private fun FirstRunAsk(onCreate: () -> Unit, onPlay: () -> Unit) {
    val quiet = remember { MutableInteractionSource() }
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f)).clickable(quiet, null) {}, contentAlignment = Alignment.BottomCenter) {
        Column(
            Modifier.navigationBarsPadding().padding(12.dp).widthIn(max = 440.dp).fillMaxWidth()
                .clip(RoundedCornerShape(16.dp)).background(Color(0xFA4A3AB0))
                .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                .padding(horizontal = 16.dp, vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("🧒", fontSize = 46.sp)
            Text(tr("רוצים ליצור פרופיל לילד שלכם?"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
                fontSize = 23.sp, textAlign = TextAlign.Center)
            Text(tr("ככה הילדים מרוויחים זמן מסך בטופי: עונים על שאלות, והשניות נצברות. ההרשמה לוקחת כדקה."),
                color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 15.5.sp, textAlign = TextAlign.Center)
            Text(tr("ליצור ילד"), color = Color(0xFF2A1E5C), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(GoldBrush)
                    .clickable(onClick = onCreate).padding(vertical = 15.dp))
            Text(tr("להמשיך לשחק"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 16.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f))
                    .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                    .clickable(onClick = onPlay).padding(vertical = 13.dp))
        }
    }
}
