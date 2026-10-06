package com.rani.tofy.ui.common

import android.content.Context
import android.content.SharedPreferences
import android.view.HapticFeedbackConstants
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.absoluteOffset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.FirebaseApp
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.delay
import kotlin.math.roundToInt

/**
 * 🧭 CoachMarks.swift for Compose — a first-run tour: one stop per button, in
 * order, on the REAL screen. Rani asked for it on Android too: "למה לא היה לי
 * הדרכה שעשינו כמו באפל? שזה עובר כפתור כפתור ומסביר?"
 *
 * How it fits together, exactly like iOS:
 *  * A control marks itself with `Modifier.coachMark("p.bell")`. That publishes
 *    its bounds, so the tour never needs to know where anything is laid out —
 *    on a phone, a tablet or the Duo it points at what is really there. Inside
 *    a LazyColumn / LazyVerticalGrid the mark lives and dies with its item.
 *  * The screen hosts one `CoachTour(steps, active, onFinish)`. A stop whose
 *    control is not on screen right now (no device yet, below the fold, a
 *    feature this family does not have) is simply skipped.
 *  * Each tour runs ONCE per key, and can be replayed from the parent's
 *    settings (`CoachTours.reset()`).
 *
 * The overlay is laid out left-to-right on purpose: anchors are physical
 * pixels, and an RTL parent would mirror every offset we compute — the same
 * trap iOS warns about. The card's own text is set back to the app's direction.
 */
data class CoachStep(val id: String, val title: String, val text: String)

/** Every marked control's bounds, in root (window) pixels. */
class CoachMarkRegistry internal constructor() {
    internal val marks = mutableStateMapOf<String, Rect>()
}

private val globalCoachMarks = CoachMarkRegistry()

/** One registry for the app — the parent's home and a child's home never share a screen. */
val LocalCoachMarks = staticCompositionLocalOf { globalCoachMarks }

/**
 * Mark this control as a stop on a tour.
 *
 * @param enabled mark only one of a repeated control — the FIRST child's card,
 *   say. Fixed per row, like iOS's `coachMark(_:if:)`.
 */
@Composable
fun Modifier.coachMark(id: String, enabled: Boolean = true): Modifier {
    val reg = LocalCoachMarks.current
    if (!enabled) return this
    DisposableEffect(reg, id) { onDispose { reg.marks.remove(id) } }
    val mark = remember(reg, id) {
        Modifier.onGloballyPositioned { reg.marks[id] = it.boundsInRoot() }
    }
    return this.then(mark)
}

/** Which tours have run, per device (and per child for the kid's) — iOS's UserDefaults keys. */
object CoachTours {
    /** ParentDashboardView.parentTourKey. */
    const val PARENT_HOME = "parentHome.v1"

    /** WorldMapView.kidTourKey(childID). */
    fun kidHome(childID: String) = "kidHome.v1.$childID"

    fun key(tour: String) = "coachTour.done.$tour"

    private fun prefs(): SharedPreferences? = runCatching {
        FirebaseApp.getInstance().applicationContext.getSharedPreferences("tofy", Context.MODE_PRIVATE)
    }.getOrNull()

    fun isDone(tour: String): Boolean = prefs()?.getBoolean(key(tour), false) ?: true

    fun markDone(tour: String) { prefs()?.edit()?.putBoolean(key(tour), true)?.apply() }

    /** "הצגת ההדרכה שוב" — every tour on this device runs again. */
    fun reset() {
        val p = prefs() ?: return
        val e = p.edit()
        p.all.keys.filter { it.startsWith("coachTour.done.") }.forEach { e.remove(it) }
        e.apply()
    }
}

// ── the steps ───────────────────────────────────────────────────────────────

/**
 * ParentDashboardView.parentTourSteps — every control on the home, in the order
 * the eye meets it. Parent copy: no niqqud. `p.chat` is left out: Android has no
 * support chat yet.
 *
 * @param childName already stripped of niqqud by the caller.
 */
fun parentTourSteps(childName: String): List<CoachStep> {
    val name = childName.ifBlank { tr("הילד") }
    return listOf(
        // "מידע נוסף" lives inside the card, which keeps its own anchor from the
        // tour — so the card's stop says where it leads.
        CoachStep("p.card", tr("הכרטיס של %@", name),
            tr("כמה דקות הרוויח היום, כמה שאלות ענה ובכמה צדק. לחיצה על הכרטיס או על \"מידע נוסף\" פותחת את הדוח המלא וההגדרות של הילד.")),
        CoachStep("p.actions", tr("פעולות"),
            tr("מרחוק, בלי לגעת בטלפון שלו: מתנת דקות, נעילה ומטלות.")),
        CoachStep("p.playHere", tr("תנו ל%@ לשחק כאן", name),
            tr("הילד משחק בטלפון שלכם: הכל ננעל חוץ מטופי, והיציאה מוגנת בקוד.")),
        CoachStep("p.connect", tr("חיבור מכשיר"),
            tr("מחברים את הטלפון או האייפד של הילד בסריקת קוד אחת.")),
        CoachStep("p.newChild", tr("ילד נוסף"),
            tr("מוסיפים עוד ילד למשפחה — לכל אחד כיתה וזמן מסך משלו.")),
        CoachStep("p.chores", tr("מטלות"),
            tr("הילד בוחר מטלה בבית, אתם מאשרים, והוא מקבל דקות או כסף.")),
        CoachStep("p.bell", tr("עדכונים"),
            tr("כל מה שקורה אצל הילדים: מה עשו, בקשות שמחכות לכם והודעות שנשלחו.")),
        CoachStep("p.gear", tr("הגדרות"),
            tr("זמן מסך ליום, תגמולים, שפה, ושוב את ההדרכה הזאת.")),
    )
}

/** WorldMapView.kidTourSteps — the child's side: niqqud, and the right form for a boy or a girl. */
fun kidTourSteps(girl: Boolean): List<CoachStep> = listOf(
    CoachStep("k.world", tr("עוֹלָמוֹת"),
        tr("בּוֹחֲרִים עוֹלָם, וְעוֹנִים בּוֹ עַל שְׁאֵלוֹת אוֹ מְשַׂחֲקִים. כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחָה דַּקּוֹת.")),
    CoachStep("k.tofyTime", tr("טוֹפִי טַיים"),
        if (girl) tr("שְׁאֵלוֹת שֶׁטּוֹפִי בּוֹחֵר בִּשְׁבִילֵךְ, מִכָּל הָעוֹלָמוֹת.")
        else tr("שְׁאֵלוֹת שֶׁטּוֹפִי בּוֹחֵר בִּשְׁבִילְךָ, מִכָּל הָעוֹלָמוֹת.")),
    CoachStep("k.games", tr("מִשְׂחָקִים"),
        tr("מִשְׂחָקִים קְצָרִים — נִפְתָּחִים אַחֲרֵי כַּמָּה תְּשׁוּבוֹת נְכוֹנוֹת בַּיּוֹם.")),
    CoachStep("k.minutes", tr("הַדַּקּוֹת"),
        if (girl) tr("כָּאן פּוֹתְחִים אֶת הַדַּקּוֹת שֶׁהִרְוַחְתְּ, וְהַטֶּלֶפוֹן נִפְתָּח.")
        else tr("כָּאן פּוֹתְחִים אֶת הַדַּקּוֹת שֶׁהִרְוַחְתָּ, וְהַטֶּלֶפוֹן נִפְתָּח.")),
    CoachStep("k.wallet", tr("כּוֹכָבִים וִיהַלוֹמִים"),
        tr("כּוֹכָבִים עַל כָּל הַצְלָחָה, וִיהַלוֹמִים לִקְנִיּוֹת בַּחֲנוּת.")),
    CoachStep("k.challenge", tr("אֶתְגַּר יוֹמִי"),
        tr("מְשִׂימָה קְטַנָּה כָּל יוֹם — וּפְרָס כְּשֶׁמְּסַיְּמִים.")),
    CoachStep("k.chores", tr("מְטָלוֹת"),
        tr("עוֹזְרִים בַּבַּיִת וּמַרְוִיחִים — אַבָּא אוֹ אִמָּא מְאַשְּׁרִים.")),
    CoachStep("k.shop", tr("חֲנוּת"),
        tr("קוֹנִים דְּמֻיּוֹת וּבְגָדִים עִם הַיַּהֲלוֹמִים.")),
    CoachStep("k.friends", tr("חֲבֵרִים"),
        tr("טַבְלַת הַחֲבֵרִים, וּמִשְׂחָק חַי בְּיַחַד.")),
    CoachStep("k.settings", tr("לַהוֹרִים"),
        tr("הַהַגְדָּרוֹת שֶׁל אַבָּא וְאִמָּא — נִפְתָּחוֹת רַק עִם קוֹד.")),
)

// ── the overlay ─────────────────────────────────────────────────────────────

/**
 * Run a tour over the screen this sits on, while [active]. [onFinish] fires
 * once, whether the tour ended on its last step or was skipped.
 *
 * Place it as the LAST child of a full-screen Box, so it draws over the screen
 * and under anything modal.
 *
 * @param forKid sets the card's own words with niqqud (the child's side) or
 *   without (the parent's).
 */
@Composable
fun CoachTour(
    steps: List<CoachStep>,
    active: Boolean,
    forKid: Boolean = false,
    onFinish: () -> Unit,
) {
    if (!active) return
    val reg = LocalCoachMarks.current
    val view = LocalView.current
    val density = LocalDensity.current
    val appDir = if (I18n.language.rtl) LayoutDirection.Rtl else LayoutDirection.Ltr

    var origin by remember { mutableStateOf(Offset.Zero) }
    var canvas by remember { mutableStateOf(IntSize.Zero) }
    // The stops that were really on screen when the tour opened — fixed, so the
    // "N מתוך M" counter does not shuffle while the parent reads it.
    var plan by remember { mutableStateOf<List<CoachStep>>(emptyList()) }
    var index by remember { mutableIntStateOf(0) }
    var closed by remember { mutableStateOf(false) }

    fun finish() {
        if (closed) return
        closed = true
        onFinish()
    }

    fun advance() {
        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
        if (index + 1 < plan.size) index++ else finish()
    }

    // One frame is not enough: onGloballyPositioned lands after layout, a lazy
    // list fills in as it measures, and the parent's child card is re-keyed on
    // every 1 s tick. Give the screen a few tries before deciding a stop is not
    // there — a tour wrongly marked done is a tour the parent never sees.
    LaunchedEffect(steps, canvas) {
        if (canvas.height == 0 || plan.isNotEmpty() || closed) return@LaunchedEffect
        val w = canvas.width.toFloat()
        val h = canvas.height.toFloat()
        val need = with(density) { 120.dp.toPx() }
        var previous = -1
        repeat(8) {
            delay(300)
            val live = steps.filter { step ->
                val r = reg.marks[step.id]?.translate(-origin.x, -origin.y) ?: return@filter false
                if (r.width <= 4f || r.height <= 4f) return@filter false
                if (r.right <= 0f || r.left >= w) return@filter false
                // Partly below the fold is fine — the hole is clamped to the screen.
                (minOf(r.bottom, h) - maxOf(r.top, 0f)) >= minOf(r.height * 0.6f, need)
            }
            // Settle first: a list still measuring would hand us two stops out of
            // nine and the parent would get a two-point tour.
            if (live.size == steps.size || (live.isNotEmpty() && live.size == previous)) {
                plan = live
                return@LaunchedEffect
            }
            previous = live.size
        }
        finish()
    }

    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        val source = remember { MutableInteractionSource() }
        Box(
            Modifier
                .fillMaxSize()
                .onGloballyPositioned { origin = it.boundsInRoot().topLeft; canvas = it.size }
                // iOS: a tap anywhere moves on.
                .clickable(interactionSource = source, indication = null) { advance() },
        ) {
            val step = plan.getOrNull(index)
            val now = step?.let { reg.marks[it.id]?.translate(-origin.x, -origin.y) }
            // The parent's child card is re-keyed every second, which unregisters
            // and re-registers its mark inside one frame. Hold the last bounds so
            // the spotlight never blinks across that gap.
            val cached = remember(index) { arrayOfNulls<Rect>(1) }
            if (now != null) cached[0] = now
            val live = now ?: cached[0]

            // The control really went away (scrolled off, a feature closed) — move on.
            if (step != null && now == null) {
                LaunchedEffect(index, step.id) {
                    delay(700)
                    if (reg.marks[step.id] == null) advance()
                }
            }

            if (step != null && live != null && canvas.height > 0) {
                val pad = with(density) { 8.dp.toPx() }
                val wantL = (live.left - pad).coerceIn(0f, canvas.width.toFloat())
                val wantT = (live.top - pad).coerceIn(0f, canvas.height.toFloat())
                val wantR = (live.right + pad).coerceIn(0f, canvas.width.toFloat())
                val wantB = (live.bottom + pad).coerceIn(0f, canvas.height.toFloat())
                val spec = tween<Float>(260)
                val hl by animateFloatAsState(wantL, spec, label = "coachL")
                val ht by animateFloatAsState(wantT, spec, label = "coachT")
                val hr by animateFloatAsState(wantR, spec, label = "coachR")
                val hb by animateFloatAsState(wantB, spec, label = "coachB")
                val hole = Rect(hl, ht, hr, hb)

                Spotlight(hole)

                CoachCard(
                    step = step,
                    hole = hole,
                    canvas = canvas,
                    number = index + 1,
                    total = plan.size,
                    forKid = forKid,
                    appDir = appDir,
                    onNext = { advance() },
                    onSkip = { finish() },
                )
            }
        }
    }
}

/** The screen dimmed, a hole around the control, a soft halo and a gold dashed ring. */
@Composable
private fun Spotlight(hole: Rect) {
    val radius = with(LocalDensity.current) { 16.dp.toPx() }
    // The dim, with the control cut out of it. Offscreen compositing is what
    // makes BlendMode.Clear punch this layer and not the whole screen.
    Canvas(Modifier.fillMaxSize().graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen)) {
        drawRect(Color.Black.copy(alpha = 0.62f))
        drawRoundRect(
            color = Color.Black,
            topLeft = Offset(hole.left, hole.top),
            size = Size(hole.width, hole.height),
            cornerRadius = CornerRadius(radius),
            blendMode = BlendMode.Clear,
        )
    }
    Canvas(Modifier.fillMaxSize()) {
        val halo = 7.dp.toPx()
        drawRoundRect(
            color = Ink.gold2.copy(alpha = 0.22f),
            topLeft = Offset(hole.left - halo, hole.top - halo),
            size = Size(hole.width + halo * 2, hole.height + halo * 2),
            cornerRadius = CornerRadius(radius + halo),
            style = Stroke(width = halo * 2),
        )
        drawRoundRect(
            color = Ink.gold2,
            topLeft = Offset(hole.left, hole.top),
            size = Size(hole.width, hole.height),
            cornerRadius = CornerRadius(radius),
            style = Stroke(
                width = 2.5.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 5.dp.toPx())),
            ),
        )
    }
}

/** The white card: title, the sentence, «הבא» / «סיימנו», "N מתוך M" and «דלג». */
@Composable
private fun CoachCard(
    step: CoachStep,
    hole: Rect,
    canvas: IntSize,
    number: Int,
    total: Int,
    forKid: Boolean,
    appDir: LayoutDirection,
    onNext: () -> Unit,
    onSkip: () -> Unit,
) {
    val density = LocalDensity.current
    val margin = with(density) { 16.dp.toPx() }
    val gap = with(density) { 14.dp.toPx() }
    val cardW = with(density) { minOf(canvas.width - margin * 2, 380.dp.toPx()) }
    // A generous first guess; the card re-places itself once it has measured.
    var cardH by remember { mutableIntStateOf(with(density) { 160.dp.roundToPx() }) }
    val last = number >= total
    val ink = Ink.deep

    // Below the control when there is room, otherwise above it.
    val below = hole.bottom + gap + cardH + margin < canvas.height || hole.center.y < canvas.height / 2f
    val x = (hole.center.x - cardW / 2f).coerceIn(margin, maxOf(margin, canvas.width - cardW - margin))
    val rawY = if (below) hole.bottom + gap else hole.top - gap - cardH
    val y = rawY.coerceIn(margin, maxOf(margin, canvas.height - cardH - margin))

    // The frame is placed in the overlay's left-to-right space; the words inside
    // go back to the app's direction.
    Box(
        Modifier
            .absoluteOffset { IntOffset(x.roundToInt(), y.roundToInt()) }
            .width(with(density) { cardW.toDp() })
            .onSizeChanged { cardH = it.height },
    ) {
        CompositionLocalProvider(LocalLayoutDirection provides appDir) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .shadow(18.dp, RoundedCornerShape(20.dp))
                    .clip(RoundedCornerShape(20.dp))
                    .background(Color.White)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(step.title, color = ink, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 17.sp, lineHeight = 23.sp)
                Text(step.text, color = ink.copy(alpha = 0.82f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, lineHeight = 22.sp)
                Row(
                    Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Box(
                        Modifier
                            .clip(RoundedCornerShape(50))
                            .background(Color(0xFF6C4CF1))
                            .clickable(onClick = onNext)
                            .padding(horizontal = 20.dp, vertical = 9.dp),
                    ) {
                        Text(
                            if (last) (if (forKid) tr("סִיַּמְנוּ") else tr("סיימנו"))
                            else (if (forKid) tr("הַבָּא") else tr("הבא")),
                            color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 15.sp,
                        )
                    }
                    Text(
                        if (forKid) tr("%lld מִתּוֹךְ %lld", number, total) else tr("%lld מתוך %lld", number, total),
                        color = ink.copy(alpha = 0.55f), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp,
                    )
                    Spacer(Modifier.weight(1f))
                    if (!last) Text(
                        if (forKid) tr("דַּלְּגוּ") else tr("דלג"),
                        Modifier.clip(RoundedCornerShape(50)).clickable(onClick = onSkip).padding(horizontal = 8.dp, vertical = 4.dp),
                        color = ink.copy(alpha = 0.55f), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.sp,
                    )
                }
            }
        }
    }
}
