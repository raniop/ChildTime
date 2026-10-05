package com.rani.tofy.ui.settings

import android.app.Activity
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.DialogProperties
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.OAuthProvider
import com.rani.tofy.data.SettingsRepository
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.GlassButton
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

private enum class DeleteStep { CONFIRM, REAUTH, DELETING }

/**
 * "מחק את כל הנתונים שלי" — Google Play's in-app account deletion, with the
 * iOS cascade (HouseholdManager.deleteAllData) behind a strong confirmation:
 * the iOS dialog plus typing a word. Firebase needs a fresh sign-in to delete
 * an account, so that is asked BEFORE anything is wiped.
 */
@Composable
fun DeleteAccountFlow(onCancel: () -> Unit) {
    val ctx = LocalContext.current
    var step by remember { mutableStateOf(DeleteStep.CONFIRM) }
    fun start() { step = DeleteStep.DELETING; SettingsRepository.deleteEverything(ctx) }

    when (step) {
        DeleteStep.CONFIRM -> ConfirmDialog(onCancel) { if (SettingsRepository.needsRecentLogin()) step = DeleteStep.REAUTH else start() }
        DeleteStep.REAUTH -> ReauthDialog(onCancel) { start() }
        DeleteStep.DELETING -> AlertDialog(
            onDismissRequest = {}, confirmButton = {}, containerColor = Ink.sheet,
            properties = DialogProperties(dismissOnBackPress = false, dismissOnClickOutside = false),
            text = {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(Modifier.size(22.dp), color = Ink.primary, strokeWidth = 2.dp)
                    P(tr("מוחק…"), 15f, color = Ink.primary, weight = FontWeight.Bold)
                }
            },
        )
    }
}

@Composable
private fun ConfirmDialog(onCancel: () -> Unit, onConfirm: () -> Unit) {
    val word = tr("מחיקה")
    var typed by remember { mutableStateOf("") }
    val ok = typed.trim().equals(word, ignoreCase = true)
    AlertDialog(
        onDismissRequest = onCancel, containerColor = Ink.sheet,
        title = { Text(tr("למחוק את כל הנתונים לצמיתות?"), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, color = Ink.primary) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                P(tr("פעולה זו תמחק את כל הילדים, ההתקדמות וההיסטוריה מהמכשיר ומהענן, ותנתק את החשבון. לא ניתן לבטל."), 14.5f)
                P(tr("כדי לאשר, הקלידו: %@", word), 14f, color = Ink.primary, weight = FontWeight.Bold)
                OutlinedTextField(typed, { typed = it }, Modifier.fillMaxWidth(), singleLine = true, colors = glassFieldColors(), shape = RoundedCornerShape(12.dp))
            }
        },
        confirmButton = {
            TextButton(onConfirm, enabled = ok) {
                Text(tr("מחק הכול"), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, color = if (ok) Ink.weak else Ink.tertiary)
            }
        },
        dismissButton = { TextButton(onCancel) { Text(tr("בטל"), fontFamily = Rounded, color = Ink.secondary) } },
    )
}

/** Sign in again with whatever this account uses — Google, a password, or (an iOS-made account) Apple. */
@Composable
private fun ReauthDialog(onCancel: () -> Unit, onDone: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val providers = remember { SettingsRepository.providers }
    var password by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = { if (!busy) onCancel() }, containerColor = Ink.sheet, confirmButton = {},
        dismissButton = { TextButton(onCancel, enabled = !busy) { Text(tr("בטל"), fontFamily = Rounded, color = Ink.secondary) } },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                P(tr("מטעמי אבטחה, לפני מחיקת החשבון צריך להתחבר שוב."), 15f, color = Ink.primary, weight = FontWeight.Bold)
                if ("google.com" in providers) GlassButton(tr("התחבר עם Google"), Modifier.fillMaxWidth()) {
                    if (busy) return@GlassButton
                    busy = true; error = null
                    scope.launch {
                        val err = SettingsRepository.reauthWithGoogle(ctx)
                        busy = false
                        when (err) { null -> onDone(); "cancel" -> {}; else -> error = err }
                    }
                }
                if ("password" in providers) {
                    OutlinedTextField(
                        password, { password = it }, Modifier.fillMaxWidth(), singleLine = true,
                        placeholder = { Text(tr("סיסמה"), fontFamily = Rounded) },
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        colors = glassFieldColors(), shape = RoundedCornerShape(12.dp),
                    )
                    GlassButton(tr("התחבר"), Modifier.fillMaxWidth()) {
                        if (busy || password.isEmpty()) return@GlassButton
                        busy = true; error = null
                        scope.launch {
                            val ok = SettingsRepository.reauthWithPassword(password)
                            busy = false
                            if (ok) onDone() else error = tr("האימייל או הסיסמה לא נכונים — נסו שוב, או הקישו \"שכחתי סיסמה\"")
                        }
                    }
                }
                if ("apple.com" in providers) GlassButton(tr("התחבר עם Apple או Google"), Modifier.fillMaxWidth()) {
                    val activity = ctx as? Activity ?: return@GlassButton
                    val user = FirebaseAuth.getInstance().currentUser ?: return@GlassButton
                    if (busy) return@GlassButton
                    busy = true; error = null
                    scope.launch {
                        val r = runCatching { user.startActivityForReauthenticateWithProvider(activity, OAuthProvider.newBuilder("apple.com").build()).await() }
                        busy = false
                        r.onSuccess { onDone() }.onFailure { error = it.localizedMessage }
                    }
                }
                if (busy) CircularProgressIndicator(Modifier.size(22.dp).align(Alignment.CenterHorizontally), color = Ink.primary, strokeWidth = 2.dp)
                error?.let { P(it, 13f, color = Ink.weak) }
            }
        },
    )
}
