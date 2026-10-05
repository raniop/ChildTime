package com.rani.tofy.kid.enforce

import android.content.Context
import android.graphics.PixelFormat
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.CharacterImage
import com.rani.tofy.kid.ui.CloseCircle
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.TofyTheme

/**
 * The screen a child meets when they open a locked app — the Android twin of
 * ShieldConfigurationExtension.swift (same three moods, same words, the
 * child's own name), drawn by the accessibility service as an
 * TYPE_ACCESSIBILITY_OVERLAY window: no "draw over other apps" permission, and
 * it sits above every app window.
 *
 * iOS lets the shield do one thing (dismiss). Here the one button can do what
 * it says — "בּוֹאוּ נַרְוִיחַ דַּקּוֹת" opens Tofy — and the ✕ goes back to the
 * home screen. Never failure language: the app is waiting, not forbidden.
 */
private const val MAX_SHOWN_MS = 20_000L

internal class GuardOverlay(private val ctx: Context, private val onOpenTofy: () -> Unit, private val onDismiss: () -> Unit) {
    private val wm = ctx.getSystemService(WindowManager::class.java)
    private val audio = ctx.getSystemService(AudioManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private var shownAt = 0L
    /**
     * An accessibility overlay sits ABOVE the status bar and the notification
     * shade — so it would hide an incoming call. The lock itself is "send the
     * app home + re-block it the moment it comes back"; the card only explains.
     * So it steps aside for any call and leaves by itself after [MAX_SHOWN_MS].
     */
    private val watchdog = object : Runnable {
        override fun run() {
            if (view == null) return
            val mode = runCatching { audio?.mode }.getOrNull()
            val inCall = mode == AudioManager.MODE_RINGTONE || mode == AudioManager.MODE_IN_CALL ||
                mode == AudioManager.MODE_IN_COMMUNICATION
            if (inCall || System.currentTimeMillis() - shownAt > MAX_SHOWN_MS) { hide(); return }
            main.postDelayed(this, 500)
        }
    }
    private var view: ComposeView? = null
    private var owner: OverlayOwner? = null
    private var copy by mutableStateOf<GuardStateSource.LockCopy?>(null)

    /** The package this card is covering (null = not shown). */
    var coveringPackage: String? = null
        private set
    val isShowing: Boolean get() = view != null

    fun show(pkg: String, c: GuardStateSource.LockCopy) {
        coveringPackage = pkg
        copy = c
        shownAt = System.currentTimeMillis()
        if (view != null) return
        val o = OverlayOwner().also { it.start() }
        val v = ComposeView(ctx).apply {
            setViewTreeLifecycleOwner(o)
            setViewTreeSavedStateRegistryOwner(o)
            setViewTreeViewModelStoreOwner(o)
            setContent { TofyTheme { copy?.let { LockCard(it, onOpenTofy, onDismiss) } } }
        }
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            // Not focusable: no keyboard, and system back/home keep working. It is
            // full-screen and touchable, so the app beneath gets no touches.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            if (Build.VERSION.SDK_INT >= 28) layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        val added = runCatching { wm.addView(v, lp) }.isSuccess
        if (added) { view = v; owner = o; main.post(watchdog) } else { o.stop(); coveringPackage = null }
    }

    fun update(c: GuardStateSource.LockCopy) { if (view != null) copy = c }

    fun hide() {
        main.removeCallbacks(watchdog)
        val v = view ?: return
        runCatching { wm.removeViewImmediate(v) }
        owner?.stop()
        view = null; owner = null; coveringPackage = null
    }
}

@Composable
private fun LockCard(c: GuardStateSource.LockCopy, onOpenTofy: () -> Unit, onDismiss: () -> Unit) {
    val name = c.name
    val (title, subtitle, button, tint) = when (c.mode) {
        LockMode.HAS_MINUTES -> {
            val m = maxOf(1, c.minutes)
            Quad(
                when {
                    name.isEmpty() && c.girl -> tr("יֵשׁ לָךְ %lld דַּקּוֹת", m)
                    name.isEmpty() -> tr("יֵשׁ לְךָ %lld דַּקּוֹת", m)
                    c.girl -> tr("%@, יֵשׁ לָךְ %lld דַּקּוֹת", name, m)
                    else -> tr("%@, יֵשׁ לְךָ %lld דַּקּוֹת", name, m)
                },
                if (c.girl) tr("הִרְוַחְתְּ אוֹתָן — הֵן מְחַכּוֹת בְּטוֹפִי") else tr("הִרְוַחְתָּ אוֹתָן — הֵן מְחַכּוֹת בְּטוֹפִי"),
                tr("בּוֹאוּ נִפְתַּח אוֹתָן"), Color(0xFF2ED6A1),
            )
        }
        LockMode.DAILY_CAP_REACHED -> Quad(
            if (name.isEmpty()) tr("מַסְפִּיק לְהַיּוֹם") else tr("%@, מַסְפִּיק לְהַיּוֹם", name),
            if (c.girl) tr("הִגַּעַתְּ לְכָל הַדַּקּוֹת שֶׁל הַיּוֹם.\nנִתְרָאֶה מָחָר בַּבֹּקֶר") else tr("הִגַּעְתָּ לְכָל הַדַּקּוֹת שֶׁל הַיּוֹם.\nנִתְרָאֶה מָחָר בַּבֹּקֶר"),
            tr("הֵבַנְתִּי"), Color(0xFF5E60CE),
        )
        LockMode.NEEDS_QUESTIONS -> {
            val m = maxOf(1, c.batchMinutes)
            val worth = if (m == 1) tr("דַּקָּה אַחַת") else tr("%lld דַּקּוֹת", m)
            Quad(
                when {
                    name.isEmpty() && c.girl -> tr("עוֹד אֵין לָךְ דַּקּוֹת")
                    name.isEmpty() -> tr("עוֹד אֵין לְךָ דַּקּוֹת")
                    c.girl -> tr("%@, עוֹד אֵין לָךְ דַּקּוֹת", name)
                    else -> tr("%@, עוֹד אֵין לְךָ דַּקּוֹת", name)
                },
                tr(EVERY_N_ANSWERS_KEY, maxOf(1, c.batchAnswers), worth),
                tr("בּוֹאוּ נַרְוִיחַ דַּקּוֹת"), Color(0xFF7A5CFF),
            )
        }
        LockMode.PARENT_ONLY -> Quad(
            tr("הַהַגְדָּרוֹת שֶׁל הַמַּכְשִׁיר שְׁמוּרוֹת לַהוֹרִים 🔐"),
            tr("אַבָּא אוֹ אִמָּא יְכוֹלִים לִפְתּוֹחַ אוֹתָן מִטּוֹפִי, עִם קוֹד הַהוֹרֶה"),
            tr("הֵבַנְתִּי"), Color(0xFF5E60CE),
        )
    }
    // Daily cap / parent-only: there is nothing to do in Tofy about it — the
    // button just closes (iOS: "הֵבַנְתִּי" dismisses).
    val opensTofy = c.mode == LockMode.HAS_MINUTES || c.mode == LockMode.NEEDS_QUESTIONS
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().safeDrawingPadding().padding(horizontal = 28.dp, vertical = 40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
        ) {
            CharacterImage("fox", Modifier.size(132.dp))
            Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 28.sp,
                textAlign = TextAlign.Center, lineHeight = 34.sp)
            Text(subtitle, color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold,
                fontSize = 17.sp, textAlign = TextAlign.Center, lineHeight = 24.sp)
            Box(
                Modifier.padding(top = 10.dp).widthIn(max = 420.dp).fillMaxWidth().clip(RoundedCornerShape(30.dp))
                    .background(Color.White).border(1.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(30.dp))
                    .clickable { if (opensTofy) onOpenTofy() else onDismiss() }
                    .padding(vertical = 17.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(button, color = tint, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp, textAlign = TextAlign.Center)
            }
        }
        Box(Modifier.align(Alignment.TopStart).safeDrawingPadding().padding(16.dp)) { CloseCircle(onDismiss) }
    }
}

/**
 * The iOS key (positional, in the catalog with en/ru/ar). Kept as a constant
 * because tools/android-missing-strings.py can't read Kotlin's `\$` escape
 * inside a translated literal.
 */
private const val EVERY_N_ANSWERS_KEY = "כָּל %1\$lld תְּשׁוּבוֹת נְכוֹנוֹת בְּטוֹפִי = %2\$@ מִשְׂחָק"

private data class Quad(val a: String, val b: String, val c: String, val d: Color)

/** A lifecycle for a ComposeView that lives outside any Activity. */
private class OverlayOwner : LifecycleOwner, SavedStateRegistryOwner, ViewModelStoreOwner {
    private val registry = LifecycleRegistry(this)
    private val saved = SavedStateRegistryController.create(this)
    override val lifecycle: Lifecycle get() = registry
    override val savedStateRegistry: SavedStateRegistry get() = saved.savedStateRegistry
    override val viewModelStore = ViewModelStore()

    fun start() {
        saved.performRestore(null)
        registry.currentState = Lifecycle.State.RESUMED
    }

    fun stop() {
        registry.currentState = Lifecycle.State.DESTROYED
        viewModelStore.clear()
    }
}
