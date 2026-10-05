package com.rani.tofy.kid.enforce

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.rani.tofy.kid.core.AppleTime
import com.rani.tofy.kid.core.DayMath
import com.rani.tofy.kid.core.KidIdentity
import com.rani.tofy.kid.core.KidPersistence
import com.rani.tofy.kid.core.KidSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import java.time.ZoneId

/**
 * Is the lock on, and what does the device row say about it.
 *
 * iOS reports `shieldAuthorized` (Screen Time approved) on childDevices/{row};
 * the parent's dashboard warns while it is false, the "waiting for the lock"
 * onboarding screen ends when it turns true, and the server pushes the parents
 * "🔓 הנעילה של טופי כובתה…" when it flips true → false. On Android the same
 * flag means "Tofy's accessibility guard is switched on in Settings".
 */
object EnforcementStatus {

    /** The guard is switched on in Settings → Accessibility (what we report). */
    fun isActive(ctx: Context): Boolean = isServiceEnabled(ctx)

    /** The guard's process is connected right now (diagnostics; lags [isActive] at start-up). */
    val isRunning: Boolean get() = TofyGuardService.instance != null

    fun isServiceEnabled(ctx: Context): Boolean = runCatching {
        val on = Settings.Secure.getInt(ctx.contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 0) == 1
        if (!on) return false
        val list = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val me = ComponentName(ctx, TofyGuardService::class.java)
        list.split(':').any { ComponentName.unflattenFromString(it.trim()) == me }
    }.getOrDefault(false)

    // ── reporting ────────────────────────────────────────────────────────────
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var lastWritten: Pair<String, Boolean>? = null

    /**
     * Put the current state on KidSession (so every heartbeat carries it) and,
     * when it CHANGED, write it to our device row now — the parent's push must
     * not wait for the child to open Tofy (the heartbeat pauses in background).
     * Only on a managed child device; a parent phone never reports a lock.
     */
    fun refresh(ctx: Context, activeOverride: Boolean? = null) {
        val cid = GuardStateSource.childID(ctx) ?: return
        val active = activeOverride ?: isActive(ctx)
        KidSession.shieldAuthorized = active
        // Android's guard covers apps installed later by construction (iOS lockEverythingNew).
        KidSession.newAppsLocked = active
        if (lastWritten == cid to active) return
        writeRow(cid, active)
    }

    /** Merge just the flags + the identity fields every row write carries (KidSync.reportTimeState). */
    private fun writeRow(cid: String, active: Boolean) {
        scope.launch {
            repeat(2) { attempt ->
                val hid = KidSession.childDoc.value?.get("householdID") as? String
                if (hid.isNullOrEmpty()) { delay(5_000); return@repeat }
                val me = KidIdentity.installID
                val data = hashMapOf<String, Any?>(
                    "shieldAuthorized" to active, "newAppsLocked" to active,
                    "childID" to cid, "householdID" to hid, "deviceID" to me,
                )
                val ok = withTimeoutOrNull(8_000) {
                    runCatching {
                        FirebaseFirestore.getInstance().collection("childDevices").document("${cid}_$me")
                            .set(data, SetOptions.merge()).await()
                    }.isSuccess
                } ?: false
                if (ok) { lastWritten = cid to active; return@launch }
                if (attempt == 0) delay(3_000)
            }
            // Not confirmed: the next heartbeat carries KidSession.shieldAuthorized anyway.
        }
    }
}

/** Builds [GuardState] from the device role, KidSession and [EnforcementStore]. */
internal object GuardStateSource {

    /** The child this device enforces for: a CHILD device, bound, not Kid Mode. */
    fun childID(ctx: Context): String? {
        val p = ctx.applicationContext.getSharedPreferences("tofy", Context.MODE_PRIVATE)
        if (p.getString("deviceRole", null) != "CHILD") return null
        if (p.getString("kidModeChildID", null) != null) return null
        return p.getString("joinedChildID", null)
    }

    /**
     * After a reboot the guard starts the process before anyone opens Tofy. Bind
     * the session so the parent's remote lock / unlock and the window's end keep
     * working — then pause the heartbeat at once: the child is NOT "in Tofy now".
     */
    fun ensureBound(ctx: Context) {
        val cid = childID(ctx) ?: return
        if (KidSession.boundChildID != null) return
        runCatching {
            KidSession.init(ctx)
            KidSession.bind(cid, kidMode = false)
            KidSession.onBackground()
        }
    }

    fun current(ctx: Context, now: Double): GuardState {
        val cid = childID(ctx) ?: return GuardState(managed = false)
        return GuardState(
            managed = true,
            windowOpen = windowOpen(ctx, cid, now),
            openByDesign = EnforcementStore.openByDesign(ctx),
            temporaryAllowed = EnforcementStore.temporaryAllowed(ctx),
            temporaryEndsAt = EnforcementStore.temporaryEndsAt(ctx),
        )
    }

    private fun windowOpen(ctx: Context, cid: String, now: Double): Boolean {
        val e = KidSession.engine()
        if (e != null && KidSession.boundChildID == cid && !KidSession.kidMode) return e.isUnlocked && !e.unlockBudgetExhausted
        // Not bound (yet): the window KidSession last saved for this child.
        val raw = ctx.applicationContext.getSharedPreferences("tofy.kid.state", Context.MODE_PRIVATE).getString(cid, null) ?: return false
        val end = KidPersistence.decode(raw)?.second?.unlockEndsAt ?: return false
        return end > now
    }

    /** Seconds until the open window ends (for the re-check alarm), or null. */
    fun windowEndsIn(now: Double): Double? {
        val e = KidSession.engine() ?: return null
        val end = e.local.unlockEndsAt ?: return null
        return (end - now).takeIf { it > 0 }
    }

    data class LockCopy(val mode: LockMode, val name: String, val girl: Boolean, val minutes: Int, val batchAnswers: Int, val batchMinutes: Int)

    /** ShieldBridge.refresh(): what the lock screen should say. */
    fun lockCopy(verdict: Verdict, now: Double): LockCopy {
        val doc = KidSession.childDoc.value
        val name = (doc?.get("name") as? String)?.trim().orEmpty()
        val girl = doc?.get("gender") == "girl"
        val e = KidSession.engine()
        if (e == null) return LockCopy(EnforcementPolicy.lockMode(verdict, false, 0, 0, 0), name, girl, 0, 10, 4)
        val snap = e.snapshot
        val earnedToday = if (DayMath.usedToday(snap.dailyEarnedDate, AppleTime.fromUnix(now), ZoneId.systemDefault())) snap.minutesEarnedToday else 0
        val cap = e.settings.dailyCap
        val pending = maxOf(0, e.pendingMinutes)
        val mode = EnforcementPolicy.lockMode(verdict, cap.enabled, cap.max, earnedToday, pending)
        return LockCopy(mode, name, girl, pending, maxOf(1, e.settings.batchAnswers), maxOf(1, e.settings.batchMinutes))
    }
}
