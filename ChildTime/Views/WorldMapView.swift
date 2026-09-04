import SwiftUI

struct WorldMapView: View {
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var subs: SubscriptionManager
    @ObservedObject private var household = HouseholdManager.shared
    @ObservedObject private var leaseMgr = PlayWindowLeaseManager.shared
    @Environment(\.horizontalSizeClass) private var hsc

    @ObservedObject private var friends = FriendsManager.shared
    @ObservedObject private var liveGame = LiveGameManager.shared
    @ObservedObject private var kidMode = KidModeManager.shared
    @State private var inviteBannerVisible = false
    @State private var showKidExit = false
    @StateObject private var companion = CompanionController()
    @State private var selectedWorld: World?
    @State private var showDailyChest = false
    @State private var challengeCelebration: String? = nil
    @State private var infoSheet: InfoSheet? = nil

    /// Which home-card explainer is open (daily challenge / topic-of-the-day).
    private enum InfoSheet: Int, Identifiable { case dailyChallenge, event; var id: Int { rawValue } }
    @State private var showingParentGate = false
    @State private var showingDemo = false
    /// 🎒 September 1st "you moved up a grade!" party (once per school year).
    @State private var showSchoolYearParty = false
    /// 🎓 Kid-facing grade picker, when the profile has no grade yet.
    @State private var showChildGradePicker = false
    /// Limited-time event SPLASH (💎×2 etc.) — a full pop-up like the lucky
    /// wheel, once a day; the kid closes it or jumps straight in.
    @State private var showEventSplash = false
    /// Drives the daily-challenge card's living flame/gift pulse.
    @State private var challengePulse = false
    @State private var showingShop = false
    @State private var showingWheel = false
    @State private var showingGames = false
    @State private var showingChores = false
    @StateObject private var choreStore = ChoreStore.shared
    @State private var showingLeaderboard = false
    @State private var showingSmartFeed = false
    @State private var showingChildSettings = false
    @State private var showingPaywall = false
    @State private var showingAppLockSetup = false
    /// The child's "protect my time" code flow. `pendingUnlockAction` remembers
    /// which unlock the kid tapped, to run right after a successful verify.
    @State private var playPINSheet: PlayPINSheet? = nil
    @State private var pendingUnlockAction: (() -> Void)? = nil
    @State private var lastSeenStars = 0
    @State private var heroAppeared = false
    // 🔒→🔓 Window transfer ("נעל באייפד ופתח כאן"): when THIS child's window is
    // open on another device, the kid can ask to lock it there and continue
    // here. We open here only AFTER the other device confirms (row cleared).
    @State private var transferRequestedAt: Date? = nil
    @State private var transferTimedOut = false
    /// Which device kind the window was taken FROM — so the parent's push can
    /// say "מהאייפד לאייפון".
    @State private var transferFromKind = ""
    @State private var showLevelInfo = false

    private var isCompact: Bool { hsc == .compact }
    private var companionSize: CGFloat { isCompact ? 90 : 120 }
    // iPad shows the title inside the header row, so it's smaller there.
    private var heroTitleSize: CGFloat { isCompact ? 46 : 54 }

    @State private var infoStat: StatInfo? = nil

    enum StatInfo: String, Identifiable {
        case minutes, stars, diamonds
        var id: String { rawValue }
    }

    private var worldGridColumns: [GridItem] {
        let count = isCompact ? 2 : 3
        return Array(
            repeating: GridItem(.flexible(), spacing: AppSpacing.md),
            count: count
        )
    }

    /// Worlds the parent enabled for the active child (all topics if unset). A
    /// disabled topic is hidden entirely — the child never sees that world card,
    /// and the Smart Feed won't serve its questions either.
    private var enabledWorlds: [World] {
        let allowed = profiles.active?.enabledTopics ?? Set(Topic.allCases)
        return Worlds.all.filter { world in
            // 💫 The arena isn't a topic — always on, except for pre-readers
            // (the extra-hard pool is text-based).
            if world.isBonusWorld { return (profiles.active?.effectiveGrade ?? 1) >= 1 }
            return allowed.contains(world.topic)
        }
    }

    /// Total width cap for the world grid (so the 3 cards stay centered on iPad
    /// instead of pushing to one edge).
    private var worldGridMaxWidth: CGFloat {
        isCompact ? .infinity : 860
    }

    /// Shared side margin for the header card AND the world grid, so both have the
    /// exact same gap from the screen edges (and the same width on iPad).
    private var homeHPad: CGFloat { isCompact ? AppSpacing.sm : AppSpacing.lg }

    var body: some View {
        ZStack {
            // Layered background
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs.home()
            SparkleField(count: 25, size: 14)

            ScrollView {
                VStack(spacing: 0) {
                    topBar
                        .frame(maxWidth: worldGridMaxWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, homeHPad)
                    // (The limited-time event banner is now a transient TOAST —
                    // see eventToastOverlay — instead of a permanent row here
                    // that ate a full line of the map all day.)
                    if kidMode.active { kidExitBar }
                    VStack(spacing: AppSpacing.lg) {
                        // The brand + "בחר עולם" line live UNDER the daily
                        // challenge, heading the world grid (Rani tried it as a
                        // top masthead and preferred it back here). No extra top
                        // padding — the gap above טופי should match the gap
                        // between the subtitle and the cards below.
                        if isCompact {
                            heroTitle
                        }
                        LazyVGrid(
                            columns: worldGridColumns,
                            spacing: AppSpacing.md
                        ) {
                            FeatureCard(
                                emoji: "🧠",
                                title: "הַרְפַּתְקָה חֲכָמָה",
                                subtitle: "שְׁאֵלוֹת בִּמְיוּחָד בִּשְׁבִילְךָ",
                                gradient: AppGradient.portal,
                                glowColor: AppColor.companionGlow
                            ) {
                                // No companion line here — we leave this screen
                                // immediately, so a bubble would only flash & clip.
                                Haptic.light()
                                showingSmartFeed = true
                            }
                            .frame(maxWidth: .infinity)

                            ForEach(enabledWorlds) { world in
                                WorldCard(
                                    // Premium unlocks every world (that's what the
                                    // subscription buys). Stars are now a spendable
                                    // currency, so they no longer gate worlds —
                                    // otherwise buying cosmetics could re-lock them.
                                    world: world,
                                    isUnlocked: subs.isPremium,
                                    currentRoom: progress.progress(in: world.id),
                                    starsHeld: progress.stars,
                                    subscriptionLocked: !subs.isPremium
                                ) {
                                    if subs.isPremium {
                                        selectedWorld = world
                                    } else {
                                        // Until they subscribe, only "הרפתקה חכמה"
                                        // is playable — the worlds open the paywall.
                                        Haptic.light()
                                        showingPaywall = true
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }

                            // 🎮 Games LAST in the grid (Rani): learning worlds
                            // come first in the child's choice order; the arcade
                            // is the dessert at the end.
                            FeatureCard(
                                emoji: "🎮",
                                title: "מִשְׂחָקִים",
                                // Daily warm-up gate: games open after a few CORRECT
                                // answers of real learning (Rani). Framed as a goal,
                                // never a lock — no grey-out, no failure language.
                                subtitle: gamesUnlockedToday
                                    ? "מֵרוֹץ נָכוֹן/לֹא · הַתְאָמַת זוּגוֹת"
                                    : "עוֹנִים \(gamesGateTarget) נְכוֹנוֹת — וְנִפְתָּח! 💪",
                                gradient: LinearGradient(colors: [Color(hex: "EF476F"), Color(hex: "9B5DE5")],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing),
                                glowColor: Color(hex: "EF476F"),
                                badge: gamesUnlockedToday
                                    ? nil
                                    : "\(min(progress.correctToday, gamesGateTarget))/\(gamesGateTarget) ✅"
                            ) {
                                Haptic.light()
                                if gamesUnlockedToday {
                                    showingGames = true
                                } else {
                                    companion.cheer("עוֹד \(gamesGateRemaining) תְּשׁוּבוֹת נְכוֹנוֹת וְהַמִּשְׂחָקִים נִפְתָּחִים! 🎮")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: worldGridMaxWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, homeHPad)
                    // Breathing room between the header card and the world grid
                    // (compact: none — the grid VStack's own spacing already
                    // matches the subtitle→cards gap, so טופי sits evenly).
                    .padding(.top, isCompact ? 0 : AppSpacing.xxxl)
                    // Bottom inset just tall enough for the floating CTA panel
                    // (two pills + the protect-code line ≈ 180pt) with a small
                    // margin — 360 left a huge dead gap after the last row
                    // (Rani, on-device). The companion floats and never needs
                    // scroll room of its own.
                    .padding(.bottom, isCompact ? 220 : 190)
                }
            }

            // Bottom CTAs floating panel
            VStack {
                Spacer()
                bottomCTAs
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
            }


            // Companion wanders the screen and is also draggable.
            // On iPhone we keep the wander zone tighter so it doesn't park
            // on top of world cards in the middle of the grid.
            FloatingCompanion(
                controller: companion,
                profile: profiles.active,
                onTap: {
                    Haptic.light()
                    showingShop = true
                },
                showGift: progress.dailyChestAvailable,
                onGiftTap: { showDailyChest = true },
                size: companionSize,
                // Keep the buddy (and the gift above its head) BELOW the taller
                // header card so it never parks on top of the stats.
                topInset: isCompact ? 300 : 230,
                bottomInset: isCompact ? 220 : 200,
                horizontalInset: AppSpacing.lg
            )
        }
        // Returning from the smart adventure with the warm-up freshly completed →
        // celebrate the games opening (the map's onAppear doesn't re-fire under
        // a dismissed fullScreenCover, so listen to the cover's flag directly).
        .onChangeCompat(of: showingSmartFeed) { _, showing in
            if !showing { celebrateGamesUnlockIfNeeded() }
        }
        // Window transfer completion: the other device's row updates live; the
        // moment its window is confirmed gone we finish the handoff.
        .onChangeCompat(of: household.devicesByChild) { _, _ in
            completeWindowTransferIfReady()
        }
        .onAppear {
            lastSeenStars = progress.stars
            celebrateGamesUnlockIfNeeded()
            ChoreStore.shared.startIfNeeded()   // 🧹 live chores for the tile
            // 🔐 live view of the child's single authoritative play window.
            if let cid = profiles.activeID { PlayWindowLeaseManager.shared.startIfNeeded(childID: cid) }
            // 🎓 No grade yet (families from before grades existed): the kid
            // picks their own — synced to the parent flagged for verification.
            if let p = profiles.active, p.grade == nil {
                showChildGradePicker = true
            }
            // 🎒 September 1st: the child advanced a grade — celebrate once.
            else if let p = profiles.active, SchoolYearCelebration.shouldCelebrate(p) {
                showSchoolYearParty = true
            }
            // Keep my friends-board score live during play (even with the board
            // closed), so friends always see my current stars.
            FriendsManager.shared.beginScoreSync()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                greetIfNeeded()
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                heroAppeared = true
            }
            checkWorldUnlocks()
            // Event splash: announce today's event ONCE a day as a full pop-up
            // (like the lucky wheel) — it used to be a permanent row eating map
            // space. Never on top of the grade picker / school-year party.
            if GameEvent.current() != nil, !showChildGradePicker, !showSchoolYearParty {
                let day = Calendar.current.component(.year, from: Date()) * 1000
                    + (Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0)
                let key = "eventSplash.lastShownDay"
                if UserDefaults.standard.integer(forKey: key) != day {
                    UserDefaults.standard.set(day, forKey: key)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        showEventSplash = true
                    }
                }
            }
            // Returning after being away earns a "welcome back" spin.
            progress.grantComebackWheelIfReturning()
            // Wheel pops when we return to the map after earning a free spin.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                maybeAutoPresentWheel()
            }
            maybePromptAppLockSetup()
            // Refresh this child device's "last seen" so the parent sees it live,
            // and re-publish this child's local progress to the cloud — this is
            // the source of truth and restores the parent's view if the cloud doc
            // was ever stale/zeroed.
            if settings.deviceRole == .child, let cid = profiles.activeID {
                Task { await HouseholdManager.shared.registerDevice(forChildID: cid) }
                RemoteSyncManager.shared.pushNow()
                // A registered child device needs notification permission too (for
                // live-game invites + parent live events). We never asked on the
                // child side before — prompt now, but ONLY if undecided, so it also
                // catches devices that registered before this existed and never
                // gets re-shown to anyone who already chose.
                if ChildTimeApp.demoScreen == nil {
                    Task { await PushManager.shared.requestAuthorizationIfNotDetermined() }
                }
            }
        }
        // A fullScreenCover doesn't re-fire the map's .onAppear when it closes,
        // so check the wheel when a play session actually ends.
        .onChangeCompat(of: showingSmartFeed) { _, shown in
            if !shown { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { maybeAutoPresentWheel() } }
        }
        .onChangeCompat(of: selectedWorld?.id) { _, world in
            if world == nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { maybeAutoPresentWheel() } }
        }
        .onChangeCompat(of: progress.stars) { _, new in
            if new > lastSeenStars {
                companion.cheer()
            }
            lastSeenStars = new
            checkWorldUnlocks()
        }
        .fullScreenCover(item: $selectedWorld) { world in
            WorldDetailView(world: world)
        }
        .fullScreenCover(isPresented: $showDailyChest) {
            DailyChestView()
        }
        .overlay(alignment: .top) {
            if let msg = challengeCelebration {
                Text(msg)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(AppColor.successMint.opacity(0.95), in: Capsule())
                    .glow(AppColor.successMint, radius: 12)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: challengeCelebration)
        .sheet(isPresented: $showingParentGate) {
            // On the child device the gate opens ONLY the device-local parent
            // controls (app-lock + manual unlock) — everything else is on the
            // parent's own device. respectSession:false — THE DEVICE IS IN THE
            // KID'S HANDS: after the parent used the controls once and left,
            // the next gear tap must ask for the code again (reported: it
            // walked straight back in off the session unlock).
            ParentGateView(respectSession: false) {
                ChildDeviceControlsView()
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .fullScreenCover(isPresented: $showingAppLockSetup) {
            ChildAppLockSetupView()
                .environment(\.layoutDirection, .rightToLeft)
        }
        // The child's "protect my time" code — verify before spending minutes,
        // plus the set/change/remove flows.
        .fullScreenCover(item: $playPINSheet) { sheet in
            playPINCover(sheet)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .fullScreenCover(isPresented: $showingShop) {
            ShopView()
        }
        .fullScreenCover(isPresented: $showingLeaderboard) {
            LeaderboardView()
        }
        // The live friends quiz — ONE flow cover for setup → lobby → game, so
        // there's never a second presentation racing the first.
        .fullScreenCover(isPresented: Binding(
            get: { liveGame.isSettingUp || liveGame.game != nil },
            set: { if !$0 { Task { await liveGame.leaveGame() } } })) {
            LiveGameFlowView()
        }
        // A friend invite link opened the app → jump to the leaderboard, which
        // consumes the pending code and adds the friend.
        .onChangeCompat(of: friends.pendingFriendCode) { _, code in
            if code != nil { showingLeaderboard = true }
        }
        // A game deep link / push tap → join the game (the cover shows it).
        .onChangeCompat(of: liveGame.pendingGameID) { _, id in
            guard let id else { return }
            liveGame.pendingGameID = nil
            Task { await liveGame.joinGame(id) }
        }
        // The leaderboard's "create game" button asked to open setup. Delay a beat
        // so the leaderboard cover finishes dismissing before this one presents.
        .onChangeCompat(of: liveGame.wantsNewGame) { _, want in
            guard want else { return }
            liveGame.wantsNewGame = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { liveGame.openSetup() }
        }
        .onAppear {
            if friends.pendingFriendCode != nil { showingLeaderboard = true }
            if let id = liveGame.pendingGameID { liveGame.pendingGameID = nil; Task { await liveGame.joinGame(id) } }
            liveGame.startInvitesListener()
        }
        .onDisappear { liveGame.stopInvitesListener() }
        // Leaving Kid Mode — a SINGLE authentication (Face ID, with code fallback).
        // On success we mark the session unlocked and exit immediately, so the
        // dashboard doesn't re-prompt: one Face ID, no separate "are you sure?".
        // respectSession:false so this gate itself always authenticates.
        .sheet(isPresented: $showKidExit) {
            ParentGateView(allowClose: true,
                           gateTitle: "יְצִיאָה מִמַּצַּב יֶלֶד",
                           gateReason: "אַמְּתוּ זֶהוּת כְּדֵי לָצֵאת מִמַּצַּב יֶלֶד",
                           useFaceID: true,
                           respectSession: false,
                           onAuthorized: {
                               KidModeManager.shared.exit()
                               showKidExit = false
                           }) {
                Color.clear
            }
            .environmentObject(settings)
            .environment(\.layoutDirection, .rightToLeft)
        }
        // A friend started a game I'm invited to → pop a toast at the top (far more
        // visible than the small red dot). It auto-hides after a few seconds; the
        // red dot on the controller button stays as the persistent reminder.
        .overlay(alignment: .top) {
            if inviteBannerVisible, let invite = liveGame.invites.first,
               liveGame.game == nil, !liveGame.isSettingUp {
                gameInviteBanner(invite)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: inviteBannerVisible)
        .onChangeCompat(of: liveGame.invites.count) { old, new in
            guard new > old else { if new == 0 { inviteBannerVisible = false }; return }
            Haptic.success(); SoundPlayer.shared.play(.portalAppear)
            inviteBannerVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { inviteBannerVisible = false }
        }
        .fullScreenCover(isPresented: $showingGames) {
            GamesMenuView { showingGames = false }
        }
        .fullScreenCover(isPresented: $showingChores) {
            ChoresKidView { showingChores = false }
                .environmentObject(profiles)
                .environmentObject(progress)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .fullScreenCover(isPresented: $showingWheel) {
            LuckyWheelView { showingWheel = false }
        }
        .fullScreenCover(isPresented: $showingSmartFeed) {
            // Smart Feed play — grants minutes (capped by the daily maximum).
            QuestionRunnerView(mode: .smartFeed, purpose: .earnTime)
        }
        .fullScreenCover(item: $infoSheet) { sheet in
            challengeInfoScreen(for: sheet)
        }
        // Kids Category (App Review guideline 1.3): commerce must sit behind a
        // parental gate that can't be bypassed. respectSession:false so this ALWAYS
        // re-authenticates — an earlier unlock this session must not open the store.
        .fullScreenCover(isPresented: $showingPaywall) {
            ParentGateView(allowClose: true,
                           gateTitle: "אֵזוֹר הוֹרִים",
                           gateReason: "כְּדֵי לִרְאוֹת אֶת הַמִּנּוּי בְּתַשְׁלוּם — בַּקְּשׁוּ מֵהוֹרֶה לְהַזִּין אֶת הַקּוֹד",
                           useFaceID: true,
                           respectSession: false) {
                PaywallView()
                    .environmentObject(subs)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .environmentObject(settings)
            .environment(\.layoutDirection, .rightToLeft)
        }
        .sheet(isPresented: $showingChildSettings) {
            if let active = profiles.active {
                ProfileEditorView(mode: .edit(active)) { updated in
                    profiles.update(updated)
                } onDelete: { profile in
                    profiles.remove(profile)
                }
                .environmentObject(profiles)
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .fullScreenCover(isPresented: $showEventSplash) {
            // The daily event as a real MOMENT (Rani): full pop-up like the
            // lucky wheel — big emoji, one "let's go", easy close.
            if let event = GameEvent.current() {
                let copy = eventCopy(event)
                ChallengeInfoView(
                    emoji: event.emoji,
                    title: copy.title,
                    message: copy.message,
                    ctaTitle: "יַאלְלָה, בּוֹאוּ נַאֲסֹף! 🚀",
                    onCTA: {
                        showEventSplash = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showingSmartFeed = true }
                    },
                    onClose: { showEventSplash = false }
                )
                .environment(\.layoutDirection, .rightToLeft)
            } else {
                Color.clear.onAppear { showEventSplash = false }
            }
        }
        .fullScreenCover(isPresented: $showChildGradePicker) {
            if let p = profiles.active {
                ChildGradePickerView(profile: p) { g in
                    var updated = p
                    updated.grade = g
                    updated.gradeSchoolYear = Profile.schoolYear()
                    updated.gradeSetByChild = true
                    profiles.update(updated)
                    showChildGradePicker = false
                }
            }
        }
        .fullScreenCover(isPresented: $showSchoolYearParty) {
            if let p = profiles.active {
                SchoolYearCelebrationView(
                    gradeName: Profile.gradeDisplayName(p.effectiveGrade),
                    childName: p.name,
                    gender: p.gender
                ) { showSchoolYearParty = false }
            }
        }
        .fullScreenCover(isPresented: $showingDemo) {
            ZStack(alignment: .topTrailing) {
                DemoView()
                Button { showingDemo = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                }
            }
        }
    }

    /// A friendly "you're invited!" banner that drops in at the top of the home
    /// screen, with the host's name and a one-tap Join.
    private func gameInviteBanner(_ invite: LiveGameInvite) -> some View {
        HStack(spacing: 12) {
            Text("🎮").font(.system(size: 30))
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(invite.hostName) מַזְמִין/ה אוֹתְךָ!")
                    .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text("מִשְׂחָק חִידוֹן נֶגֶד חֲבֵרִים")
                    .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Button {
                Haptic.medium()
                Task { await liveGame.joinGame(invite.id) }
            } label: {
                Text("הִצְטָרְפוּ")
                    .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(AppColor.textOnLight)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Capsule().fill(AppColor.starGold))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous).fill(AppColor.gemPurple))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 1))
        .glow(AppColor.gemPurple, radius: 14)
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .frame(maxWidth: 520)
        .environment(\.layoutDirection, .rightToLeft)
        .eraseToAnyView()
    }

    /// Slim "exit Kid Mode" bar shown UNDER the top-bar buttons while the parent's
    /// phone is acting as a kid device — so it never overlaps the action buttons.
    private var kidExitBar: some View {
        Button {
            Haptic.light()
            showKidExit = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold))
                Text("יְצִיאָה מִמַּצַּב יֶלֶד").font(.system(size: 15, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28).padding(.vertical, 12)
            .background(Capsule().fill(Color(hex: "EF4655")))
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
            .shadow(color: Color(hex: "EF4655").opacity(0.4), radius: 10, y: 4)
        }
        .buttonStyle(.juicy)
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
        .eraseToAnyView()
    }

    // MARK: - Top bar

    private var topBar: some View {
        let avatarSize: CGFloat = isCompact ? 46 : 54
        let btnSize: CGFloat = isCompact ? 42 : 46
        return VStack(spacing: isCompact ? 12 : 16) {
            // Row 1 — identity on the left, round nav buttons on the right. A custom
            // alignment puts the avatar, the name and every button CIRCLE on one
            // line (the button captions hang below without shifting it). Forced LTR
            // so it matches the design even though the app root is RTL.
            ZStack {
                HStack(alignment: .headerIcon, spacing: isCompact ? 6 : 14) {
                    identityBlock(avatar: avatarSize)
                        .alignmentGuide(.headerIcon) { $0[VerticalAlignment.center] }
                    Spacer(minLength: 2)
                    navButtonsRow(size: btnSize)
                        .alignmentGuide(.headerIcon) { _ in btnSize / 2 }
                }
                // On iPad the "טופי" title is centered over the whole row (= screen
                // center, since the card is centered). Capped narrower than the gap
                // between identity and the (smaller) nav buttons so it can't overlap.
                if !isCompact {
                    heroTitle
                        .frame(maxWidth: 300)
                        .allowsHitTesting(false)
                }
            }
            statsPanel
            // אתגר יומי squeezed LEFT, מטלות הבית on its RIGHT (Rani) — the
            // chores entry lives up here with the daily loop, not as a world.
            HStack(spacing: 10) {
                dailyChallengeCard
                choresTopCard
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(isCompact ? 14 : 18)
        .background(glassCard)
        .padding(.top, AppSpacing.sm)
        .eraseToAnyView()
    }

    /// Daily challenge — a compact vertical card, the exact TWIN of
    /// `choresTopCard` (Rani: same size, side by side). Icon ring → title →
    /// one status line → progress track. Tap → the explainer sheet.
    private var dailyChallengeCard: some View {
        let target = ProgressStore.dailyChallengeTarget
        let done = progress.dailyChallengeProgress
        let ready = progress.dailyChallengeRewardReady
        let claimed = progress.dailyChallengeClaimed
        let frac = (ready || claimed) ? 1 : CGFloat(min(done, target)) / CGFloat(max(1, target))
        return Button {
            Haptic.light()
            infoSheet = .dailyChallenge
        } label: {
            VStack(spacing: 6) {
                // A living flame in a fiery ring — the streak count rides it.
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: "FFB347"), Color(hex: "FF5E3A")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 1.5))
                        .glow(AppColor.flameOrange, radius: challengePulse ? 12 : 5)
                    Text("🔥")
                        .font(.system(size: 24))
                        .scaleEffect(challengePulse ? 1.12 : 0.95)
                        .frame(width: 44, height: 44)
                    if progress.dayStreak > 0 {
                        Text("\(progress.dayStreak)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(AppColor.textOnLight)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.white))
                            .overlay(Capsule().stroke(AppColor.flameOrange, lineWidth: 1.2))
                            .offset(x: 6, y: 4)
                    }
                }
                Text("אֶתְגָּר יוֹמִי")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                Group {
                    if claimed {
                        Text("כָּל הַכָּבוֹד! נִפְגָּשִׁים מָחָר 🌙")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1).minimumScaleFactor(0.6)
                    } else if ready {
                        HStack(spacing: 4) {
                            Text("🎁").font(.system(size: 14))
                                .scaleEffect(challengePulse ? 1.18 : 1)
                                .rotationEffect(.degrees(challengePulse ? 8 : -8))
                            Text("פִּתְחוּ!")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(AppColor.textOnLight)
                                .lineLimit(1).fixedSize()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(AppGradient.gold, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1.2))
                        .glow(AppColor.starGold, radius: challengePulse ? 12 : 6)
                    } else {
                        let left = max(0, target - done)
                        Text(left == 1 ? "עוֹד תְּשׁוּבָה אַחַת! · \(done)/\(target)"
                                       : "עוֹד \(left) תְּשׁוּבוֹת · \(done)/\(target)")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
                .frame(height: 26)

                headerTrack(frac: frac,
                            fill: ready || claimed
                                ? LinearGradient(colors: [AppColor.successMint, Color(hex: "06D6A0")],
                                                 startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color(hex: "FFD23F"), AppColor.flameOrange],
                                                 startPoint: .leading, endPoint: .trailing),
                            glowColor: ready || claimed ? AppColor.successMint : AppColor.starGold,
                            tip: frac > 0 ? (ready || claimed ? "🏆" : "⭐️") : nil)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(height: Self.headerCardHeight)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "FF5E7E").opacity(0.50),
                                                  Color(hex: "FF9E2C").opacity(0.35),
                                                  Color(hex: "7C4DFF").opacity(0.45)],
                                         startPoint: .topTrailing, endPoint: .bottomLeading))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(LinearGradient(colors: [AppColor.starGold.opacity(0.75), .white.opacity(0.2)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
            )
            .shadow(color: AppColor.flameOrange.opacity(0.25), radius: 10, y: 4)
        }
        .buttonStyle(.juicy)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                challengePulse = true
            }
        }
        .eraseToAnyView()
    }

    /// Both header cards are exactly this tall — they must read as twins.
    private static let headerCardHeight: CGFloat = 148

    /// The shared progress track at the foot of both header cards.
    private func headerTrack(frac: CGFloat, fill: LinearGradient, glowColor: Color, tip: String?) -> some View {
        GeometryReader { geo in
            let w = frac <= 0 ? 0 : max(16, geo.size.width * min(frac, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                if w > 0 {
                    Capsule()
                        .fill(fill)
                        .frame(width: w)
                        .glow(glowColor, radius: 4)
                        .overlay(alignment: .trailing) {
                            if let tip {
                                Text(tip)
                                    .font(.system(size: 13))
                                    .shadow(color: .black.opacity(0.3), radius: 2)
                                    .offset(y: -1)
                            }
                        }
                }
            }
        }
        .frame(height: 10)
    }

    /// Claim the daily-challenge prize (called from the explainer's CTA).
    private func claimChallenge() {
        let grant = progress.claimDailyChallenge()
        Haptic.success()
        SoundPlayer.shared.play(.streakUp)
        let total = grant.addedToday + grant.bankedForTomorrow
        challengeCelebration = "🎉 כָּל הַכָּבוֹד! +\(15 + min(progress.dayStreak, 7) * 2) 💎" + (total > 0 ? " וְ-\(total) דַּקּוֹת" : "")
        companion.hype("שָׁמַרְתָּ עַל הָרֶצֶף! 🔥")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { challengeCelebration = nil }
    }

    /// Close any open explainer, then jump into the Smart Feed to play/earn.
    private func enterSmartFeedFromInfo() {
        infoSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showingSmartFeed = true }
    }

    @ViewBuilder
    private func challengeInfoScreen(for sheet: InfoSheet) -> some View {
        switch sheet {
        case .dailyChallenge:
            let target = ProgressStore.dailyChallengeTarget
            let done = progress.dailyChallengeProgress
            let ready = progress.dailyChallengeRewardReady
            let claimed = progress.dailyChallengeClaimed
            let prize = 15 + min(progress.dayStreak, 7) * 2
            ChallengeInfoView(
                emoji: "🔥",
                title: "אֶתְגָּר יוֹמִי",
                message: claimed
                    ? "הִשְׁלַמְתָּ אֶת הָאֶתְגָּר הַיּוֹם — כָּל הַכָּבוֹד! 🎉\nאֶפְשָׁר לְהַמְשִׁיךְ לְשַׂחֵק וְלִצְבֹּר עוֹד."
                    : "עֲנֵה נָכוֹן עַל \(target) שְׁאֵלוֹת הַיּוֹם וְזָכֵה בִּ-\(prize) 💎!\nכָּל יוֹם רָצוּף שֶׁמְּשַׂחֲקִים — הַפְּרָס גָּדֵל. 🔥",
                progressText: "\(done)/\(target)",
                ctaTitle: ready ? "אַסְפוּ אֶת הַפְּרָס 🎁" : "קָדִימָה, נְעַנֶּה! 🚀",
                onCTA: {
                    if ready { claimChallenge(); infoSheet = nil }
                    else { enterSmartFeedFromInfo() }
                },
                onClose: { infoSheet = nil }
            )
        case .event:
            eventInfoScreen
        }
    }

    private func eventCopy(_ event: GameEvent) -> (title: String, message: String) {
        switch event {
        case .doubleDiamonds:
            return ("סוֹף שָׁבוּעַ כָּפוּל!",
                    "כָּל הַיַּהֲלוֹמִים שֶׁתִּצְבְּרוּ הַיּוֹם — כְּפוּלִים! 💎×2\nזֶה הַזְּמַן הֲכִי טוֹב לֶאֱסֹף הַרְבֵּה.")
        case .featuredTopic(let t):
            return ("נוֹשֵׂא הַיּוֹם: \(t.displayName)",
                    "הַיּוֹם כָּל תְּשׁוּבָה נְכוֹנָה בְּ\(t.displayName) שָׁוָה יַהֲלוֹמִים כְּפוּלִים! 💎×2")
        }
    }

    @ViewBuilder
    private var eventInfoScreen: some View {
        if let event = GameEvent.current() {
            let copy = eventCopy(event)
            ChallengeInfoView(
                emoji: event.emoji,
                title: copy.title,
                message: copy.message,
                ctaTitle: "קָדִימָה! 🚀",
                onCTA: { enterSmartFeedFromInfo() },
                onClose: { infoSheet = nil }
            )
        } else {
            // Event lapsed while open — nothing to show; just dismiss.
            Color.clear.onAppear { infoSheet = nil }
        }
    }

    /// Frosted translucent card so the dreamy background glows through.
    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.12)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.25), radius: 22, y: 12)
            .eraseToAnyView()
    }

    /// Avatar + name (tap → edit the child's profile) and a level badge
    /// (tap → the "רָמַת טוֹפִי" level info). The name is centered over the badge.
    private func identityBlock(avatar: CGFloat) -> some View {
        HStack(spacing: 9) {
            Button {
                Haptic.light(); showingChildSettings = true
            } label: {
                CharacterView(character: profiles.active?.character
                              ?? Character3DCatalog.find(Character3DCatalog.defaultID),
                              portrait: true)
                    .frame(width: avatar, height: avatar)
                    .background(Circle().fill(Color.white.opacity(0.18)))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            .buttonStyle(.plain)

            VStack(alignment: .center, spacing: 3) {
                Button {
                    Haptic.light(); showingChildSettings = true
                } label: {
                    Text(profiles.active?.name ?? "טוֹפִי")
                        .font(.system(size: avatar * 0.40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .buttonStyle(.plain)

                Button {
                    Haptic.light(); showLevelInfo = true
                } label: {
                    Text("רָמָה \(progress.companionLevel)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Capsule().fill(AppColor.gemPurple))
                        .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .eraseToAnyView()
    }

    private func navButtonsRow(size: CGFloat) -> some View {
        HStack(spacing: isCompact ? 5 : 9) {
            navButton(icon: "gamecontroller.fill", color: AppColor.gemPurple,
                      label: "טוּרְנִיר", badge: !liveGame.invites.isEmpty, size: size) {
                Haptic.light()
                if let invite = liveGame.invites.first { Task { await liveGame.joinGame(invite.id) } }
                else { liveGame.openSetup() }
            }
            navButton(icon: "trophy.fill", color: Color(hex: "10B981"),
                      label: "דֵּירוּג", badge: false, size: size) {
                Haptic.light(); showingLeaderboard = true
            }
            navButton(icon: "storefront.fill", color: Color(hex: "F59E0B"),
                      label: "חֲנוּת", badge: false, size: size) {
                Haptic.light(); showingShop = true
            }
            navButton(icon: "gearshape.fill", color: AppColor.gemPurple,
                      label: "הַגְדָּרוֹת", badge: false, size: size, neutral: true,
                      longPress: { showingDemo = true }) {
                showingParentGate = true
            }
        }
        .eraseToAnyView()
    }

    private func navButton(icon: String, color: Color, label: String, badge: Bool,
                           size: CGFloat, neutral: Bool = false, longPress: (() -> Void)? = nil,
                           action: @escaping () -> Void) -> some View {
        let circle = Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(
                        Circle().fill(neutral
                            ? AnyShapeStyle(Color.white.opacity(0.16))
                            : AnyShapeStyle(LinearGradient(colors: [color, color.opacity(0.8)],
                                                           startPoint: .top, endPoint: .bottom)))
                    )
                    .overlay(Circle().stroke(.white.opacity(neutral ? 0.4 : 0.9), lineWidth: neutral ? 1.5 : 2))
                    .shadow(color: neutral ? .clear : color.opacity(0.45), radius: 6, y: 3)
                if badge {
                    Circle().fill(AppColor.flameOrange).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2)).offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)

        return VStack(spacing: 5) {
            if let longPress {
                circle.onLongPressGesture(minimumDuration: 1.5, perform: longPress)
            } else {
                circle
            }
            Text(label)
                .font(.system(size: isCompact ? 10 : 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                // Keep each caption within its button column so a long word (e.g.
                // "מִשְׂחָקִים") can't spill over and collide with the neighbour's
                // caption. Shrink-to-fit instead of truncating to "…".
                .minimumScaleFactor(0.6)
                .frame(width: size + (isCompact ? 8 : 16))
        }
        .eraseToAnyView()
    }

    /// The stats panel: 💎 diamonds (left) · big time card (center, with progress
    /// bar) · ⭐ stars (right). The "time earned today" lives ONLY here.
    private var statsPanel: some View {
        HStack(spacing: isCompact ? 8 : 12) {
            Button { Haptic.light(); infoStat = .diamonds } label: {
                statColumn(emoji: "💎", value: progress.diamonds.currencyShort,
                           label: "יַהֲלוֹמִים", iconTrailing: false)
            }
            .buttonStyle(.plain)

            Button { Haptic.light(); infoStat = .minutes } label: { timeCenterCard }
                .buttonStyle(.plain)

            Button { Haptic.light(); infoStat = .stars } label: {
                statColumn(emoji: "⭐", value: progress.stars.currencyShort,
                           label: "כּוֹכָבִים", iconTrailing: true)
            }
            .buttonStyle(.plain)
        }
        .padding(isCompact ? 8 : 10)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.07)))
        // One clean bottom sheet for the stat explanations (a popover floated
        // awkwardly over the header on iPhone).
        .sheet(item: $infoStat) { stat in
            statInfoCard(stat)
                .environment(\.layoutDirection, .rightToLeft)
                .presentationDetents([.height(stat == .minutes ? 460 : 380)])
                .presentationDragIndicator(.visible)
        }
        .eraseToAnyView()
    }

    private func statColumn(emoji: String, value: String, label: String, iconTrailing: Bool) -> some View {
        HStack(spacing: 7) {
            if !iconTrailing { Text(emoji).font(.system(size: isCompact ? 22 : 28)) }
            VStack(spacing: 1) {
                Text(value)
                    .font(.system(size: isCompact ? 22 : 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(label)
                    .font(.system(size: isCompact ? 11 : 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            if iconTrailing { Text(emoji).font(.system(size: isCompact ? 22 : 28)) }
        }
        .padding(.horizontal, 4)
    }

    private var timeCenterCard: some View {
        let cap = progress.dailyCap
        let earned = progress.minutesEarnedToday
        let frac: Double = cap.enabled
            ? min(1, Double(earned) / Double(max(1, cap.max)))
            : (progress.pendingMinutes > 0 ? 1 : 0)
        let value = cap.enabled ? "\(earned)/\(cap.max)" : "\(progress.pendingMinutes)"
        return VStack(spacing: isCompact ? 4 : 6) {
            HStack(spacing: 5) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: isCompact ? 10 : 12, weight: .bold))
                Text("זְמַן שֶׁהִרְוַחְתִּי הַיּוֹם")
                    .font(.system(size: isCompact ? 10 : 12, weight: .heavy, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .foregroundStyle(.white.opacity(0.85))

            Text(value)
                .font(.system(size: isCompact ? 26 : 34, weight: .black, design: .rounded))
                .foregroundStyle(.white).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.20))
                    Capsule()
                        .fill(LinearGradient(colors: [AppColor.successMint, AppColor.diamondBlue, AppColor.gemPurple],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, g.size.width * frac))
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, isCompact ? 10 : 16)
        .padding(.vertical, isCompact ? 8 : 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.13)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
        .eraseToAnyView()
    }

    // MARK: - Stat info popovers

    @ViewBuilder
    private func statInfoCard(_ stat: StatInfo) -> some View {
        let info = statInfoContent(stat)
        // Card forces RTL, so `.leading` = the visual RIGHT. Everything is
        // right-aligned (natural Hebrew); the emoji sits on the left.
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(info.subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(info.emoji)
                    .font(.system(size: 46))
            }

            Text(info.body)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let tip = info.tip {
                HStack(alignment: .top, spacing: 8) {
                    Text(tip)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(AppColor.starGold)
                        .font(.system(size: 16))
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 8)

            // Quick jump straight from the explanation: diamonds → shop,
            // stars → the friends leaderboard (דֵּירוּג).
            if stat == .diamonds {
                infoCTA(title: "לַחֲנוּת", icon: "storefront.fill",
                        gradient: AnyShapeStyle(AppGradient.gold), glow: AppColor.starGold) {
                    showingShop = true
                }
            } else if stat == .stars {
                infoCTA(title: "לַדֵּרוּג", icon: "trophy.fill",
                        gradient: AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "10B981"), Color(hex: "0E9E72")],
                            startPoint: .leading, endPoint: .trailing)),
                        glow: Color(hex: "10B981")) {
                    showingLeaderboard = true
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// A full-width CTA at the bottom of a stat sheet (closes it, then navigates).
    private func infoCTA(title: String, icon: String, gradient: AnyShapeStyle,
                         glow: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            infoStat = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: action)
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .glow(glow, radius: 8)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private struct InfoContent {
        let emoji: String
        let title: String
        let subtitle: String
        let body: String
        let tip: String?
    }

    private func statInfoContent(_ stat: StatInfo) -> InfoContent {
        switch stat {
        case .minutes:
            let cap = progress.dailyCap
            var lines: [String] = []
            if progress.canRedeemNow {
                // Enough to open now.
                lines.append("אֶפְשָׁר לִפְתּוֹחַ עַכְשָׁיו \(progress.redeemableMinutesNow) דַּקּוֹת מִשְׂחָק! 🎮")
                if progress.pendingMinutes > progress.redeemableMinutesNow {
                    lines.append("בָּאַרְנָק יֵשׁ \(progress.pendingMinutes) — הַשְּׁאָר נִשְׁמָר לְיָמִים הַבָּאִים.")
                }
            } else if progress.dailyScreenTimeMaxedOut {
                // Today's screen-time cap is used up — the wallet waits for tomorrow.
                lines.append("הִגַּעְתָּ לְמַקְסִימוּם זְמַן הַמָּסָךְ הַיּוֹמִי 🌙 — \(progress.pendingMinutes) דַּקּוֹת שְׁמוּרוֹת לְמָחָר!")
            } else if progress.pendingMinutes > 0 {
                // Has some, but below the 15-min minimum we can open.
                lines.append("יֵשׁ לְךָ \(progress.pendingMinutes) דַּקּוֹת. פּוֹתְחִים זְמַן מִשְׂחָק מִ-\(progress.minimumUnlockMinutes) דַּקּוֹת — עֲנוּ עַל עוֹד שְׁאֵלוֹת! 😊")
            } else if cap.enabled, progress.minutesEarnedToday >= cap.max {
                // Earned the WHOLE day's allowance and spent it — a win, not a
                // lack ("עדיין אין דקות" here read as failure and invited more
                // answering "to earn", when today's earning is over). Point at
                // what IS possible now: tomorrow's bank + the gift pocket.
                lines.append("וָאוּ — נִצַּלְתָּ אֶת כָּל \(cap.max) הַדַּקּוֹת שֶׁל הַיּוֹם! 🏆")
                lines.append("כָּל מַה שֶּׁתַּרְוִיחַ עַכְשָׁיו נִשְׁמָר לְמָחָר.")
                if progress.parentGiftMinutes > 0 {
                    lines.append("וְיֵשׁ לְךָ \(progress.parentGiftMinutes) דַּקּוֹת מַתָּנָה 💝 שֶׁאֶפְשָׁר לִפְתּוֹחַ גַּם עַכְשָׁיו!")
                }
            } else {
                lines.append("עֲדַיִן אֵין דַּקּוֹת. עֲנוּ עַל שְׁאֵלוֹת כְּדֵי לְהַרְוִיחַ דַּקּוֹת מִשְׂחָק! 🎮")
            }
            if cap.enabled {
                lines.append("הַיּוֹם הִרְוַחְתָּ \(progress.minutesEarnedToday) מִתּוֹךְ \(cap.max) דַּקּוֹת.")
            }
            if progress.carryOverMinutes > 0 {
                lines.append("🎁 \(progress.carryOverMinutes) דַּקּוֹת נִשְׁמְרוּ לְמָחָר.")
            }
            return InfoContent(
                emoji: "🎮",
                title: "דַּקּוֹת מִשְׂחָק",
                subtitle: "זְמַן הַמִּשְׂחָק שֶׁלְּךָ",
                body: lines.joined(separator: "\n"),
                tip: "עוֹנִים נָכוֹן — מַרְוִיחִים עוֹד דַּקּוֹת!"
            )
        case .stars:
            return InfoContent(
                emoji: "⭐",
                title: "\(progress.stars.grouped) כּוֹכָבִים",
                subtitle: "הַדֵּרוּג שֶׁלָּכֶם",
                body: "אוֹסְפִים כּוֹכָב עַל כָּל תְּשׁוּבָה נְכוֹנָה. הַכּוֹכָבִים אַף פַּעַם לֹא יוֹרְדִים — הֵם הַנִּקּוּד שֶׁלָּכֶם בְּטַבְלַת הַחֲבֵרִים!",
                tip: "כָּל מַה שֶּׁאַתֶּם לוֹמְדִים מְטַפֵּס בַּדֵּרוּג 🏆"
            )
        case .diamonds:
            return InfoContent(
                emoji: "💎",
                title: "\(progress.diamonds.grouped) יַהֲלוֹמִים",
                subtitle: "הַאַרְנָק שֶׁלָּכֶם",
                body: "מַרְוִיחִים יַהֲלוֹמִים עַל תְּשׁוּבוֹת נְכוֹנוֹת, מִמַּתָּנוֹת וּמִגַּלְגַּל הַמַּזָּל — וְקוֹנִים בָּהֶם בַּחֲנוּת.",
                tip: "קְנִיָּה לֹא פּוֹגַעַת בַּדֵּרוּג שֶׁלָּכֶם 😊"
            )
        }
    }

    // MARK: - Hero title

    private var heroTitle: some View {
        VStack(spacing: 4) {
            // Premium subscribers see the "+" brand — matches the paywall / settings.
            Text(subs.isPremium ? "טופי+" : "טופי")
                .font(.system(size: heroTitleSize, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColor.starGold, AppColor.companionGlow, .white],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .glow(AppColor.starGold, radius: 14)
                .lineLimit(1).minimumScaleFactor(0.5)
                .scaleEffect(heroAppeared ? 1 : 0.5)
                .opacity(heroAppeared ? 1 : 0)

            Text("בְּחַר עוֹלָם וְהַתְחֵל הַרְפַּתְקָה!")
                .font(.system(size: isCompact ? 16 : 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1).minimumScaleFactor(0.6)
                .opacity(heroAppeared ? 1 : 0)
            // (The "רָמַת טוֹפִי" XP pill was removed — the level now lives in the
            // header card's level badge; tapping the avatar opens the level info.)
        }
        .sheet(isPresented: $showLevelInfo) {
            levelInfoSheet
                .environment(\.layoutDirection, .rightToLeft)
                .presentationDetents([.medium])
        }
        .eraseToAnyView()
    }

    private var levelInfoSheet: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 14, size: 12)
            VStack(spacing: AppSpacing.lg) {
                Text("⭐").font(.system(size: 54))
                Text("רָמַת טוֹפִי")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("כָּל תְּשׁוּבָה נְכוֹנָה נוֹתֶנֶת נְקוּדּוֹת. כְּשֶׁהַפַּס מִתְמַלֵּא — טוֹפִי עוֹלֶה רָמָה, וְאַתֶּם פּוֹתְחִים עוֹלָמוֹת וְהַפְתָּעוֹת חֲדָשׁוֹת!")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppSpacing.lg)

                VStack(spacing: 6) {
                    Text("רָמָה נוֹכְחִית: \(progress.companionLevel)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                    Text("עוֹד \(progress.questionsUntilNextLevel) תְּשׁוּבוֹת נְכוֹנוֹת לָרָמָה הַבָּאָה")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.vertical, AppSpacing.md)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                .padding(.horizontal, AppSpacing.lg)

                Button { showLevelInfo = false } label: {
                    Text("הֵבַנְתִּי!")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .glow(AppColor.starGold, radius: 10)
                }
                .buttonStyle(.juicy)
                .padding(.horizontal, AppSpacing.lg)
            }
            .padding(.vertical, AppSpacing.xl)
        }
    }

    private var xpProgress: Double {
        let range = max(1, progress.xpForNextLevel - progress.xpForCurrentLevel)
        let done = max(0, progress.xp - progress.xpForCurrentLevel)
        return min(1, Double(done) / Double(range))
    }

    // MARK: - Bottom CTAs

    @ViewBuilder
    private var bottomCTAs: some View {
        VStack(spacing: AppSpacing.sm) {
            // The daily gift now lives as a lively beacon in the top bar (see
            // DailyGiftBeacon) instead of a full-width bottom button. Every world
            // & Smart Adventure earns minutes, so the only bottom CTA left is the
            // "redeem my minutes" button below.
            // 💝 ONE button for everything the PARENTS gave: the gift pocket plus
            // any frozen leftover of an earlier parent window (the kid tapped "עצור
            // ושמור"). Both are parent time — never blurred with earned minutes.
            // Opens both together as one fixed manual window (outside the cap).
            if (progress.parentGiftMinutes > 0 || progress.hasPausedManualTime) && !progress.isUnlocked
                && peerWindow == nil {
                Button {
                    requestUnlock { redeemGift() }
                } label: {
                    HStack(spacing: 10) {
                        Text("💝").font(.system(size: 22))
                        Text(giftButtonTitle)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.7).lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [Color(hex: "FF6FAE"), Color(hex: "FFB347")],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .glow(Color(hex: "FF6FAE"), radius: 16)
                }
                .buttonStyle(.juicy)
                .frame(maxWidth: 480)
                .padding(.bottom, 6)
            }

            // Another device of THIS child has the window open — say so instead of
            // showing a "redeem" button that would be refused on tap, and offer
            // the TRANSFER: lock it THERE (stop-and-save, nothing lost), wait for
            // the honest confirmation, then the regular open buttons return here.
            if let other = peerWindow {
                let mins = max(1, (other.secondsLeft + 59) / 60)
                let where_ = other.kindLabel == "ipad" ? "בָּאַיְפֵּד" : (other.kindLabel == "iphone" ? "בָּאַיְפוֹן" : "בְּמַכְשִׁיר אַחֵר")
                VStack(spacing: 10) {
                    bottomHint("🎮 הַזְּמַן שֶׁלְּךָ פָּתוּחַ עַכְשָׁיו \(where_) — עוֹד \(mins) דַּקּוֹת")
                    if transferRequestedAt != nil {
                        bottomHint("🔒 נוֹעֲלִים \(where_)… רֶגַע אֶחָד ⏳")
                    } else {
                        // NO "open anyway" escape hatch (Rani). An override that
                        // opens a window while another device may still hold one
                        // is the exact hole this whole design closes — and it is
                        // no longer needed: a device that stopped playing hands
                        // the lease back on its own (honorReleaseRequestIfNeeded,
                        // and the wake-up sweep), and a genuinely dead lease
                        // expires. So the honest answer here is "try again".
                        if transferTimedOut {
                            bottomHint("לֹא הִצְלַחְנוּ לִנְעֹל \(where_) עַכְשָׁיו — אוּלַי הוּא כָּבוּי. אֶפְשָׁר לְנַסּוֹת שׁוּב 😊")
                        }
                        Button {
                            transferWindowHere(rowID: other.rowID, peerSecondsLeft: other.secondsLeft)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.arrow.circlepath")
                                    .font(.system(size: 20, weight: .bold))
                                Text("נַעֲלוּ \(where_) וּפִתְחוּ כָּאן")
                                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                                    .minimumScaleFactor(0.7).lineLimit(1)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.xl)
                            .padding(.vertical, 15)
                            .frame(maxWidth: .infinity)
                            .background(LinearGradient(colors: [Color(hex: "5B6CFF"), Color(hex: "9B5DE5")],
                                                       startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .glow(Color(hex: "5B6CFF"), radius: 14)
                        }
                        .buttonStyle(.juicy)
                        .frame(maxWidth: 480)
                    }
                }
            } else if progress.canRedeemNow {
                Button {
                    requestUnlock { redeemMinutes() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 24))
                        Text("פִּתְחוּ לִי \(progress.redeemableMinutesNow) דַּקּוֹת לְשַׂחֵק")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(AppGradient.castle)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .glow(AppColor.flameOrange, radius: 16)
                }
                .buttonStyle(.juicy)
                .frame(maxWidth: 480)
            } else if progress.dailyScreenTimeMaxedOut {
                // Wallet has minutes, but today's screen-time cap is used up — they
                // wait for tomorrow. Say so clearly (don't tell them to earn more).
                bottomHint("הִגַּעְתָּ לְמַקְסִימוּם זְמַן הַמָּסָךְ הַיּוֹמִי 🌙 — \(progress.pendingMinutes) דַּקּוֹת שְׁמוּרוֹת לְמָחָר")
            } else if progress.redeemableMinutesNow > 0 {
                // Has some minutes but below the 15-min minimum we can enforce.
                // Tell the kid how many more to go instead of hiding the button.
                bottomHint("עוֹד \(max(0, progress.minimumUnlockMinutes - progress.redeemableMinutesNow)) דַּקּוֹת וְאֶפְשָׁר לִפְתּוֹחַ זְמַן מִשְׂחָק 🎮")
            } else {
                // Empty wallet (nothing earned / all opened). Nudge to earn instead
                // of leaving the spot blank.
                bottomHint("עֲנוּ עַל שְׁאֵלוֹת כְּדֵי לְהַרְוִיחַ דַּקּוֹת מִשְׂחָק 🎮")
            }

            // "Protect my time" — the child's own code on the unlock buttons, so a
            // sibling/friend holding the device can't spend the earned minutes.
            // Discreet: a small text button, only where it's relevant (there's
            // something to protect, or a code already exists to manage).
            if let p = profiles.active,
               p.hasPlayPIN || progress.pendingMinutes > 0 || progress.hasPausedManualTime {
                Button {
                    Haptic.light()
                    playPINSheet = p.hasPlayPIN ? .manage : .setNew
                } label: {
                    Label(p.hasPlayPIN ? "הַזְּמַן שֶׁלְּךָ מוּגָן בְּקוֹד" : "הָגֵנּוּ עַל הַזְּמַן שֶׁלָּכֶם בְּקוֹד",
                          systemImage: p.hasPlayPIN ? "lock.fill" : "lock.open")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// A pill-styled hint shown in the bottom CTA spot when there's no openable
    /// grant — so the area is never silently blank.
    private func bottomHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            // Dark text on a LIGHT pill — readable, and the 🎮 emoji (dark) shows
            // up too. The dark pill made the controller emoji invisible.
            .foregroundStyle(Color(hex: "2A1E5C"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.xl).padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.92),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppColor.starGold.opacity(0.7), lineWidth: 2))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            .frame(maxWidth: 480)
    }

    // MARK: - Play-protection code (the child's own 🔒)

    /// Which KidPIN screen is up. All flows re-ask for the code — the whole
    /// point is a sibling grabbing the device mid-session.
    enum PlayPINSheet: String, Identifiable {
        case verifyUnlock      // code before spending minutes
        case setNew            // first-time setup (enter → confirm)
        case manage            // has a code: choose change / remove
        case verifyThenSet     // change: prove you know it, then pick a new one
        case verifyThenClear   // remove: prove you know it, then clear
        case forgot            // "I forgot" — pings the parents + parent-code reset
        var id: String { rawValue }
    }

    /// Run `action` immediately when the child has no protection code, otherwise
    /// hold it and ask for the code first.
    private func requestUnlock(_ action: @escaping () -> Void) {
        guard let p = profiles.active else { return }
        // Family-wide double-spend guard: if THIS child's OTHER device already has
        // a play window open, don't open a second one here (the wallet drain
        // may not have synced yet — that's how 30 minutes became 60).
        if let other = HouseholdManager.shared.otherDeviceOpenWindow(forChildID: p.id) {
            let mins = max(1, (other.secondsLeft + 59) / 60)
            let where_ = other.device.kind == "ipad" ? "בָּאַיְפֵּד" : (other.device.kind == "iphone" ? "בָּאַיְפוֹן" : "בְּמַכְשִׁיר אַחֵר")
            Haptic.warning()
            companion.console("הַזְּמַן שֶׁלְּךָ כְּבָר פָּתוּחַ \(where_) — עוֹד \(mins) דַּקּוֹת 🎮")
            return
        }
        guard p.hasPlayPIN else { action(); return }
        pendingUnlockAction = action
        playPINSheet = .verifyUnlock
    }

    private func savePlayPIN(_ pin: String) {
        guard var p = profiles.active else { return }
        p.playPIN = pin
        profiles.update(p)
        companion.cheer("הַזְּמַן שֶׁלְּךָ מוּגָן! 🔒")
    }

    private func clearPlayPIN() {
        guard var p = profiles.active else { return }
        // "" (not nil) — the deliberate-clear sentinel that survives sync merges.
        p.playPIN = ""
        profiles.update(p)
        companion.cheer("הַקּוֹד הוּסַר 🔓")
    }

    /// The KidPIN full-screen flows, attached to the map's root in `body`.
    @ViewBuilder
    fileprivate func playPINCover(_ sheet: PlayPINSheet) -> some View {
        if let p = profiles.active {
            switch sheet {
            case .verifyUnlock:
                KidPINView(profile: p, mode: .verify(title: "פּוֹתְחִים זְמַן מִשְׂחָק")) { _ in
                    playPINSheet = nil
                    let action = pendingUnlockAction
                    pendingUnlockAction = nil
                    // Present-dismiss race safety: run after the cover closes.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { action?() }
                } onCancel: {
                    pendingUnlockAction = nil
                    playPINSheet = nil
                } onForgot: {
                    pendingUnlockAction = nil
                    playPINSheet = .forgot
                }
            case .setNew:
                KidPINView(profile: p, mode: .setNew) { pin in
                    savePlayPIN(pin)
                    playPINSheet = nil
                } onCancel: { playPINSheet = nil }
            case .manage:
                PlayPINManageView(
                    onChange: { playPINSheet = .verifyThenSet },
                    onRemove: { playPINSheet = .verifyThenClear },
                    onClose: { playPINSheet = nil }
                )
            case .verifyThenSet:
                KidPINView(profile: p, mode: .verify(title: "קֹדֶם הַקּוֹד הַנּוֹכְחִי")) { _ in
                    playPINSheet = .setNew
                } onCancel: { playPINSheet = nil }
                  onForgot: { playPINSheet = .forgot }
            case .verifyThenClear:
                KidPINView(profile: p, mode: .verify(title: "קֹדֶם הַקּוֹד הַנּוֹכְחִי")) { _ in
                    clearPlayPIN()
                    playPINSheet = nil
                } onCancel: { playPINSheet = nil }
                  onForgot: { playPINSheet = .forgot }
            case .forgot:
                PlayPINForgotView(childName: p.name) {
                    // A parent authenticated with the PARENT code right here —
                    // clear the kid's code on the spot.
                    clearPlayPIN()
                    playPINSheet = nil
                    companion.cheer("הַקּוֹד אֻפַּס! אֶפְשָׁר לִבְחוֹר חָדָשׁ 🔓")
                } onClose: { playPINSheet = nil }
            }
        }
    }

    // MARK: - Actions

    // MARK: - 🔒→🔓 Window transfer between the child's own devices

    /// Ask the OTHER device (holding the open window) to lock: it stops-and-
    /// saves (earned → wallet, gift → 💝 pocket — nothing lost), acks, and
    /// uploads the refreshed balance. We do NOT open here yet — completion is
    /// detected in `completeWindowTransferIfReady` only when the other row's
    /// window is truly gone (the honest confirmation Rani asked for).
    /// Is the child's ONE play window held by another of their devices right now?
    /// The lease is authoritative when it's on; the old device-row inference is
    /// consulted only while the lease doc is idle, which is what lets a new build
    /// interoperate with a peer still on the old build.
    private var peerWindow: (kindLabel: String, secondsLeft: Int, rowID: String?)? {
        if PlayWindowLeaseManager.isEnabled {
            let l = leaseMgr.lease
            if l.isHeldElsewhere() {
                let row = (household.devicesByChild[profiles.activeID?.uuidString ?? ""] ?? [])
                    .first { $0.deviceID == l.ownerDeviceID }?.id
                return (l.ownerKind ?? "other", l.remainingSeconds(), row)
            }
            if l.isHeld { return nil }          // it's ours — nobody else
        }
        if let other = household.otherDeviceOpenWindow(forChildID: profiles.activeID ?? UUID()) {
            return (other.device.kind, other.secondsLeft, other.device.id)
        }
        return nil
    }

    /// "נעלו שם ופתחו כאן". With the lease ON this is one honest handshake:
    /// ask the owner to release, ring its doorbell, wait for the ONE atomic fact
    /// that proves it closed, then claim — the refunded minutes are already in the
    /// wallet the claim reads. Falls back to the legacy row-watching flow while
    /// the lease is off or the peer is on an old build.
    private func transferWindowHere(rowID: String?, peerSecondsLeft: Int) {
        guard PlayWindowLeaseManager.isEnabled, let cid = profiles.activeID else {
            if let rowID, let dev = (household.devicesByChild[cid_ns] ?? []).first(where: { $0.id == rowID }) {
                startWindowTransfer(other: dev)
            }
            return
        }
        Haptic.medium()
        transferTimedOut = false
        transferRequestedAt = Date()
        transferFromKind = leaseMgr.lease.ownerKind ?? ""
        Task { @MainActor in
            let kind = leaseMgr.lease.kind
            // Ask for what the CHILD is looking at. Reading only the lease made
            // this a dead end whenever the card came from the old device-row
            // inference instead: the lease is idle there, so `want` was 0 and the
            // claim came back `.insufficient` — the button visibly did nothing.
            let want = max(progress.redeemableMinutesNow,
                           max(leaseMgr.lease.remainingSeconds(), peerSecondsLeft) / 60)
            let outcome = await leaseMgr.transferHere(childID: cid, ownerDeviceRowID: rowID,
                                                      kind: kind, requestedSeconds: want * 60)
            transferRequestedAt = nil
            switch outcome {
            case .granted(let leaseID, let seconds, let wallet):
                let mins = seconds / 60
                guard mins > 0 else { return }
                if let wallet { progress.applyClaimedWallet(wallet) }
                shields.unlock(minutes: mins)
                progress.startUnlock(minutes: mins, manual: kind == .gift, leaseID: leaseID,
                                     leaseKind: kind.rawValue)
                LiveEventReporter.report(.screenTimeMoved, extra: ["fromKind": transferFromKind])
                Haptic.success()
                companion.hype("נָעוּל שָׁם! ✅ אֶפְשָׁר לְשַׂחֵק כָּאן 🎉")
            case .heldElsewhere:
                transferTimedOut = true      // owner never answered → "try again"
                Haptic.warning()
            case .insufficient, .offline:
                transferTimedOut = true
                Haptic.warning()
            }
        }
    }

    private var cid_ns: String { profiles.activeID?.uuidString ?? "" }

    private func startWindowTransfer(other: ChildDevice) {
        Haptic.medium()
        transferTimedOut = false
        transferRequestedAt = Date()
        transferFromKind = other.kind ?? ""
        household.lockOtherDeviceWindow(deviceRowID: other.id)
        // Honest timeout: the other device may be off/offline. Give it 30s;
        // the command stays queued in the cloud and will still apply when it
        // wakes — but we stop holding the kid here waiting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if transferRequestedAt != nil,
               household.otherDeviceOpenWindow(forChildID: profiles.activeID ?? UUID()) != nil {
                transferRequestedAt = nil
                transferTimedOut = true
                Haptic.warning()
            }
        }
    }

    /// Called when the live device rows change: if a transfer is in flight and
    /// the other window is CONFIRMED closed, pull the freshest cloud balance
    /// (the locked device just pushed it) and hand back the regular open flow.
    private func completeWindowTransferIfReady() {
        guard transferRequestedAt != nil, let cid = profiles.activeID,
              household.otherDeviceOpenWindow(forChildID: cid) == nil else { return }
        transferRequestedAt = nil
        // Tell the parents the play window moved between the child's devices —
        // they asked to know (Rani), and the lock there was already applied.
        LiveEventReporter.report(.screenTimeMoved, extra: ["fromKind": transferFromKind])
        Task { @MainActor in
            // MERGE, never a wholesale apply gated on `revision`: that gate used a
            // per-device counter, so the busier device ignored the balance the
            // locked device had just banked (opening its own stale wallet — a
            // double-spend caused by the very feature meant to prevent one), and
            // when it did apply it could lower local accumulators outright.
            if let cloud = await RemoteSyncManager.shared.fetchSnapshot(for: cid) {
                _ = ProgressStore.shared.mergeRemote(cloud)
            }
            Haptic.success()
            companion.hype("נָעוּל שָׁם! ✅ הַדַּקּוֹת חָזְרוּ — אֶפְשָׁר לִפְתּוֹחַ כָּאן 🎉")
        }
    }

    // MARK: - 🎮 Games warm-up gate (learning first, games after)

    /// Correct answers needed today before the mini-games open. One reward
    /// batch (10) for readers; 5 for גן kids (10 is a lot pre-reading).
    private var gamesGateTarget: Int {
        (profiles.active?.effectiveGrade ?? 1) <= 0 ? 5 : 10
    }
    private var gamesGateRemaining: Int { max(0, gamesGateTarget - progress.correctToday) }

    // MARK: - 🧹 Chores (header card, twin of the daily challenge)

    /// Compact chores entry beside אתגר יומי — identical size and anatomy:
    /// broom ring (available-count badge) → title → live line → today's-progress
    /// track (approved chores out of the day's list).
    private var choresTopCard: some View {
        let all = profiles.activeID.map { choreStore.chores(forChild: $0) } ?? []
        let available = all.filter { $0.isAvailable }.count
        let pending = all.filter { $0.isPendingApproval }.count
        let doneToday = all.filter { $0.approvedToday }.count
        let frac = all.isEmpty ? 0 : CGFloat(doneToday) / CGFloat(all.count)
        return Button {
            Haptic.light()
            showingChores = true
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: "F4A261"), Color(hex: "E76F51")],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 1.5))
                        Text("🧹").font(.system(size: 23))
                    }
                    if available > 0 {
                        Text("\(available)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(AppColor.textOnLight)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.white))
                            .overlay(Capsule().stroke(Color(hex: "E76F51"), lineWidth: 1.2))
                            .offset(x: 6, y: 4)
                    }
                }
                Text("מַטְלוֹת הַבַּיִת")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                Group {
                    Text(pending > 0 ? "מְחַכֶּה לְאִשּׁוּר 🕐"
                         : doneToday > 0 ? "\(doneToday) הֻשְׁלְמוּ הַיּוֹם! 💪"
                         : "עוֹזְרִים — וּבוֹחֲרִים פְּרָס!")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(height: 26)

                headerTrack(frac: frac,
                            fill: LinearGradient(colors: [Color(hex: "FFD23F"), Color(hex: "F4A261")],
                                                 startPoint: .leading, endPoint: .trailing),
                            glowColor: Color(hex: "F4A261"),
                            tip: frac > 0 ? "🧹" : nil)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(height: Self.headerCardHeight)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "F4A261").opacity(0.50),
                                                  Color(hex: "E76F51").opacity(0.40),
                                                  Color(hex: "7C4DFF").opacity(0.30)],
                                         startPoint: .topTrailing, endPoint: .bottomLeading))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(LinearGradient(colors: [Color(hex: "F4A261").opacity(0.8), .white.opacity(0.2)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
            )
            .shadow(color: Color(hex: "F4A261").opacity(0.25), radius: 10, y: 4)
        }
        .buttonStyle(.juicy)
        .environment(\.layoutDirection, .rightToLeft)
    }
    /// `correctToday` resets at midnight, so the warm-up is a fresh daily goal.
    private var gamesUnlockedToday: Bool { gamesGateRemaining == 0 }

    /// One celebratory line the first time the games open each day.
    private func celebrateGamesUnlockIfNeeded() {
        guard gamesUnlockedToday else { return }
        let key = "gamesUnlockCelebratedDate"
        if DayGate.usedToday(UserDefaults.standard.object(forKey: key) as? Date) { return }
        UserDefaults.standard.set(Date(), forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            companion.hype(Gendered.g("פָּתַחְתָּ אֶת הַמִּשְׂחָקִים לְהַיּוֹם! 🎮✨",
                                      "פָּתַחְתְּ אֶת הַמִּשְׂחָקִים לְהַיּוֹם! 🎮✨"))
        }
    }

    private func greetIfNeeded() {
        if progress.dayStreak == 0 {
            companion.cheer("הֵיי! יַאלְלָה לְהַרְפַּתְקָה 🌟")
        } else if progress.dayStreak == 1 {
            companion.cheer("בָּרוּךְ הַבָּא! 👋")
        } else {
            companion.cheer("חָזַרְתָּ! \(progress.dayStreak) יָמִים בְּרֶצֶף 🔥")
        }
    }

    /// Auto-presents the Lucky Wheel once the child has earned a free spin
    /// (after `questionsPerWheel` answers), then resets the counter so it
    /// won't pop again until the next batch. Replaces the old top-bar button.
    private func maybeAutoPresentWheel() {
        guard progress.freeWheelAvailable, !showingWheel, !showingSmartFeed else { return }
        progress.resetWheelProgress()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showingWheel = true
        }
    }

    /// One-time, after a child device joins: offer to pick which apps to lock.
    /// Shielding is device-local, so this has to happen here on the child device.
    private func maybePromptAppLockSetup() {
        guard settings.deviceRole == .child,
              !settings.hasPromptedChildAppLock,
              SelectionStorage.isEmpty(settings.activitySelectionData),
              !showingWheel, !showingSmartFeed
        else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showingAppLockSetup = true
        }
    }

    private func checkWorldUnlocks() {
        for world in Worlds.all where !progress.unlockedWorlds.contains(world.id) {
            if progress.canUnlock(world: world) {
                progress.unlockWorld(world.id)
                companion.wow("\(world.emoji) \(world.name) נִפְתַּח!")
            }
        }
    }

    /// Open earned minutes. With the lease ON, the CLAIM commits first (wallet
    /// debit + lease write in one transaction) and the shield only opens on a
    /// granted claim — never unshield before the claim is durable.
    private func redeemMinutes() {
        guard !progress.isUnlocked else { return }
        guard PlayWindowLeaseManager.isEnabled, let cid = profiles.activeID else {
            legacyRedeemMinutes(); return
        }
        let want = progress.redeemableMinutesNow
        guard want > 0 else { return }
        Task { @MainActor in
            let outcome = await PlayWindowLeaseManager.shared.claim(
                childID: cid, kind: .earned, requestedSeconds: want * 60)
            switch outcome {
            case .granted(let leaseID, let seconds, let wallet):
                let mins = seconds / 60
                guard mins > 0 else { return }
                if let wallet { progress.applyClaimedWallet(wallet) }
                shields.unlock(minutes: mins)
                progress.startUnlock(minutes: mins, leaseID: leaseID, leaseKind: "earned")
                LearningHistoryStore.shared.recordMinutesUsed(mins)
                LiveEventReporter.report(.screenTimeStart, extra: ["minutes": mins])
            case .heldElsewhere:
                // The lease listener drives the "open on your iPad" card + transfer.
                Haptic.warning()
            case .insufficient:
                Haptic.light()
            case .offline:
                // Transactions don't queue offline. Fall back to the bounded local
                // window so a kid with no network is never stranded.
                legacyRedeemMinutes()
            }
        }
    }

    private func legacyRedeemMinutes() {
        // Re-check (a fast double-tap with the 💝 button could open a manual
        // window first; without this guard startUnlock would overwrite it and
        // the gift window's banked leftover would be lost).
        guard !progress.isUnlocked else { return }
        // Cap a single unlock to today's remaining screen-time allowance; the
        // accumulated wallet beyond the daily cap stays for future days.
        let minutes = progress.consumeMinutesForUnlock()
        guard minutes > 0 else { return }
        shields.unlock(minutes: minutes)
        progress.startUnlock(minutes: minutes)
        LearningHistoryStore.shared.recordMinutesUsed(minutes)
        // Tell the parent the child just opened screen time (+ how many minutes).
        LiveEventReporter.report(.screenTimeStart, extra: ["minutes": minutes])
    }

    /// "מַתָּנָה מֵהַהוֹרִים · 10 דַּקּוֹת + ❄️ 8 שְׁמוּרוֹת" — whatever parts exist.
    private var giftButtonTitle: String {
        let gift = progress.parentGiftMinutes
        let frozen = progress.pausedManualMinutes
        var parts: [String] = []
        if gift > 0 { parts.append("\(gift) דַּקּוֹת") }
        if frozen > 0 { parts.append("❄️ \(frozen) שְׁמוּרוֹת") }
        return "מַתָּנָה מֵהַהוֹרִים · " + parts.joined(separator: " + ")
    }

    /// 💝 Open ALL parent time as one fixed manual window: the gift pocket plus
    /// any frozen leftover. Outside the daily cap; leftover freezes again on
    /// stop-and-save (so nothing a parent gave is ever wasted).
    private func redeemGift() {
        guard !progress.isUnlocked else { return }
        guard PlayWindowLeaseManager.isEnabled, let cid = profiles.activeID,
              progress.parentGiftMinutes > 0 else { legacyRedeemGift(); return }
        let want = progress.parentGiftMinutes
        Task { @MainActor in
            let outcome = await PlayWindowLeaseManager.shared.claim(
                childID: cid, kind: .gift, requestedSeconds: want * 60)
            switch outcome {
            case .granted(let leaseID, let seconds, let wallet):
                let mins = seconds / 60
                guard mins > 0 else { return }
                if let wallet { progress.applyClaimedWallet(wallet) }
                shields.unlock(minutes: mins)
                progress.startUnlock(minutes: mins, manual: true, leaseID: leaseID, leaseKind: "gift")
                LiveEventReporter.report(.screenTimeStart, extra: ["minutes": mins, "gift": true])
            case .heldElsewhere: Haptic.warning()
            case .insufficient:  Haptic.light()
            case .offline:       legacyRedeemGift()
            }
        }
    }

    private func legacyRedeemGift() {
        guard !progress.isUnlocked else { return }   // re-check: PIN cover runs us later
        let gift = progress.consumeParentGiftForUnlock()
        // Frozen seconds resume as their own manual window; fold the gift on top.
        let frozenMinutes = progress.hasPausedManualTime ? progress.resumeManualUnlock() : 0
        let total = gift + frozenMinutes
        guard total > 0 else { return }
        if gift > 0 {
            if frozenMinutes > 0 { progress.extendUnlock(minutes: gift) }
            else { progress.startUnlock(minutes: gift, manual: true, leaseKind: "gift") }
        }
        shields.unlock(minutes: total)
        LiveEventReporter.report(.screenTimeStart, extra: ["minutes": total, "gift": true])
    }

}

/// Minimal animated XP bar for the hero header.
struct XPBarMini: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule()
                    .fill(AppGradient.gold)
                    .frame(width: geo.size.width * progress)
                    .glow(AppColor.starGold, radius: 4)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 6)
    }
}

#Preview {
    WorldMapView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(ShieldManager.shared)
        .environmentObject(ProfileStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}

/// Aligns the avatar, the name, and each header button CIRCLE on one line — the
/// button captions hang below without shifting it.
private extension VerticalAlignment {
    enum HeaderIconID: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
    }
    static let headerIcon = VerticalAlignment(HeaderIconID.self)
}

/// Type-erasure boundary for the header/scaffold builders above. NOT cosmetic:
/// without it, the fully-inlined generic type of body (topBar → navButtonsRow →
/// navButton → …) is so deep that a DEBUG build EXC_BAD_ACCESSes inside the Swift
/// runtime's metadata instantiation (buildDescriptorPath) on a physical device —
/// the main thread there has a 1MB stack vs 8MB in the simulator, which is why it
/// only crashed on-device. AnyView at each builder caps the nesting depth.
private extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}
