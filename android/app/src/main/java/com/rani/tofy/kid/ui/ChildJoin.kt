package com.rani.tofy.kid.ui

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.google.firebase.auth.FirebaseAuth
import com.google.zxing.BarcodeFormat
import com.journeyapps.barcodescanner.BarcodeCallback
import com.journeyapps.barcodescanner.DecoratedBarcodeView
import com.journeyapps.barcodescanner.DefaultDecoderFactory
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.GoldButton
import com.rani.tofy.ui.onboarding.StepsHeader
import com.rani.tofy.ui.settings.QrImage
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * ContentView.childFlow: no anonymous identity yet → ChildAuthLoadingView;
 * else ChildJoinView. "Back" to the role picker exists ONLY during first-time
 * setup — never on a disconnected child device (it must not become a parent
 * device in one tap).
 */
@Composable
internal fun ChildJoinFlow(onJoined: (String) -> Unit, onBack: () -> Unit) {
    val ctx = LocalContext.current
    remember { KidBinding.init(ctx) }
    val b by KidBinding.state.collectAsState()
    val canGoBack = b.joinedChildID == null && !b.justDisconnected
    var uid by remember { mutableStateOf(FirebaseAuth.getInstance().currentUser?.uid) }
    var attempt by remember { mutableIntStateOf(0) }
    var timedOut by remember { mutableStateOf(false) }

    LaunchedEffect(attempt) {
        if (uid != null) return@LaunchedEffect
        timedOut = false
        uid = JoinRepository.ensureAnonymous(8000)
        if (uid == null) timedOut = true
    }
    BackHandler(enabled = canGoBack) { KidBinding.setRole("unset"); onBack() }

    if (uid == null) ChildAuthLoading(timedOut, canGoBack, onRetry = { attempt++ }, onBack = { KidBinding.setRole("unset"); onBack() })
    else ChildJoin(b.justDisconnected, canGoBack, onJoined, onBack = { KidBinding.setRole("unset"); onBack() })
}

/** ChildAuthLoadingView: a spinner, then after 8 s an honest message + retry. */
@Composable
private fun ChildAuthLoading(timedOut: Boolean, canGoBack: Boolean, onRetry: () -> Unit, onBack: () -> Unit) {
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(28.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        ) {
            if (timedOut) {
                Text("📡", fontSize = 52.sp)
                KidTitle(tr("לֹא הִצְלַחְנוּ לְהִתְחַבֵּר"), 22)
                KidBody(tr("בִּדְקוּ אֶת חִבּוּר הָאִינְטֶרְנֶט וְנַסּוּ שׁוּב."), 15f)
                GoldButton(tr("נַסּוּ שׁוּב"), Modifier.widthIn(max = 260.dp), onClick = onRetry)
                if (canGoBack) Text(
                    tr("הַחְלִיפוּ סוּג מַכְשִׁיר"), Modifier.clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.16f))
                        .clickable(onClick = onBack).padding(horizontal = 20.dp, vertical = 10.dp),
                    color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp,
                )
            } else {
                CircularProgressIndicator(color = Color.White)
                KidTitle(tr("מִתְחַבְּרִים…"), 18)
            }
        }
        if (canGoBack) TopStart { BackCapsule(onBack) }
    }
}

@Composable
private fun ChildJoin(justDisconnected: Boolean, canGoBack: Boolean, onJoined: (String) -> Unit, onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var code by remember { mutableStateOf("") }
    var working by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var showScanner by remember { mutableStateOf(false) }

    fun join(raw: String) {
        if (working) return
        val (codePart, _) = JoinRepository.parse(raw)
        if (codePart.length < 6) return
        scope.launch {
            working = true
            message = tr("מִתְחַבְּרִים…")
            when (val r = JoinRepository.redeem(raw)) {
                is JoinRepository.Result.Failed -> {
                    message = r.message
                    // Keep the code so "חִבּוּר" retries it (the invite carries the childID).
                    if (code.isEmpty()) code = codePart
                }
                is JoinRepository.Result.Joined -> {
                    val cid = r.childID
                    if (cid == null) {
                        message = tr("כִּמְעַט! בְּמַכְשִׁיר הַהוֹרֶה לַחֲצוּ עַל הַיֶּלֶד הַסְּפֵּצִיפִי כְּדֵי לְקַבֵּל קוֹד אִישִׁי, אוֹ סִרְקוּ אֶת קוֹד הַ-QR שֶׁלּוֹ.")
                    } else {
                        KidBinding.bind(cid)
                        message = tr("הִתְחַבַּרְתֶּם! 🎉")
                        delay(400)
                        onJoined(cid)
                    }
                }
            }
            working = false
        }
    }
    // An opened https://tofyapp.com/join?c=&k= link (KidDeepLinks) joins like a scan.
    val joinLink = com.rani.tofy.kid.ui.home.KidDeepLinks.pendingJoinLink
    LaunchedEffect(joinLink) {
        if (joinLink != null) { com.rani.tofy.kid.ui.home.KidDeepLinks.pendingJoinLink = null; join(joinLink) }
    }

    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().imePadding().verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.widthIn(max = 340.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(18.dp)) {
                if (!justDisconnected) Box(Modifier.padding(top = 36.dp)) { StepsHeader(3, tr("בטלפון של הילד")) }
                CharacterImage("fox", Modifier.size(120.dp))
                if (justDisconnected) {
                    KidTitle(tr("הַמַּכְשִׁיר נוּתַּק"), 30)
                    Text(
                        "▣ " + tr("סִרְקוּ שׁוּב אֶת קוֹד הַהוֹרֶה כְּדֵי לְהַמְשִׁיךְ"),
                        Modifier.clip(RoundedCornerShape(16.dp)).background(Color(0xFFFF9F43).copy(alpha = 0.9f)).padding(horizontal = 16.dp, vertical = 10.dp),
                        color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, textAlign = TextAlign.Center,
                    )
                    KidBody(com.rani.tofy.kid.ui.social.SocialMe.g(tr("הַהִתְקַדְּמוּת שֶׁלְּךָ שְׁמוּרָה בֶּעָנָן — שׁוּם דָּבָר לֹא אָבַד."), tr("הַהִתְקַדְּמוּת שֶׁלָּךְ שְׁמוּרָה בֶּעָנָן — שׁוּם דָּבָר לֹא אָבַד.")), 14f, alpha = 0.85f)
                } else {
                    KidTitle(tr("מְחַבְּרִים אֶת הַטֶּלֶפוֹן הַזֶּה"), 30)
                    KidBody(tr("סוֹרְקִים אֶת הַקּוֹד שֶׁמּוֹפִיעַ בַּטֶּלֶפוֹן שֶׁל הַהוֹרֶה"), 16f, alpha = 0.9f)
                }

                GoldButton("▣  " + tr("סִרְקוּ קוֹד QR"), enabled = !working) { showScanner = true }

                // The code row: Latin letters + digits — an ASCII keyboard, so a phone
                // set to Hebrew/Russian/Arabic can type it (iOS asciiCapable).
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.weight(1f).height(52.dp).glassPane(16.dp), contentAlignment = Alignment.Center) {
                        if (code.isEmpty()) Text(tr("אוֹ מַקְלִידִים אֶת הַקּוֹד"), color = Color.White.copy(alpha = 0.75f),
                            fontFamily = Rounded, fontSize = 17.sp, textAlign = TextAlign.Center)
                        BasicTextField(
                            code, { v -> code = v.filter { it.isLetterOrDigit() || it == '|' }.uppercase().take(64) },
                            Modifier.fillMaxWidth().padding(horizontal = 10.dp),
                            singleLine = true,
                            textStyle = TextStyle(color = Color.White, fontSize = 20.sp, fontFamily = FontFamily.Monospace, textAlign = TextAlign.Center),
                            cursorBrush = SolidColor(Color.White),
                            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters, autoCorrectEnabled = false,
                                keyboardType = KeyboardType.Ascii, imeAction = ImeAction.Go),
                            keyboardActions = KeyboardActions(onGo = { if (code.length >= 6) join(code) }),
                        )
                    }
                    val ready = code.length >= 6 && !working
                    Box(
                        Modifier.height(52.dp).clip(RoundedCornerShape(16.dp)).background(GoldBrush)
                            .then(if (ready) Modifier else Modifier.background(Color.Black.copy(alpha = 0.25f)))
                            .clickable(enabled = ready) { join(code) }.padding(horizontal = 18.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (working) CircularProgressIndicator(Modifier.size(20.dp), color = Ink.deep, strokeWidth = 2.5.dp)
                        else Text(tr("חִבּוּר"), color = Ink.deep, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
                    }
                }

                message?.let { KidBody(it, 14f, alpha = 0.9f) }

                // The roadmap for families who started on the KID's device (no share
                // button — a leave-app path on a child screen).
                Column(Modifier.fillMaxWidth().glassInset(16.dp).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(tr("עוֹד אֵין לָכֶם טוֹפִי אֵצֶל הַהוֹרֶה?"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.5.sp)
                    listOf(
                        tr("מוֹרִידִים אֶת טוֹפִי בַּמַּכְשִׁיר שֶׁל הַהוֹרֶה"),
                        tr("נִרְשָׁמִים וְיוֹצְרִים שָׁם אֶת הַיְלָדִים"),
                        tr("חוֹזְרִים לְכָאן וְסוֹרְקִים אֶת הַקּוֹד"),
                    ).forEachIndexed { i, step ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Box(Modifier.size(22.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.92f)), contentAlignment = Alignment.Center) {
                                Text("${i + 1}", color = Ink.indigo, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 12.sp)
                            }
                            Text(step, color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp, lineHeight = 18.sp)
                        }
                    }
                }

                // getTofyOnIPhoneCard, Android wording: the site's QR, drawn locally and
                // NOT tappable — the parent's camera opens it on their phone.
                Column(Modifier.fillMaxWidth().glassInset(16.dp).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(tr("עוֹד אֵין לָכֶם טוֹפִי בַּטֶּלֶפוֹן שֶׁל הַהוֹרֶה?"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.5.sp)
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        QrImage("https://tofyapp.com", 72.dp)
                        Text(tr("סִרְקוּ עִם הַמַּצְלֵמָה שֶׁל הַטֶּלֶפוֹן שֶׁל הַהוֹרֶה כְּדֵי לְהוֹרִיד אֶת טוֹפִי, צְרוּ מִשְׁפָּחָה וְחִזְרוּ לְכָאן"),
                            color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, lineHeight = 18.sp)
                    }
                }
            }
        }
        if (canGoBack) TopStart { BackCapsule(onBack) }
        if (showScanner) QrScannerCover(onScanned = { showScanner = false; join(it) }, onCancel = { showScanner = false })
    }
}

/**
 * QRScannerView: the ZXing embedded scanner, on-device only (no Google ML
 * Kit — the Kids no-analytics promise). Asks for the camera the first time.
 */
@Composable
private fun QrScannerCover(onScanned: (String) -> Unit, onCancel: () -> Unit) {
    val ctx = LocalContext.current
    var granted by remember {
        mutableStateOf(ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED)
    }
    var denied by remember { mutableStateOf(false) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> granted = ok; denied = !ok }
    LaunchedEffect(Unit) { if (!granted) ask.launch(Manifest.permission.CAMERA) }
    BackHandler(onBack = onCancel)

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        if (granted) {
            val owner = LocalLifecycleOwner.current
            var delivered by remember { mutableStateOf(false) }
            val view = remember {
                DecoratedBarcodeView(ctx).apply {
                    barcodeView.decoderFactory = DefaultDecoderFactory(listOf(BarcodeFormat.QR_CODE))
                    setStatusText("")
                    decodeContinuous(BarcodeCallback { r ->
                        val t = r?.text ?: return@BarcodeCallback
                        if (!delivered) { delivered = true; pause(); onScanned(t) }
                    })
                }
            }
            DisposableEffect(owner) {
                val obs = LifecycleEventObserver { _, e ->
                    if (e == Lifecycle.Event.ON_RESUME) view.resume() else if (e == Lifecycle.Event.ON_PAUSE) view.pause()
                }
                owner.lifecycle.addObserver(obs)
                if (owner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) view.resume()
                onDispose { owner.lifecycle.removeObserver(obs); view.pause() }
            }
            AndroidView({ view }, Modifier.fillMaxSize())
        } else if (denied) {
            Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically)) {
                Text("📷", fontSize = 48.sp)
                KidBody(tr("כְּדֵי לִסְרֹק צָרִיךְ לְאַשֵּׁר לְטוֹפִי גִּישָׁה לַמַּצְלֵמָה — אוֹ מַקְלִידִים אֶת הַקּוֹד"), 16f)
            }
        }
        Row(
            Modifier.fillMaxWidth().systemBarsPadding().background(Color.Black.copy(alpha = 0.5f)).padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(tr("סריקת קוד"), Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 17.sp)
            Text(tr("ביטול"), Modifier.clip(RoundedCornerShape(16.dp)).border(1.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(16.dp))
                .clickable(onClick = onCancel).padding(horizontal = 14.dp, vertical = 6.dp),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 15.sp)
        }
    }
}
