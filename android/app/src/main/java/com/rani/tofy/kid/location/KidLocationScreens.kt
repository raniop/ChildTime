package com.rani.tofy.kid.location

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.JoinRepository
import com.rani.tofy.kid.ui.KidCta
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.launch

/** 🔔 iOS KidBeepOverlay — over everything while the phone rings. */
@Composable
fun KidBeepScreen() {
    Column(
        Modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFFFF5FA8), Color(0xFFB25BEA), Color(0xFF6C4DF0))))
            .systemBarsPadding().padding(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))
        Text("🔔", fontSize = 90.sp)
        Spacer(Modifier.height(20.dp))
        Text(tr("מְחַפְּשִׂים אֶת הַטֵּלֵפוֹן!"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black,
            fontSize = 30.sp, textAlign = TextAlign.Center)
        Spacer(Modifier.height(10.dp))
        Text(tr("אַבָּא אוֹ אִמָּא בִּקְּשׁוּ לְצַפְצֵף כְּדֵי לִמְצֹא אוֹתוֹ"), color = Color.White, fontFamily = Rounded,
            fontSize = 17.sp, textAlign = TextAlign.Center)
        Spacer(Modifier.weight(1f))
        KidCta(tr("מָצָאתִי! 👋"), Color.White, Color.White, size = 22) { KidLocation.stopBeep(true) }
    }
}

/**
 * The permission flow, shared by the kid's explanation and the parent's
 * onboarding step: fine location first, then "allow all the time".
 *
 * Android 11+ grants "all the time" only on the app's own settings page — the
 * runtime request for ACCESS_BACKGROUND_LOCATION is refused with no UI at all
 * (seen on SDK 35: "Cannot grant LOCATION as the foreground permissions are …
 * already granted"), so a child's phone never got past "while using the app".
 * When that happens: one short step in our words, then the settings page, and
 * location starts when the child comes back. [kid] = the niqqud wording.
 */
@Composable
private fun rememberLocationRequest(kid: Boolean, onFinished: () -> Unit): () -> Unit {
    val ctx = LocalContext.current
    var askSettings by remember { mutableStateOf(false) }
    var inSettings by remember { mutableStateOf(false) }
    val finish = { KidLocation.start(); onFinished() }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        val obs = LifecycleEventObserver { _, e ->
            if (e == Lifecycle.Event.ON_RESUME && inSettings) { inSettings = false; finish() }
        }
        lifecycle.addObserver(obs)
        onDispose { lifecycle.removeObserver(obs) }
    }
    val background = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (!granted && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) askSettings = true else finish()
    }
    val fine = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { granted ->
        if (granted[Manifest.permission.ACCESS_FINE_LOCATION] == true && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
            && !KidLocation.hasBackground()) background.launch(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        else finish()
    }
    if (askSettings) AlertDialog(
        onDismissRequest = { askSettings = false; finish() },
        title = { Text(if (kid) tr("עוֹד צַעַד אֶחָד 📍") else tr("עוד צעד אחד 📍"), fontFamily = Rounded, fontWeight = FontWeight.Black) },
        text = {
            Text(if (kid) tr("בַּהַגְדָּרוֹת שֶׁיִּפָּתְחוּ: הַרְשָׁאוֹת ← מִקּוּם ← כָּל הַזְּמַן")
                 else tr("כדי שההתראות על הגעה ויציאה יעבדו גם כשטופי סגור: בהגדרות שייפתחו בוחרים הרשאות ← מיקום ← כל הזמן."),
                fontFamily = Rounded, fontSize = 16.sp)
        },
        confirmButton = {
            TextButton(onClick = {
                askSettings = false; inSettings = true
                ctx.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", ctx.packageName, null))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }) { Text(if (kid) tr("פְּתִיחַת הַהַגְדָּרוֹת") else tr("פתיחת ההגדרות"), fontFamily = Rounded, fontWeight = FontWeight.Bold) }
        },
        dismissButton = {
            TextButton(onClick = { askSettings = false; finish() }) { Text(if (kid) tr("אַחַר כָּךְ") else tr("אחר כך"), fontFamily = Rounded) }
        },
    )
    return {
        if (!KidLocation.hasFine()) fine.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
        else if (!KidLocation.hasBackground() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) background.launch(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        else finish()
    }
}

/** 📍 iOS KidLocationPermissionSheet — the kid's words before Android's question. */
@Composable
fun KidLocationPermissionScreen(isGirl: Boolean, onDone: () -> Unit) {
    val ask = rememberLocationRequest(kid = true, onDone)
    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding().padding(26.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.weight(1f))
            Text("📍", fontSize = 76.sp)
            Spacer(Modifier.height(16.dp))
            Text(if (isGirl) tr("אַבָּא וְאִמָּא יִרְאוּ אֵיפֹה אַתְּ") else tr("אַבָּא וְאִמָּא יִרְאוּ אֵיפֹה אַתָּה"),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 26.sp, textAlign = TextAlign.Center)
            Spacer(Modifier.height(12.dp))
            Text(if (isGirl) tr("כְּשֶׁהַטֵּלֵפוֹן זָז, הַהוֹרִים שֶׁלָּךְ יוֹדְעִים שֶׁהִגַּעַתְּ בְּשָׁלוֹם — לְבֵית הַסֵּפֶר, הַבַּיְתָה אוֹ לַחוּג.")
                 else tr("כְּשֶׁהַטֵּלֵפוֹן זָז, הַהוֹרִים שֶׁלְּךָ יוֹדְעִים שֶׁהִגַּעְתָּ בְּשָׁלוֹם — לְבֵית הַסֵּפֶר, הַבַּיְתָה אוֹ לַחוּג."),
                color = Color.White, fontFamily = Rounded, fontSize = 17.sp, textAlign = TextAlign.Center)
            Spacer(Modifier.height(16.dp))
            Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.16f)).padding(14.dp)) {
                Text(if (isGirl) tr("👉 בַּמָּסָךְ הַבָּא הַטֵּלֵפוֹן יִשְׁאַל — לִחְצִי עַל הָאִשּׁוּר")
                     else tr("👉 בַּמָּסָךְ הַבָּא הַטֵּלֵפוֹן יִשְׁאַל — לְחַץ עַל הָאִשּׁוּר"),
                    color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 15.5.sp)
            }
            Spacer(Modifier.weight(1f))
            KidCta(tr("מַמְשִׁיכִים ←"), Color.White, Color.White, size = 20) { KidLocation.countPrompt(); ask() }
        }
    }
}

/**
 * 📍 iOS ChildLockSetupView step 3: right after the lock, while the PARENT
 * holds the child's phone — Android's location question answered by an adult.
 * Parent-facing: no niqqud. Skippable.
 */
@Composable
fun OnboardingLocationStep(childID: String, householdID: String?, name: String, isGirl: Boolean, onDone: () -> Unit) {
    val scope = rememberCoroutineScope()
    var saving by remember { mutableStateOf(false) }
    val ask = rememberLocationRequest(kid = false, onDone)
    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding().padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Spacer(Modifier.height(20.dp))
            Text("📍", fontSize = 44.sp)
            Text(if (name.isEmpty()) tr("לדעת איפה הטלפון? (לא חובה)") else tr("לדעת איפה %@? (לא חובה)", name),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 26.sp, textAlign = TextAlign.Center)
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.16f)).padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                listOf(
                    if (isGirl) tr("מה נשמר: המיקום האחרון של הטלפון שלה, והגעה או יציאה מהמקומות שסימנתם. לא מסלול של כל היום.")
                    else tr("מה נשמר: המיקום האחרון של הטלפון שלו, והגעה או יציאה מהמקומות שסימנתם. לא מסלול של כל היום."),
                    tr("מי רואה: רק ההורים במשפחה. שום דבר לא עובר לאף גורם אחר."),
                    tr("אפשר לכבות בכל רגע, והמיקום השמור נמחק מיד."),
                ).forEach { Text(it, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.5.sp) }
            }
            Spacer(Modifier.weight(1f))
            KidCta(tr("אישור והפעלת מיקום"), Color(0xFFFFB13B), Color(0xFFFFD84A), busy = saving, size = 18) {
                saving = true
                scope.launch {
                    JoinRepository.childWrite(childID, householdID, mapOf("locationSharing" to mapOf(
                        "enabled" to true, "consentAt" to System.currentTimeMillis() / 1000.0, "consentBy" to "onboarding")))
                    KidLocation.countPrompt()
                    saving = false
                    ask()
                }
            }
            Text(tr("אולי אחר כך"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 15.sp,
                modifier = Modifier.clickable(onClick = onDone).padding(8.dp))
        }
    }
}
