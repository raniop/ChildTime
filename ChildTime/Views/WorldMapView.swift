import SwiftUI

struct WorldMapView: View {
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var subs: SubscriptionManager
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
    @State private var showingShop = false
    @State private var showingWheel = false
    @State private var showingGames = false
    @State private var showingLeaderboard = false
    @State private var showingSmartFeed = false
    @State private var showingChildSettings = false
    @State private var showingPaywall = false
    @State private var showingAppLockSetup = false
    @State private var lastSeenStars = 0
    @State private var heroAppeared = false
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
        return Worlds.all.filter { allowed.contains($0.topic) }
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
                    eventBanner
                        .frame(maxWidth: worldGridMaxWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, homeHPad)
                    if kidMode.active { kidExitBar }
                    VStack(spacing: AppSpacing.lg) {
                        if isCompact {
                            heroTitle
                                .padding(.top, AppSpacing.sm)
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

                            FeatureCard(
                                emoji: "🎮",
                                title: "מִשְׂחָקִים",
                                subtitle: "מֵרוֹץ נָכוֹן/לֹא · הַתְאָמַת זוּגוֹת",
                                gradient: LinearGradient(colors: [Color(hex: "EF476F"), Color(hex: "9B5DE5")],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing),
                                glowColor: Color(hex: "EF476F")
                            ) {
                                Haptic.light()
                                showingGames = true
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
                        }
                    }
                    .frame(maxWidth: worldGridMaxWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, homeHPad)
                    // Breathing room between the header card and the world grid.
                    .padding(.top, isCompact ? AppSpacing.sm : AppSpacing.xxxl)
                    // Big bottom inset on iPhone so the cards aren't hidden
                    // by the floating daily-chest CTA + companion.
                    .padding(.bottom, isCompact ? 360 : 260)
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
        .onAppear {
            lastSeenStars = progress.stars
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
            // parent's own device.
            ParentGateView {
                ChildDeviceControlsView()
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .fullScreenCover(isPresented: $showingAppLockSetup) {
            ChildAppLockSetupView()
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
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView()
                .environmentObject(subs)
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
    }

    // MARK: - Top bar

    private var topBar: some View {
        let avatarSize: CGFloat = isCompact ? 46 : 58
        let btnSize: CGFloat = isCompact ? 42 : 52
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
                // center, since the card is centered). On iPhone it stays below.
                if !isCompact {
                    heroTitle
                        .frame(maxWidth: 360)
                }
            }
            statsPanel
            dailyChallengeCard
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(isCompact ? 14 : 18)
        .background(glassCard)
        .padding(.top, AppSpacing.sm)
    }

    /// Daily challenge: answer N questions today → collect a reward, and keep the
    /// 🔥 day-streak alive. The "don't break the streak" loop that brings kids back
    /// every day. Forced RTL inside the LTR header so the Hebrew reads correctly.
    private var dailyChallengeCard: some View {
        let target = ProgressStore.dailyChallengeTarget
        let done = progress.dailyChallengeProgress
        let ready = progress.dailyChallengeRewardReady
        let claimed = progress.dailyChallengeClaimed
        return Button {
            Haptic.light()
            infoSheet = .dailyChallenge
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("🔥").font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("אֶתְגָּר יוֹמִי")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(progress.dayStreak > 0 ? "\(progress.dayStreak) יָמִים בְּרֶצֶף" : "מַתְחִילִים רֶצֶף חָדָשׁ!")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    if claimed {
                        Text("✓ הוּשְׁלַם הַיּוֹם")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppColor.successMint)
                    } else if ready {
                        Text("מוּכָן! 🎁")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppColor.textOnLight)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(AppGradient.gold, in: Capsule())
                    } else {
                        HStack(spacing: 4) {
                            Text("\(done)/\(target)")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 12, weight: .heavy)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                // Progress bar of today's answers toward the goal.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        Capsule().fill(ready || claimed ? AnyShapeStyle(AppColor.successMint) : AnyShapeStyle(AppGradient.gold))
                            .frame(width: geo.size.width * CGFloat(done) / CGFloat(max(1, target)))
                    }
                }
                .frame(height: 8)
            }
            .padding(isCompact ? 10 : 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .rightToLeft)
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

    /// Limited-time event banner (e.g. weekend 💎×2 / topic-of-the-day). Driven
    /// purely by GameEvent.current() so it appears/disappears with the date.
    @ViewBuilder private var eventBanner: some View {
        if let event = GameEvent.current() {
            Button {
                Haptic.light()
                infoSheet = .event
            } label: {
                HStack(spacing: 8) {
                    Text(event.emoji).font(.system(size: 18))
                    Text(event.bannerText)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.textOnLight)
                        .lineLimit(2).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(AppColor.textOnLight.opacity(0.6))
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.5), lineWidth: 1))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .buttonStyle(.juicy)
            .padding(.top, 10)
            .environment(\.layoutDirection, .rightToLeft)
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
    }

    private func navButtonsRow(size: CGFloat) -> some View {
        HStack(spacing: isCompact ? 5 : 12) {
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
                .font(.system(size: isCompact ? 10 : 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                // Keep each caption within its button column so a long word (e.g.
                // "מִשְׂחָקִים") can't spill over and collide with the neighbour's
                // caption. Shrink-to-fit instead of truncating to "…".
                .minimumScaleFactor(0.6)
                .frame(width: size + (isCompact ? 8 : 16))
        }
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
            // Frozen manual time the child paused earlier — let them resume it so a
            // parent's grant is never wasted. Shown above the earn/redeem CTA.
            if progress.hasPausedManualTime {
                Button {
                    resumeManual()
                } label: {
                    HStack(spacing: 10) {
                        Text("❄️").font(.system(size: 22))
                        Text("הַמְשֵׁךְ זְמַן מָסָךְ · \(progress.pausedManualMinutes) דַּקּוֹת שְׁמוּרוֹת")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.7).lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [Color(hex: "5B6CFF"), Color(hex: "06D6A0")],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .glow(Color(hex: "5B6CFF"), radius: 16)
                }
                .buttonStyle(.juicy)
                .frame(maxWidth: 480)
                .padding(.bottom, 6)
            }

            if progress.canRedeemNow {
                Button {
                    redeemMinutes()
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

    // MARK: - Actions

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

    private func redeemMinutes() {
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

    /// Resume the frozen leftover of a parent's manual grant (reopens the shield +
    /// the play window from the exact saved seconds).
    private func resumeManual() {
        let minutes = progress.resumeManualUnlock()
        guard minutes > 0 else { return }
        shields.unlock(minutes: minutes)
        LiveEventReporter.report(.screenTimeStart, extra: ["minutes": minutes])
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
