package com.rani.tofy.ui.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.platform.LocalContext
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.rani.tofy.data.ChildRepository
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.nowSecs
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

private enum class Step { CHILD, DEVICE, CONNECT, DONE, GIFT }

/**
 * Onboarding steps ②–④ (ParentDashboardView.swift's create → DeviceQuestion →
 * OnboardingConnect → OnboardingDone chain). `firstChild` = the new-parent flow
 * (`ParentOnboarding`): steps bar, the QR as a full screen, "הכל מוכן" + gift at
 * the end, and a relaunch resumes where it stopped. Otherwise (＋ from home):
 * the same child screen and question without the bar, then the dashboard's
 * QR sheet.
 *
 * NOTE for AppNav: once the child is created `children` is no longer empty —
 * keep this on screen while `rememberOnboardingActive()` is true, or steps ③–④
 * vanish the moment step ② saves.
 */
@Composable
fun AddChildFlow(firstChild: Boolean, onDone: () -> Unit, onCancel: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val state by FamilyRepository.state.collectAsState()

    var step by rememberSaveable { mutableStateOf(Step.CHILD) }
    var childID by rememberSaveable { mutableStateOf<String?>(null) }
    var draftName by rememberSaveable { mutableStateOf("") }
    var draftGirl by rememberSaveable { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf(false) }
    var sheetFor by remember { mutableStateOf<String?>(null) }
    var giftUntil by rememberSaveable { mutableStateOf<Double?>(null) }

    // A relaunch mid-flow picks it up where it stopped (iOS dashboard .onAppear).
    // Keyed on the live list: the children snapshot can land after the household's.
    LaunchedEffect(state.children.map { it.id }) {
        if (!firstChild || busy || childID != null || !ParentOnboarding.isActive(ctx)) return@LaunchedEffect
        val s = FamilyRepository.state.value
        val kid = s.children.firstOrNull { it.id == ParentOnboarding.childID(ctx) } ?: s.orderedChildren.firstOrNull() ?: return@LaunchedEffect
        childID = kid.id; draftName = kid.name; draftGirl = kid.isGirl
        step = when (ParentOnboarding.plan(ctx, kid.id)) {
            "own" -> if (s.devicesOf(kid.id).any { it.shieldAuthorized == true }) Step.DONE else Step.CONNECT
            else -> Step.DEVICE
        }
    }

    val child = state.children.firstOrNull { it.id == childID }
    val name = plainName(child?.name ?: draftName)
    val girl = child?.isGirl ?: draftGirl

    /** "Later" ends the guided flow; the gift (if any) is told first, as iOS does on its way home. */
    fun endLater() {
        if (!firstChild) { onDone(); return }
        val until = GiftWelcome.until(state.household)
        if (until != null && GiftWelcome.isDue(ctx, state.household, insideFlow = true)) { giftUntil = until; step = Step.GIFT }
        else { ParentOnboarding.finish(ctx); onDone() }
    }

    fun create(d: ChildDraft) {
        val afterFailure = error
        busy = true; error = false
        // The flow turns ON at the parent's tap (iOS: when the family is made) —
        // never on a mere composition, which a still-loading existing family can
        // trigger for a frame — and BEFORE the child exists, so AppNav keeps this
        // screen when `children` stops being empty mid-save.
        if (firstChild) ParentOnboarding.begin(ctx)
        scope.launch {
            val id = createOnce(d, afterFailure)
            if (id == null) { busy = false; error = true; return@launch }
            // Set before the next suspension so the resume effect above never races it.
            childID = id; draftName = d.name; draftGirl = d.gender == "girl"
            if (firstChild) ParentOnboarding.setChildID(ctx, id)
            // createChild writes the record's defaults; the level ("developing" is
            // LearningLevel's default raw value) and interests go on as a confirmed merge.
            val extra = mutableMapOf<String, Any?>("learningLevel" to d.learningLevel)
            if (d.interests.isNotEmpty()) extra["interests"] = d.interests
            runCatching { ChildRepository.update(id, extra) }
            busy = false
            step = Step.DEVICE
        }
    }

    BackHandler(enabled = !firstChild && step == Step.CHILD) { onCancel() }
    BackHandler(enabled = !firstChild && step == Step.DEVICE) { onDone() }

    when (step) {
        Step.CHILD -> ChildCreateStep(showSteps = firstChild, busy = busy, error = error, onCancel = if (firstChild) null else onCancel, onSave = ::create)
        Step.DEVICE -> DeviceQuestionScreen(name, girl, showSteps = firstChild, onOwnDevice = {
            val id = childID ?: return@DeviceQuestionScreen
            ParentOnboarding.setPlan(ctx, id, "own")
            if (firstChild) step = Step.CONNECT else sheetFor = id
        }, onPlaysHere = {
            val id = childID ?: return@DeviceQuestionScreen
            ParentOnboarding.setPlan(ctx, id, "here")
            ParentOnboarding.finish(ctx)
            GiftWelcome.markShown(ctx, state.household)
            com.rani.tofy.DeviceRole.startKidMode(id)   // hands this device over now
            onDone()
        }, onLater = ::endLater)
        Step.CONNECT -> OnboardingConnectScreen(childID ?: "", name, girl, onLocked = { step = Step.DONE }, onLater = ::endLater)
        Step.DONE -> OnboardingDoneScreen(name, girl) {
            GiftWelcome.markShown(ctx, state.household)
            ParentOnboarding.finish(ctx)
            onDone()
        }
        Step.GIFT -> GiftWelcomeScreen(giftUntil ?: nowSecs()) {
            GiftWelcome.markShown(ctx, state.household)
            ParentOnboarding.finish(ctx)
            onDone()
        }
    }

    sheetFor?.let { id -> ConnectDeviceSheet(id, onDismiss = { sheetFor = null; onDone() }) }
}

/**
 * createChild, without ever making two of the same child: if a first attempt
 * half-succeeded (the child doc landed, the household's childIDs did not), the
 * child is already in the live list — reuse it and finish the link instead of
 * minting a duplicate (the duplicate-child bug).
 */
private suspend fun createOnce(d: ChildDraft, afterFailure: Boolean): String? {
    fun recent() = FamilyRepository.state.value.children.firstOrNull { it.name.trim() == d.name && nowSecs() - it.createdAt < 600 }
    if (afterFailure) recent()?.let { kid -> return if (linkToHousehold(kid.id)) kid.id else null }
    return runCatching { ChildRepository.createChild(d.name, d.gender, d.grade, d.capMinutes) }.getOrElse {
        FamilyRepository.reassertMembership()
        recent()?.let { kid -> if (linkToHousehold(kid.id)) kid.id else null }
    }
}

private suspend fun linkToHousehold(childID: String): Boolean {
    val hid = FamilyRepository.householdID ?: return false
    if (FamilyRepository.state.value.household?.childIDs?.contains(childID) == true) return true
    return runCatching {
        FirebaseFirestore.getInstance().collection("households").document(hid).update("childIDs", FieldValue.arrayUnion(childID)).await()
    }.isSuccess
}
