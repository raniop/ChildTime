package com.rani.tofy.kid.ui.play

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import com.rani.tofy.R

/**
 * The game sounds — ChildTime/Audio/SoundLibrary.swift + SoundPlayer.swift.
 * The ten WAVs live in res/raw under their iOS names. SoundPool keeps them
 * decoded so a tap plays instantly (AVAudioPlayer.prepareToPlay on iOS).
 *
 * Mute: iOS gates every sound on the device-level ParentSettings.soundsEnabled
 * (UserDefaults, default ON). Android reads the same key from the app prefs —
 * nothing writes it yet, so sounds are on unless a settings screen turns them off.
 */
enum class AppSound(val res: Int) {
    UI_TAP(R.raw.ui_tap),
    CORRECT_SMALL(R.raw.correct_small),
    CORRECT_BIG(R.raw.correct_big),
    WRONG_SOFT(R.raw.wrong_soft),
    STREAK_UP(R.raw.streak_up),
    PORTAL_APPEAR(R.raw.portal_appear),
    CHEST_OPEN(R.raw.chest_open),
    LEVEL_UP(R.raw.level_up),
    COMPANION_CHEER(R.raw.companion_cheer),
    WORLD_UNLOCK(R.raw.world_unlock),
}

object KidSounds {
    private var pool: SoundPool? = null
    private val ids = HashMap<AppSound, Int>()
    private var app: Context? = null

    /** Idempotent — the runner calls it on entry. */
    fun init(context: Context) {
        if (pool != null) return
        app = context.applicationContext
        val p = SoundPool.Builder()
            .setMaxStreams(6)
            // .ambient + mixWithOthers on iOS: game sounds never stop the child's music.
            .setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            .build()
        AppSound.entries.forEach { ids[it] = p.load(context.applicationContext, it.res, 1) }
        pool = p
    }

    /** ParentSettings.soundsEnabled (default true). */
    val soundsEnabled: Boolean
        get() = app?.getSharedPreferences("tofy", Context.MODE_PRIVATE)?.getBoolean("soundsEnabled", true) ?: true

    fun play(sound: AppSound) {
        if (!soundsEnabled) return
        val p = pool ?: return
        val id = ids[sound] ?: return
        p.play(id, 1f, 1f, 1, 0, 1f)
    }
}

/** Haptic.swift — light / medium / heavy / soft / success / warning on the screen's View. */
class KidHaptics(private val view: View) {
    private fun fire(c: Int) { view.performHapticFeedback(c) }
    fun light() = fire(HapticFeedbackConstants.CLOCK_TICK)
    fun soft() = fire(HapticFeedbackConstants.CLOCK_TICK)
    fun medium() = fire(HapticFeedbackConstants.VIRTUAL_KEY)
    fun heavy() = fire(HapticFeedbackConstants.LONG_PRESS)
    fun success() = fire(if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY)
    fun warning() = fire(if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS)
}
