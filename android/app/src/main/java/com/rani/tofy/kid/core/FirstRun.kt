package com.rani.tofy.kid.core

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.firebase.auth.FirebaseAuth
import com.rani.tofy.DeviceRole
import com.rani.tofy.kid.ui.KidBinding

/**
 * 🎬 First run (Rani, 2026-10-12 — the same as iOS `DemoTour`): a parent who has
 * just installed Tofy lands straight on Tofy Time's questions. The first right
 * answer and the first wrong one are explained by Tofy himself; after four
 * answers they are asked whether to create a child's profile — "ליצור ילד" or
 * "להמשיך לשחק" — and, if they play on, again every five.
 *
 * Nothing of it leaves the phone, and nothing of it stays on it:
 *  1. **No account.** It starts only where no one is signed in — not even a
 *     child device's anonymous user — and never signs in. Every Firestore rule
 *     needs a signed-in user.
 *  2. **No sync.** The session is bound `local`: no listeners, no uploads, no
 *     device row, no play-window lease (`KidSession.localOnly`).
 *  3. **Nothing left.** The made-up child lives under one fixed id whose saved
 *     numbers are removed when the run ends — and before it starts.
 */
object FirstRun {
    /** The made-up child. Not a UUID on purpose: no real child can ever have this id. */
    const val CHILD_ID = "FIRST-RUN"
    const val FIRST_ASK_AFTER = 4
    const val ASK_AGAIN_EVERY = 5
    private const val PREFS = "firstRun"
    private const val DONE = "done"
    private const val SIGN_UP_NEXT = "signUpNext"

    var isOn by mutableStateOf(false); private set
    /** The question itself, over the quiz. */
    var asking by mutableStateOf(false)
    var answered by mutableIntStateOf(0); private set
    private var explainedRight = false
    private var explainedWrong = false

    private fun prefs(ctx: Context) = ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** After the 4th answer, then the 9th, the 14th… */
    fun asks(afterAnswer: Int): Boolean =
        afterAnswer == FIRST_ASK_AFTER || (afterAnswer > FIRST_ASK_AFTER && (afterAnswer - FIRST_ASK_AFTER) % ASK_AGAIN_EVERY == 0)

    /** Only once per install, and only where there is nothing to mix with. */
    fun shouldOpen(ctx: Context): Boolean =
        !isOn && !prefs(ctx).getBoolean(DONE, false)
            && DeviceRole.role == null && DeviceRole.joinedChildID == null && DeviceRole.kidModeChildID == null
            && !KidBinding.state.value.hasSeenWelcome
            && FirebaseAuth.getInstance().currentUser == null

    fun start(ctx: Context) {
        if (!shouldOpen(ctx)) return
        // The welcome pages are what this replaces; leaving the quiz goes
        // straight to "who uses this device".
        KidBinding.markWelcomeSeen()
        KidSession.init(ctx.applicationContext)
        KidSession.forget(CHILD_ID)           // a clean slate: the clock starts at 0:00
        KidSession.bind(CHILD_ID, kidMode = false, local = true)
        answered = 0; asking = false; explainedRight = false; explainedWrong = false
        isOn = true
    }

    /** Called by the quiz for every answer. True the FIRST time it was right
     *  (or wrong): Tofy explains it then, and talks as usual from the second. */
    fun noteAnswer(correct: Boolean): Boolean {
        if (!isOn) return false
        answered++
        val first = if (correct) !explainedRight else !explainedWrong
        if (correct) explainedRight = true else explainedWrong = true
        return first
    }

    /** Out of the first run, with nothing of it left. `signUp` ("ליצור ילד")
     *  leads on to the parent's way in — through the age check, like every other. */
    fun end(ctx: Context, signUp: Boolean) {
        if (!isOn) return
        asking = false
        KidSession.unbind()                   // a local session removes its own saved numbers
        KidSession.forget(CHILD_ID)
        prefs(ctx).edit().putBoolean(DONE, true).putBoolean(SIGN_UP_NEXT, signUp).apply()
        isOn = false
    }

    /** True once, right after "ליצור ילד" — the role picker then goes straight on. */
    fun consumeSignUpNext(ctx: Context): Boolean {
        val p = prefs(ctx)
        if (!p.getBoolean(SIGN_UP_NEXT, false)) return false
        p.edit().remove(SIGN_UP_NEXT).apply()
        return true
    }
}
