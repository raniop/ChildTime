package com.rani.tofy.ui.activity

import com.rani.tofy.ui.common.contentColumn

import android.text.format.DateFormat
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.rani.tofy.data.ActivityStore
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.FamilyState
import com.rani.tofy.data.nowSecs
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.*
import com.rani.tofy.ui.theme.*
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.ceil
import kotlin.math.roundToInt

/**
 * 🔔 ActivityCenterView.swift — everything that happened lately around the
 * children, grouped by day, newest first, with the standing notices ("מטופי")
 * on top. Opening it clears the bell's badge, but the dots that show what was
 * new stay while the parent reads.
 */
@Composable
fun ActivityScreen(onBack: () -> Unit) {
    LaunchedEffect(Unit) { ActivityStore.start() }
    BackHandler(onBack = onBack)
    val items by ActivityStore.items.collectAsState()
    val fam by FamilyRepository.state.collectAsState()
    // Freeze what was unread BEFORE clearing the badge.
    val readMark = remember { ActivityStore.readAt.value }
    LaunchedEffect(Unit) { ActivityStore.markRead() }

    val ctx = LocalContext.current
    var notifOn by remember { mutableStateOf(notificationsOn(ctx)) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { notifOn = notificationsOn(ctx) }
    val askNotifications = rememberNotificationsAsk { notifOn = notificationsOn(ctx) }
    val offers = offers(fam, notifOn)
    val days = remember(items, I18n.language) { group(items) }
    val kids = fam.children.associateBy { it.id }

    GlassBackdrop {
        Column(Modifier.contentColumn().fillMaxSize().systemBarsPadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(44.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f)).clickable(onClick = onBack), contentAlignment = Alignment.Center) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, tr("חזרה"), tint = Color.White)
                }
                H(tr("עדכונים"), 19, Modifier.weight(1f).padding(horizontal = 10.dp), align = TextAlign.Center)
                Spacer(Modifier.size(44.dp))
            }

            if (days.isEmpty() && offers.isEmpty()) {
                Column(
                    Modifier.fillMaxSize().padding(horizontal = 32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically),
                ) {
                    Text("🔔", fontSize = 54.sp)
                    H(tr("אין עדכונים חדשים"), 20, align = TextAlign.Center)
                    P(tr("כאן יופיע כל מה שקורה אצל הילדים: כל התראה ששלחנו לכם, סבב שהסתיים ודקות שהורווחו, מטלה שמחכה לאישור שלכם, דקות מתנה ונעילה מרחוק, הישגים כמו רצף ועליית רמה, מכשיר שהצטרף למשפחה, ותשובה מצוות טופי."),
                        14f, align = TextAlign.Center)
                }
                return@Column
            }

            LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (offers.isNotEmpty()) {
                    item { Header(tr("מטופי")) }
                    item {
                        Column(Modifier.fillMaxWidth().glassPane(18.dp)) {
                            offers.forEachIndexed { i, o ->
                                if (i > 0) RowDivider()
                                OfferRow(o, if (o.id == "offer.notifications") askNotifications else null)
                            }
                        }
                    }
                }
                if (days.isEmpty()) item {
                    P(tr("עוד אין פעילות להראות. ברגע שהילדים יתחילו לשחק, הכל יופיע כאן."), 13f,
                        Modifier.fillMaxWidth().padding(vertical = 10.dp), align = TextAlign.Center)
                }
                days.forEach { (title, rows) ->
                    item(key = "h-$title") { Header(title) }
                    item(key = "d-$title") {
                        Column(Modifier.fillMaxWidth().glassPane(18.dp)) {
                            rows.forEachIndexed { i, it ->
                                if (i > 0) RowDivider()
                                FeedRow(it, kids[it.childID ?: ""], it.at > readMark)
                            }
                        }
                    }
                }
                item {
                    P(tr("מוצגים כאן העדכונים מהשבועיים האחרונים. הם נשארים בתוך המשפחה שלכם בלבד."), 12f,
                        Modifier.fillMaxWidth().padding(vertical = 10.dp), color = Ink.tertiary, align = TextAlign.Center)
                }
            }
        }
    }
}

/** The bell's badge: rows newer than the parent's last visit (offers never count). */
@Composable
fun unreadActivityCount(): Int {
    LaunchedEffect(Unit) { ActivityStore.start() }
    return ActivityStore.unread.collectAsState().value
}

@Composable
private fun Header(text: String) =
    Text(text, Modifier.padding(start = 6.dp, top = 6.dp), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp)

@Composable
private fun RowDivider() = Box(Modifier.fillMaxWidth().padding(start = 70.dp).height(1.dp).background(Color.White.copy(alpha = 0.12f)))

@Composable
private fun FeedRow(item: ActivityStore.Item, child: com.rani.tofy.data.Child?, unread: Boolean) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 11.dp), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        // The child's own portrait when the row is about a child, else the kind's emoji on a glass disc.
        if (child != null) {
            Box(Modifier.size(44.dp)) {
                ChildAvatar(child, 40.dp)
                Box(Modifier.align(Alignment.BottomEnd).clip(CircleShape).background(Color.Black.copy(alpha = 0.45f)).padding(3.dp)) {
                    Text(item.kind.emoji, fontSize = 11.sp)
                }
            }
        } else EmojiDisc(item.kind.emoji, gold = false)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            val name = child?.name ?: item.childName
            if (!name.isNullOrEmpty()) Text(name, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp)
            Text(item.title, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            item.detail?.let { P(it, 13f, maxLines = 3) }
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(timeOf(item.at), color = Ink.tertiary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 12.sp)
            if (unread) Box(Modifier.size(8.dp).clip(CircleShape).background(Ink.good))
        }
    }
}

@Composable
private fun EmojiDisc(emoji: String, gold: Boolean) =
    Box(
        Modifier.size(44.dp).clip(CircleShape)
            .background(if (gold) Color(0xFFFFD23F).copy(alpha = 0.28f) else Color.White.copy(alpha = 0.18f))
            .border(1.dp, if (gold) Color(0xFFFFEBAA).copy(alpha = 0.6f) else Color.White.copy(alpha = 0.26f), CircleShape),
        contentAlignment = Alignment.Center,
    ) { Text(emoji, fontSize = 20.sp) }

// MARK: standing notices (ActivityOffers)

private data class Offer(val id: String, val emoji: String, val title: String, val detail: String?, val gold: Boolean)

@Composable
private fun OfferRow(o: Offer, onClick: (() -> Unit)?) {
    Row(
        Modifier.fillMaxWidth().then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier).padding(horizontal = 14.dp, vertical = 11.dp),
        verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        EmojiDisc(o.emoji, o.gold)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(o.title, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
            o.detail?.let { P(it, 13f) }
        }
        if (onClick != null) Chevron()
    }
}

/**
 * ActivityOffers.current, minus what Android can't act on yet (the paywall,
 * the Tofy+ upsell, the activation journey): a child's own request first, the
 * gift journey / Tofy+ status, then notifications being off.
 */
private fun offers(fam: FamilyState, notificationsOn: Boolean): List<Offer> {
    val out = mutableListOf<Offer>()
    val hh = fam.household
    val buyNote = tr("הרכישה נעשית במכשיר של הילד, עם קוד ההורים")
    premiumAskers(fam).takeIf { it.isNotEmpty() }?.let { out += Offer("offer.premiumRequest", "👑", premiumAskTitle(it), buyNote, true) }
    packAskers(fam).forEach { (c, emoji, name) -> out += Offer("offer.pack.${c.id}", emoji, tr("%@ רוצה את %@", c.name, name), buyNote, false) }

    val now = nowSecs()
    val giftUntil = if (hh?.premiumSource == "gift") hh.giftUntil ?: hh.premiumUntil else null
    if (giftUntil != null && giftUntil > now) {
        val days = maxOf(0, ceil((giftUntil - now) / 86_400).toInt())
        if (days > 7) {
            out += Offer("offer.gift", "🎁", tr("טופי+ במתנה — עוד %lld ימים", days), tr("כל העולמות פתוחים עד %@. בלי כרטיס, לא מתחדש.", shortDate(giftUntil)), true)
        } else {
            val star = fam.children.mapNotNull { c -> fam.progress[c.id] }.maxByOrNull { it.totalAnswered }
            val detail = if (star != null && star.totalAnswered > 0) {
                val worlds = star.topicAnswered.values.count { it > 0 }
                val accuracy = (star.totalCorrect.toDouble() / star.totalAnswered * 100).roundToInt()
                tr("%lld עולמות · %lld שאלות · %lld%% הצלחה — אפשר להשאיר הכל פתוח", worlds, star.totalAnswered, accuracy)
            } else tr("אפשר להשאיר את כל העולמות פתוחים")
            out += Offer("offer.gift", "🎁", tr("המתנה מסתיימת ב-%@", shortDate(giftUntil)), detail, true)
        }
    } else if (hh?.isPremium == true) {
        out += Offer("offer.tofyPlus", "👑", tr("טופי+ פעיל"), tr("לכל המשפחה · ניהול המנוי"), true)
    }
    if (!notificationsOn) out += Offer("offer.notifications", "🔕", tr("ההתראות כבויות"), tr("הפעילו כדי לדעת מיד כשמשהו קורה אצל הילדים"), false)
    return out
}

// MARK: dates (ActivityDay)

private fun locale() = Locale(I18n.language.code)

private fun fmt(skeleton: String, t: Double): String =
    SimpleDateFormat(DateFormat.getBestDateTimePattern(locale(), skeleton), locale()).format(Date((t * 1000).toLong()))

private fun timeOf(t: Double) = fmt("jmm", t)
private fun shortDate(t: Double) = fmt("dMMMM", t)

private fun dayKey(t: Double): String {
    val c = Calendar.getInstance().apply { timeInMillis = (t * 1000).toLong() }
    return "${c.get(Calendar.YEAR)}-${c.get(Calendar.DAY_OF_YEAR)}"
}

/** Newest-first rows → day sections ("היום" / "אתמול" / a date), newest day first. */
private fun group(items: List<ActivityStore.Item>): List<Pair<String, List<ActivityStore.Item>>> {
    val now = nowSecs()
    val today = dayKey(now)
    val yesterday = dayKey(now - 86_400)
    val buckets = LinkedHashMap<String, MutableList<ActivityStore.Item>>()
    for (it in items) buckets.getOrPut(dayKey(it.at)) { mutableListOf() } += it
    return buckets.map { (key, rows) ->
        val title = when (key) {
            today -> tr("היום")
            yesterday -> tr("אתמול")
            else -> fmt("EEEEdMMMM", rows.first().at)
        }
        title to rows
    }
}
