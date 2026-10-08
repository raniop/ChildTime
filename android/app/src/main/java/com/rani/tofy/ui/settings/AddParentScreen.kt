package com.rani.tofy.ui.settings

import com.rani.tofy.ui.common.contentColumn

import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.CompositionLocalProvider
import com.google.firebase.auth.FirebaseAuth
import com.rani.tofy.data.ChildRepository
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.SettingsRepository
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.GoldButton
import com.rani.tofy.ui.common.H
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.launch

/** Co-parents recorded on the household, minus me — HouseholdManager.linkedParentSummaries. */
fun linkedParentNames(names: Map<String, String>): List<String> {
    val me = FirebaseAuth.getInstance().currentUser?.uid
    return names.filter { it.key != me && it.value.isNotEmpty() }.values.sorted()
}

/**
 * CoParentLinkingViews.AddParentView: invite by email (the friction-free path),
 * or a 6-character family code + QR + share sheet for the other parent's
 * "join a family" screen. Celebrates when a new parent shows up on the household.
 */
@Composable
fun AddParentScreen(onClose: () -> Unit) {
    BackHandler(onBack = onClose)
    val state by FamilyRepository.state.collectAsState()
    val linked = linkedParentNames(state.household?.parentNames ?: emptyMap()).size
    val baseline = remember { mutableIntStateOf(linked) }
    var justJoined by remember { mutableStateOf(false) }
    LaunchedEffect(linked) { if (linked > baseline.intValue) justJoined = true }

    GlassBackdrop {
        Column(Modifier.contentColumn().fillMaxSize().systemBarsPadding().imePadding()) {
            SettingsTopBar(tr("הוספת הורה"), onClose)
            Column(
                Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Column(Modifier.widthIn(max = 460.dp), verticalArrangement = Arrangement.spacedBy(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    if (justJoined) JoinedBanner(onClose) else Content()
                }
            }
        }
    }
}

@Composable
private fun Content() {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("👨‍👩‍👧‍👦", fontSize = 52.sp)
        H(tr("הוסיפו הורה למשפחה"), 22, align = TextAlign.Center)
        P(tr("שניכם תראו את אותם הילדים ואת אותה ההתקדמות."), 14f, color = Color.White.copy(alpha = 0.8f), align = TextAlign.Center)
    }
    EmailInviteCard()
    StepsCard(tr("או — במכשיר של ההורה השני:"), listOf(
        tr("התקינו את אפליקצית טופי"),
        tr("במסך הפתיחה הקישו “כבר יש לכם משפחה? הצטרפו”"),
        tr("התחברו, וסרקו את הקוד שכאן (או הקלידו אותו)"),
        // The joiner meets the parent-code gate next — told here, to the
        // person who knows it (verbally, never in a message).
        tr("בכניסה יתבקש קוד ההורה — מסרו לו את הקוד שלכם בעל־פה 🔑"),
    ))
    CodeCard()
}

@Composable
private fun EmailInviteCard() {
    val scope = rememberCoroutineScope()
    var email by remember { mutableStateOf("") }
    var sent by remember { mutableStateOf(false) }
    var inviting by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().glassPane(20.dp, 0.10f).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        H(tr("✉️ הדרך הקלה: הזמינו באימיל"), 16, align = TextAlign.Center)
        P(tr("ההורה השני פשוט יתחבר עם האימיל הזה — והמשפחה תחכה לו שם, בלי קודים."), 13f, color = Color.White.copy(alpha = 0.8f), align = TextAlign.Center)
        if (sent) P("✓ " + tr("ההזמנה נשמרה! אפשר להזמין עוד אימיל"), 13.5f, color = Ink.good, weight = FontWeight.ExtraBold, align = TextAlign.Center)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            // An address reads left-to-right whatever the app language.
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                OutlinedTextField(
                    email, { email = it.trim() }, Modifier.weight(1f), singleLine = true,
                    placeholder = { Text(tr("אימיל של ההורה השני"), fontFamily = Rounded) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, autoCorrectEnabled = false),
                    colors = glassFieldColors(), shape = RoundedCornerShape(12.dp),
                )
            }
            val ok = email.contains("@")
            Box(
                Modifier.clip(RoundedCornerShape(30.dp)).background(if (ok) GoldBrush else androidx.compose.ui.graphics.SolidColor(Color.White.copy(alpha = 0.25f)))
                    .clickable(enabled = ok && !inviting) {
                        inviting = true; sent = false
                        scope.launch {
                            var valid = true
                            val done = SettingsRepository.householdWrite { valid = ChildRepository.inviteParentByEmail(email) }
                            inviting = false
                            if (done && valid) { sent = true; email = "" }
                        }
                    }
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                if (inviting) CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                else Text(tr("הזמינו"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
            }
        }
    }
}

@Composable
private fun CodeCard() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var code by remember { mutableStateOf<String?>(null) }
    var working by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    fun generate() {
        working = true; error = null
        scope.launch {
            code = runCatching { ChildRepository.createInvite() }.getOrNull()
                ?: run { FamilyRepository.reassertMembership(); runCatching { ChildRepository.createInvite() }.getOrNull() }
            if (code == null) error = tr("לא ניתן ליצור קוד כעת")
            working = false
        }
    }
    LaunchedEffect(Unit) { if (code == null) generate() }

    // The code and QR read left-to-right in every language (iOS forces .leftToRight).
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Column(Modifier.fillMaxWidth().glassPane(20.dp, 0.10f).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            val c = code
            when {
                c != null -> {
                    QrImage(c, 190.dp)
                    Text(c, color = Color.White, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.ExtraBold, fontSize = 32.sp, letterSpacing = 6.sp)
                    Box(
                        Modifier.clip(RoundedCornerShape(30.dp)).background(Color.White.copy(alpha = 0.18f)).clickable {
                            val send = Intent(Intent.ACTION_SEND).setType("text/plain")
                                .putExtra(Intent.EXTRA_TEXT, tr("הצטרפו אלי בטופי! קוד המשפחה: %@", c))
                            ctx.startActivity(Intent.createChooser(send, null))
                        }.padding(horizontal = 16.dp, vertical = 9.dp),
                    ) { Text("⇪  " + tr("שיתוף הקוד"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp) }
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(Modifier.size(14.dp), color = Color.White, strokeWidth = 2.dp)
                        P(tr("ממתין שההורה יצטרף…"), 13f, color = Color.White.copy(alpha = 0.7f), weight = FontWeight.SemiBold)
                    }
                }
                working -> CircularProgressIndicator(color = Color.White)
                error != null -> {
                    P(error!!, 12.5f, color = Color.White.copy(alpha = 0.8f), align = TextAlign.Center)
                    Text(tr("נסו שוב"), Modifier.clickable { generate() }.padding(8.dp), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun JoinedBanner(onClose: () -> Unit) {
    Column(Modifier.padding(top = 40.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("🎉", fontSize = 64.sp)
        H(tr("הורה נוסף למשפחה!"), 22, align = TextAlign.Center)
        P(tr("מעכשיו שניכם רואים את אותם הילדים."), 14f, color = Color.White.copy(alpha = 0.8f), align = TextAlign.Center)
        GoldButton(tr("סיום"), Modifier.padding(top = 6.dp), onClick = onClose)
    }
}
