package com.rani.tofy

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.graphics.Color
import com.rani.tofy.auth.AuthRepository
import com.rani.tofy.data.AccountRepository
import com.rani.tofy.data.Bootstrap
import com.rani.tofy.push.PushRegistrar
import com.rani.tofy.ui.AppNav
import com.rani.tofy.ui.login.LoginScreen
import com.rani.tofy.ui.onboarding.FamilyChoiceScreen
import com.rani.tofy.ui.onboarding.JoinFamilyScreen
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.TofyTheme

class MainActivity : ComponentActivity() {
    /** Play recommends it: finish any purchase that completed while we were away. */
    override fun onResume() {
        super.onResume()
        runCatching { com.rani.tofy.billing.BillingRepository.resume(this) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // A tapped push / opened link (iOS onOpenURL + PushManager tap) — once, not on recreation.
        if (savedInstanceState == null) { com.rani.tofy.kid.ui.home.KidDeepLinks.handle(intent); openPlacePush(intent) }
        // 🧪 Debug builds only: `adb shell am start -n com.rani.tofy/.MainActivity
        // --es demoGame VAULT [--es demoGrade 6]` opens one mini-game on its own,
        // so a game can be checked without walking the whole app to it.
        val demoGame = if (BuildConfig.DEBUG) intent?.getStringExtra("demoGame") else null
        if (BuildConfig.DEBUG) intent?.getStringExtra("demoGrade")?.toIntOrNull()?.let {
            com.rani.tofy.kid.ui.games.MiniGameLevel.debugGrade = it
        }
        setContent {
            TofyTheme {
                // Tap anywhere outside a field to put the keyboard away. A child's
                // tablet has no "done" habit, and a half-covered screen reads as
                // broken. A control that consumes the tap (button, field) is
                // untouched — detectTapGestures only fires on an unconsumed one.
                val focus = androidx.compose.ui.platform.LocalFocusManager.current
                androidx.compose.foundation.layout.Box(
                    androidx.compose.ui.Modifier.fillMaxSize().pointerInput(Unit) {
                        detectTapGestures { focus.clearFocus() }
                    },
                ) {
                    val demo = demoGame?.let { g -> com.rani.tofy.kid.ui.games.MiniGameKind.entries.firstOrNull { it.name.equals(g, true) } }
                    // Be the device's own child, so the ⭐/💎 chips show the real wallet.
                    if (demo != null) androidx.compose.runtime.LaunchedEffect(Unit) {
                        com.rani.tofy.DeviceRole.joinedChildID?.let { com.rani.tofy.kid.core.KidSession.bind(it, false) }
                    }
                    if (demo != null) com.rani.tofy.kid.ui.games.MiniGameScreen(demo, null) { finish() }
                    else Root()
                    ForcedUpdateOverlay()
                }
            }
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        com.rani.tofy.kid.ui.home.KidDeepLinks.handle(intent)
        openPlacePush(intent)
    }

    /** 📍 A tapped "🏫 נוני הגיעה" push → the parent's map, on that child. */
    private fun openPlacePush(i: android.content.Intent?) {
        if (i?.getStringExtra("type") == "place") i.getStringExtra("childID")?.let { com.rani.tofy.ui.location.LocationRepository.openMapFor.value = it }
    }
}

/**
 * 🔄 Below `minAndroidBuild` this copy can no longer be trusted against the
 * server, so it covers everything (ChildTimeApp's ForcedUpdateView overlay).
 * The kid experience draws its own (Kid Mode keeps its parent-gated way out),
 * so here: parent surfaces get the store button, everything else is told to
 * ask a grown-up.
 */
@Composable
private fun ForcedUpdateOverlay() {
    val update by com.rani.tofy.update.AppUpdateConfig.state.collectAsState()
    if (update !is com.rani.tofy.update.AppUpdateConfig.State.Required) return
    val inKidExperience = DeviceRole.kidModeChildID != null ||
        (DeviceRole.role == DeviceRole.Role.CHILD && DeviceRole.joinedChildID != null)
    if (inKidExperience) return
    com.rani.tofy.update.ForcedUpdateScreen(parent = DeviceRole.role == DeviceRole.Role.PARENT)
}

/** ContentView.parentFlow: signed out → login; no family → choice; else home. */
@Composable
private fun Root() {
    // Kid Mode and a child device come BEFORE any parent sign-in routing.
    DeviceRole.kidModeChildID?.let { cid ->
        com.rani.tofy.kid.ui.KidRoot(cid, kidMode = true, onExitKidMode = { DeviceRole.endKidMode() }); return
    }
    when (DeviceRole.role) {
        null -> { com.rani.tofy.kid.ui.RolePickerScreen(onParent = { DeviceRole.choose(DeviceRole.Role.PARENT) }, onChild = { DeviceRole.choose(DeviceRole.Role.CHILD) }); return }
        DeviceRole.Role.CHILD -> {
            val cid = DeviceRole.joinedChildID
            if (cid == null) com.rani.tofy.kid.ui.ChildJoinScreen(onJoined = { DeviceRole.join(it) }, onBack = { DeviceRole.choose(null) })
            else com.rani.tofy.kid.ui.KidRoot(cid, kidMode = false, onExitKidMode = {})
            return
        }
        DeviceRole.Role.PARENT -> ParentRoot()
    }
}

@Composable
private fun ParentRoot() {
    val user by AuthRepository.user.collectAsState(initial = com.google.firebase.auth.FirebaseAuth.getInstance().currentUser)
    val boot by AccountRepository.boot.collectAsState()
    var joining by remember { mutableStateOf(false) }

    val real = user?.let { !it.isAnonymous } == true
    LaunchedEffect(user?.uid) {
        if (real) { AccountRepository.bootstrap(); PushRegistrar.register() }
    }
    when {
        !real -> LoginScreen()
        boot is Bootstrap.Loading -> Loading()
        boot is Bootstrap.NeedsFamilyChoice && joining -> JoinFamilyScreen(onBack = { joining = false })
        boot is Bootstrap.NeedsFamilyChoice -> FamilyChoiceScreen(onJoin = { joining = true })
        boot is Bootstrap.EmailInvite -> com.rani.tofy.ui.onboarding.EmailInviteScreen(boot as Bootstrap.EmailInvite)
        // 🔌 Never a raw exception and a dead end: retry by itself, and a button.
        boot is Bootstrap.Failed -> com.rani.tofy.ui.common.FamilyConnectingScreen(failed = true) { AccountRepository.retryNow() }
        else -> AppNav()
    }
}

@Composable
private fun Loading(message: String? = null) {
    GlassBackdrop {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            if (message == null) CircularProgressIndicator(color = Color.White) else Text(message, color = Color.White)
        }
    }
}
