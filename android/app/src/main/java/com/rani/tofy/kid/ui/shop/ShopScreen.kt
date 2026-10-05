package com.rani.tofy.kid.ui.shop

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.data.Child
import com.rani.tofy.data.WriteOutcome
import com.rani.tofy.data.nowSecs
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.ui.JoinRepository
import com.rani.tofy.kid.ui.KidBottomCard
import com.rani.tofy.kid.ui.KidCenterCard
import com.rani.tofy.kid.ui.KidCta
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.kid.ui.play.KidHaptics
import com.rani.tofy.kid.ui.play.KidSounds
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * ShopView.swift — the character shop: the equipped character big, then the
 * collectible grid (buy with 💎 / equip). The 💎 balance opens the real-money
 * diamond packs, ALWAYS behind the parent gate (Kids Category 1.3).
 * Not ported: the hero's "עֲרוֹךְ פְּרוֹפִיל" pill (the profile editor is parent UI).
 */
@Composable
fun ShopScreenImpl(onExit: () -> Unit) {
    val ctx = LocalContext.current
    remember { KidSounds.init(ctx); CosmeticStore.init(ctx); 0 }
    val state by KidSession.state.collectAsState()
    val child = rememberBoundChild()
    val col = rememberCollectionState(child)
    var starShop by remember { mutableStateOf(false) }
    BackHandler(enabled = !starShop && !col.hasDialog) { onExit() }

    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            ShopTopBar(tr("חֲנוּת הַדְּמוּיוֹת"), onExit) { DiamondPill(state?.snapshot?.diamonds ?: 0) { col.haptics?.light(); starShop = true } }
            CollectionGrid(col, state?.snapshot?.diamonds ?: 0, state?.snapshot?.ownedCharacterIDs ?: emptyList()) {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    Column(Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 8.dp), horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        BobbingCharacter(col.selectedID, Modifier.width(140.dp).height(203.dp))
                        Text(child?.name.orEmpty(), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
                    }
                }
            }
        }
        CollectionDialogs(col, onBuyDiamonds = { starShop = true })
        if (starShop) StarShopGate(child) { starShop = false }
    }
}

/**
 * Character3DPickerView — the same grid with a "בְּחַר דְּמוּת" header; closes
 * itself a beat after a pick so the gold check registers.
 */
@Composable
fun CharacterCollectionScreenImpl(onExit: () -> Unit) {
    val ctx = LocalContext.current
    remember { KidSounds.init(ctx); CosmeticStore.init(ctx); 0 }
    val state by KidSession.state.collectAsState()
    val child = rememberBoundChild()
    val scope = rememberCoroutineScope()
    val col = rememberCollectionState(child, onPicked = { scope.launch { delay(180); onExit() } })
    var starShop by remember { mutableStateOf(false) }
    BackHandler(enabled = !starShop && !col.hasDialog) { onExit() }

    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            ShopTopBar(tr("בְּחַר דְּמוּת"), onExit) { DiamondPill(state?.snapshot?.diamonds ?: 0) { col.haptics?.light(); starShop = true } }
            CollectionGrid(col, state?.snapshot?.diamonds ?: 0, state?.snapshot?.ownedCharacterIDs ?: emptyList()) {}
        }
        CollectionDialogs(col, onBuyDiamonds = { starShop = true })
        if (starShop) StarShopGate(child) { starShop = false }
    }
}

// ── CharacterCollectionView ─────────────────────────────────────────────────

@Stable
internal class CollectionState(private val scope: CoroutineScope, private val onPicked: (() -> Unit)?) {
    var childID: String? = null
    var householdID: String? = null
    /** children/{id}.character3DID as the doc has it now. */
    var docCharacter: String? = null
    var haptics: KidHaptics? = null
    var pending by mutableStateOf<ShopCharacter?>(null)
    var shortBy by mutableStateOf<Int?>(null)
    /** The pick shown at once, until the child doc's listener catches up. */
    var picked by mutableStateOf<String?>(null)
    val hasDialog: Boolean get() = pending != null || shortBy != null
    val selectedID: String get() = picked ?: docCharacter ?: CharacterCatalog.DEFAULT_ID

    fun tap(c: ShopCharacter, owned: Boolean, diamonds: Int) {
        haptics?.light()
        when (val r = ShopMath.evaluate(owned, c.priceDiamonds, diamonds)) {
            Purchase.AlreadyOwned -> select(c)
            is Purchase.Ok -> pending = c
            is Purchase.NotEnoughDiamonds -> shortBy = r.short
        }
    }

    fun buy(c: ShopCharacter) {
        pending = null
        val r = KidSession.edit { it.purchaseCharacter(c) }
        if (r !is Purchase.Ok) return
        haptics?.success()
        KidSession.pushNow()   // ownership + the spent 💎 reach the cloud right away
        select(c)
    }

    /**
     * Equip: Profile.character3DID + the characterUpdatedAt freshness stamp (the
     * fresher pick wins every merge), merge-written to children/{id} and confirmed.
     */
    fun select(c: ShopCharacter) {
        val cid = childID ?: return
        picked = c.id
        scope.launch {
            val out = JoinRepository.childWrite(cid, householdID, mapOf("character3DID" to c.id, "characterUpdatedAt" to nowSecs()))
            if (out == WriteOutcome.DENIED || out == WriteOutcome.ERROR) picked = null
        }
        onPicked?.invoke()
    }
}

@Composable
internal fun rememberCollectionState(child: Child?, onPicked: (() -> Unit)? = null): CollectionState {
    val scope = rememberCoroutineScope()
    val view = LocalView.current
    val st = remember { CollectionState(scope, onPicked) }
    st.childID = child?.id
    st.householdID = child?.householdID
    st.docCharacter = child?.character3DID
    st.haptics = remember(view) { KidHaptics(view) }
    // The doc caught up with the pick → drop the optimistic override.
    LaunchedEffect(child?.character3DID) { if (st.picked == child?.character3DID) st.picked = null }
    return st
}

@Composable
internal fun CollectionGrid(col: CollectionState, diamonds: Int, ownedIDs: List<String>, header: LazyGridScope.() -> Unit) {
    val all = remember(com.rani.tofy.i18n.I18n.language) { CharacterCatalog.all() }
    LazyVerticalGrid(
        GridCells.Adaptive(150.dp), Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 48.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        header()
        items(all, key = { it.id }) { c ->
            val owned = ShopMath.ownsCharacter(c, ownedIDs)
            CharacterCard(c, selected = col.selectedID == c.id, owned = owned, affordable = diamonds >= c.priceDiamonds) {
                col.tap(c, owned, diamonds)
            }
        }
    }
}

@Composable
private fun CharacterCard(c: ShopCharacter, selected: Boolean, owned: Boolean, affordable: Boolean, onTap: () -> Unit) {
    val tier = c.tier
    val shape = RoundedCornerShape(22.dp)
    Box(
        Modifier.fillMaxWidth().tintedPane(if (selected) KidColor.starGold else tier.color)
            .then(if (selected) Modifier.border(2.dp, KidColor.starGold.copy(alpha = 0.9f), shape) else Modifier)
            .clickable(onClick = onTap),
    ) {
        ShopCharImage(c.id, Modifier.align(Alignment.Center).padding(vertical = 8.dp).height(170.dp).fillMaxWidth(), owned)
        // Rarity badge (top-start).
        Text(
            tier.label, Modifier.align(Alignment.TopStart).padding(8.dp).clip(RoundedCornerShape(50)).background(tier.color.copy(alpha = 0.75f))
                .border(1.dp, Color.White.copy(alpha = 0.45f), RoundedCornerShape(50)).padding(horizontal = 9.dp, vertical = 4.dp),
            color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 11.sp,
        )
        if (selected) Box(
            Modifier.align(Alignment.TopEnd).padding(8.dp).size(26.dp).clip(CircleShape).background(Color.White),
            contentAlignment = Alignment.Center,
        ) { Text("✓", color = KidColor.starGold, fontWeight = FontWeight.Black, fontSize = 17.sp) }
        // A price tag, never a lock (no lock language for the child).
        if (!owned) Row(
            Modifier.align(Alignment.BottomCenter).padding(bottom = 12.dp).clip(RoundedCornerShape(50))
                .background(Color.White.copy(alpha = if (affordable) 0.92f else 0.18f))
                .border(1.dp, Color.White.copy(alpha = 0.35f), RoundedCornerShape(50)).padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text("${c.priceDiamonds}", color = if (affordable) Color(0xFF4B3FBF) else Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
            Text("💎", fontSize = 12.sp)
        }
    }
}

/** The buy-and-equip confirmation and the "not enough 💎" card. */
@Composable
internal fun CollectionDialogs(col: CollectionState, onBuyDiamonds: () -> Unit) {
    col.pending?.let { c ->
        BackHandler { col.pending = null }
        KidBottomCard(onDismiss = { col.pending = null }) {
            Text("${c.name} — ${c.priceDiamonds} 💎", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 18.sp, textAlign = TextAlign.Center)
            ShopCharImage(c.id, Modifier.height(120.dp))
            KidCta(tr("קְנֵה וְהַחֲלֵף"), Color(0xFFFFB547), Color(0xFFFF8A3D), emoji = "💎") { col.buy(c) }
            CancelLink(tr("בִּטּוּל")) { col.pending = null }
        }
    }
    col.shortBy?.let { s ->
        BackHandler { col.shortBy = null }
        KidCenterCard(onDismiss = { col.shortBy = null }) {
            Text(tr("חֲסֵרִים יַהֲלוֹמִים 💎"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 20.sp, textAlign = TextAlign.Center)
            Text(tr("צָרִיךְ עוֹד %lld יַהֲלוֹמִים. תַּמְשִׁיךְ לִלְמוֹד וְתַרְוִיחַ — אוֹ הוֹרֶה יָכוֹל לִקְנוֹת.", s),
                color = Color.White.copy(alpha = 0.88f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp,
                textAlign = TextAlign.Center, lineHeight = 21.sp)
            KidCta(tr("קְנֵה יַהֲלוֹמִים"), Color(0xFF9B5DE5), Color(0xFF5E60CE), emoji = "💎") { col.shortBy = null; onBuyDiamonds() }
            CancelLink(tr("הֵבַנְתִּי")) { col.shortBy = null }
        }
    }
}

@Composable
internal fun CancelLink(text: String, onClick: () -> Unit) {
    Text(
        text, Modifier.widthIn(min = 120.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, Color.White.copy(alpha = 0.30f), RoundedCornerShape(50)).clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 10.dp),
        color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, textAlign = TextAlign.Center,
    )
}
