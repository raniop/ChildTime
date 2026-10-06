package com.rani.tofy.kid.ui.home

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.CompositionLocalProvider
import com.rani.tofy.data.Child
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidState
import com.rani.tofy.kid.core.ProgressEngine
import com.rani.tofy.kid.core.RewardEngine
import com.rani.tofy.kid.ui.BottomHint
import com.rani.tofy.kid.ui.BuddyBubble
import com.rani.tofy.kid.ui.CharacterImage
import com.rani.tofy.kid.ui.KidCta
import com.rani.tofy.kid.ui.StatInfoKind
import com.rani.tofy.kid.ui.timeLabel
import com.rani.tofy.ui.common.coachMark
import com.rani.tofy.ui.common.isWideScreen
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.PlatformTextStyle
import com.rani.tofy.ui.home.gradeName
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import com.rani.tofy.ui.theme.glassPane

/** What the bottom panel shows — decided by KidExperience from the engine + lease. */
data class HomeCtaModel(
    /** 💝 openable gift seconds (0 → no gift button). */
    val giftSeconds: Int,
    val opening: Boolean,
    val openingGift: Boolean,
    /** The window is open on another of this child's devices (kind, seconds left) — the transfer card. */
    val peer: Pair<String, Int>?,
    val transferring: Boolean,
    val transferTimedOut: Boolean,
    val canRedeem: Boolean,
    val redeemableSeconds: Int,
    val maxedOut: Boolean,
    val minutesPlayedToday: Int,
    val capMax: Int,
    val pendingMinutes: Int,
    val redeemableMinutes: Int,
    /** 🔒 the child's own code for their minutes (iOS "קוד סודי לדקות שלי"). */
    val hasPlayPin: Boolean = false,
    val showPlayPin: Boolean = false,
)

/** The round-button / twin-card / games-tile / buddy entries of the home (WorldMapView). */
data class HomeExtras(
    /** 🏆 badge: a live-game invite is waiting. */
    val friendsBadge: Boolean = false,
    /** 🎁 on the buddy's head (ProgressStore.dailyChestAvailable). */
    val chestReady: Boolean = false,
    val choresPending: Int = 0,
    val choresDoneToday: Int = 0,
    val choresTotal: Int = 0,
    /** The games' daily warm-up: correct answers today vs the target (גן 5, readers 10). */
    val correctToday: Int = 0,
    val gamesGateTarget: Int = 10,
)

/** The approved kid home (WorldMapView): brand row, the glass header, the world grid, the floating minutes panel. */
@Composable
internal fun KidHome(
    childID: String,
    child: Child?,
    state: KidState,
    engine: ProgressEngine?,
    premium: Boolean,
    kidMode: Boolean,
    tiles: List<HomeTile>,
    cta: HomeCtaModel,
    buddyLine: String?,
    onSettings: () -> Unit,
    onKidExit: () -> Unit,
    onTile: (HomeTile) -> Unit,
    onChallenge: () -> Unit,
    onLevelInfo: () -> Unit,
    onPlayPin: () -> Unit,
    /** ⭐ 💎 ⏱ 💝 and "הרווחת היום" each explain themselves (WorldMapView.infoStat). */
    onStatInfo: (StatInfoKind) -> Unit,
    onOpenEarned: () -> Unit,
    onOpenGift: () -> Unit,
    onTransfer: () -> Unit,
    extras: HomeExtras = HomeExtras(),
    onShop: () -> Unit = {},
    onFriends: () -> Unit = {},
    onAvatar: () -> Unit = {},
    onChores: () -> Unit = {},
    onGames: () -> Unit = {},
    onChest: () -> Unit = {},
    /** The top banner: a friend invited me to a live game. */
    inviteBanner: @Composable () -> Unit = {},
) {
    val snap = state.snapshot
    var panelPx by remember { mutableIntStateOf(0) }
    val density = LocalDensity.current
    val girl = child?.isGirl == true

    GlassBackdrop {
        // A tablet gets a third column, but the whole board stays in a centred
        // 900dp block — stretched across 1280dp the header pane flings the stats
        // to opposite edges and the fox wanders over the cards.
        BoxWithConstraints(Modifier.widthIn(max = 900.dp).fillMaxSize()) {
            val cols = if (maxWidth >= 600.dp) 3 else 2
            val hPad = if (cols == 2) 10.dp else 22.dp
            LazyVerticalGrid(
                GridCells.Fixed(cols),
                Modifier.fillMaxSize().statusBarsPadding(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    start = hPad, end = hPad, bottom = with(density) { panelPx.toDp() } + 16.dp,
                ),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(span = { GridItemSpan(maxLineSpan) }) { BrandRow(premium, extras.friendsBadge, onShop, onFriends, onSettings) }
                item(span = { GridItemSpan(maxLineSpan) }) {
                    HeaderPane(child, snap.stars, snap.diamonds, snap.dayStreak, snap.xp, engine, cta, extras, onLevelInfo, onStatInfo, onChallenge, onAvatar, onChores)
                }
                // Like iOS: the exit bar sits UNDER the header pane, right above the worlds.
                if (kidMode) item(span = { GridItemSpan(maxLineSpan) }) { KidExitBar(onKidExit) }
                item(span = { GridItemSpan(maxLineSpan) }) {
                    // 🧭 The worlds' stop: on a phone the first world sits under the
                    // floating minutes panel, so the tour points at the line that heads
                    // them, which is always in view (iOS marks the same heroTitle).
                    Text(tr("בּוֹחֲרִים עוֹלָם וְיוֹצְאִים לְהַרְפַּתְקָה ✨"), Modifier.fillMaxWidth().padding(top = 6.dp).coachMark("k.world"),
                        color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, textAlign = TextAlign.Center, maxLines = 1)
                }
                items(tiles, key = { it.key }) { t ->
                    when (t) {
                        HomeTile.TofyTime -> FeatureTile("🎲", tr("טוֹפִי טַיים"), tr("שְׁאֵלוֹת בִּמְיוּחָד בִּשְׁבִילְךָ"),
                            Color(0xFF8C7BFF), Modifier.coachMark("k.tofyTime"),
                            badge = tr("✨ חינם"), badgeTint = Color(0xFF8CFFC4)) { onTile(t) }
                        is HomeTile.WorldTile -> {
                            val w = t.world
                            val room = snap.worldProgress[w.id] ?: 0
                            val roomLabel = maxOf(1, minOf(room + 1, w.rooms))
                            val foot = if (!t.open && room > 0)
                                tr("חֶדֶר %lld/%lld · %@ לְהַמְשִׁיךְ?", roomLabel, w.rooms, if (girl) tr("רוֹצָה") else tr("רוֹצֶה"))
                            else tr("חֶדֶר %lld/%lld", roomLabel, w.rooms)
                            val badge = when { t.guest -> tr("🌟 אוֹרֵחַ הַשָּׁבוּעַ"); !t.open -> tr("👑 טוֹפִי+"); else -> null }
                            val subtitle = if (w.isArena) tr("כָּל הַנּוֹשְׂאִים · דַּקּוֹת כְּפוּלוֹת") else w.topic?.displayName ?: ""
                            FeatureTile(w.emoji, w.name, subtitle, w.glow, badge = badge, foot = foot,
                                footFrac = room / maxOf(1, w.rooms).toFloat()) { onTile(t) }
                        }
                    }
                }
                // 🎮 Games LAST in the grid (Rani): learning first, the arcade is dessert.
                // A daily warm-up goal, never a lock — no grey-out, no failure language.
                item(key = "games") {
                    val target = extras.gamesGateTarget
                    val done = minOf(extras.correctToday, target)
                    val open = extras.correctToday >= target
                    FeatureTile(
                        "🎮", tr("מִשְׂחָקִים"),
                        if (open) tr("מֵרוֹץ נָכוֹן/לֹא · הַתְאָמַת זוּגוֹת") else tr("עוֹנִים %lld נְכוֹנוֹת — וְנִפְתָּח! 💪", target),
                        Color(0xFFEF476F), Modifier.coachMark("k.games"),
                        badge = when { !premium -> tr("👑 טוֹפִי+"); open -> null; else -> "$done/$target ✅" },
                        foot = if (open) tr("🎮 פָּתוּחַ הַיּוֹם") else tr("חִמּוּם יוֹמִי"),
                        footFrac = if (open) null else done / maxOf(1, target).toFloat(),
                        onClick = onGames,
                    )
                }
            }

            // The floating minutes panel over a soft scrim — tiles fade out under it.
            // The scrim spans the WHOLE screen width, like the iPad: drawn wider than
            // the centred 900dp column it lives in, so on a tablet it isn't a box
            // with edges (Rani: "הוא לא עד הסוף מגיע כמו באייפד").
            Column(
                Modifier.align(Alignment.BottomCenter).fillMaxWidth()
                    .drawBehind {
                        val extra = 4000f
                        drawRect(
                            Brush.verticalGradient(0f to Color.Transparent, 0.35f to Ink.deep.copy(alpha = 0.72f), 1f to Ink.deep.copy(alpha = 0.9f),
                                startY = 0f, endY = size.height),
                            topLeft = Offset(-extra, 0f), size = Size(size.width + 2 * extra, size.height + extra),
                        )
                    }
                    .navigationBarsPadding()
                    .padding(start = 20.dp, end = 20.dp, top = 40.dp, bottom = 14.dp)
                    .onSizeChanged { panelPx = it.height }
                    // 🧭 The hole goes around the bubble + the CTA, not the scrim's fade.
                    .coachMark("k.minutes"),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                BuddyBubble(buddyLine, Modifier.fillMaxWidth())
                BottomCtas(cta, onOpenEarned, onOpenGift, onTransfer)
                if (cta.showPlayPin) PlayPinChip(cta.hasPlayPin, onPlayPin)
            }

            // The child's buddy roams between the header and the panel; tap → shop, 🎁 → chest.
            val compact = cols == 2
            FloatingBuddy(
                child?.character3DID, extras.chestReady,
                topInset = if (compact) 300.dp else 230.dp,
                bottomInset = with(density) { panelPx.toDp() },
                size = if (compact) 90.dp else 120.dp,
                onTap = onShop, onGift = onChest,
                modifier = Modifier.statusBarsPadding(),
            )

            // 🎮 "You're invited!" drops in at the top for a few seconds.
            Box(Modifier.align(Alignment.TopCenter).fillMaxWidth().statusBarsPadding(), contentAlignment = Alignment.TopCenter) { inviteBanner() }
        }
    }
}

// ── brand row + header ──────────────────────────────────────────────────────

@Composable
private fun BrandRow(premium: Boolean, friendsBadge: Boolean, onShop: () -> Unit, onFriends: () -> Unit, onSettings: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(
            if (premium) tr("טופי+") else tr("טופי"),
            style = TextStyle(
                brush = Brush.verticalGradient(listOf(Color(0xFFFFF6C4), Color(0xFFFFD23F), Color(0xFFFFB347))),
                fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 34.sp,
            ),
        )
        Spacer(Modifier.width(8.dp))
        // Our own lion, head and waving paw only — the top of the full-body PNG.
        Box(Modifier.size(width = 32.dp, height = 39.dp).clip(RoundedCornerShape(6.dp))) {
            CharacterImage("lion", Modifier.fillMaxSize(), contentScale = ContentScale.Crop, alignment = Alignment.TopCenter)
        }
        Spacer(Modifier.weight(1f))
        // Three round glass buttons, no captions (Rani, 2026-09-06): 🛍️ shop · 🏆 friends
        // (the live tournament lives inside; a waiting invite lights the dot) · ⚙️ the
        // parent's corner. Shop and friends are NOT behind Tofy+.
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            NavButton("🛍️", false, Modifier.coachMark("k.shop"), onShop)
            // The parent can switch friends + leaderboards off for this child (child doc friendsEnabled).
            if (com.rani.tofy.kid.ui.social.SocialMe.friendsEnabled) NavButton("🏆", friendsBadge, Modifier.coachMark("k.friends"), onFriends)
            NavButton("⚙️", false, Modifier.coachMark("k.settings"), onSettings)
        }
    }
}

@Composable
private fun NavButton(emoji: String, badge: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(modifier.size(44.dp)) {
        Box(
            Modifier.size(44.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.24f))
                .border(1.dp, Color.White.copy(alpha = 0.32f), CircleShape).clickable(onClick = onClick),
            contentAlignment = Alignment.Center,
        ) { Text(emoji, fontSize = 19.sp) }
        if (badge) Box(
            Modifier.align(Alignment.TopEnd).size(12.dp).clip(CircleShape).background(Color.White).padding(2.dp)
                .clip(CircleShape).background(Color(0xFFFF7A3D)),
        )
    }
}

@Composable
private fun KidExitBar(onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth().padding(top = 4.dp), contentAlignment = Alignment.Center) {
        Row(
            Modifier.clip(RoundedCornerShape(50)).background(Color(0xFFEF4655)).border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(50))
                .clickable(onClick = onClick).padding(horizontal = 22.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp),
        ) {
            Text("🔓", fontSize = 16.sp)
            Text(tr("יְצִיאָה מִמַּצַּב יֶלֶד וְשִׁחְרוּר נְעִילַת הַמַּכְשִׁיר"), color = Color.White, fontFamily = Rounded,
                fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, textAlign = TextAlign.Center)
        }
    }
}

/** StarCounter.currencyShort — 1,284 → "1.2K". */
private fun currencyShort(v: Int): String {
    val a = kotlin.math.abs(v)
    if (a < 1_000) return "$v"
    val sign = if (v < 0) "-" else ""
    fun fmt(x: Double, suf: String): String {
        if (x < 10) { val t = kotlin.math.floor(x * 10) / 10; val s = "%.1f".format(java.util.Locale.US, t); return sign + s.removeSuffix(".0") + suf }
        return sign + x.toInt() + suf
    }
    return if (a < 1_000_000) fmt(a / 1_000.0, "K") else fmt(a / 1_000_000.0, "M")
}

/** ONE glass pane: identity + wallet, the stat strip, then the daily challenge (topBar). */
@Composable
private fun HeaderPane(
    child: Child?, stars: Int, diamonds: Int, dayStreak: Int, xp: Int, engine: ProgressEngine?,
    cta: HomeCtaModel, extras: HomeExtras, onLevelInfo: () -> Unit, onStatInfo: (StatInfoKind) -> Unit, onChallenge: () -> Unit,
    onAvatar: () -> Unit, onChores: () -> Unit,
) {
    // iOS sizes, one set for the phone (compact) and one for the tablet (iPad).
    val compact = !isWideScreen()
    Column(Modifier.fillMaxWidth().padding(top = 6.dp).glassPane(24.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            // The ring says the level tier: bronze from 5, silver from 10, gold from 20.
            val tier = RewardEngine.levelTier(RewardEngine.level(xp))
            val ring = listOf(Color.White.copy(alpha = 0.5f), Color(0xFFCD7F32), Color(0xFFD9D9E3), Color(0xFFFFD23F))[tier]
            CharacterImage(child?.character3DID ?: "fox",
                Modifier.size(if (compact) 52.dp else 60.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f))
                    .border(if (tier == 0) 1.dp else 2.5.dp, ring, CircleShape).clickable(onClick = onAvatar),
                contentScale = ContentScale.Crop)
            Column(Modifier.weight(1f).clickable(onClick = onLevelInfo), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                val first = (child?.name?.takeIf { it.isNotBlank() } ?: tr("טוֹפִי")).split(" ").first()
                // Two fixed lines, so the wallet's numbers sit on the name line and its
                // labels on the grade line (iOS identityBlock / walletStat).
                TightText(first, if (compact) 17f else 20f, if (compact) 22 else 26, Color.White, FontWeight.Black)
                val line = gradeName(child?.effectiveGrade ?: 1) + if (dayStreak > 0) tr(" · 🔥 %lld יָמִים", dayStreak) else ""
                TightText(line, if (compact) 12f else 13f, 16, Ink.secondary, FontWeight.Bold)
            }
            // ⭐ · 💎 beside the name; on a tablet also 💝 gift and ⏱ earned minutes —
            // the iPad header, with no extra row under it (Rani: it sat badly).
            Row(Modifier.coachMark("k.wallet"), horizontalArrangement = Arrangement.spacedBy(if (compact) 12.dp else 18.dp)) {
                WalletStat("⭐ " + currencyShort(stars), tr("כּוֹכָבִים"), compact) { onStatInfo(StatInfoKind.STARS) }
                WalletStat("💎 " + currencyShort(diamonds), tr("יַהֲלוֹמִים"), compact) { onStatInfo(StatInfoKind.DIAMONDS) }
                if (!compact) {
                    WalletStat("💝 ${(engine?.giftSecondsAvailable ?: 0) / 60}", tr("דַּקּ׳ מַתָּנָה"), compact) { onStatInfo(StatInfoKind.GIFT) }
                    WalletStat("⏱ ${engine?.pendingMinutes ?: 0}", tr("דַּקּ׳ לְשַׂחֵק"), compact) { onStatInfo(StatInfoKind.MINUTES) }
                }
            }
        }
        StatsPanel(engine, onLevelInfo, onStatInfo, compact)
        // The twins: אתגר יומי · מטלות הבית — same size, side by side.
        Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            ChallengeCard(engine, onChallenge, Modifier.weight(1f).fillMaxHeight().coachMark("k.challenge"))
            ChoresCard(extras, onChores, Modifier.weight(1f).fillMaxHeight().coachMark("k.chores"))
        }
    }
}

@Composable
private fun WalletStat(value: String, label: String, compact: Boolean, onClick: () -> Unit) {
    Column(Modifier.clip(RoundedCornerShape(10.dp)).clickable(onClick = onClick), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            TightText(value, if (compact) 14.5f else 16f, if (compact) 22 else 26, Color.White, FontWeight.Black)
        }
        TightText(label, if (compact) 11f else 12.5f, 16, Ink.secondary, FontWeight.Bold)
    }
}

/**
 * One line in a box exactly `boxDp` tall, the glyphs centred in it — iOS's
 * `.frame(height:)`. Without it Rubik's own ascent/descent (tall, for niqqud)
 * pushed each number a long way from its label (Rani, on the tablet).
 */
@Composable
private fun TightText(text: String, size: Float, boxDp: Int, color: Color, weight: FontWeight) {
    Box(Modifier.height(boxDp.dp), contentAlignment = Alignment.Center) {
        Text(text, color = color, fontFamily = Rounded, fontWeight = weight, fontSize = size.sp, maxLines = 1,
            overflow = TextOverflow.Ellipsis, style = tightStyle(size))
    }
}

private fun tightStyle(size: Float) = TextStyle(
    lineHeight = (size * 1.2f).sp,
    lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.Both),
    platformStyle = PlatformTextStyle(includeFontPadding = false),
)

/** ⏱ minutes today (of the cap) · ✅ correct today · ⭐ level. */
@Composable
private fun StatsPanel(engine: ProgressEngine?, onLevelInfo: () -> Unit, onStatInfo: (StatInfoKind) -> Unit, compact: Boolean) {
    val snap = engine?.snapshot
    val cap = engine?.settings?.dailyCap
    val minutes = if (cap?.enabled == true) "${snap?.minutesEarnedToday ?: 0}" else "${engine?.pendingMinutes ?: 0}"
    val suffix = if (cap?.enabled == true) "/${cap.max}" else null
    Row(Modifier.fillMaxWidth().glassInset(18.dp).padding(vertical = 13.dp, horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        StatColumn(minutes, suffix, tr("⏱ הִרְוַחְתָּ הַיּוֹם"), { onStatInfo(StatInfoKind.TODAY) }, compact)
        StatDivider()
        StatColumn("${snap?.correctToday ?: 0}", null, tr("✅ נְכוֹנוֹת הַיּוֹם"), { onStatInfo(StatInfoKind.CORRECT) }, compact)
        StatDivider()
        StatColumn("${engine?.companionLevel ?: 1}", null, tr("⭐ רָמָה"), onLevelInfo, compact)
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.StatColumn(value: String, suffix: String?, label: String, onClick: (() -> Unit)?, compact: Boolean) {
    Column(
        Modifier.weight(1f).then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            val big = if (compact) 20f else 24f
            Row(verticalAlignment = Alignment.Bottom) {
                Text(value, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = big.sp, style = tightStyle(big))
                if (suffix != null) {
                    val small = if (compact) 14f else 16f
                    Text(suffix, color = Ink.tertiary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = small.sp,
                        style = tightStyle(small), modifier = Modifier.padding(bottom = 2.dp))
                }
            }
        }
        val labelSize = if (compact) 12f else 13.5f
        Text(label, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = labelSize.sp, maxLines = 1,
            style = tightStyle(labelSize))
    }
}

@Composable
private fun StatDivider() = Box(Modifier.width(1.dp).height(36.dp).background(Color.White.copy(alpha = 0.16f)))

/** The daily challenge twin card: 🔥 ring → title → status → track. */
@Composable
private fun ChallengeCard(engine: ProgressEngine?, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val target = ProgressEngine.DAILY_CHALLENGE_TARGET
    val done = engine?.dailyChallengeProgress ?: 0
    val ready = engine?.dailyChallengeRewardReady == true
    val claimed = engine?.dailyChallengeClaimed == true
    val frac = if (ready || claimed) 1f else minOf(done, target) / target.toFloat()
    val t = rememberInfiniteTransition(label = "pulse")
    val pulse by t.animateFloat(0.95f, 1.12f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "pulse")
    Row(
        modifier.glassInset(16.dp).clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            Modifier.size(40.dp).clip(CircleShape).background(Brush.linearGradient(listOf(Color(0xFFFFB347), Color(0xFFFF5E3A))))
                .border(1.5.dp, Color.White.copy(alpha = 0.55f), CircleShape),
            contentAlignment = Alignment.Center,
        ) { Text("🔥", fontSize = 21.sp, modifier = Modifier.graphicsLayer { scaleX = pulse; scaleY = pulse }) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(tr("אֶתְגָּר יוֹמִי"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 13.5.sp)
            when {
                claimed -> Text(tr("כָּל הַכָּבוֹד! נִפְגָּשִׁים מָחָר 🌙"), color = Color.White.copy(alpha = 0.88f), fontFamily = Rounded,
                    fontWeight = FontWeight.Bold, fontSize = 11.5.sp, maxLines = 1)
                ready -> Text("🎁 " + tr("פִּתְחוּ!"), Modifier.clip(RoundedCornerShape(50)).background(Brush.horizontalGradient(listOf(Ink.gold1, Ink.gold2)))
                    .padding(horizontal = 10.dp, vertical = 3.dp), color = Ink.deep, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 12.sp)
                else -> Text(tr("%lld מִתּוֹךְ %lld", done, target), color = Color.White.copy(alpha = 0.88f), fontFamily = Rounded,
                    fontWeight = FontWeight.Bold, fontSize = 11.5.sp, maxLines = 1)
            }
            Track(frac, Modifier.padding(top = 4.dp))
        }
    }
}

/** choresTopCard — the twin of the challenge: 🧹 ring → title → live line → today's track. */
@Composable
private fun ChoresCard(e: HomeExtras, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val frac = if (e.choresTotal == 0) 0f else e.choresDoneToday / e.choresTotal.toFloat()
    Row(
        modifier.glassInset(16.dp).clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            Modifier.size(40.dp).clip(CircleShape).background(Brush.linearGradient(listOf(Color(0xFF48BFE3), Color(0xFF5E60CE))))
                .border(1.5.dp, Color.White.copy(alpha = 0.55f), CircleShape),
            contentAlignment = Alignment.Center,
        ) { Text("🧹", fontSize = 20.sp) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(tr("מַטְלוֹת הַבַּיִת"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 13.5.sp, maxLines = 1)
            Text(
                when {
                    e.choresPending == 1 -> tr("אַחַת מְחַכָּה")
                    e.choresPending > 1 -> tr("%lld מְחַכּוֹת", e.choresPending)
                    e.choresDoneToday > 0 -> tr("%lld הֻשְׁלְמוּ הַיּוֹם! 💪", e.choresDoneToday)
                    else -> tr("עוֹזְרִים — וּבוֹחֲרִים פְּרָס!")
                },
                color = Color.White.copy(alpha = 0.88f), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 11.5.sp, maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Track(frac, Modifier.padding(top = 4.dp))
        }
    }
}

@Composable
fun Track(frac: Float, modifier: Modifier = Modifier, fill: Color = Color.White) {
    Box(modifier.fillMaxWidth().height(10.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.14f))) {
        if (frac > 0f) Box(Modifier.fillMaxWidth(frac.coerceIn(0.06f, 1f)).height(10.dp).clip(RoundedCornerShape(50)).background(fill))
    }
}

// ── tiles ───────────────────────────────────────────────────────────────────

/** WorldCard / FeatureCard: a glass tile with a whisper of the world's own colour. */
@Composable
private fun FeatureTile(
    emoji: String, title: String, subtitle: String, tint: Color, modifier: Modifier = Modifier,
    badge: String? = null, badgeTint: Color? = null, foot: String? = null, footFrac: Float? = 0f, onClick: () -> Unit,
) {
    Column(
        modifier.fillMaxWidth().heightIn(min = 158.dp).clip(RoundedCornerShape(22.dp))
            .drawBehind { drawCircle(tint.copy(alpha = 0.38f), radius = size.width * 0.75f, center = Offset(size.width * 0.15f, 0f)) }
            .glassPane(22.dp, 0.13f).clickable(onClick = onClick).padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Text(emoji, fontSize = 32.sp)
            Spacer(Modifier.weight(1f))
            if (badge != null) Text(
                badge,
                Modifier.clip(RoundedCornerShape(50)).background(badgeTint?.copy(alpha = 0.9f) ?: Color.White.copy(alpha = 0.22f))
                    .padding(horizontal = 8.dp, vertical = 3.dp),
                color = if (badgeTint != null) Ink.deep else Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 10.5.sp, maxLines = 1,
            )
        }
        Spacer(Modifier.height(6.dp))
        Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.5.sp, maxLines = 2, lineHeight = 19.sp)
        Text(subtitle, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.sp, maxLines = 2, lineHeight = 16.sp)
        if (foot != null) {
            Spacer(Modifier.height(8.dp))
            Text(foot, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 11.sp, maxLines = 1)
            if (footFrac != null) Track(footFrac, Modifier.padding(top = 4.dp).height(6.dp))
        }
    }
}

// ── the bottom CTAs ─────────────────────────────────────────────────────────

@Composable
private fun ColumnScope.BottomCtas(c: HomeCtaModel, onOpenEarned: () -> Unit, onOpenGift: () -> Unit, onTransfer: () -> Unit) {
    // 💝 ONE button for everything the PARENTS gave — never blurred with earned minutes.
    if (c.giftSeconds > 0 && c.peer == null) {
        if (c.opening && c.openingGift) KidCta(tr("פּוֹתְחִים לְךָ… ✨"), Color(0xFFFF5FA8), Color(0xFFFFA53A), busy = true) {}
        else KidCta(tr("מַתָּנָה מֵהַהוֹרִים · ") + minutesText(c.giftSeconds),
            Color(0xFFFF5FA8), Color(0xFFFFA53A), emoji = "💝", enabled = !c.opening, size = 19, onClick = onOpenGift)
    }
    val peer = c.peer
    when {
        peer != null -> {
            val where = when (peer.first) { "ipad" -> tr("בָּאַיְפֵּד"); "iphone" -> tr("בָּאַיְפוֹן"); else -> tr("בְּמַכְשִׁיר אַחֵר") }
            val left = maxOf(0, peer.second)
            BottomHint(tr("🎮 הַזְּמַן שֶׁלְּךָ פָּתוּחַ עַכְשָׁיו %@ — נִשְׁאֲרוּ %lld:%@", where, left / 60, "%02d".format(left % 60)))
            if (c.transferTimedOut) BottomHint(tr("לֹא הִצְלַחְנוּ לִנְעֹל %@ עַכְשָׁיו — אוּלַי הוּא כָּבוּי. אֶפְשָׁר לְנַסּוֹת שׁוּב 😊", where))
            if (c.transferring) KidCta(tr("מַעֲבִירִים לְכָאן… ✨"), Color(0xFF5B6CFF), Color(0xFF9B5DE5), busy = true, size = 19) {}
            else KidCta(tr("נַעֲלוּ %@ וּפִתְחוּ כָּאן", where), Color(0xFF5B6CFF), Color(0xFF9B5DE5), emoji = "🔁", size = 19, onClick = onTransfer)
        }
        c.canRedeem -> {
            if (c.opening && !c.openingGift) KidCta(tr("פּוֹתְחִים לְךָ… ✨"), Color(0xFF5E60CE), Color(0xFF3E8BF0), busy = true) {}
            else KidCta(
                if (c.redeemableSeconds % 60 == 0) tr("פִּתְחוּ לִי %lld דַּקּוֹת לְשַׂחֵק", c.redeemableSeconds / 60)
                else tr("פִּתְחוּ לִי %@ דַּקּוֹת לְשַׂחֵק", timeLabel(c.redeemableSeconds)),
                Color(0xFF5E60CE), Color(0xFF3E8BF0),
                emoji = "🎮", enabled = !c.opening, onClick = onOpenEarned)
        }
        c.maxedOut -> BottomHint(tr("שִׂחַקְתָּ הַיּוֹם %lld מִתּוֹךְ %lld דַּקּוֹת 🌙 — %lld שְׁמוּרוֹת לְמָחָר", c.minutesPlayedToday, c.capMax, c.pendingMinutes))
        // Below the 15-min minimum: what they have, where opening starts, how many more —
        // "12 דק' לשחק" above and a bare "עוד 3" here read as a contradiction (Rani).
        c.redeemableMinutes > 0 -> BottomHint(tr("%lld דַּקּ׳ לְשַׂחֵק · פּוֹתְחִים מִ־%lld — עוֹד %lld! 🎮",
            c.redeemableMinutes, ProgressEngine.MINIMUM_UNLOCK_MINUTES, maxOf(0, ProgressEngine.MINIMUM_UNLOCK_MINUTES - c.redeemableMinutes)))
        else -> BottomHint(tr("עֲנוּ עַל שְׁאֵלוֹת כְּדֵי לְהַרְוִיחַ דַּקּוֹת מִשְׂחָק 🎮"))
    }
}

/** "🔓 קוד סודי לדקות שלי" / "🔒 הדקות שלי מוגנות בקוד" — small and discreet, under the buttons. */
@Composable
private fun PlayPinChip(hasPin: Boolean, onClick: () -> Unit) {
    Text((if (hasPin) "🔒 " + tr("הַדַּקּוֹת שֶׁלִּי מוּגָנוֹת בְּקוֹד") else "🔓 " + tr("קוֹד סוֹדִי לַדַּקּוֹת שֶׁלִּי")),
        Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.16f))
            .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(50)).clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
        color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.5.sp, maxLines = 1)
}

/** "16 דַּקּוֹת" / "16:45 דַּקּוֹת" — the gift pocket to the second, never quietly rounded. */
private fun minutesText(seconds: Int): String =
    if (seconds % 60 == 0) tr("%lld דַּקּוֹת", seconds / 60) else tr("%lld:%@ דַּקּוֹת", seconds / 60, "%02d".format(seconds % 60))
