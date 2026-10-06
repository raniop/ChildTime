package com.rani.tofy.kid.ui

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.ContextWrapper
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.google.firebase.firestore.FirebaseFirestore
import com.rani.tofy.data.Child
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.Household
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.content.ChildContentProfile
import com.rani.tofy.kid.content.ContentMode
import com.rani.tofy.kid.content.QuestionSource
import com.rani.tofy.kid.core.KidEvent
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.core.OpenResult
import com.rani.tofy.kid.core.ProgressEngine
import com.rani.tofy.kid.core.ProgressEvent
import com.rani.tofy.kid.core.RewardEngine
import com.rani.tofy.kid.enforce.ChildLockSetupScreen
import com.rani.tofy.kid.enforce.EnforcementStatus
import com.rani.tofy.kid.enforce.EnforcementStore
import com.rani.tofy.kid.ui.games.GamesMenuScreen
import com.rani.tofy.kid.ui.games.WorldGameChooser
import com.rani.tofy.kid.ui.games.worldOpensStraightToQuestions
import com.rani.tofy.kid.ui.home.ConversionConfig
import com.rani.tofy.kid.ui.home.HomeCtaModel
import com.rani.tofy.kid.ui.home.HomeExtras
import com.rani.tofy.kid.ui.home.HomeTile
import com.rani.tofy.kid.ui.home.KidDeepLinks
import com.rani.tofy.kid.ui.home.KidHome
import com.rani.tofy.kid.ui.home.KidWorld
import com.rani.tofy.kid.ui.home.allWorlds
import com.rani.tofy.kid.ui.home.homeTiles
import com.rani.tofy.kid.ui.play.QuestionRunnerScreen
import com.rani.tofy.kid.ui.shop.CharacterCollectionScreen
import com.rani.tofy.kid.ui.shop.DailyChestScreen
import com.rani.tofy.kid.ui.shop.ShopScreen
import com.rani.tofy.kid.ui.shop.WheelScreen
import com.rani.tofy.kid.ui.shop.dailyChestReady
import com.rani.tofy.kid.ui.shop.grantComebackWheelIfReturning
import com.rani.tofy.kid.ui.shop.wheelSpinsAvailable
import com.rani.tofy.kid.ui.social.FriendsRepository
import com.rani.tofy.kid.ui.social.FriendsScreen
import com.rani.tofy.kid.ui.social.KidChoresScreen
import com.rani.tofy.kid.ui.social.LiveGameRepository
import com.rani.tofy.kid.ui.social.LiveInviteBanner
import com.rani.tofy.kid.ui.social.LiveQuizScreen
import com.rani.tofy.kid.ui.social.choresDoneTodayCount
import com.rani.tofy.kid.ui.social.choresTotalCount
import com.rani.tofy.kid.ui.social.pendingChoresCount
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.child.hasPlayPIN
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** One-time wiring of the kid layers (idempotent; Application.onCreate would do too). */
internal object KidBoot {
    private var done = false
    fun init(ctx: Context) {
        if (done) return
        done = true
        KidBinding.init(ctx)
        KidSession.init(ctx)            // idempotent; TofyApp also inits it (and QuestionSource)
        ConversionConfig.start()
    }
}

private tailrec fun Context.activity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.activity()
    else -> null
}

private fun Activity.isPinned(): Boolean =
    (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE

/**
 * KidRoot: ContentView.childPlay / kidModeRoot. On a child device whose
 * binding was dropped (parent removed it, or "disconnect" behind the gear) it
 * shows the reconnect screen in place; in Kid Mode it first explains the
 * screen pinning, pins, and un-pins only after the parent gate.
 */
@Composable
internal fun KidRootImpl(childID: String, kidMode: Boolean, onExitKidMode: () -> Unit) {
    val ctx = LocalContext.current
    remember { KidBoot.init(ctx) }
    val binding by KidBinding.state.collectAsState()
    val activity = remember { ctx.activity() }

    if (!kidMode && binding.joinedChildID == null && binding.justDisconnected) {
        ChildJoinFlow(onJoined = {}, onBack = {})
        return
    }
    val cid = if (kidMode) childID else (binding.joinedChildID ?: childID)

    if (kidMode) {
        // rememberSaveable: the system "App is pinned" dialog can recreate the
        // activity, and a plain remember dropped the parent back on this intro.
        var started by androidx.compose.runtime.saveable.rememberSaveable { mutableStateOf(activity?.isPinned() == true) }
        if (!started) {
            val doc by KidSession.childDoc.collectAsState()
            val child = doc?.takeIf { KidSession.boundChildID == cid }?.let { Child.from(cid, it) }
                ?: FamilyRepository.state.value.children.firstOrNull { it.id == cid }
            KidModeIntro(child, onStart = {
                runCatching { activity?.startLockTask() }
                started = true
            }, onCancel = onExitKidMode)
            return
        }
    }
    KidExperience(cid, kidMode, onExitKidMode = {
        KidSession.unbind()
        if (activity?.isPinned() == true) runCatching { activity.stopLockTask() }
        onExitKidMode()
    })
}

/** households/{hid} for the kid side — the parent repo's copy in Kid Mode, else our own listener. */
@Composable
private fun rememberHousehold(hid: String?): Pair<Household?, Boolean> {
    val family by FamilyRepository.state.collectAsState()
    val fromFamily = family.household?.takeIf { it.id == hid }
    var own by remember(hid) { mutableStateOf<Household?>(null) }
    var loaded by remember(hid) { mutableStateOf(false) }
    DisposableEffect(hid, fromFamily != null) {
        if (hid == null || fromFamily != null) return@DisposableEffect onDispose {}
        val reg = FirebaseFirestore.getInstance().collection("households").document(hid).addSnapshotListener { s, err ->
            if (err != null) { loaded = true; return@addSnapshotListener }
            s?.data?.let { own = Household.from(hid, it) }
            if (s != null && !s.metadata.isFromCache) loaded = true
        }
        onDispose { reg.remove() }
    }
    val hh = fromFamily ?: own
    return hh to (hh != null || loaded)
}

private sealed class Cover {
    data object Settings : Cover()
    data object KidExit : Cover()
    data class Ask(val world: KidWorld?) : Cover()
    data object PlayPin : Cover()
    data object PinForgot : Cover()
    data object Challenge : Cover()
    data object Level : Cover()
}

/** The full-screen kid destinations WorldMapView presents as fullScreenCovers. */
private sealed class KidScreen {
    data object Shop : KidScreen()
    data object Characters : KidScreen()
    data object Friends : KidScreen()
    data class LiveQuiz(val gameID: String?) : KidScreen()
    data object Chores : KidScreen()
    data object Games : KidScreen()
    data object Wheel : KidScreen()
    data object Chest : KidScreen()
    /** The guard's manage screen, from the parent-gated ⚙️. */
    data object AppLock : KidScreen()
}

/**
 * WorldEntryView: a tapped world decides ONCE whether it opens to the game
 * chooser or straight to its questions; [questions] = the chooser's 📝 card
 * opened the runner on top of it (closing it returns to the chooser).
 */
private data class WorldEntry(val world: KidWorld, val straight: Boolean, val questions: Boolean = false)

@Composable
private fun KidExperience(cid: String, kidMode: Boolean, onExitKidMode: () -> Unit) {
    remember(cid, kidMode) { KidSession.bind(cid, kidMode); 0 }
    val scope = rememberCoroutineScope()
    val state by KidSession.state.collectAsState()
    val lease by KidSession.lease.collectAsState()
    val doc by KidSession.childDoc.collectAsState()
    val opening by KidSession.opening.collectAsState()
    val conv by ConversionConfig.values.collectAsState()
    val nowMs by produceState(System.currentTimeMillis()) { while (true) { delay(1000); value = System.currentTimeMillis() } }

    val child = doc?.let { Child.from(cid, it) } ?: FamilyRepository.state.value.children.firstOrNull { it.id == cid }
    val (household, householdLoaded) = rememberHousehold(child?.householdID?.takeIf { it.isNotEmpty() })
    val lang = AppLanguage.of(child?.language) ?: I18n.language
    val childNow by rememberUpdatedState(child)

    var playing by remember { mutableStateOf<ContentMode?>(null) }
    var cover by remember { mutableStateOf<Cover?>(null) }
    var pendingOpen by remember { mutableStateOf<(suspend () -> Unit)?>(null) }
    var buddy by remember { mutableStateOf<String?>(null) }
    var buddyJob by remember { mutableStateOf<Job?>(null) }
    var transferring by remember { mutableStateOf(false) }
    var transferTimedOut by remember { mutableStateOf(false) }
    var playable by remember { mutableStateOf<Set<Topic>>(emptySet()) }
    var greeted by remember { mutableStateOf(false) }
    var screen by remember { mutableStateOf<KidScreen?>(null) }
    var entry by remember { mutableStateOf<WorldEntry?>(null) }
    val ctx = LocalContext.current
    // 🛡 ChildLockSetup.markPending → step ④ on a child device, before its home (iOS ContentView cover).
    var lockSetupDone by remember { mutableStateOf(kidMode || EnforcementStore.setupDone(ctx)) }

    fun say(line: String) {
        buddyJob?.cancel()
        buddy = line
        buddyJob = scope.launch { delay(3800); buddy = null }
    }

    // ── lifecycle: foreground/background reports + the content preload ─────
    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val obs = LifecycleEventObserver { _, e ->
            when (e) {
                Lifecycle.Event.ON_START -> {
                    KidSession.onForeground(); QuestionSource.refreshCloud()
                    // shieldAuthorized / newAppsLocked for the heartbeat (+ the parent's "lock is off" push).
                    EnforcementStatus.refresh(ctx)
                }
                Lifecycle.Event.ON_STOP -> {
                    KidSession.onBackground()
                    // The device is in the kid's hands: leaving the app closes the parent's corner.
                    if (cover == Cover.Settings || cover == Cover.KidExit) cover = null
                }
                else -> Unit
            }
        }
        owner.lifecycle.addObserver(obs)
        onDispose { owner.lifecycle.removeObserver(obs) }
    }
    LaunchedEffect(lang) { runCatching { QuestionSource.preload(lang) } }

    // Profile.playableTopics for the grid — off the main thread (it reads the banks).
    val snapDoc = state?.snapshot
    LaunchedEffect(child?.raw, household?.isPremium, lang) {
        val c = child ?: return@LaunchedEffect
        playable = withContext(Dispatchers.Default) {
            runCatching { ChildContentProfile.from(c, household, snapDoc?.toFirestore(), lang).playableTopics() }.getOrDefault(emptySet())
        }
    }

    // ── KidEvents ───────────────────────────────────────────────────────────
    LaunchedEffect(cid) {
        KidSession.events.collect { ev ->
            when (ev) {
                KidEvent.RemoteLock -> { playing = null; say(tr("הַהוֹרִים עָצְרוּ אֶת זְמַן הַמִּשְׂחָק — הַדַּקּוֹת שֶׁנִּשְׁאֲרוּ שְׁמוּרוֹת 😊")) }
                is KidEvent.RemoteUnlock -> say(tr("הַהוֹרִים פָּתְחוּ זְמַן מִשְׂחָק 🎉"))
                KidEvent.WindowTakenByOtherDevice -> say(tr("הַזְּמַן עָבַר לְמַכְשִׁיר אַחֵר — הַדַּקּוֹת שֶׁנִּשְׁאֲרוּ שְׁמוּרוֹת 😊"))
                KidEvent.WindowEnded -> KidSession.reportEvent("screenTimeEnd", extra = mapOf("minutes" to 0))
                is KidEvent.GiftArrived -> if (ev.minutes > 0) say(
                    if (childNow?.isGirl == true) tr("קִבַּלְתְּ %lld דַּקּוֹת מַתָּנָה מֵהַהוֹרִים 💝", ev.minutes)
                    else tr("קִבַּלְתָּ %lld דַּקּוֹת מַתָּנָה מֵהַהוֹרִים 💝", ev.minutes),
                )
                is KidEvent.ResetApplied -> QuestionSource.memory(cid).clear()
                KidEvent.DeviceRemoved -> {
                    QuestionSource.memory(cid).clear()
                    if (kidMode) onExitKidMode() else KidBinding.disconnected()
                }
                KidEvent.OpenSlow -> say(tr("רֶגַע, הָאִינְטֶרְנֶט קְצָת אִטִּי — נְנַסֶּה שׁוּב? 😊"))
                // ProgressStore.unlockWorld: one row in the parent's activity centre, by NAME.
                is KidEvent.Progress -> (ev.event as? ProgressEvent.WorldUnlocked)?.let { u ->
                    KidSession.reportEvent("worldUnlocked", value = allWorlds().firstOrNull { it.id == u.worldID }?.name ?: u.worldID)
                }
                is KidEvent.MinutesAdjusted, is KidEvent.GiftRevoked, is KidEvent.AppRemovalWindow -> Unit
            }
        }
    }

    // checkWorldUnlocks + the greeting, once the engine is up.
    LaunchedEffect(cid, state != null) {
        if (state == null) return@LaunchedEffect
        val e = KidSession.engine() ?: return@LaunchedEffect
        // Every world's starsToUnlock is 0 (World.swift), so this only fills in the list.
        val missing = allWorlds().filter { it.id !in e.snapshot.unlockedWorlds }
        missing.forEach { w -> KidSession.edit { it.unlockWorld(w.id) } }
        if (!greeted) {
            greeted = true
            delay(500)
            val ds = KidSession.engine()?.snapshot?.dayStreak ?: 0
            say(when (ds) { 0 -> tr("הֵיי! יַאלְלָה לְהַרְפַּתְקָה 🌟"); 1 -> tr("בָּרוּךְ הַבָּא! 👋"); else -> tr("חָזַרְתָּ! %lld יָמִים בְּרֶצֶף 🔥", ds) })
        }
    }

    if (!lockSetupDone) {
        ChildLockSetupScreen(onDone = { lockSetupDone = true; EnforcementStatus.refresh(ctx) }, fromOnboarding = true)
        return
    }

    val st = state
    val engine = KidSession.engine()
    if (st == null || engine == null) { Box(Modifier.fillMaxSize()); return }

    // Kid Mode: system back never leaves — it asks for the parent code.
    BackHandler(enabled = kidMode && cover == null && playing == null && entry == null && screen == null) { cover = Cover.KidExit }

    // ── routing ────────────────────────────────────────────────────────────
    playing?.let { mode ->
        QuestionRunnerScreen(mode) { playing = null }
        return
    }
    entry?.let { e ->
        key(e) {
            val mode = e.world.topic?.let { ContentMode.World(it) } ?: ContentMode.BonusArena
            if (e.straight || e.questions) QuestionRunnerScreen(mode) { entry = if (e.straight) null else e.copy(questions = false) }
            else WorldGameChooser(e.world.topic?.raw ?: e.world.id, onPlayQuestions = { entry = e.copy(questions = true) }, onExit = { entry = null })
        }
        return
    }
    screen?.let { s ->
        val close = { screen = null }
        when (s) {
            KidScreen.Shop -> ShopScreen(close)
            KidScreen.Characters -> CharacterCollectionScreen(close)
            KidScreen.Friends -> FriendsScreen(close)
            is KidScreen.LiveQuiz -> LiveQuizScreen(s.gameID, close)
            KidScreen.Chores -> KidChoresScreen(close)
            KidScreen.Games -> GamesMenuScreen(close)
            KidScreen.Wheel -> WheelScreen(close)
            KidScreen.Chest -> DailyChestScreen(close)
            KidScreen.AppLock -> ChildLockSetupScreen(onDone = { close(); EnforcementStatus.refresh(ctx) }, fromOnboarding = false)
        }
        return
    }
    val unlocked = nowMs > 0 && engine.isUnlocked   // nowMs: re-read the window every second
    val isGirl = child?.isGirl == true

    // Open helpers (WorldMapView.redeemMinutes / redeemGift) — every OpenResult said kindly.
    fun handle(r: OpenResult, gift: Boolean) {
        when (r) {
            is OpenResult.Opened, OpenResult.AlreadyOpen, OpenResult.Busy -> Unit
            is OpenResult.HeldElsewhere -> say(tr("הַזְּמַן שֶׁלְּךָ פָּתוּחַ עַכְשָׁיו בְּמַכְשִׁיר אַחֵר 🎮"))
            OpenResult.Insufficient -> say(tr("עוֹד קְצָת דַּקּוֹת וְנִפְתַּח לְךָ! 💪"))
            is OpenResult.Failed -> say(when {
                !gift -> tr("רֶגַע, לֹא הִצְלַחְנוּ לִפְתֹּחַ עַכְשָׁיו — נְנַסֶּה שׁוּב 😊")
                r.tellParent -> tr("רֶגַע, אֲנִי בּוֹדֵק אֶת הַמַּתָּנָה שֶׁלְּךָ — סִפַּרְתִּי לַהוֹרִים שֶׁלְּךָ וְהֵם יַעַזְרוּ 😊")
                else -> tr("רֶגַע, אֲנִי בּוֹדֵק אֶת הַמַּתָּנָה שֶׁלְּךָ — נְנַסֶּה שׁוּב? 😊")
            })
            OpenResult.NothingToOpen -> say(if (gift) tr("רֶגַע, אֲנִי בּוֹדֵק אֶת הַמַּתָּנָה שֶׁלְּךָ — נְנַסֶּה שׁוּב? 😊")
                else tr("עֲנוּ עַל שְׁאֵלוֹת כְּדֵי לְהַרְוִיחַ דַּקּוֹת מִשְׂחָק 🎮"))
        }
    }
    // The child's own play code first, when they set one (requestUnlock).
    fun requestUnlock(action: suspend () -> Unit) {
        if (opening != null) return
        if (child?.hasPlayPIN == true) { pendingOpen = action; cover = Cover.PlayPin }
        else scope.launch { action() }
    }
    fun stopAndSave() {
        val banked = KidSession.stop()
        KidSession.reportEvent("screenTimeEnd", extra = mapOf("minutes" to banked))
        KidSession.pushNow()
    }

    Box(Modifier.fillMaxSize()) { when {
        cover == Cover.KidExit -> ParentGate(household?.parentPinHash, householdLoaded,
            tr("יְצִיאָה מִמַּצַּב יֶלֶד וְשִׁחְרוּר נְעִילַת הַמַּכְשִׁיר"), tr("אַמְּתוּ זֶהוּת כְּדֵי לָצֵאת מִמַּצַּב יֶלֶד"),
            onAuthorized = { cover = null; onExitKidMode() }, onClose = { cover = null })
        cover == Cover.PlayPin -> KidPinVerify(child?.playPIN.orEmpty(),
            onSuccess = { cover = null; val a = pendingOpen; pendingOpen = null; a?.let { scope.launch { it() } } },
            onCancel = { cover = null; pendingOpen = null }, onForgot = { pendingOpen = null; cover = Cover.PinForgot })
        cover == Cover.PinForgot -> KidPinForgot(child?.name.orEmpty(), household?.parentPinHash, householdLoaded,
            onParentReset = {
                cover = null
                // "" (not deleted) — the deliberate-clear sentinel that survives sync merges.
                scope.launch { JoinRepository.childWrite(cid, child?.householdID, mapOf("playPIN" to "")) }
                say(tr("הַקּוֹד אֻפַּס! אֶפְשָׁר לִבְחוֹר חָדָשׁ 🔓"))
            }, onClose = { cover = null })
        unlocked || opening != null -> UnlockedScreen(
            preparing = opening != null && !unlocked,
            gift = if (opening != null && !unlocked) opening?.gift == true else engine.local.unlockIsManual,
            secondsRemaining = engine.unlockSecondsRemaining, isGirl = isGirl, kidMode = kidMode, buddyLine = buddy,
            onStop = { stopAndSave() }, onKidExit = { cover = Cover.KidExit },
        )
        child != null && child.grade == null -> ChildGradePicker(child.name, isGirl) { g ->
            scope.launch { saveChildGrade(cid, child.householdID, g) }
        }
        else -> {
            val premium = household?.isPremium == true
            // The games' daily warm-up: one reward batch (10) for readers, 5 for גן kids.
            val gamesTarget = if ((child?.effectiveGrade ?: 1) <= 0) 5 else 10
            val tiles = remember(child?.raw, premium, playable, st.snapshot.worldProgress, conv, nowMs / 3_600_000) {
                homeTiles(child, cid, child?.effectiveGrade ?: 1, premium, playable, st.snapshot.worldProgress, conv)
            }
            val peer = if (lease.isHeldElsewhere()) (lease.ownerKind ?: "other") to lease.remainingSeconds() else null
            val cap = engine.settings.dailyCap
            val cta = HomeCtaModel(
                giftSeconds = engine.openableSeconds(true),
                opening = opening != null, openingGift = opening?.gift == true,
                peer = peer, transferring = transferring, transferTimedOut = transferTimedOut,
                canRedeem = engine.canRedeemNow, redeemableSeconds = engine.redeemableSecondsNow,
                maxedOut = engine.dailyScreenTimeMaxedOut, minutesPlayedToday = engine.minutesPlayedToday,
                capMax = cap.max, pendingMinutes = engine.pendingMinutes, redeemableMinutes = engine.redeemableMinutesNow,
            )
            KidHome(
                childID = cid, child = child, state = st, engine = engine, premium = premium, kidMode = kidMode,
                tiles = tiles, cta = cta, buddyLine = buddy,
                onSettings = { cover = Cover.Settings },
                onKidExit = { cover = Cover.KidExit },
                onTile = { t ->
                    when (t) {
                        HomeTile.TofyTime -> playing = ContentMode.SmartFeed
                        is HomeTile.WorldTile -> when {
                            !t.open -> cover = Cover.Ask(t.world)   // the kid screen never sells — ask a parent
                            // WorldEntryView: the chooser, or straight to questions (decided once, on tap).
                            else -> entry = WorldEntry(t.world, worldOpensStraightToQuestions(t.world.topic?.raw ?: t.world.id))
                        }
                    }
                },
                onChallenge = { cover = if (premium) Cover.Challenge else Cover.Ask(null) },
                onLevelInfo = { cover = Cover.Level },
                onOpenEarned = { requestUnlock { handle(KidSession.openEarned(), false) } },
                onOpenGift = { requestUnlock { handle(KidSession.openGift(), true) } },
                onTransfer = {
                    if (!transferring) scope.launch {
                        transferTimedOut = false; transferring = true
                        val r = KidSession.transferHere()
                        transferring = false
                        if (r is OpenResult.Opened) say(tr("נָעוּל שָׁם! ✅ אֶפְשָׁר לְשַׂחֵק כָּאן 🎉")) else transferTimedOut = true
                    }
                },
                extras = HomeExtras(
                    friendsBadge = LiveGameRepository.invites.isNotEmpty(),
                    chestReady = dailyChestReady(),
                    choresPending = pendingChoresCount(), choresDoneToday = choresDoneTodayCount(), choresTotal = choresTotalCount(),
                    correctToday = st.snapshot.correctToday, gamesGateTarget = gamesTarget,
                ),
                onShop = { screen = KidScreen.Shop },
                onFriends = { screen = KidScreen.Friends },
                onAvatar = { screen = KidScreen.Characters },
                // Everything on the home but טופי טיים, the shop and friends is Tofy+ (requirePremium → ask a parent).
                onChores = { if (premium) screen = KidScreen.Chores else cover = Cover.Ask(null) },
                onGames = {
                    when {
                        !premium -> cover = Cover.Ask(null)
                        st.snapshot.correctToday >= gamesTarget -> screen = KidScreen.Games
                        else -> say(tr("עוֹד %lld תְּשׁוּבוֹת נְכוֹנוֹת וְהַמִּשְׂחָקִים נִפְתָּחִים! 🎮", gamesTarget - st.snapshot.correctToday))
                    }
                },
                onChest = { screen = KidScreen.Chest },
                inviteBanner = { LiveInviteBanner { id -> screen = KidScreen.LiveQuiz(id) } },
            )

            // WorldMapView.onAppear (and the return from a round / world, which iOS
            // watches separately): the comeback spin, then the wheel if a spin waits,
            // and one line the first time today the games open.
            LaunchedEffect(Unit) {
                grantComebackWheelIfReturning()
                if (st.snapshot.correctToday >= gamesTarget) {
                    val p = ctx.getSharedPreferences("tofy", android.content.Context.MODE_PRIVATE)
                    val today = java.time.LocalDate.now().toString()
                    if (p.getString("gamesUnlockCelebratedDate", null) != today) {
                        p.edit().putString("gamesUnlockCelebratedDate", today).apply()
                        launch { delay(1200); say(if (isGirl) tr("פָּתַחְתְּ אֶת הַמִּשְׂחָקִים לְהַיּוֹם! 🎮✨") else tr("פָּתַחְתָּ אֶת הַמִּשְׂחָקִים לְהַיּוֹם! 🎮✨")) }
                    }
                }
                delay(600)
                // maybeAutoPresentWheel: entering the wheel spends the spin.
                if (wheelSpinsAvailable() > 0 && cover == null && screen == null && playing == null && entry == null) screen = KidScreen.Wheel
            }
            // A push tap / game link → join it; a friend link → the board (it adds the code).
            val pendingGame = KidDeepLinks.pendingGameID
            val pendingFriend = FriendsRepository.pendingFriendCode
            LaunchedEffect(pendingGame, pendingFriend, cover == null) {
                if (cover != null) return@LaunchedEffect
                if (pendingGame != null) { KidDeepLinks.pendingGameID = null; screen = KidScreen.LiveQuiz(pendingGame) }
                else if (pendingFriend != null) screen = KidScreen.Friends
            }
            when (val c = cover) {
                Cover.Settings -> ParentGateThen(household?.parentPinHash, householdLoaded, onClose = { cover = null }) {
                    KidDeviceControls(
                        child, kidMode, windowOpen = unlocked, secondsLeft = engine.unlockSecondsRemaining,
                        onLockNow = { stopAndSave() },
                        onExitKidMode = { cover = null; onExitKidMode() },
                        onDisconnect = {
                            cover = null
                            // resetAsRemovedDevice: local data only — the cloud is never touched.
                            QuestionSource.memory(cid).clear()
                            KidSession.onDeviceRemoved(cid)
                        },
                        onClose = { cover = null },
                        onAppLock = if (kidMode) null else ({ cover = null; screen = KidScreen.AppLock }),
                    )
                }
                is Cover.Ask -> AskParent(child, cid, child?.householdID, c.world) { cover = null }
                Cover.Challenge -> {
                    val target = ProgressEngine.DAILY_CHALLENGE_TARGET
                    val prize = 15 + minOf(st.snapshot.dayStreak, 7) * 2
                    val ready = engine.dailyChallengeRewardReady
                    ChallengeInfo(engine.dailyChallengeProgress, target, prize, ready, engine.dailyChallengeClaimed, onCta = {
                        cover = null
                        if (ready) {
                            val grant = KidSession.edit { it.claimDailyChallenge() }
                            val total = (grant?.addedToday ?: 0) + (grant?.bankedForTomorrow ?: 0)
                            say(tr("🎉 כָּל הַכָּבוֹד! +%lld 💎", prize) + if (total > 0) tr(" וְ-%lld דַּקּוֹת", total) else "")
                        } else playing = ContentMode.SmartFeed
                    }, onClose = { cover = null })
                }
                Cover.Level -> {
                    val xp = st.snapshot.xp
                    val until = maxOf(0, RewardEngine.xpForNextLevel(xp) - xp + RewardEngine.xpPerCorrect - 1) / maxOf(1, RewardEngine.xpPerCorrect)
                    LevelInfo(engine.companionLevel, until) { cover = null }
                }
                else -> Unit
            }
        }
    } }
}

/** respectSession:false — the gate every time, then the content until it closes. */
@Composable
private fun ParentGateThen(pinHash: String?, householdLoaded: Boolean, onClose: () -> Unit, content: @Composable () -> Unit) {
    var authorized by remember { mutableStateOf(false) }
    if (authorized) content()
    else ParentGate(pinHash, householdLoaded, onAuthorized = { authorized = true }, onClose = onClose)
}
