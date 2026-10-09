package com.rani.tofy.ui.onboarding

import com.rani.tofy.ui.common.contentColumn

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.google.firebase.auth.FirebaseAuth
import com.rani.tofy.data.AccountRepository
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.*
import com.rani.tofy.ui.theme.*
import kotlinx.coroutines.launch

/** FamilyChoiceView.swift: family name + consent on one screen; joining is a secondary link. */
@Composable
fun FamilyChoiceScreen(onJoin: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val user = FirebaseAuth.getInstance().currentUser
    val first = user?.displayName?.trim()?.split(" ")?.firstOrNull().orEmpty()
    val last = user?.displayName?.trim()?.split(" ")?.drop(1)?.lastOrNull()
    var name by remember { mutableStateOf(last?.let { tr("משפחת %@", it) } ?: "") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    GlassBackdrop {
        Column(
            Modifier.contentColumn().fillMaxSize().systemBarsPadding().imePadding().verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            OnboardingProgress(step = 1)
            H(if (first.isNotEmpty()) tr("ברוכים הבאים, %@! 👋\nאיך קוראים למשפחה?", first) else tr("איך קוראים למשפחה?"), 25, align = TextAlign.Center)
            P(tr("השם יופיע במסך הבית ובעדכונים"), 15f, align = TextAlign.Center)
            OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), placeholder = { Text(tr("למשל: משפחת גולן"), fontFamily = Rounded) }, singleLine = true)
            error?.let { P(it, 13f, color = Ink.weak) }
            GoldButton(tr("המשך"), enabled = name.isNotBlank(), busy = busy) {
                busy = true
                scope.launch {
                    runCatching {
                        AccountRepository.createOwnHousehold(name)
                        AccountRepository.recordConsent()
                    }.onFailure { error = tr("אין כרגע חיבור, אז לא הצלחנו ליצור את המשפחה. בדקו את האינטרנט ונסו שוב."); busy = false }
                }
            }
            P(tr("הוזמנתם על ידי הורה אחר? הצטרפו למשפחה"), 15f, Modifier.clickable(onClick = onJoin), color = Ink.primary, weight = FontWeight.Bold, align = TextAlign.Center)
            P(tr("בהמשך אתם מאשרים כהורים את תנאי השימוש ואת מדיניות הפרטיות"), 12.5f, color = Ink.tertiary, align = TextAlign.Center)
            Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                P(tr("תנאי שימוש"), 13f, Modifier.clickable { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://tofyapp.com/terms.html"))) }, weight = FontWeight.Bold)
                P(tr("מדיניות פרטיות"), 13f, Modifier.clickable { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://tofyapp.com/privacy.html"))) }, weight = FontWeight.Bold)
            }
        }
    }
}

/** OnboardingSteps.swift progress bar — 4 steps. */
@Composable
fun OnboardingProgress(step: Int, total: Int = 4) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        repeat(total) { i ->
            Box(Modifier.weight(1f).height(6.dp).glassPane(3.dp, if (i < step) 0.9f else 0.2f, shadow = false))
        }
    }
}

/** JoinFamilyFlowView (CoParentLinkingViews.swift): type the co-parent's code. */
@Composable
fun JoinFamilyScreen(onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var code by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    androidx.activity.compose.BackHandler(onBack = onBack)
    GlassBackdrop {
        Column(
            Modifier.contentColumn().fillMaxSize().systemBarsPadding().imePadding().verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            H(tr("הצטרפות למשפחה"), 25, align = TextAlign.Center)
            Column(Modifier.fillMaxWidth().glassPane().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                P(tr("במכשיר של ההורה שכבר רשום:"), 15f, color = Ink.primary, weight = FontWeight.Bold)
                P("1. " + tr("פתחו את טופי → הגדרות ⚙️"), 14.5f)
                P("2. " + tr("הקישו “הוסיפו הורה”"), 14.5f)
                P("3. " + tr("יופיע קוד / QR — סרקו אותו כאן או הקלידו:"), 14.5f)
            }
            OutlinedTextField(code, { code = it.uppercase().filter { c -> c.isLetterOrDigit() }.take(6); error = null }, Modifier.fillMaxWidth(), singleLine = true,
                placeholder = { Text(tr("6 תווים"), fontFamily = Rounded, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center) },
                textStyle = MaterialTheme.typography.headlineMedium.copy(textAlign = TextAlign.Center, letterSpacing = androidx.compose.ui.unit.TextUnit(6f, androidx.compose.ui.unit.TextUnitType.Sp)))
            error?.let { P(it, 13f, color = Ink.weak, align = TextAlign.Center) }
            GoldButton(tr("הצטרפו"), enabled = code.length == 6, busy = busy) {
                busy = true; error = null
                scope.launch {
                    AccountRepository.redeemInvite(code).onFailure {
                        busy = false
                        // A bad/expired code vs. a join that worked but whose family
                        // couldn't load (offline) — the second isn't "קוד לא תקין".
                        error = when (it.message) {
                            "code", "expired" -> tr("קוד לא תקין")
                            else -> tr("אין כרגע חיבור. בדקו את האינטרנט ונסו שוב — אותו קוד יעבוד.")
                        }
                    }
                }
            }
            TextButton(onBack) { Text(tr("ביטול"), fontFamily = Rounded, color = Ink.secondary) }
        }
    }
}

/** EmailInviteWelcomeView: "משפחת X מחכה לכם!" — one tap. */
@Composable
fun EmailInviteScreen(invite: com.rani.tofy.data.Bootstrap.EmailInvite) {
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    GlassBackdrop {
        Column(
            Modifier.contentColumn().fillMaxSize().systemBarsPadding().padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("👨‍👩‍👧", fontSize = androidx.compose.ui.unit.TextUnit(56f, androidx.compose.ui.unit.TextUnitType.Sp))
            H(tr("%@ מחכה לכם!", invite.familyName ?: tr("המשפחה שלכם")), 26, align = TextAlign.Center)
            P(tr("הוזמנתם להצטרף כהורה — תראו את הילדים, ההתקדמות והשליטה, בדיוק כמו ההורה שהזמין אתכם."), 15f, align = TextAlign.Center)
            GoldButton(tr("הצטרפו למשפחה"), busy = busy) {
                busy = true
                failed = false
                scope.launch { runCatching { AccountRepository.acceptEmailInvite(invite.householdID) }.onFailure { busy = false; failed = true } }
            }
            if (failed) P(tr("אין כרגע חיבור. בדקו את האינטרנט ונסו שוב."), 13f, color = Ink.weak, align = TextAlign.Center)
            TextButton({ AccountRepository.declineEmailInvite() }) { Text(tr("לא המשפחה שלי — התחילו מהתחלה"), fontFamily = Rounded, color = Ink.secondary) }
        }
    }
}
