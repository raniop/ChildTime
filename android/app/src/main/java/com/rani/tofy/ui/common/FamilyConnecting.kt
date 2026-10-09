package com.rani.tofy.ui.common

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.theme.GlassBackdrop
import kotlinx.coroutines.delay

/**
 * 🔌 "מתחברים למשפחה…" — FamilyConnectionViews.swift. Shown while the family
 * hasn't come down (or its load failed), instead of a blank screen or a raw
 * exception. After 10s (or on a failure) it offers "נסו שוב".
 */
@Composable
fun FamilyConnectingScreen(failed: Boolean = false, onRetry: () -> Unit) {
    var slow by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { delay(10_000); slow = true }
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().padding(horizontal = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            CircularProgressIndicator(color = Color.White)
            Spacer(Modifier.height(20.dp))
            Text(tr("מתחברים למשפחה…"), color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.ExtraBold)
            Spacer(Modifier.height(10.dp))
            Text(
                if (slow || failed) tr("זה לוקח יותר מהרגיל. בדקו שיש חיבור לאינטרנט — אנחנו ממשיכים לנסות לבד.")
                else tr("מורידים את הילדים וההגדרות של המשפחה"),
                color = Color.White.copy(alpha = 0.8f), fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center,
            )
            if (slow || failed) {
                Spacer(Modifier.height(20.dp))
                Box(
                    Modifier.widthIn(max = 280.dp).fillMaxWidth().height(50.dp)
                        .background(Color(0xFFFFD23F), RoundedCornerShape(16.dp))
                        .clickable { onRetry() },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(tr("נסו שוב"), color = Color(0xFF2A1E5C), fontSize = 17.sp, fontWeight = FontWeight.ExtraBold)
                }
            }
        }
    }
}

/** The dashboard banner while a live listener is down (FamilyLinkBanner). */
@Composable
fun FamilyLinkBanner(onRetry: () -> Unit) {
    Row(
        Modifier.fillMaxWidth()
            .background(Color(0x33FF8A3D), RoundedCornerShape(16.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("⚠️", fontSize = 20.sp)
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(tr("אין כרגע חיבור למשפחה"), color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.ExtraBold)
            Text(tr("מה שמוצג עלול להיות ישן. מנסים להתחבר שוב לבד."), color = Color.White.copy(alpha = 0.8f),
                fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.width(6.dp))
        Box(
            Modifier.height(36.dp).background(Color(0xFFFFD23F), RoundedCornerShape(16.dp))
                .clickable { onRetry() }.padding(horizontal = 12.dp),
            contentAlignment = Alignment.Center,
        ) { Text(tr("נסו שוב"), color = Color(0xFF2A1E5C), fontSize = 14.sp, fontWeight = FontWeight.ExtraBold) }
    }
}
