package com.rani.tofy

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { TofyTheme { Root() } }
    }
}

/** ContentView.parentFlow: signed out → login; no family → choice; else home. */
@Composable
private fun Root() {
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
        boot is Bootstrap.Failed -> Loading((boot as Bootstrap.Failed).message)
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
