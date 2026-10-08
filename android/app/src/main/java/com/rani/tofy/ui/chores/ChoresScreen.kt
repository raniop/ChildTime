package com.rani.tofy.ui.chores

import com.rani.tofy.ui.common.contentColumn

import android.graphics.BitmapFactory
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import coil.compose.AsyncImage
import com.rani.tofy.data.Chore
import com.rani.tofy.data.ChoresRepository
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.*
import com.rani.tofy.ui.theme.*
import kotlinx.coroutines.launch

private val EMOJI_OPTIONS = listOf("🧹", "🛏", "🍽", "🗑", "👕", "🐕", "🪴", "🎒", "🧸", "🛒", "🍳", "🧺")

/**
 * 🧹 ChoresParentView.swift — the chores of one child, with a picker across all
 * the kids. The catalog is built in (every child has ~20 chores); here the
 * parent approves / returns what the kid marked done, retunes a chore's
 * minutes, hides catalog chores (swipe) or adds custom ones. No money rewards
 * (removed on iOS too).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChoresScreen(onBack: () -> Unit) {
    LaunchedEffect(Unit) { ChoresRepository.start() }
    BackHandler(onBack = onBack)
    val fam by FamilyRepository.state.collectAsState()
    val all by ChoresRepository.chores.collectAsState()
    val stats by ChoresRepository.stats.collectAsState()
    val approving by ChoresRepository.approving.collectAsState()
    val failed by ChoresRepository.lastActionFailed.collectAsState()
    val scope = rememberCoroutineScope()
    val kids = fam.orderedChildren

    // Open on the child the banner pointed at, else the first one with a chore waiting.
    var selectedID by remember {
        mutableStateOf(ChoresRepository.focusChildID?.takeIf { id -> kids.any { it.id == id } }
            ?: ChoresRepository.pendingApproval(all).firstOrNull()?.childID
            ?: kids.firstOrNull()?.id)
    }
    LaunchedEffect(Unit) { ChoresRepository.focusChildID = null }
    val child = kids.firstOrNull { it.id == selectedID } ?: kids.firstOrNull()

    var editing by remember { mutableStateOf<Chore?>(null) }

    GlassBackdrop {
        Column(Modifier.contentColumn().fillMaxSize().systemBarsPadding()) {
            TopRow(if (child != null) tr("מטלות הבית · %@", child.name) else tr("מטלות הבית"), onBack)
            if (child == null) return@Column
            val mine = ChoresRepository.choresFor(child.id, all)
            val pending = mine.filter { it.isPendingApproval }
            val rest = mine.filter { !it.isPendingApproval }
            val hidden = ChoresRepository.hiddenPresets(child.id, all)
            val earned = stats[child.id]?.minutes ?: 0

            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                if (kids.size > 1) item {
                    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        kids.forEach { k ->
                            // 🕐 marks a kid with a chore waiting for approval.
                            val waiting = ChoresRepository.choresFor(k.id, all).any { it.isPendingApproval }
                            val on = k.id == child.id
                            Box(
                                Modifier.clip(RoundedCornerShape(16.dp))
                                    .background(if (on) Color.White.copy(alpha = 0.92f) else Color.White.copy(alpha = 0.16f))
                                    .clickable { selectedID = k.id; editing = null }
                                    .padding(horizontal = 16.dp, vertical = 9.dp),
                            ) {
                                Text(if (waiting) "${k.name} 🕐" else k.name, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.sp,
                                    color = if (on) Ink.indigo else Color.White)
                            }
                        }
                    }
                }

                if (pending.isNotEmpty()) {
                    item { SectionTitle(if (pending.size == 1) tr("מחכה לאישור שלכם 🕐") else tr("מחכות לאישור שלכם 🕐")) }
                    items(pending, key = { "p-" + it.id }) { c ->
                        PendingRow(c, c.id in approving,
                            onApprove = { ChoresRepository.approve(c) },
                            onReturn = { scope.launch { ChoresRepository.returnChore(c) } })
                    }
                }

                if (earned > 0) item {
                    P(tr("סה\"כ הרוויח%@ מהמטלות: 🎮 %lld דקות משחק", if (child.isGirl) tr("ה") else "", earned), 12.5f, color = Ink.secondary)
                }

                item { SectionTitle(tr("המטלות של %@", child.name)) }
                items(rest, key = { "r-" + it.id }) { c ->
                    SwipeToHide(onHide = {
                        scope.launch { if (c.isPreset) ChoresRepository.hideChore(c) else ChoresRepository.deleteChore(c) }
                    }) { ChoreRow(c) { editing = c } }
                }
                item {
                    P(tr("כל המטלות זמינות אוטומטית, ופרס דקות המשחק מוצע לפי גודל המטלה. לחיצה על מטלה — עריכת הפרס; החלקה — הסתרה."),
                        12f, color = Ink.tertiary, modifier = Modifier.padding(horizontal = 6.dp))
                }

                if (hidden.isNotEmpty()) {
                    item { SectionTitle(tr("מטלות שהוסתרו 🙈")) }
                    items(hidden, key = { "h-" + it.id }) { c ->
                        Row(Modifier.fillMaxWidth().glassPane(16.dp).padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                            P("${c.emoji} ${c.title}", 14.5f, Modifier.weight(1f), color = Ink.secondary)
                            Text(tr("החזירו"), Modifier.clickable { scope.launch { ChoresRepository.restoreChore(c) } }.padding(6.dp),
                                color = Ink.warn, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        }
                    }
                }

                item { SectionTitle(tr("מטלה חדשה ➕")) }
                item(key = "new-${child.id}") {
                    Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        ChoreForm(null) { title, emoji, minutes, times ->
                            scope.launch { ChoresRepository.addChore(child.id, title, emoji, minutes, times) }
                        }
                    }
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }

    // Editing opens in place as a sheet (iOS: nobody found the editor at the bottom).
    editing?.let { c ->
        ModalBottomSheet(onDismissRequest = { editing = null }, containerColor = Ink.sheet) {
            Column(Modifier.fillMaxWidth().padding(horizontal = 18.dp).padding(bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    H(tr("עריכת מטלה"), 19, Modifier.weight(1f))
                    Text(tr("ביטול"), Modifier.clickable { editing = null }.padding(6.dp), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold)
                }
                H("${c.emoji} ${c.title}", 17)
                ChoreForm(c) { title, emoji, minutes, times ->
                    scope.launch { ChoresRepository.updateChore(c, title, emoji, minutes, times) }
                    editing = null
                }
            }
        }
    }

    if (failed) AlertDialog(
        onDismissRequest = { ChoresRepository.lastActionFailed.value = false },
        confirmButton = { TextButton(onClick = { ChoresRepository.lastActionFailed.value = false }) { Text(tr("הבנתי")) } },
        title = { Text(tr("האישור לא נשלח")) },
        text = { Text(tr("לא הצלחנו לאשר את המטלה כרגע. בדקו את החיבור לאינטרנט ונסו שוב.")) },
    )
}

@Composable
private fun TopRow(title: String, onBack: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        // Auto-mirrored: points "back" in both RTL and LTR.
        Box(Modifier.size(44.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f)).clickable(onClick = onBack), contentAlignment = Alignment.Center) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, tr("חזרה"), tint = Color.White)
        }
        H(title, 19, Modifier.weight(1f).padding(horizontal = 10.dp), align = TextAlign.Center)
        Spacer(Modifier.size(44.dp))
    }
}

@Composable
private fun SectionTitle(text: String) =
    Text(text, Modifier.padding(start = 6.dp, top = 8.dp), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.5.sp)

@Composable
private fun PendingRow(c: Chore, approving: Boolean, onApprove: () -> Unit, onReturn: () -> Unit) {
    Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("${c.emoji} ${c.title}", Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
            P(tr("🎮 %lld דק׳ משחק", c.rewardMinutes), 12.5f)
        }
        ProofPhoto(c)
        RowSpaced {
            Box(
                Modifier.weight(1f).height(46.dp).clip(RoundedCornerShape(16.dp)).background(Color(0xFF2EBD6B))
                    .clickable(enabled = !approving, onClick = onApprove),
                contentAlignment = Alignment.Center,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    if (approving) CircularProgressIndicator(Modifier.size(16.dp), color = Color.White, strokeWidth = 2.dp)
                    Text(if (approving) tr("מאשר…") else tr("בוצע — אשרו ✅"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
                }
            }
            GlassButton(tr("עוד לא הושלמה"), Modifier.weight(1f)) { if (!approving) onReturn() }
        }
    }
}

/** The kid's proof photo: the JPEG on the doc, or (if only the token is there) the chorePhoto function. */
@Composable
private fun ProofPhoto(c: Chore) {
    val bytes = c.photo
    val bmp = remember(c.id, bytes?.size) { bytes?.let { runCatching { BitmapFactory.decodeByteArray(it, 0, it.size) }.getOrNull() } }
    val mod = Modifier.fillMaxWidth().height(160.dp).clip(RoundedCornerShape(16.dp))
    if (bmp != null) {
        Image(bmp.asImageBitmap(), null, mod, contentScale = ContentScale.Crop)
    } else if (c.photoToken != null) {
        val hid = FamilyRepository.householdID ?: return
        AsyncImage(ChoresRepository.photoURL(hid, c.id, c.photoToken), null, mod, contentScale = ContentScale.Crop)
    }
}

@Composable
private fun ChoreRow(c: Chore, onEdit: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().glassPane(16.dp).clickable(onClick = onEdit).padding(horizontal = 14.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(c.emoji, fontSize = 22.sp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(c.title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            val parts = buildList {
                add(tr("🎮 %lld דק׳", c.rewardMinutes))
                if (c.timesPerDay > 1) add(tr("🔁 עד %lld ביום", c.timesPerDay))
                if (c.isDaily && c.doneToday > 0) add(if (c.approvedToday) tr("✅ הושלמה להיום") else tr("✅ %lld/%lld היום", c.doneToday, c.timesPerDay))
            }
            P(parts.joinToString("  "), 12f)
        }
        Text("✎", color = Ink.tertiary, fontSize = 16.sp)
    }
}

/** iOS swipe-to-delete on the list: a catalog chore hides, a custom one is deleted. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeToHide(onHide: () -> Unit, content: @Composable () -> Unit) {
    val state = rememberSwipeToDismissBoxState(confirmValueChange = {
        if (it == SwipeToDismissBoxValue.EndToStart) { onHide(); true } else false
    })
    SwipeToDismissBox(
        state, enableDismissFromStartToEnd = false,
        backgroundContent = {
            Box(Modifier.fillMaxSize().clip(RoundedCornerShape(16.dp)).background(Color(0xFFE76F51)).padding(horizontal = 18.dp),
                contentAlignment = Alignment.CenterEnd) {
                Text(tr("הסתרה"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold)
            }
        },
    ) { content() }
}

/**
 * The shared fields — name + emoji (custom chores only; a catalog chore keeps
 * its name), the minutes and per-day steppers, and the save button.
 */
@Composable
private fun ChoreForm(editing: Chore?, onSave: (title: String, emoji: String, minutes: Int, times: Int) -> Unit) {
    var title by remember(editing?.id) { mutableStateOf(editing?.title ?: "") }
    var emoji by remember(editing?.id) { mutableStateOf(editing?.emoji ?: "🧹") }
    var minutes by remember(editing?.id) { mutableIntStateOf(editing?.rewardMinutes ?: 10) }
    var times by remember(editing?.id) { mutableIntStateOf(editing?.timesPerDay ?: 1) }
    val keepName = editing?.isPreset == true

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (!keepName) {
            TextField(
                title, { title = it }, Modifier.fillMaxWidth(),
                placeholder = { Text(tr("מה המטלה? (למשל: לשטוף את האוטו)"), color = Ink.tertiary) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                shape = RoundedCornerShape(16.dp),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.White.copy(alpha = 0.12f), unfocusedContainerColor = Color.White.copy(alpha = 0.12f),
                    focusedTextColor = Color.White, unfocusedTextColor = Color.White, cursorColor = Color.White,
                    focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent,
                ),
            )
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                EMOJI_OPTIONS.forEach { e ->
                    Box(
                        Modifier.size(42.dp).clip(RoundedCornerShape(16.dp))
                            .background(if (emoji == e) Color.White.copy(alpha = 0.3f) else Color.Transparent)
                            .clickable { emoji = e },
                        contentAlignment = Alignment.Center,
                    ) { Text(e, fontSize = 24.sp) }
                }
            }
        }
        Stepper(tr("🎮 פרס דקות משחק: %lld", minutes), canDec = minutes > 5, canInc = minutes < 120,
            onDec = { minutes = maxOf(5, minutes - 5) }, onInc = { minutes = minOf(120, minutes + 5) })
        Stepper(if (times == 1) tr("🔁 פעם אחת ביום") else tr("🔁 עד %lld פעמים ביום", times), canDec = times > 1, canInc = times < 6,
            onDec = { times = maxOf(1, times - 1) }, onInc = { times = minOf(6, times + 1) })
        val ok = (editing != null || title.isNotBlank()) && minutes > 0
        GoldButton(if (editing == null) tr("הוסיפו מטלה") else tr("שמרו שינויים"), enabled = ok) {
            onSave(if (keepName) editing!!.title else title.trim(), if (keepName) editing!!.emoji else emoji, minutes, times)
            if (editing == null) { title = ""; emoji = "🧹"; minutes = 10; times = 1 }
        }
    }
}

@Composable
private fun Stepper(label: String, canDec: Boolean, canInc: Boolean, onDec: () -> Unit, onInc: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        P(label, 14.5f, Modifier.weight(1f), color = Color.White, weight = FontWeight.SemiBold)
        Row(Modifier.glassInset(16.dp), verticalAlignment = Alignment.CenterVertically) {
            StepBtn("−", canDec, onDec)
            Box(Modifier.width(1.dp).height(22.dp).background(Color.White.copy(alpha = 0.3f)))
            StepBtn("+", canInc, onInc)
        }
    }
}

@Composable
private fun StepBtn(t: String, enabled: Boolean, onClick: () -> Unit) =
    Box(Modifier.size(width = 46.dp, height = 36.dp).clickable(enabled = enabled, onClick = onClick), contentAlignment = Alignment.Center) {
        Text(t, color = if (enabled) Color.White else Color.White.copy(alpha = 0.35f), fontSize = 20.sp, fontWeight = FontWeight.Bold)
    }
