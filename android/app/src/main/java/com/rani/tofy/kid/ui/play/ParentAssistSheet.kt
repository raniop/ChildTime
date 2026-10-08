package com.rani.tofy.kid.ui.play

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.content.Question
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * ParentAssistView (kid side): pick a parent → that parent gets a push with the
 * question and two options; one tap removes a wrong option from the child's
 * screen. Warm, no pressure, never shaming.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ParentAssistSheet(r: RunnerController, question: Question, topic: Topic, onDismiss: () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    var sent by remember { mutableStateOf(false) }
    val girl = r.isGirl
    val parents = r.linkedParents

    fun ask(uid: String) {
        if (sent) return
        r.askParent(question, topic, uid)
        sent = true
        scope.launch { delay(1400); onDismiss() }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = state, containerColor = Ink.sheet) {
        Column(
            Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 24.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("🤔", fontSize = 60.sp)
                Text(if (girl) tr("רוֹצָה עֶזְרָה בַּשְּׁאֵלָה הַזּוֹ?") else tr("רוֹצֶה עֶזְרָה בַּשְּׁאֵלָה הַזּוֹ?"),
                    color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 24.sp, textAlign = TextAlign.Center)
                Text(
                    if (girl) tr("אַבָּא אוֹ אִמָּא יוֹרִידוּ תְּשׁוּבָה אַחַת לֹא נְכוֹנָה — וְאַתְּ עוֹנָה 😉")
                    else tr("אַבָּא אוֹ אִמָּא יוֹרִידוּ תְּשׁוּבָה אַחַת לֹא נְכוֹנָה — וְאַתָּה עוֹנֶה 😉"),
                    color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, textAlign = TextAlign.Center,
                )
            }
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                when {
                    sent -> Text(
                        "💌 " + tr("שָׁלַחְנוּ בַּקָּשַׁת עֶזְרָה!"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
                        fontSize = 19.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().glassInset(16.dp).padding(vertical = 16.dp),
                    )
                    // No named parent on file — every parent device gets the same request.
                    parents.isEmpty() -> AssistButton(if (girl) tr("👨‍👩‍👧 בַּקְּשִׁי עֶזְרָה מֵאַבָּא אוֹ אִמָּא") else tr("👨‍👩‍👧 בַּקֵּשׁ עֶזְרָה מֵאַבָּא אוֹ אִמָּא")) { ask("all") }
                    else -> parents.forEach { (uid, name) ->
                        AssistButton(if (girl) tr("👋 בַּקְּשִׁי עֶזְרָה מ%@", name) else tr("👋 בַּקֵּשׁ עֶזְרָה מ%@", name)) { ask(uid) }
                    }
                }
            }
            Text(
                tr("🚀 אַמְשִׁיךְ לְבַד"), color = Color.White.copy(alpha = if (sent) 0.5f else 1f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
                fontSize = 17.sp, textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().glassInset(16.dp).clickable(enabled = !sent) { onDismiss() }.padding(vertical = 14.dp),
            )
        }
    }
}

@Composable
private fun AssistButton(title: String, onClick: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp))
            .background(Brush.horizontalGradient(listOf(Color(0xFF5E60CE), Color(0xFF3E8BF0))))
            .clickable(onClick = onClick).padding(vertical = 15.dp),
        contentAlignment = Alignment.Center,
    ) { Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, textAlign = TextAlign.Center) }
}
