package com.rani.tofy.billing

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.rani.tofy.DeviceRole
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.ParentGate
import com.rani.tofy.kid.ui.shop.rememberParentPin
import com.rani.tofy.ui.onboarding.ParentPinSetupScreen

/**
 * ParentGateView(respectSession: false) in front of every purchase — Kids
 * Category (guideline 1.3 on iOS, Families policy on Play): ALL commerce sits
 * behind the parent code, re-asked on every open, on the parent's phone too.
 *
 * On a PARENT device whose family never picked a code, iOS offers to set one
 * up (allowSetup) — setting it is the gate. A child device never can: it shows
 * the honest "not available here" (kid ParentGate).
 */
@Composable
fun BillingParentGate(reason: String, onClose: () -> Unit, content: @Composable () -> Unit) {
    var authorized by remember { mutableStateOf(false) }
    if (authorized) { content(); return }
    val family by FamilyRepository.state.collectAsState()
    val parentDevice = DeviceRole.role == DeviceRole.Role.PARENT && DeviceRole.kidModeChildID == null
    val hid = family.household?.id ?: BillingRepository.householdFor(null)
    val (pinHash, loaded) = rememberParentPin(hid)
    if (parentDevice && loaded && pinHash == null && family.household != null) {
        ParentPinSetupScreen(onDone = { authorized = true })
    } else {
        ParentGate(pinHash, loaded, tr("אֵזוֹר הוֹרִים"), reason, onAuthorized = { authorized = true }, onClose = onClose)
    }
}
