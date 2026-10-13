package com.rani.tofy.kid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.content.ContentMode
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.key
import androidx.compose.ui.text.style.TextDecoration
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.I18n
import com.rani.tofy.kid.core.FirstRun
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.ui.play.QuestionRunnerScreen
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Rounded

/**
 * 🎬 The whole first run (see `FirstRun`): Tofy Time's questions first; ✕ leads
 * on to the made-up child's home under a band. Everything said here speaks to
 * the parent: no niqqud.
 */
@Composable
fun FirstRunRoot() {
    val ctx = LocalContext.current
    Box(Modifier.fillMaxSize()) {
        if (!FirstRun.onHome) FirstRunQuiz() else FirstRunHome()
        FirstRun.invite?.let { reason ->
            FirstRunInvite(reason, onSignUp = { FirstRun.end(ctx, signUp = true) }, onStay = { FirstRun.invite = null },
                onLeave = { FirstRun.end(ctx, signUp = false) })
        }
        FirstRun.explaining?.let { key ->
            FirstRunKeys(key, KidSession.engine()?.openableSeconds(false) ?: 0,
                onSignUp = { FirstRun.end(ctx, signUp = true) }, onClose = { FirstRun.explaining = null })
        }
        if (FirstRun.showLanguages) FirstRunLanguages { FirstRun.showLanguages = false }
    }
}

/** The quiz, and over it — after four answers, then every five — the one question. */
@Composable
private fun FirstRunQuiz() {
    val ctx = LocalContext.current
    Box(Modifier.fillMaxSize()) {
        // ✕ (or the end of the round) goes on to the child's home — still the first
        // run, still local. A new language starts the round over (`round`).
        key(FirstRun.round) { QuestionRunnerScreen(ContentMode.SmartFeed) { FirstRun.leaveQuizToHome() } }
        if (FirstRun.asking) FirstRunAsk(FirstRun.answered, KidSession.engine()?.openableSeconds(false) ?: 0,
            onCreate = { FirstRun.end(ctx, signUp = true) }, onPlay = { FirstRun.asking = false })
    }
}

/** The made-up child's home, under the band that keeps the two ways to a real family on screen. */
@Composable
private fun FirstRunHome() {
    val ctx = LocalContext.current
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().background(Color(0xEB2A1E5C)).statusBarsPadding().padding(start = 16.dp, end = 8.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically) {
            Text(tr("כבר יש לכם משפחה?"), Modifier.clickable { FirstRun.end(ctx, signUp = false) }.padding(vertical = 7.dp),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.5.sp, textDecoration = TextDecoration.Underline, maxLines = 1)
            Spacer(Modifier.weight(1f))
            Text(tr("ליצור משפחה"), Modifier.clip(RoundedCornerShape(16.dp)).background(GoldBrush).clickable { FirstRun.invite = FirstRun.Invite.BAND }
                .padding(horizontal = 12.dp, vertical = 7.dp),
                color = Color(0xFF2A1E5C), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, maxLines = 1)
        }
        // The home pads for the status bar itself; the band already did.
        Box(Modifier.weight(1f).consumeWindowInsets(WindowInsets.statusBars)) {
            KidRootImpl(FirstRun.CHILD_ID, kidMode = false, onExitKidMode = {})
        }
    }
}

/** The dimmed sheet from the bottom that every first-run question and explanation shares. */
@Composable
private fun FirstRunCard(onOutside: () -> Unit = {}, content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    val quiet = remember { MutableInteractionSource() }
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f)).clickable(quiet, null, onClick = onOutside), contentAlignment = Alignment.BottomCenter) {
        Column(
            Modifier.navigationBarsPadding().padding(12.dp).widthIn(max = 440.dp).fillMaxWidth()
                .clip(RoundedCornerShape(16.dp)).background(Color(0xFA4A3AB0))
                .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                .clickable(remember { MutableInteractionSource() }, null) {}
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp), content = content,
        )
    }
}

@Composable
private fun GoldAction(text: String, onClick: () -> Unit) =
    Text(text, color = Color(0xFF2A1E5C), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, textAlign = TextAlign.Center,
        modifier = Modifier.padding(top = 4.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(GoldBrush)
            .clickable(onClick = onClick).padding(vertical = 15.dp))

@Composable
private fun QuietAction(text: String, onClick: () -> Unit) =
    Text(text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 16.sp, textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick).padding(vertical = 13.dp))

@Composable
private fun Point(emoji: String, text: String) = Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
    Text(emoji, fontSize = 16.sp)
    Text(text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
}

/**
 * The one question of the first run — and the pitch (Rani: "חייבים שזה יגרום
 * להורה לפתוח משפחה"): what the parent has just earned, in their own numbers,
 * and what a real family adds to it.
 */
@Composable
private fun FirstRunAsk(answered: Int, seconds: Int, onCreate: () -> Unit, onPlay: () -> Unit) {
    FirstRunCard {
        Text("👨‍👩‍👧‍👦", fontSize = 46.sp)
        Text(tr("רוצים ליצור משפחה בטופי?"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
            fontSize = 23.sp, textAlign = TextAlign.Center)
        Text(if (seconds > 0) tr("עניתם על %lld שאלות וצברתם %lld שניות של זמן מסך. ככה הילדים מרוויחים אותו בטופי.", answered, seconds)
             else tr("ככה הילדים מרוויחים זמן מסך בטופי: עונים על שאלות, והשניות נצברות. ההרשמה לוקחת כדקה."),
            color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 15.5.sp, textAlign = TextAlign.Center)
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.1f)).padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Point("🔒", tr("האפליקציות והמשחקים נעולים, ונפתחים בזמן שהילד הרוויח"))
            Point("📱", tr("אתם רואים מהטלפון שלכם מה הילד למד וכמה שיחק"))
            Point("🎁", tr("30 יום של טופי+ במתנה"))
        }
        // One name for it everywhere — the band above the child's home says the same.
        GoldAction(tr("ליצור משפחה"), onCreate)
        QuietAction(tr("להמשיך לשחק"), onPlay)
        if (seconds > 0) Text(tr("ההרשמה לוקחת כדקה"), color = Color.White.copy(alpha = 0.75f), fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.sp)
    }
}

/** "זה נפתח אחרי ההרשמה" / the band's own button: sign up, stay, or leave. */
@Composable
private fun FirstRunInvite(reason: FirstRun.Invite, onSignUp: () -> Unit, onStay: () -> Unit, onLeave: () -> Unit) {
    FirstRunCard(onOutside = onStay) {
        Text(if (reason == FirstRun.Invite.CLOSED) "🔑" else "🎉", fontSize = 44.sp)
        Text(if (reason == FirstRun.Invite.CLOSED) tr("זה נפתח אחרי ההרשמה") else tr("עכשיו עם הילדים שלכם"), color = Color.White,
            fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 24.sp, textAlign = TextAlign.Center)
        Text(tr("מה שראיתם הוא משפחה לדוגמה. ההרשמה לוקחת כדקה, ואחריה מוסיפים את הילדים ומתחילים."), color = Color.White.copy(alpha = 0.88f),
            fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 15.sp, textAlign = TextAlign.Center)
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.1f)).padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Point("🎁", tr("30 יום של טופי+ במתנה"))
            Point("🧹", tr("ההדגמה נמחקת מהמכשיר, ומתחילים נקי"))
        }
        GoldAction(tr("ליצור משפחה"), onSignUp)
        QuietAction(tr("להמשיך בהדגמה"), onStay)
        Text(tr("יציאה מההדגמה"), Modifier.clickable(onClick = onLeave).padding(6.dp), color = Color.White.copy(alpha = 0.85f),
            fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.sp, textDecoration = TextDecoration.Underline)
    }
}

/** What the minutes, the gift and the code under the child's home are — the tapped one marked. */
@Composable
private fun FirstRunKeys(tapped: FirstRun.Key, earnedSeconds: Int, onSignUp: () -> Unit, onClose: () -> Unit) {
    @Composable
    fun KeyRow(key: FirstRun.Key, emoji: String, title: String, text: String) {
        val on = key == tapped
        val shape = RoundedCornerShape(16.dp)
        Row(Modifier.fillMaxWidth().clip(shape).background(Color.White.copy(alpha = if (on) 0.18f else 0.08f))
            .border(if (on) 1.5.dp else 1.dp, if (on) Color(0xFFFFD23F) else Color.White.copy(alpha = 0.18f), shape).padding(11.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(emoji, fontSize = 24.sp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                Text(text, color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 14.sp)
            }
        }
    }
    FirstRunCard(onOutside = onClose) {
        Text(tr("שלושת הכפתורים שלמטה"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp, textAlign = TextAlign.Center)
        KeyRow(FirstRun.Key.MINUTES, "🎮", tr("דקות לשחק"),
            if (earnedSeconds > 0) tr("הזמן שהילד הרוויח בתשובות נכונות — כאן זה מה שאתם צברתם עכשיו. כשנצברות מספיק דקות, הילד לוחץ, והאפליקציות והמשחקים שלו נפתחים עד שהזמן נגמר.")
            else tr("הזמן שהילד הרוויח בתשובות נכונות. כשנצברות מספיק דקות, הילד לוחץ, והאפליקציות והמשחקים שלו נפתחים עד שהזמן נגמר."))
        KeyRow(FirstRun.Key.GIFT, "💝", tr("דקות מתנה"),
            tr("דקות שאתם נותנים לילד מהטלפון שלכם, בלי קשר לשאלות: על עזרה בבית, או סתם כי בא לכם. ה־30 שכאן הן לדוגמה."))
        KeyRow(FirstRun.Key.CODE, "🔒", tr("קוד סודי"), tr("קוד שהילד בוחר לעצמו, כדי שרק הוא יוכל לפתוח את הדקות שלו — ולא אח או אחות."))
        GoldAction(tr("ליצור משפחה"), onSignUp)
        QuietAction(tr("הבנתי"), onClose)
    }
}

private fun flag(lang: AppLanguage) = when (lang) { AppLanguage.HE -> "🇮🇱"; AppLanguage.EN -> "🇺🇸"; AppLanguage.RU -> "🇷🇺"; AppLanguage.AR -> "🇦🇪" }

/** 🌐 The language, on the first run's quiz, beside ✕: a parent who landed on questions they don't read changes it right there. */
@Composable
fun FirstRunLanguageChip() {
    Row(Modifier.height(32.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.16f))
        .clickable { FirstRun.showLanguages = true }.padding(horizontal = 9.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(flag(I18n.language), fontSize = 15.sp)
        Text("🌐", fontSize = 13.sp)
    }
}

/** The four languages. The choice is the phone's from here on — it is the parent's own. */
@Composable
private fun FirstRunLanguages(onClose: () -> Unit) {
    FirstRunCard(onOutside = onClose) {
        Text(tr("שפה · Language"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
        AppLanguage.entries.forEach { lang ->
            val on = I18n.language == lang
            val shape = RoundedCornerShape(16.dp)
            Row(Modifier.fillMaxWidth().clip(shape).background(Color.White.copy(alpha = if (on) 0.2f else 0.1f))
                .border(1.dp, Color.White.copy(alpha = if (on) 0.6f else 0.2f), shape)
                .clickable {
                    onClose()
                    if (!on) { I18n.set(lang); FirstRun.languageChanged() }
                }.padding(horizontal = 14.dp, vertical = 13.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(flag(lang), fontSize = 20.sp)
                Text(lang.native, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
                if (on) Text("✓", color = Color(0xFF8CFFC4), fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 18.sp)
            }
        }
        Text(tr("השפה משתנה מיד בכל האפליקציה: טקסטים, כיוון, הקראה ושאלות."), color = Color.White.copy(alpha = 0.75f),
            fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 12.5.sp, textAlign = TextAlign.Center)
    }
}
