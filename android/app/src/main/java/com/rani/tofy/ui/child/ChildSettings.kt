package com.rani.tofy.ui.child

import com.rani.tofy.ui.common.contentColumn

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestoreException
import com.rani.tofy.data.*
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.ChildAvatar
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.home.gradeName
import com.rani.tofy.ui.theme.*
import kotlinx.coroutines.launch

private enum class Page { MAIN, PROFILE, LANGUAGE, DIFFICULTY, WORLDS, SCREEN_TIME, FRIENDS, SCHOOL, BEDTIME }

/**
 * ChildSettingsView.swift — everything about ONE child that is SET rather than
 * read, plus the editors it opens (ProfileEditorView, ChildLanguageView,
 * ChildDifficultyView, ChildWorldsView, ChildScreenTimeView, ChildFriendsView).
 * Every edit merge-writes only the changed fields through ChildRepository.update
 * (confirmed, membership self-heal) and says so honestly when it didn't save.
 */
@Composable
internal fun ChildSettingsContent(childID: String, onBack: () -> Unit, onDeleted: () -> Unit) {
    val state by FamilyRepository.state.collectAsState()
    val child = state.children.firstOrNull { it.id == childID }
    val stateDoc by remember(childID) { ChildReportRepository.stateDoc(childID) }.collectAsState(initial = emptyMap())
    val scope = rememberCoroutineScope()
    val note = remember { WriteNote() }
    var page by rememberSaveableEnum(Page.MAIN)

    fun write(fields: Map<String, Any?>) { scope.launch { note.report(ChildRepository.update(childID, fields)) } }

    // The screen-time editor saves on the way out (one write per edit session, like iOS onDisappear).
    // A plain holder, not state: re-registering every recomposition must not trigger another one.
    val pendingCapSave = remember { arrayOfNulls<() -> Unit>(1) }
    fun back() {
        if (page == Page.MAIN) onBack() else { pendingCapSave[0]?.invoke(); pendingCapSave[0] = null; page = Page.MAIN }
    }
    BackHandler { back() }

    GlassBackdrop {
        if (child == null) {
            Column(Modifier.contentColumn().fillMaxSize().systemBarsPadding().padding(16.dp)) { PageBar("", onBack) }
            return@GlassBackdrop
        }
        val progress = state.progress[childID] ?: Progress.EMPTY
        val extras = remember(stateDoc) { SnapshotExtras.from(stateDoc) }
        Box(Modifier.contentColumn().fillMaxSize().systemBarsPadding().imePadding()) {
            when (page) {
                Page.MAIN -> MainList(child, progress, extras, state.devicesOf(childID).isNotEmpty(), note, ::back, onOpen = { page = it }, write = ::write, onDeleted = onDeleted)
                Page.PROFILE -> ProfileEditor(child, ::back, onSave = { f -> if (f.isNotEmpty()) write(f); page = Page.MAIN }, onDeleted = onDeleted, note = note)
                Page.LANGUAGE -> LanguageEditor(child, ::back, ::write)
                Page.DIFFICULTY -> DifficultyEditor(child, ::back, ::write)
                Page.WORLDS -> WorldsEditor(child, ::back, ::write)
                Page.SCREEN_TIME -> ScreenTimeEditor(child, ::back, ::write) { pendingCapSave[0] = it }
                Page.FRIENDS -> FriendsList(child, ::back, note)
                Page.SCHOOL -> QuietEditor(child, QuietKind.SCHOOL, ::back, ::write) { pendingCapSave[0] = it }
                Page.BEDTIME -> QuietEditor(child, QuietKind.BEDTIME, ::back, ::write) { pendingCapSave[0] = it }
            }
            note.Host(Modifier.align(Alignment.BottomCenter))
        }
    }
}

@Composable
private fun rememberSaveableEnum(initial: Page): MutableState<Page> =
    androidx.compose.runtime.saveable.rememberSaveable { mutableStateOf(initial) }

@Composable
private fun Scroll(content: @Composable ColumnScope.() -> Unit) =
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp).padding(bottom = 60.dp), verticalArrangement = Arrangement.spacedBy(18.dp), content = content)

private val AppLanguage.flag get() = when (this) { AppLanguage.HE -> "🇮🇱"; AppLanguage.EN -> "🇺🇸"; AppLanguage.RU -> "🇷🇺"; AppLanguage.AR -> "🇦🇪" }

// MARK: - The list

@Composable
private fun MainList(
    child: Child, s: Progress, extras: SnapshotExtras, connected: Boolean, note: WriteNote, onBack: () -> Unit,
    onOpen: (Page) -> Unit, write: (Map<String, Any?>) -> Unit, onDeleted: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val girl = child.isGirl
    var confirmPin by remember { mutableStateOf(false) }
    var confirmReset by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    var remoteNote by remember { mutableStateOf<String?>(null) }

    Scroll {
        PageBar(tr("הַגְדָּרוֹת שֶׁל %@", child.name), onBack)

        // הַיֶּלֶד / הַיַּלְדָּה — the grade drives ALL curriculum content: flag it when missing or child-picked.
        val flagged = child.grade == null || child.gradeSetByChild
        val grade = if (child.grade == null) tr("כיתה לא הוגדרה — הגדירו")
            else gradeName(child.effectiveGrade) + (if (child.gradeSetByChild) " " + tr("· נבחרה ע\"י הילד — בדקו") else "")
        val lang = AppLanguage.of(child.language)
        SettingsSection(if (girl) tr("הַיַּלְדָּה") else tr("הַיֶּלֶד")) {
            SettingsRow("✏️", tr("שֵׁם, גִּיל וְכִתָּה"), "${child.name} · ${AgeBracket.of(child.age).label} · $grade",
                valueColor = if (flagged) Color(0xFFFF8A3D) else Ink.secondary) { onOpen(Page.PROFILE) }
            RowDivider()
            SettingsRow("🌍", if (girl) tr("שָׂפָה בַּמַּכְשִׁיר שֶׁלָּהּ") else tr("שָׂפָה בַּמַּכְשִׁיר שֶׁלּוֹ"), lang?.let { "${it.flag} ${it.native}" }) { onOpen(Page.LANGUAGE) }
        }

        val listed = child.listedWorlds()
        val open = listed.count { child.allows(it.topic) }
        SettingsSection(tr("לְמִידָה")) {
            SettingsRow("🎚️", tr("רָמַת קֹשִׁי"), difficultySummary(child)) { onOpen(Page.DIFFICULTY) }
            RowDivider()
            SettingsRow("🌐", tr("עוֹלָמוֹת פְּעִילִים"), if (listed.isEmpty()) null else tr("%lld מִתּוֹךְ %lld", open, listed.size)) { onOpen(Page.WORLDS) }
            RowDivider()
            // 📝 A world opens straight into regular questions, without the game chooser.
            ToggleRow("📝", tr("רק שאלות רגילות"), tr("בלי מסך המשחקים: בחירת עולם מובילה ישר לשאלות"), child.onlyRegularQuestions) {
                if (it != child.onlyRegularQuestions) write(mapOf("onlyRegularQuestions" to it))
            }
            RowDivider()
            // 🏆 Friends + leaderboards for this child (Families policy: a parent control).
            // Off also takes the child's public card down, so they vanish from every board.
            val friendsOn = child.raw["friendsEnabled"] as? Boolean ?: true
            ToggleRow("🏆", tr("חברים וטבלת שחקנים"), tr("הילד רואה חברים שהוסיף בקוד, ובטבלה הכללית מופיעים שחקנים אחרים רק באות ראשונה"), friendsOn) { on ->
                if (on != friendsOn) {
                    write(mapOf("friendsEnabled" to on))
                    if (!on) scope.launch { runCatching { com.google.firebase.firestore.FirebaseFirestore.getInstance().collection("friendCards").document(child.id).delete() } }
                }
            }
        }

        // רמת קושי חכמה — where the adaptive engine moved each practiced topic.
        val practiced = practicedTopics(child, s)
        if (hasAdaptiveSignal(s) && practiced.isNotEmpty()) {
            val raised = practiced.firstOrNull { adaptiveState(it, child, extras.adaptive).direction == Direction.RAISED }
            val eased = practiced.firstOrNull { adaptiveState(it, child, extras.adaptive).direction == Direction.EASED }
            val sentence = when {
                raised != null -> tr("%@ %@ יפה ב%@, אז המערכת התחילה להוסיף שאלות מעט מאתגרות יותר.", child.name, if (girl) tr("מתקדמת") else tr("מתקדם"), raised.displayName)
                eased != null -> tr("ב%@ המערכת הורידה מעט את הקושי כדי לבנות ביטחון והצלחה.", eased.displayName)
                else -> null
            }
            SettingsSection(tr("רמת קושי חכמה"), sentence) {
                practiced.forEach { t ->
                    val st = adaptiveState(t, child, extras.adaptive)
                    Row(Modifier.fillMaxWidth().padding(vertical = 9.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("${t.emoji} ${t.displayName}", Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, maxLines = 1)
                        st.direction?.let { d ->
                            Text(if (d == Direction.RAISED) "↑ " + tr("מְאַתְגֵּר יוֹתֵר") else "↓ " + tr("בּוֹנֶה בִּטָּחוֹן"),
                                color = if (d == Direction.RAISED) Ink.good else Ink.warn, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 11.sp, maxLines = 1)
                        }
                        Text(st.served.displayName, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.sp,
                            modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(Color.White.copy(alpha = 0.16f))
                                .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(20.dp)).padding(horizontal = 9.dp, vertical = 3.dp))
                    }
                }
            }
        }

        val (capOn, capMin) = child.resolvedCap()
        SettingsSection(tr("זְמַן מָסָךְ")) {
            SettingsRow("⏳", tr("זְמַן מָסָךְ יוֹמִי"), if (capOn) tr("%lld דַּקּוֹת", capMin) else tr("לְלֹא הַגְבָּלָה")) { onOpen(Page.SCREEN_TIME) }
            // 🏫🌙 Hours when minutes don't open (QuietHours.kt).
            RowDivider()
            SettingsRow("🏫", tr("זמן בית ספר"), quietSummary(child.quietHours, QuietKind.SCHOOL)) { onOpen(Page.SCHOOL) }
            RowDivider()
            SettingsRow("🌙", tr("שעת שינה"), quietSummary(child.quietHours, QuietKind.BEDTIME)) { onOpen(Page.BEDTIME) }
            RowDivider()
            // The child's play-protection code — full parental transparency: SEE it, and reset it.
            if (!child.hasPlayPIN) {
                SettingsRow("🔐", tr("קוֹד הַגָּנַת זְמַן הַמִּשְׂחָק"),
                    if (girl) tr("%@ עוֹד לֹא בָּחֲרָה קוֹד", child.name) else tr("%@ עוֹד לֹא בָּחַר קוֹד", child.name), chevron = false, onClick = null)
            } else {
                SettingsRow("🔐", tr("קוֹד הַגָּנַת זְמַן הַמִּשְׂחָק"),
                    if (girl) tr("%@ מַזִּינָה אוֹתוֹ כְּדֵי לִפְתֹּחַ אֶת הַדַּקּוֹת שֶׁצָּבְרָה", child.name) else tr("%@ מַזִּין אוֹתוֹ כְּדֵי לִפְתֹּחַ אֶת הַדַּקּוֹת שֶׁצָּבַר", child.name),
                    chevron = false, onClick = null, trailing = {
                        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                            Text(child.playPIN ?: "", color = Color.White, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp, letterSpacing = 3.sp)
                        }
                        Text(tr("אפס"), color = Color(0xFFFFA94D), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp,
                            modifier = Modifier.clip(RoundedCornerShape(10.dp)).background(Color(0xFFFFA94D).copy(alpha = 0.18f)).clickable { confirmPin = true }
                                .padding(horizontal = 10.dp, vertical = 6.dp))
                    })
            }
        }

        SettingsSection(null) { SettingsRow("👫", tr("חֲבֵרִים")) { onOpen(Page.FRIENDS) } }

        SettingsSection(tr("מִתְקַדֵּם")) {
            SettingsRow("🗑️", tr("לְאַפְשֵׁר מְחִיקַת אַפְּלִיקַצְיוֹת (5 דַּק')"), chevron = false) {
                Commands.allowAppRemoval(child.id)
                remoteNote = if (connected) tr("נִפְתָּח חַלּוֹן שֶׁל 5 דַּקּוֹת לִמְחִיקַת אַפְּלִיקַצְיוֹת בַּמַּכְשִׁיר שֶׁל %@ — מִיָּדִי כְּשֶׁטּוֹפִי פָּתוּחַ שָׁם. אַחַר כָּךְ הַנְּעִילָה חוֹזֶרֶת לְבַד.", child.name)
                    else tr("אֵין כָּרֶגַע מַכְשִׁיר מְחֻבָּר לְ%@ — הַחַלּוֹן יִפָּתַח בָּרֶגַע שֶׁהַמַּכְשִׁיר יִתְחַבֵּר.", child.name)
            }
            RowDivider()
            // Repair for a device that keeps re-uploading wrong numbers: every device drops its cache.
            SettingsRow("🔄", tr("רַעֲנוּן נְתוּנִים בְּכָל הַמַּכְשִׁירִים"), chevron = false) {
                scope.launch { note.report(ChildReportRepository.withRetry { Commands.purgeCaches(child.id) }) }
            }
            RowDivider()
            SettingsRow("↩️", tr("אִפּוּס הִתְקַדְּמוּת"), destructive = true, chevron = false) { confirmReset = true }
            RowDivider()
            SettingsRow("🚮", if (girl) tr("מְחִיקַת הַיַּלְדָּה") else tr("מְחִיקַת הַיֶּלֶד"), destructive = true, chevron = false) { confirmDelete = true }
        }
    }

    if (confirmReset) Confirm(tr("לאפס את ההתקדמות של %@?", child.name),
        tr("פעולה זו תאפס דקות משחק שנצברו, ניקוד הסשן ועונש טעויות. לא יימחקו שמות, פרופילים או פריטי קוסמטיקה."),
        tr("אפס דקות + ניקוד"), cancel = tr("בטל"),
        onConfirm = { scope.launch { note.report(Commands.resetProgress(child.id)) } }, onDismiss = { confirmReset = false })
    // "" (not nil) — the deliberate-clear sentinel; survives sync merges.
    if (confirmPin) Confirm(tr("לאפס את קוד הגנת הזמן של %@?", child.name),
        tr("הקוד שהילד הגדיר לפתיחת זמן משחק יימחק. הילד יוכל להגדיר קוד חדש מהמכשיר שלו. שימושי כשהקוד נשכח."),
        tr("אפס קוד"), cancel = tr("בטל"), onConfirm = { write(mapOf("playPIN" to "")) }, onDismiss = { confirmPin = false })
    if (confirmDelete) Confirm(tr("למחוק את %@?", child.name),
        tr("הילד/ה והנתונים שלו יימחקו מהמשפחה לצמיתות. תוכלו ליצור אותו מחדש בכל עת. מכשיר שמחובר לילד הזה יתנתק."),
        tr("מְחִיקַת יֶלֶד/ה"), cancel = tr("בטל"),
        onConfirm = { scope.launch { if (deleteChild(child.id, note)) onDeleted() } }, onDismiss = { confirmDelete = false })
    remoteNote?.let { Notice(tr("שְׁלִיטָה מֵרָחוֹק"), it) { remoteNote = null } }
}

/** ChildRepository.deleteChild + the DENIED → reassert → retry rule; honest about a failure. */
private suspend fun deleteChild(id: String, note: WriteNote): Boolean {
    suspend fun once() = runCatching { ChildRepository.deleteChild(id) }
    var r = once()
    if ((r.exceptionOrNull() as? FirebaseFirestoreException)?.code == FirebaseFirestoreException.Code.PERMISSION_DENIED) {
        FamilyRepository.reassertMembership(); r = once()
    }
    if (r.isFailure) note.show(tr("הַמְּחִיקָה לֹא הִצְלִיחָה. בִּדְקוּ אֶת חִבּוּר הָאִינְטֶרְנֶט וְנַסּוּ שׁוּב."))
    return r.isSuccess
}

/** The base level the parent set — one name when every open topic shares it. */
private fun difficultySummary(c: Child): String {
    val topics = c.playableTopics.ifEmpty { Topic.entries.toSet() }
    val levels = topics.map { c.difficultyFor(it) }.toSet()
    return if (levels.size == 1) levels.first().displayName else tr("לְפִי נוֹשֵׂא")
}

@Composable
private fun ToggleRow(emoji: String, title: String, subtitle: String?, on: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 9.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        if (emoji.isNotEmpty()) Text(emoji, fontSize = 20.sp, modifier = Modifier.width(28.dp), textAlign = TextAlign.Center)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
            subtitle?.let { Text(it, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 12.5.sp) }
        }
        Switch(on, onChange, colors = SwitchDefaults.colors(checkedTrackColor = Color(0xFF34D399), checkedThumbColor = Color.White,
            uncheckedTrackColor = Color.White.copy(alpha = 0.2f), uncheckedThumbColor = Color.White, uncheckedBorderColor = Color.Transparent))
    }
}

// MARK: - ProfileEditorView (edit mode, parent side)

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ProfileEditor(child: Child, onBack: () -> Unit, onSave: (Map<String, Any?>) -> Unit, onDeleted: () -> Unit, note: WriteNote) {
    val scope = rememberCoroutineScope()
    var name by remember { mutableStateOf(child.name) }
    var gender by remember { mutableStateOf(child.gender) }
    var age by remember { mutableStateOf(AgeBracket.of(child.age)) }
    // Show the AUTO-ADVANCED grade — saving re-stamps the school-year anchor with it.
    val shownGrade = if (child.grade != null) child.effectiveGrade else null
    var grade by remember { mutableStateOf(shownGrade) }
    var level by remember { mutableStateOf(child.learningLevel) }
    var interests by remember { mutableStateOf(child.interests.toSet()) }
    var confirmDelete by remember { mutableStateOf(false) }
    // A grade choice is REQUIRED from the parent: it drives curriculum + the September promotion.
    val canSave = name.isNotBlank() && grade != null

    fun save() {
        if (!canSave) return
        // Only what changed — everything this editor doesn't touch stays as it is in the cloud.
        val f = mutableMapOf<String, Any?>()
        if (name.trim() != child.name) f["name"] = name.trim()
        if (gender != child.gender) f["gender"] = gender ?: FieldValue.delete()
        if (age.raw != child.age) f["age"] = age.raw
        if (grade != shownGrade) { f["grade"] = grade; f["gradeSchoolYear"] = schoolYear() }
        if (level != child.learningLevel || child.raw["learningLevel"] == null) f["learningLevel"] = level.raw
        if (interests != child.interests.toSet()) f["interests"] = interests.toList()
        // A parent-side save is a confirmation — clears the "child picked this grade" flag.
        if (child.gradeSetByChild) f["gradeSetByChild"] = FieldValue.delete()
        onSave(f)
    }

    Scroll {
        PageBar(tr("עֲרוֹךְ פְּרוֹפִיל"), onBack) {
            Text(tr("שְׁמוֹר"), color = if (canSave) Color.White else Color.White.copy(alpha = 0.4f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp,
                modifier = Modifier.clip(RoundedCornerShape(14.dp)).clickable(enabled = canSave) { save() }.padding(horizontal = 10.dp, vertical = 8.dp))
        }
        // The chosen character (picked by the child in the shop) — shown, not edited here, like iOS.
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            ChildAvatar(child, 96.dp)
            Text(name.trim(), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp, maxLines = 1)
        }

        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            FieldLabel(tr("שֵׁם"))
            OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), singleLine = true,
                placeholder = { Text(tr("שֵׁם הַיֶּלֶד/ה"), color = Color.White.copy(alpha = 0.5f), fontFamily = Rounded) },
                textStyle = LocalTextStyle.current.copy(color = Color.White, fontFamily = Rounded, fontSize = 17.sp),
                shape = RoundedCornerShape(16.dp), colors = glassFieldColors())
        }

        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            FieldLabel(tr("יֶלֶד אוֹ יַלְדָּה?"))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                listOf("boy" to ("👦" to tr("יֶלֶד")), "girl" to ("👧" to tr("יַלְדָּה"))).forEach { (raw, v) ->
                    ChoiceTile(gender == raw, Modifier.weight(1f), onClick = { gender = raw }) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(v.first, fontSize = 22.sp)
                            Text(v.second, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
                        }
                    }
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            FieldLabel(tr("בֶּן/בַּת כַּמָּה?"))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                AgeBracket.entries.forEach { a ->
                    ChoiceTile(age == a, Modifier.weight(1f), onClick = {
                        age = a
                        // Keep grade consistent with the bracket: a gan pick makes no sense for an older child.
                        grade?.let { g -> if ((a == AgeBracket.PRE_K && g > 0) || (a != AgeBracket.PRE_K && g < 1)) grade = null }
                    }) {
                        Text(a.emoji, fontSize = 24.sp)
                        Text(a.label, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp, maxLines = 1)
                    }
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            FieldLabel(if (age == AgeBracket.PRE_K) tr("בְּאֵיזֶה גַּן?") else tr("בְּאֵיזוֹ כִּתָּה?"))
            // The grade pulls the age bracket with it — the content follows the grade.
            val pick = { g: Int -> grade = g; age = AgeBracket.forGrade(g) }
            if (age == AgeBracket.PRE_K) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    ChoiceTile(grade == -1, Modifier.weight(1f), onClick = { pick(-1) }) { Text("🧸", fontSize = 22.sp); TileText(tr("טְרוֹם־חוֹבָה")) }
                    ChoiceTile(grade == 0, Modifier.weight(1f), onClick = { pick(0) }) { Text("🎒", fontSize = 22.sp); TileText(tr("גַּן חוֹבָה")) }
                }
            } else {
                val letters = listOf("א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ז׳", "ח׳")
                (0 until 2).forEach { r ->
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        (1..4).forEach { c -> val g = r * 4 + c
                            ChoiceTile(grade == g, Modifier.weight(1f), onClick = { pick(g) }) { TileText(tr(letters[g - 1])) }
                        }
                    }
                }
            }
            if (grade == null) P(tr("חוֹבָה לִבְחֹר — כָּךְ טוֹפִי מַתְאִים אֶת הַשְּׁאֵלוֹת לַתָּכְנִית שֶׁל מִשְׂרַד הַחִנּוּךְ, וְכָל 1 בְּסֶפְּטֶמְבֶּר עוֹלִים כִּתָּה אוֹטוֹמָטִית 🎉"),
                12f, color = Ink.gold2, weight = FontWeight.SemiBold)
        }

        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            FieldLabel(tr("רָמַת לְמִידָה הַתְחָלָתִית"))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                LearningLevel.entries.forEach { l ->
                    ChoiceTile(level == l, Modifier.weight(1f), onClick = { level = l }) {
                        Text(l.emoji, fontSize = 22.sp)
                        Text(l.displayName, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.sp, maxLines = 1)
                    }
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            FieldLabel(tr("תְּחוּמֵי עִנְיָן — מֵהֶם נִבְנוֹת הַשְּׁאֵלוֹת הַמֻּתְאָמוֹת"))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Interests.forEach { i ->
                    val on = interests.contains(i.id)
                    Text("${i.emoji} ${i.label}", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp,
                        modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(Color.White.copy(alpha = if (on) 0.30f else 0.12f))
                            .border(if (on) 2.dp else 1.dp, if (on) Ink.gold2 else Color.White.copy(alpha = 0.18f), RoundedCornerShape(20.dp))
                            .clickable { interests = if (on) interests - i.id else interests + i.id }.padding(horizontal = 14.dp, vertical = 8.dp))
                }
            }
        }

        Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(30.dp)).background(Color.Red.copy(alpha = 0.25f)).clickable { confirmDelete = true }.padding(vertical = 12.dp),
            contentAlignment = Alignment.Center) {
            Text("🗑 " + tr("מְחַק פְּרוֹפִיל"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        }
    }
    if (confirmDelete) Confirm(tr("לִמְחוֹק אֶת הַפְּרוֹפִיל שֶׁל %@?", child.name), null, tr("מְחַק"),
        onConfirm = { scope.launch { if (deleteChild(child.id, note)) onDeleted() } }, onDismiss = { confirmDelete = false })
}

@Composable
private fun TileText(t: String) = Text(t, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, maxLines = 1)

@Composable
private fun glassFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = Color.White, unfocusedTextColor = Color.White, cursorColor = Color.White,
    focusedBorderColor = Color.White.copy(alpha = 0.6f), unfocusedBorderColor = Color.White.copy(alpha = 0.3f),
    focusedContainerColor = Color.White.copy(alpha = 0.14f), unfocusedContainerColor = Color.White.copy(alpha = 0.14f),
)

// MARK: - ChildLanguageView

@Composable
private fun LanguageEditor(child: Child, onBack: () -> Unit, write: (Map<String, Any?>) -> Unit) {
    val chosen = AppLanguage.of(child.language)
    Scroll {
        PageBar(tr("שָׂפָה"), onBack)
        P(tr("בִּחֲרוּ בְּאֵיזוֹ שָׂפָה טוֹפִי יוֹפִיעַ בַּמַּכְשִׁיר שֶׁל %@. הַשִּׁנּוּי מַגִּיעַ לַמַּכְשִׁיר בַּסִּנְכְרוּן הַבָּא.", child.name), 13f)
        SettingsSection(tr("שָׂפַת הָאַפְּלִיקַצְיָה אֵצֶל הַיֶּלֶד"),
            tr("הַשָּׂפָה מְשַׁנָּה גַּם אֶת הַשְּׁאֵלוֹת, לֹא רַק אֶת הַטֶּקְסְטִים. אִם תְּשַׁנּוּ אוֹתָהּ בַּמַּכְשִׁיר שֶׁל הַיֶּלֶד עַצְמוֹ — הַבְּחִירָה הָאַחֲרוֹנָה קוֹבַעַת.")) {
            AppLanguage.entries.forEachIndexed { i, lang ->
                Row(Modifier.fillMaxWidth().clickable {
                    // The device's own picker writes the same field, stamped: last press wins.
                    if (child.language != lang.code) write(mapOf("language" to lang.code, "languageUpdatedAt" to nowSecs()))
                }.padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(lang.flag, fontSize = 24.sp)
                    Text(lang.native, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                    if (lang == chosen) Box(Modifier.size(22.dp).clip(CircleShape).background(Color(0xFF34D399)), contentAlignment = Alignment.Center) {
                        Text("✓", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }
                }
                if (i != AppLanguage.entries.lastIndex) RowDivider()
            }
        }
    }
}

// MARK: - ChildDifficultyView

@Composable
private fun DifficultyEditor(child: Child, onBack: () -> Unit, write: (Map<String, Any?>) -> Unit) {
    Scroll {
        PageBar(tr("רָמַת קוֹשִׁי"), onBack)
        P(tr("בִּחֲרוּ רָמַת קוֹשִׁי לְכָל נוֹשֵׂא עֲבוּר %@. הַשִּׁנּוּי מִסְתַּנְכְרֵן אוֹטוֹמָטִית לַמַּכְשִׁיר שֶׁל הַיֶּלֶד.", child.name), 13f)
        SettingsSection(tr("הָחֵל עַל כָּל הַנּוֹשְׂאִים")) {
            Row(Modifier.padding(vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Difficulty.entries.forEach { d ->
                    Box(Modifier.weight(1f).clip(RoundedCornerShape(20.dp)).background(Color.White.copy(alpha = 0.14f))
                        .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(20.dp))
                        .clickable { write(mapOf("difficultyByTopic" to Topic.entries.associate { it.raw to d.raw })) }.padding(vertical = 9.dp),
                        contentAlignment = Alignment.Center) {
                        Text(d.displayName, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
                    }
                }
            }
        }
        val topics = Topic.entries.filter { !it.isPack || child.allows(it) }
        SettingsSection(tr("לְפִי נוֹשֵׂא")) {
            topics.forEachIndexed { i, t ->
                Column(Modifier.padding(vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("${t.emoji} ${t.displayName}", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                    val cur = child.difficultyFor(t)
                    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Color.White.copy(alpha = 0.12f)).padding(2.dp)) {
                        Difficulty.entries.forEach { d ->
                            val on = d == cur
                            // Merge-writes just this topic's key inside the map.
                            Box(Modifier.weight(1f).clip(RoundedCornerShape(8.dp)).background(if (on) Color.White.copy(alpha = 0.92f) else Color.Transparent)
                                .clickable { if (!on) write(mapOf("difficultyByTopic" to mapOf(t.raw to d.raw))) }.padding(vertical = 7.dp), contentAlignment = Alignment.Center) {
                                Text(d.displayName, color = if (on) Ink.indigo else Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.5.sp)
                            }
                        }
                    }
                }
                if (i != topics.lastIndex) RowDivider()
            }
        }
    }
}

// MARK: - ChildWorldsView

@Composable
private fun WorldsEditor(child: Child, onBack: () -> Unit, write: (Map<String, Any?>) -> Unit) {
    val worlds = child.listedWorlds()
    Scroll {
        PageBar(tr("עוֹלָמוֹת פְּעִילִים"), onBack)
        P(tr("בִּחֲרוּ אֵילוּ עוֹלָמוֹת פְּתוּחִים עֲבוּר %@. עוֹלָם כָּבוּי נֶעֱלָם מֵהַמָּסָךְ, וְהַיֶּלֶד לֹא מְקַבֵּל מִמֶּנּוּ שְׁאֵלוֹת. הַשִּׁנּוּי מִסְתַּנְכְרֵן אוֹטוֹמָטִית לַמַּכְשִׁיר שֶׁל הַיֶּלֶד.", child.name), 13f)
        SettingsSection(tr("עוֹלָמוֹת פְּעִילִים"),
            tr("\"טוֹפִי טַיים\" תָּמִיד פְּתוּחָה וּמַגִּישָׁה רַק מֵהַנּוֹשְׂאִים הַפְּעִילִים. חַיָּב לְהִשָּׁאֵר לְפָחוֹת עוֹלָם אֶחָד פָּתוּחַ.")) {
            worlds.forEachIndexed { i, w ->
                Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(w.emoji, fontSize = 22.sp)
                    Column(Modifier.weight(1f)) {
                        Text(w.name, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                        Text(w.topic.displayName, color = Ink.secondary, fontFamily = Rounded, fontSize = 12.sp)
                    }
                    Switch(child.allows(w.topic), { on -> toggleWorld(child, w, on, write) },
                        colors = SwitchDefaults.colors(checkedTrackColor = Color(0xFF34D399), checkedThumbColor = Color.White,
                            uncheckedTrackColor = Color.White.copy(alpha = 0.2f), uncheckedThumbColor = Color.White, uncheckedBorderColor = Color.Transparent))
                }
                if (i != worlds.lastIndex) RowDivider()
            }
        }
    }
}

private fun toggleWorld(child: Child, w: World, on: Boolean, write: (Map<String, Any?>) -> Unit) {
    val t = w.topic
    if (t.isPack) {
        // A pack: the parent's per-child switch (the family keeps the pack).
        write(mapOf("disabledPacks" to if (on) FieldValue.arrayRemove(t.raw) else FieldValue.arrayUnion(t.raw)))
        return
    }
    val set = child.enabledTopicSet.toMutableSet()
    if (on) set += t else {
        // Never close the last open world — the switch just springs back.
        val openBase = child.listedWorlds().count { !it.topic.isPack && child.allows(it.topic) }
        if (openBase <= 1) return
        set -= t
    }
    write(enabledTopicsFields(set))
}

// MARK: - ChildScreenTimeView

@Composable
private fun ScreenTimeEditor(child: Child, onBack: () -> Unit, write: (Map<String, Any?>) -> Unit, registerSave: (() -> Unit) -> Unit) {
    val stored = child.dailyCapMinutes
    var limited by remember { mutableStateOf(stored?.let { it > 0 } ?: true) }
    var minutes by remember { mutableIntStateOf(stored?.takeIf { it > 0 } ?: DEFAULT_CAP) }
    var text by remember { mutableStateOf(minutes.toString()) }
    fun clamped(v: Int) = v.coerceIn(5, 600)

    // Saved when the page closes — one write per edit session, not per keystroke.
    val save = {
        val value = if (limited) clamped(minutes) else 0
        // Inheriting the default (nil) and still showing it → don't freeze the child onto an override.
        val skip = (stored == null && value == DEFAULT_CAP) || stored == value
        if (!skip) write(mapOf("dailyCapMinutes" to value))
    }
    SideEffect { registerSave(save) }

    Scroll {
        PageBar(tr("זְמַן מָסָךְ יוֹמִי"), onBack)
        P(tr("בִּחֲרוּ כַּמָּה דַּקּוֹת מָסָךְ בְּיוֹם עֲבוּר %@. הַשִּׁנּוּי מִסְתַּנְכְרֵן אוֹטוֹמָטִית לַמַּכְשִׁיר שֶׁל הַיֶּלֶד.", child.name), 13f)
        SettingsSection(tr("מַקְסִימוּם זְמַן מָסָךְ יוֹמִי"),
            tr("הַיֶּלֶד מַרְוִיחַ עַד הַתִּקְרָה הַזּוֹ בִּלְמִידָה. בּוֹנוּסִים מֵהַגַּלְגַּל/קוּפְסָה נִשְׁמָרִים לְמָחָר כְּשֶׁמַּגִּיעִים לַתִּקְרָה.")) {
            ToggleRow("", tr("הַגְבָּלַת זְמַן יוֹמִית"), null, limited) { limited = it; if (it && minutes < 5) { minutes = 60; text = "60" } }
            RowDivider()
            if (limited) {
                Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(tr("דַּקּוֹת בְּיוֹם"), Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontSize = 16.sp)
                    StepButton("−") { minutes = clamped(minutes - 5); text = minutes.toString() }
                    OutlinedTextField(text, { v -> text = v.filter(Char::isDigit).take(3); text.toIntOrNull()?.let { minutes = it } },
                        Modifier.width(84.dp), singleLine = true, shape = RoundedCornerShape(10.dp), colors = glassFieldColors(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        textStyle = LocalTextStyle.current.copy(color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, textAlign = TextAlign.Center))
                    StepButton("+") { minutes = clamped(minutes + 5); text = minutes.toString() }
                }
                P(readout(clamped(minutes)), 13f, Modifier.padding(bottom = 8.dp))
            } else {
                Row(Modifier.fillMaxWidth().padding(vertical = 10.dp)) {
                    Text(tr("לְלֹא הַגְבָּלָה"), Modifier.weight(1f), color = Ink.secondary, fontFamily = Rounded, fontSize = 16.sp)
                    Text("♾️")
                }
            }
        }
    }
}

@Composable
private fun StepButton(label: String, onClick: () -> Unit) {
    Box(Modifier.size(38.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.18f)).border(1.dp, Color.White.copy(alpha = 0.35f), CircleShape).clickable(onClick = onClick),
        contentAlignment = Alignment.Center) { Text(label, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Black) }
}

/** "שעה ו-30 דקות ביום" — the friendly hours:minutes readout (catalog wording in every language). */
private fun readout(m: Int): String {
    val h = m / 60; val r = m % 60
    val hWord = if (h == 1) tr("שָׁעָה") else tr("%lld שָׁעוֹת", h)
    if (h == 0) return tr("%lld דַּקּוֹת בְּיוֹם", r)
    if (r == 0) return tr("%@ בְּיוֹם", hWord)
    return tr("%@ וְ-%lld דַּקּוֹת בְּיוֹם", hWord, r)
}

// MARK: - ChildFriendsView

@Composable
private fun FriendsList(child: Child, onBack: () -> Unit, note: WriteNote) {
    val scope = rememberCoroutineScope()
    var friends by remember { mutableStateOf<List<FriendCardLite>?>(null) }
    var loading by remember { mutableStateOf(true) }
    suspend fun reload() {
        loading = true
        val r = ChildReportRepository.friends(child.id)
        if (r == null) note.show(tr("בִּדְקוּ אֶת חִבּוּר הָאִינְטֶרְנֶט וְנַסּוּ שׁוּב."))
        friends = r ?: emptyList(); loading = false
    }
    LaunchedEffect(child.id) { reload() }
    Scroll {
        PageBar(tr("הַחֲבֵרִים שֶׁל %@", child.name), onBack)
        SettingsSection(null) {
            val list = friends.orEmpty()
            when {
                loading -> Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(Modifier.size(24.dp), color = Color.White, strokeWidth = 2.dp) }
                list.isEmpty() -> P(tr("עֲדַיִן אֵין חֲבֵרִים."), 15f, Modifier.padding(vertical = 12.dp))
                else -> list.forEachIndexed { i, f ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        CharacterBadge(f.character3DID, 40.dp)
                        Text(f.displayName, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                        Text("${f.stars} ⭐", color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
                        Text(tr("הָסֵר"), color = Ink.weak, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp,
                            modifier = Modifier.clip(RoundedCornerShape(10.dp)).background(Ink.weak.copy(alpha = 0.16f))
                                .clickable { scope.launch { val out = ChildReportRepository.removeFriend(child.id, f.id); note.report(out); reload() } }
                                .padding(horizontal = 10.dp, vertical = 6.dp))
                    }
                    if (i != list.lastIndex) RowDivider()
                }
            }
        }
    }
}

// MARK: - 🏫 School time / 🌙 bedtime (iOS QuietHoursEditorView)

/** "א׳" in Hebrew, "Sun" elsewhere. Apple numbering: 1 = Sunday … 7 = Saturday. */
private fun dayLetter(weekday: Int): String {
    val lang = com.rani.tofy.i18n.I18n.language
    if (lang == AppLanguage.HE) return listOf("א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ש׳")[(weekday - 1) % 7]
    val dow = if (weekday == 1) java.time.DayOfWeek.SUNDAY else java.time.DayOfWeek.of(weekday - 1)
    return dow.getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale(lang.code))
}

private fun daysText(days: List<Int>): String {
    val d = days.toSortedSet().toList()
    if (d.size == 7) return tr("כל יום")
    if (d.isEmpty()) return "—"
    if (d.size > 2 && d.last() - d.first() == d.size - 1) return "${dayLetter(d.first())}–${dayLetter(d.last())}"
    return d.joinToString(", ") { dayLetter(it) }
}

/** The settings row: "א׳–ו׳ · 08:00–13:30" / "כבוי" / "חופש — מושהה". */
internal fun quietSummary(q: QuietHours?, kind: QuietKind): String {
    val w = if (kind == QuietKind.SCHOOL) q?.school else q?.bedtime
    if (w == null || !w.enabled || w.days.isEmpty()) return tr("כבוי")
    if (kind == QuietKind.SCHOOL && q?.schoolPaused == true) return tr("חופש — מושהה")
    return "${daysText(w.days)} · ⁦${QuietHours.clock(w.start)}–${QuietHours.clock(w.end)}⁩"
}

@Composable
private fun QuietEditor(child: Child, kind: QuietKind, onBack: () -> Unit, write: (Map<String, Any?>) -> Unit, registerSave: (() -> Unit) -> Unit) {
    val school = kind == QuietKind.SCHOOL
    val storedQ = child.quietHours
    val stored = if (school) storedQ?.school else storedQ?.bedtime
    val initial = stored ?: (if (school) QuietHours.SCHOOL_DEFAULT else QuietHours.BEDTIME_DEFAULT).copy(enabled = false)
    var enabled by remember { mutableStateOf(initial.enabled) }
    var days by remember { mutableStateOf(initial.days.toSet()) }
    var start by remember { mutableIntStateOf(initial.start) }
    var end by remember { mutableIntStateOf(initial.end) }
    var shortFriday by remember { mutableStateOf(initial.fridayEnd != null && initial.fridayEnd != initial.end) }
    var fridayEnd by remember { mutableIntStateOf(initial.fridayEnd ?: initial.end) }
    val todayKey = QuietHours.dayKey(java.time.LocalDate.now())
    var offToday by remember { mutableStateOf(storedQ?.schoolOffDay == todayKey) }
    var paused by remember { mutableStateOf(storedQ?.schoolPaused == true) }

    // Saved when the page closes — one write per edit session (iOS onDisappear).
    val save = {
        val w = QuietWindow(enabled, days.sorted(), start, end, if (school && shortFriday) fridayEnd else null)
        val base = storedQ ?: QuietHours()
        val q = if (school) base.copy(school = w, schoolOffDay = if (offToday) todayKey else null, schoolPaused = if (paused) true else null)
                else base.copy(bedtime = w)
        val untouched = storedQ == null && q.isEmpty && !offToday && !paused
        if (!untouched && q != storedQ) write(mapOf("quietHours" to q.toMap()))
    }
    SideEffect { registerSave(save) }

    Scroll {
        PageBar(if (school) tr("🏫 זמן בית ספר") else tr("🌙 שעת שינה"), onBack)
        SettingsSection(null, tr("בשעות האלה אי אפשר לפתוח דקות משחק. טופי והאפליקציות שתמיד פתוחות נשארים פתוחים, ואפשר להמשיך לענות ולצבור דקות לאחר כך. פתיחה ידנית שלכם תמיד עובדת.")) {
            ToggleRow("", if (school) tr("זמן בית ספר פעיל") else tr("שעת שינה פעילה"), null, enabled) { enabled = it }
        }
        if (enabled) {
            SettingsSection(tr("ימים")) {
                Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (d in 1..7) {
                        val on = d in days
                        Box(Modifier.weight(1f).height(38.dp).clip(RoundedCornerShape(10.dp))
                            .background(if (on) Color(0xFF06D6A0).copy(alpha = 0.55f) else Color.White.copy(alpha = 0.10f))
                            .clickable { days = if (on) days - d else days + d },
                            contentAlignment = Alignment.Center) {
                            Text(dayLetter(d), color = if (on) Color.White else Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
                        }
                    }
                }
            }
            SettingsSection(tr("שעות"), if (school) null else tr("שעת השינה נמשכת עד הבוקר שאחרי.")) {
                TimeStepRow(tr("שעת התחלה"), start) { start = it }
                RowDivider()
                TimeStepRow(tr("שעת סיום"), end) { end = it }
                if (school) {
                    RowDivider()
                    ToggleRow("", tr("ביום שישי מסיימים מוקדם"), null, shortFriday) { shortFriday = it }
                    if (shortFriday) { RowDivider(); TimeStepRow(tr("סיום ביום שישי"), fridayEnd) { fridayEnd = it } }
                }
            }
            if (school) {
                SettingsSection(tr("חגים וחופשות"), tr("\"היום אין לימודים\" חל רק על היום. מחר זמן בית הספר חוזר כרגיל.")) {
                    ToggleRow("", tr("היום אין לימודים"), null, offToday) { offToday = it }
                    RowDivider()
                    ToggleRow("", tr("חופש — זמן בית הספר מושהה"), null, paused) { paused = it }
                }
            }
        }
    }
}

/** "התחלה  − 08:00 +" — 15-minute steps, wrapping around midnight. */
@Composable
private fun TimeStepRow(title: String, minutes: Int, onChange: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontSize = 16.sp)
        StepButton("−") { onChange(((minutes - 15) % 1440 + 1440) % 1440) }
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Text(QuietHours.clock(minutes), Modifier.width(70.dp), color = Color.White, fontFamily = Rounded,
                fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, textAlign = TextAlign.Center)
        }
        StepButton("+") { onChange((minutes + 15) % 1440) }
    }
}
