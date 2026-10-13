package com.rani.tofy.kid.core

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.firebase.auth.FirebaseAuth
import com.rani.tofy.DeviceRole
import com.rani.tofy.data.Child
import com.rani.tofy.data.Household
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.KidBinding

/**
 * 🎬 First run (Rani, 2026-10-12 — the same as iOS `DemoTour`): a parent who has
 * just installed Tofy lands straight on Tofy Time's questions. The first right
 * answer and the first wrong one are explained by Tofy himself; after four
 * answers they are asked whether to create a family — "ליצור משפחה" or "להמשיך
 * לשחק" — and, if they play on, again every five.
 *
 * 2026-10-13, as on iOS: ✕ on the quiz is not the way out — it leads to the
 * made-up child's HOME, under a band that keeps the two ways to a real family
 * on screen. There ⚙️ opens the language, and the minutes, the gift and the
 * code at the bottom open nothing: a tap explains what the three are.
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
    /** ✕ was pressed on the quiz: the made-up child's home is showing. */
    var onHome by mutableStateOf(false); private set
    /** Bumped when the language changes on the quiz: the round starts over in it. */
    var round by mutableIntStateOf(0); private set

    /** The invitation to sign up, and what brought it up. */
    enum class Invite { BAND, CLOSED }
    var invite by mutableStateOf<Invite?>(null)
    /** The three things under the child's home — a tap on one explains all three. */
    enum class Key { MINUTES, GIFT, CODE }
    var explaining by mutableStateOf<Key?>(null)
    var showLanguages by mutableStateOf(false)
    /** "תרשום שם סתם 30 דקות" (Rani) — shown, never credited to anyone. */
    const val GIFT_MINUTES_SHOWN = 30

    /** The made-up child (the same one the iOS first run plays as): כיתה א׳. */
    fun child(): Child = Child.from(CHILD_ID, mapOf("name" to tr("יואב"), "gender" to "boy", "grade" to 1, "character3DID" to "lion"))
    /** Every world is open in the first run — there is nothing to sell before a family exists. */
    val household: Household by lazy { Household.from("FIRST-RUN-FAMILY", mapOf("premiumUntil" to 4102444800.0)) }

    fun leaveQuizToHome() { if (!isOn) return; asking = false; onHome = true }
    /** Before something only a real family can do: opens the invitation; true = stop there. */
    fun refuse(): Boolean { if (!isOn) return false; invite = Invite.CLOSED; return true }
    fun explain(key: Key): Boolean { if (!isOn) return false; explaining = key; return true }
    fun openLanguages(): Boolean { if (!isOn) return false; showLanguages = true; return true }
    /** A new language: the quiz starts over in it, and Tofy explains again. */
    fun languageChanged() {
        if (!isOn || onHome) return
        asking = false; answered = 0; explainedRight = false; explainedWrong = false; round++
    }
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
        onHome = false; invite = null; explaining = null; showLanguages = false
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
        asking = false; onHome = false; invite = null; explaining = null; showLanguages = false
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
