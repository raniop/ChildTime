package com.rani.tofy.kid.enforce

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import com.rani.tofy.kid.core.AppleTime
import com.rani.tofy.kid.core.KidEvent
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.ui.KidBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * 🛡 Tofy's guard on a child's Android device — what FamilyControls'
 * ManagedSettingsStore + DeviceActivityMonitor + the shield extension do on iOS.
 *
 * It listens ONLY to "a different window came to the front"
 * (TYPE_WINDOW_STATE_CHANGED) and never reads screen content
 * (canRetrieveWindowContent=false in res/xml/tofy_guard_service.xml). On each
 * change it asks [EnforcementPolicy]; a blocked app is sent home and covered
 * by [GuardOverlay]. It also re-checks when the play window ends, when the
 * parent locks remotely, and on a slow safety tick — a window that runs out
 * while the child is INSIDE a game must close that game too.
 *
 * The foreground package lives in memory only; nothing is stored or sent.
 */
class TofyGuardService : AccessibilityService() {

    companion object {
        /** The connected guard (null when off) — EnforcementStatus.isRunning. */
        @Volatile var instance: TofyGuardService? = null
            private set
    }

    private val main = Handler(Looper.getMainLooper())
    private var scope: CoroutineScope? = null
    private var foreground: String? = null
    private var overlay: GuardOverlay? = null
    /** Throttle for GLOBAL_ACTION_HOME so a relaunching app can't make us loop. */
    private var lastHomeAt = 0L
    private val activityCache = object : LinkedHashMap<String, Boolean>(64, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Boolean>?) = size > 200
    }
    private val endCheck = Runnable { recheck("windowEnd") }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        AllowList.invalidate()
        overlay = GuardOverlay(this, onOpenTofy = ::openTofy, onDismiss = ::dismissToHome)
        GuardStateSource.ensureBound(this)
        EnforcementStatus.refresh(this, activeOverride = true)
        // The child may already be inside an app: no event has come yet.
        foreground = UsageAccess.foregroundPackage(this)
        val s = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate).also { scope = it }
        s.launch {
            KidSession.events.collect { ev ->
                when (ev) {
                    KidEvent.RemoteLock, KidEvent.WindowEnded, KidEvent.WindowTakenByOtherDevice,
                    is KidEvent.GiftRevoked, is KidEvent.ResetApplied, is KidEvent.RemoteUnlock -> recheck("event")
                    // The parent removed this device. The kid UI does this too when it
                    // is open; when it isn't, the binding must still go, or the guard
                    // would keep a device nobody manages locked (and re-bind it).
                    KidEvent.DeviceRemoved -> {
                        KidBinding.init(this@TofyGuardService)
                        KidBinding.disconnected()
                        recheck("removed")
                    }
                    else -> Unit
                }
            }
        }
        // Any window change (opened here, by the parent, from the other device).
        s.launch { KidSession.state.collect { recheck("state") } }
        s.launch { EnforcementStore.version.collect { recheck("settings") } }
        // Safety tick: re-binds after a disconnect/reconnect and re-checks a
        // window whose end alarm was missed (clock change, doze).
        s.launch {
            while (isActive) {
                delay(30_000)
                GuardStateSource.ensureBound(this@TofyGuardService)
                recheck("tick")
            }
        }
        recheck("connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val e = event ?: return
        if (e.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = e.packageName?.toString() ?: return
        val cls = e.className?.toString()
        if (!isForegroundChange(pkg, cls)) return
        foreground = pkg
        recheck("window")
    }

    /**
     * Window-state events also fire for the keyboard, the notification shade,
     * toasts, popups — and our own lock card. Only a real Activity (or, for
     * packages we can't resolve, anything that isn't an obvious widget window)
     * counts as "this app is now in front".
     */
    private fun isForegroundChange(pkg: String, cls: String?): Boolean {
        if (pkg == "com.android.systemui" || pkg == "android") return false
        if (cls == null) return pkg != packageName
        // Our own lock card (and dialogs) are not "Tofy came to the front" — only our activities are.
        if (pkg == packageName) return isActivity(pkg, cls)
        if (isActivity(pkg, cls)) return true
        // A package we can't resolve (e.g. the in-call screen, not launchable):
        // anything but an obvious keyboard / popup / toast window counts.
        val widgety = cls.startsWith("android.widget.") || cls.startsWith("android.view.") ||
            cls.startsWith("android.app.Dialog") || cls.contains("PopupWindow") || cls.contains("Toast") ||
            cls.startsWith("android.inputmethodservice.")
        return !widgety
    }

    private fun isActivity(pkg: String, cls: String): Boolean = synchronized(activityCache) {
        val key = "$pkg/$cls"
        // NameNotFound = not an activity (or a package we can't see) — callers decide.
        activityCache[key] ?: runCatching { packageManager.getActivityInfo(ComponentName(pkg, cls), 0); true }
            .getOrDefault(false)
            .also { activityCache[key] = it }
    }

    /** Ask the policy about what's in front (and what the card covers), and act. */
    private fun recheck(@Suppress("UNUSED_PARAMETER") why: String) {
        val ov = overlay ?: return
        val now = AppleTime.nowUnix()
        val sys = AllowList.system(this)
        val state = GuardStateSource.current(this, now)

        // A card that is up: still needed?
        ov.coveringPackage?.let { covered ->
            if (EnforcementPolicy.shouldDismissOverlay(covered, foreground, now, state, sys)) ov.hide()
        }

        val fg = foreground
        val verdict = EnforcementPolicy.decide(fg, now, state, sys)
        if (verdict.block && fg != null) {
            sendHome()
            val copy = GuardStateSource.lockCopy(verdict, now)
            if (ov.coveringPackage == null) ov.show(fg, copy) else ov.update(copy)
        } else if (ov.isShowing) {
            ov.coveringPackage?.let { ov.update(GuardStateSource.lockCopy(EnforcementPolicy.decide(it, now, state, sys), now)) }
        }
        scheduleWindowEnd(now)
    }

    /** Re-check one second after the open window's end, even if no event comes. */
    private fun scheduleWindowEnd(now: Double) {
        main.removeCallbacks(endCheck)
        val inSecs = GuardStateSource.windowEndsIn(now) ?: return
        main.postDelayed(endCheck, (inSecs * 1000).toLong() + 1_000)
    }

    /** Pause the covered app (audio, video) by leaving it — the card stays on top. */
    private fun sendHome() {
        val t = System.currentTimeMillis()
        if (t - lastHomeAt < 1_500) return
        lastHomeAt = t
        performGlobalAction(GLOBAL_ACTION_HOME)
    }

    private fun openTofy() {
        overlay?.hide()
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            runCatching { startActivity(it) }
        }
    }

    private fun dismissToHome() {
        overlay?.hide()
        foreground = null
        performGlobalAction(GLOBAL_ACTION_HOME)
    }

    override fun onInterrupt() = Unit

    override fun onUnbind(intent: Intent?): Boolean {
        // Switched off in Settings (or the app is being updated): tell the parents.
        tearDown(reportOff = true)
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        tearDown(reportOff = false)
        super.onDestroy()
    }

    private fun tearDown(reportOff: Boolean) {
        main.removeCallbacks(endCheck)
        overlay?.hide(); overlay = null
        scope?.cancel(); scope = null
        if (instance === this) instance = null
        // Re-read Settings rather than assume: an app update also unbinds us.
        if (reportOff) main.postDelayed({ EnforcementStatus.refresh(applicationContext) }, 1_500)
    }
}
