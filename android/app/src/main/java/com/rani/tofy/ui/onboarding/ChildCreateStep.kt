package com.rani.tofy.ui.onboarding

import com.rani.tofy.ui.common.contentColumn

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.H
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.home.stripNiqqud
import com.rani.tofy.ui.theme.*

/** What step ② hands back — Profile's create-mode fields. */
data class ChildDraft(
    val name: String,
    val gender: String?,
    val grade: Int,
    val capMinutes: Int,
    val learningLevel: String,
    val interests: List<String>,
)

/** DailyCapChoice.label: "30 דק׳" / "שעה" / "שעה וחצי" / "שעתיים" / "ללא הגבלה". */
fun capLabel(m: Int): String = when {
    m <= 0 -> tr("ללא הגבלה")
    m == 60 -> tr("שעה")
    m == 90 -> tr("שעה וחצי")
    m == 120 -> tr("שעתיים")
    else -> tr("%lld דק׳", m)
}

/** DailyCapChoice.clampCustom: 15 min … 8 h, in 5-minute steps. */
private fun clampCustom(m: Int) = minOf(480, maxOf(15, (m / 5) * 5))

private val MINT = Color(0xFF8CFFC4)

/**
 * ProfileEditorView.swift `compactCreateForm` — a parent adding a child, on ONE
 * screen: name, girl/boy, grade (required) and the daily maximum, with level
 * and interests folded under "עוד הגדרות". Parent side: no niqqud.
 */
@Composable
fun ChildCreateStep(showSteps: Boolean, busy: Boolean, error: Boolean, onCancel: (() -> Unit)?, onSave: (ChildDraft) -> Unit) {
    var name by remember { mutableStateOf("") }
    var gender by remember { mutableStateOf<String?>(null) }
    var grade by remember { mutableStateOf<Int?>(null) }
    var cap by remember { mutableIntStateOf(60) }        // DailyCapChoice.defaultMinutes
    var customCap by remember { mutableStateOf(false) }
    var showMore by remember { mutableStateOf(false) }
    var level by remember { mutableStateOf("developing") }  // LearningLevel default
    var interests by remember { mutableStateOf(setOf<String>()) }
    val shown = name.trim()
    val canSave = shown.isNotEmpty() && grade != null

    GlassBackdrop {
        Column(Modifier.contentColumn().fillMaxSize().systemBarsPadding().imePadding()) {
            if (onCancel != null) Row(Modifier.fillMaxWidth().padding(start = 12.dp, top = 6.dp)) {
                Text(tr("ביטול"), Modifier.clip(RoundedCornerShape(50)).clickable(onClick = onCancel).padding(10.dp),
                    color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
            Column(
                Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp).padding(top = 4.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                if (showSteps) StepsHeader(step = 2)
                H(tr("מי הילד?"), 26, Modifier.fillMaxWidth(), align = TextAlign.Center)

                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Label(tr("שם"))
                    Box(Modifier.fillMaxWidth().glassPane(14.dp).padding(horizontal = 16.dp, vertical = 14.dp)) {
                        if (name.isEmpty()) Text(tr("השם של הילד"), color = Ink.tertiary, fontFamily = Rounded, fontSize = 17.sp)
                        BasicTextField(name, { name = it }, Modifier.fillMaxWidth(), singleLine = true,
                            textStyle = TextStyle(color = Color.White, fontFamily = Rounded, fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
                            cursorBrush = SolidColor(Color.White))
                    }
                }

                // ChildGender.allCases order: boy, girl.
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Choice(Modifier.weight(1f), gender == "boy", radius = 14.dp, stroke = 2.5f, onClick = { gender = "boy" }) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("👦", fontSize = 22.sp); ChoiceText(stripNiqqud(tr("ילד")), 17)
                        }
                    }
                    Choice(Modifier.weight(1f), gender == "girl", radius = 14.dp, stroke = 2.5f, onClick = { gender = "girl" }) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("👧", fontSize = 22.sp); ChoiceText(stripNiqqud(tr("ילדה")), 17)
                        }
                    }
                }

                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Label(tr("כיתה"))
                    val grades = listOf(-1 to tr("טרום"), 0 to tr("גן"), 1 to tr("א׳"), 2 to tr("ב׳"), 3 to tr("ג׳"),
                        4 to tr("ד׳"), 5 to tr("ה׳"), 6 to tr("ו׳"), 7 to tr("ז׳"), 8 to tr("ח׳"))
                    grades.chunked(5).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            row.forEach { (g, label) ->
                                Choice(Modifier.weight(1f), grade == g, onClick = { grade = g }) { ChoiceText(label, 15) }
                            }
                        }
                    }
                    P(tr("השאלות לפי תוכנית משרד החינוך, וטופי מתאים את הרמה לבד. ב-1 בספטמבר עולים כיתה אוטומטית."),
                        12.5f, color = Color.White.copy(alpha = 0.75f), weight = FontWeight.SemiBold)
                }

                // ⏱ The daily maximum, asked from the parent's side (no verb about the child).
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Label(if (shown.isEmpty()) tr("כמה זמן מסך מקסימום אתם מאפשרים ביום?") else tr("כמה זמן מסך מקסימום אתם מאפשרים ל%@ ביום?", shown))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf(30, 60, 120).forEach { m ->
                            Choice(Modifier.weight(1f), !customCap && cap == m, onClick = { customCap = false; cap = m }) { ChoiceText(capLabel(m), 15) }
                        }
                        Choice(Modifier.weight(1f), customCap, onClick = {
                            customCap = true
                            if (cap in listOf(30, 60, 120)) cap = 45
                        }) { ChoiceText(tr("✏️ אחר"), 15) }
                    }
                    if (customCap) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                        StepButton("−") { cap = clampCustom(cap - 15) }
                        Text(capLabel(cap), Modifier.widthIn(min = 110.dp), color = Color.White, fontFamily = Rounded,
                            fontWeight = FontWeight.ExtraBold, fontSize = 20.sp, textAlign = TextAlign.Center)
                        StepButton("+") { cap = clampCustom(cap + 15) }
                    }
                    P(tr("💡 הזמן נצבר בתשובות נכונות, עד המקסימום שבחרתם."), 12.5f, color = Color.White.copy(alpha = 0.75f), weight = FontWeight.SemiBold)
                }

                Row(
                    Modifier.fillMaxWidth().glassPane(14.dp, 0.1f).clickable { showMore = !showMore }.padding(horizontal = 14.dp, vertical = 11.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(tr("עוד הגדרות (לא חובה) — רמה ותחומי עניין"), Modifier.weight(1f), color = Color.White.copy(alpha = 0.9f),
                        fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    Text(if (showMore) "▴" else "▾", color = Color.White.copy(alpha = 0.9f), fontSize = 14.sp)
                }
                AnimatedVisibility(showMore) {
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        LevelRow(level) { level = it }
                        InterestsGrid(interests) { id -> interests = if (id in interests) interests - id else interests + id }
                    }
                }
            }
            Column(Modifier.padding(horizontal = 22.dp)) {
                if (error) P(tr("נסו שוב"), 14f, Modifier.fillMaxWidth(), color = Ink.warn, weight = FontWeight.Bold, align = TextAlign.Center)
                OnboardingFooter(tr("המשך"), enabled = canSave, busy = busy) {
                    if (canSave) onSave(ChildDraft(shown, gender, grade!!, cap, level, interests.toList()))
                }
            }
        }
    }
}

@Composable
private fun Label(text: String) = Text(text, color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)

@Composable
private fun ChoiceText(text: String, size: Int) =
    Text(text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = size.sp, maxLines = 1, textAlign = TextAlign.Center)

/** A glass option: brighter + mint ring when selected (genderOption / gradeOption / capPill). */
@Composable
private fun Choice(modifier: Modifier, selected: Boolean, radius: Dp = 14.dp, stroke: Float = 2.2f, onClick: () -> Unit, content: @Composable () -> Unit) {
    val shape = RoundedCornerShape(radius)
    Box(
        modifier.glassPane(radius, if (selected) 0.30f else 0.12f)
            .border(if (selected) stroke.dp else 1.dp, if (selected) MINT else Color.White.copy(alpha = 0.18f), shape)
            .clickable(onClick = onClick).padding(vertical = 11.dp, horizontal = 4.dp),
        contentAlignment = Alignment.Center,
    ) { content() }
}

@Composable
private fun StepButton(sign: String, onClick: () -> Unit) {
    Box(Modifier.size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.2f)).clickable(onClick = onClick), contentAlignment = Alignment.Center) {
        Text(sign, color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
    }
}

/** LearningLevel.allCases — raw values are what ChildRecord stores. */
@Composable
private fun LevelRow(level: String, onPick: (String) -> Unit) {
    val levels = listOf(
        Triple("beginner", "🌱", tr("מתחיל")), Triple("developing", "🌿", tr("מתפתח")),
        Triple("proficient", "🌳", tr("שולט")), Triple("advanced", "🚀", tr("מתקדם")),
    )
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Label(tr("רמת למידה התחלתית"))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            levels.forEach { (id, emoji, label) ->
                Choice(Modifier.weight(1f), level == id, onClick = { onPick(id) }) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(emoji, fontSize = 22.sp); ChoiceText(label, 12)
                    }
                }
            }
        }
    }
}

/** InterestCatalog.all (ChildRecord.swift) — ids are what ChildRecord stores. */
@Composable
private fun InterestsGrid(selected: Set<String>, onToggle: (String) -> Unit) {
    val all = listOf(
        Triple("sports", "⚽️", tr("ספורט")), Triple("space", "🚀", tr("חלל")), Triple("animals", "🦁", tr("בעלי חיים")),
        Triple("flags", "🚩", tr("דגלים")), Triple("music", "🎵", tr("מוזיקה")), Triple("art", "🎨", tr("אמנות")),
        Triple("history", "🏛️", tr("היסטוריה")), Triple("science", "🔬", tr("מדע")), Triple("english", "🔤", tr("אנגלית")),
        Triple("numbers", "🔢", tr("מספרים")), Triple("puzzles", "🧩", tr("חידות")), Triple("geography", "🌍", tr("מדינות")),
    )
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Label(tr("תחומי עניין — מהם נבנות השאלות המותאמות"))
        all.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { (id, emoji, label) ->
                    val on = id in selected
                    Row(
                        Modifier.weight(1f).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = if (on) 0.30f else 0.12f))
                            .border(if (on) 2.dp else 1.dp, if (on) Ink.gold2 else Color.White.copy(alpha = 0.18f), RoundedCornerShape(50))
                            .clickable { onToggle(id) }.padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(emoji, fontSize = 14.sp)
                        Text(label, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, maxLines = 1)
                    }
                }
            }
        }
    }
}
