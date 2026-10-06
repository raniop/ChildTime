package com.rani.tofy.ui.login

import com.rani.tofy.ui.common.contentColumn

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.R
import com.rani.tofy.auth.AuthRepository
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.*
import com.rani.tofy.ui.theme.*
import kotlinx.coroutines.launch

/** LoginGateView.swift for the parent: Google, or email. */
@Composable
fun LoginScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var showEmail by remember { mutableStateOf(false) }

    GlassBackdrop {
        Column(
            Modifier.contentColumn().fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
        ) {
            Box(Modifier.glassPane(18.dp).padding(horizontal = 18.dp, vertical = 10.dp)) { H(tr("היי! אני טופי 💫"), 20) }
            Image(painterResource(R.drawable.char_fox), null, Modifier.size(170.dp))
            H(tr("היכנסו כדי להתחיל"), 26, align = TextAlign.Center)
            Column(Modifier.fillMaxWidth().glassPane().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                ValueProp("👀", tr("רואים הכל"), tr("התקדמות חיה, מכל מכשיר"))
                ValueProp("⭐", tr("לומדים ומרוויחים"), tr("תשובה = דקות מסך"))
                ValueProp("🔒", tr("פרטי לגמרי"), tr("הנתונים נשארים אצלכם"))
            }
            // Google — white, branded, first (most Android parents already have one).
            Row(
                Modifier.fillMaxWidth().height(56.dp).clip(RoundedCornerShape(16.dp)).background(Color.White)
                    .clickable(enabled = !busy) {
                        busy = true; error = null
                        scope.launch {
                            val e = AuthRepository.signInWithGoogle(ctx)
                            busy = false
                            if (e != null && e != "cancel") error = e
                        }
                    },
                horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
            ) {
                if (busy) CircularProgressIndicator(Modifier.size(22.dp), color = Ink.indigo, strokeWidth = 3.dp)
                else {
                    Text("G", color = Color(0xFF4285F4), fontWeight = FontWeight.Black, fontSize = 22.sp)
                    Spacer(Modifier.width(10.dp))
                    Text(tr("התחבר עם Google"), color = Color(0xFF1F1F1F), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            }
            GlassButton(tr("המשך עם אימייל"), Modifier.fillMaxWidth(), height = 56.dp, radius = 16.dp) { showEmail = true }
            error?.let { P(it, 13f, color = Ink.weak, align = TextAlign.Center) }
            P(tr("בהתחברות אתם מסכימים לתנאי השימוש ולמדיניות הפרטיות"), 12.5f, color = Ink.tertiary, align = TextAlign.Center)
            Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                P(tr("תנאי שימוש"), 13f, Modifier.clickable { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://tofyapp.com/terms.html"))) }, color = Ink.secondary, weight = FontWeight.Bold)
                P(tr("מדיניות פרטיות"), 13f, Modifier.clickable { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://tofyapp.com/privacy.html"))) }, color = Ink.secondary, weight = FontWeight.Bold)
            }
        }
    }
    if (showEmail) EmailAuthSheet { showEmail = false }
}

@Composable
private fun ValueProp(emoji: String, title: String, sub: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.18f)), contentAlignment = Alignment.Center) { Text(emoji, fontSize = 19.sp) }
        Column { H(title, 16); P(sub, 13.5f) }
    }
}

/** EmailAuthView.swift — sign in / register, with "שכחתי סיסמה". */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EmailAuthSheet(onDismiss: () -> Unit) {
    val scope = rememberCoroutineScope()
    var register by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var pass by remember { mutableStateOf("") }
    var show by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var msg by remember { mutableStateOf<String?>(null) }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Ink.sheet) {
        Column(Modifier.imePadding().padding(horizontal = 20.dp).padding(bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            H(tr("חשבון הורה"), 21)
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                SegmentedButton(!register, { register = false }, SegmentedButtonDefaults.itemShape(0, 2)) { Text(tr("כניסה"), fontFamily = Rounded) }
                SegmentedButton(register, { register = true }, SegmentedButtonDefaults.itemShape(1, 2)) { Text(tr("הרשמה"), fontFamily = Rounded) }
            }
            if (register) Field(name, { name = it }, tr("שם ההורה"))
            Field(email, { email = it }, tr("אימייל"), KeyboardType.Email)
            OutlinedTextField(
                pass, { pass = it }, Modifier.fillMaxWidth(), label = { Text(tr("סיסמה (לפחות 6 תווים)"), fontFamily = Rounded) },
                singleLine = true, visualTransformation = if (show) VisualTransformation.None else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                trailingIcon = { TextButton({ show = !show }) { Text(if (show) tr("הסתר סיסמה") else tr("הצג סיסמה"), fontSize = 12.sp) } },
            )
            msg?.let { P(it, 13f, color = Ink.warn) }
            GoldButton(if (register) tr("צור חשבון") else tr("התחבר"), enabled = email.contains("@") && pass.length >= 6, busy = busy) {
                busy = true; msg = null
                scope.launch {
                    val e = if (register) AuthRepository.register(name, email, pass) else AuthRepository.signInWithEmail(email, pass)
                    busy = false
                    if (e == null) onDismiss() else msg = e
                }
            }
            if (!register) TextButton({
                scope.launch { msg = AuthRepository.resetPassword(email) ?: tr("שלחנו קישור לאיפוס הסיסמה אל %@ — בדקו את המייל (גם בספאם)", email) }
            }, Modifier.align(Alignment.CenterHorizontally)) { Text(tr("שכחתי סיסמה"), color = Color.White, fontFamily = Rounded) }
        }
    }
}

@Composable
private fun Field(v: String, on: (String) -> Unit, label: String, kb: KeyboardType = KeyboardType.Text) =
    OutlinedTextField(v, on, Modifier.fillMaxWidth(), label = { Text(label, fontFamily = Rounded) }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = kb))
