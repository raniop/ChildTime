import SwiftUI

struct WorldMapView: View {
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var subs: SubscriptionManager
    @Environment(\.horizontalSizeClass) private var hsc

    @ObservedObject private var friends = FriendsManager.shared
    @State private var companion = CompanionController()
    @State private var selectedWorld: World?
    @State private var showDailyChest = false
    @State private var showingParentGate = false
    @State private var showingDemo = false
    @State private var showingShop = false
    @State private var showingWheel = false
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
    private var heroTitleSize: CGFloat { isCompact ? 36 : 44 }

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

    /// Total width cap for the world grid (so the 3 cards stay centered on iPad
    /// instead of pushing to one edge).
    private var worldGridMaxWidth: CGFloat {
        isCompact ? .infinity : 860
    }

    var body: some View {
        ZStack {
            // Layered background
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs.home()
            SparkleField(count: 25, size: 14)

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        heroTitle
                            .padding(.top, AppSpacing.sm)
                        LazyVGrid(
                            columns: worldGridColumns,
                            spacing: AppSpacing.md
                        ) {
                            FeatureCard(
                                emoji: "🧠",
                                title: "הַרְפַּתְקָה חֲכָמָה",
                                subtitle: "שְׁאֵלוֹת בִּמְיֻחָד בִּשְׁבִילְךָ",
                                gradient: AppGradient.portal,
                                glowColor: AppColor.companionGlow
                            ) {
                                // No companion line here — we leave this screen
                                // immediately, so a bubble would only flash & clip.
                                Haptic.light()
                                showingSmartFeed = true
                            }
                            .frame(maxWidth: .infinity)

                            ForEach(Worlds.all) { world in
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
                        .frame(maxWidth: worldGridMaxWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, AppSpacing.lg)
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
                topInset: isCompact ? 140 : 90,
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
            }
        }
        // A fullScreenCover doesn't re-fire the map's .onAppear when it closes,
        // so check the wheel when a play session actually ends.
        .onChange(of: showingSmartFeed) { _, shown in
            if !shown { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { maybeAutoPresentWheel() } }
        }
        .onChange(of: selectedWorld?.id) { _, world in
            if world == nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { maybeAutoPresentWheel() } }
        }
        .onChange(of: progress.stars) { _, new in
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
        // A friend invite link opened the app → jump to the leaderboard, which
        // consumes the pending code and adds the friend.
        .onChange(of: friends.pendingFriendCode) { _, code in
            if code != nil { showingLeaderboard = true }
        }
        .onAppear {
            if friends.pendingFriendCode != nil { showingLeaderboard = true }
        }
        .fullScreenCover(isPresented: $showingWheel) {
            LuckyWheelView { showingWheel = false }
        }
        .fullScreenCover(isPresented: $showingSmartFeed) {
            // Smart Feed play — grants minutes (capped by the daily maximum).
            QuestionRunnerView(mode: .smartFeed, purpose: .earnTime)
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

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        if isCompact {
            // iPhone — stack actions and stats so nothing clips. The earned
            // play-minutes badge sits at the top-left (trailing) corner, above
            // everything, since it's the reward the child cares about most.
            VStack(spacing: 8) {
                HStack(spacing: AppSpacing.sm) {
                    topBarActions(buttonSize: 40, avatarSize: 44, iconSize: 18)
                    Spacer(minLength: 8)
                    minutesButton
                }
                topBarStats(compactStats: true)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
        } else {
            // iPad — one wide row, minutes pinned to the far-left (trailing) end.
            HStack(spacing: AppSpacing.sm) {
                topBarActions(buttonSize: 46, avatarSize: 50, iconSize: 22)
                Spacer()
                topBarStats(compactStats: false)
                minutesButton
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
        }
    }

    private func topBarActions(buttonSize: CGFloat, avatarSize: CGFloat, iconSize: CGFloat) -> some View {
        HStack(spacing: AppSpacing.sm) {
            // The child's avatar now lives ONLY as the floating buddy — tapping
            // it opens the avatar settings. So the top bar keeps just the
            // settings / shop / gift actions.
            Button {
                showingParentGate = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: buttonSize, height: buttonSize)
                    .background(.white.opacity(0.15), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
            }
            .onLongPressGesture(minimumDuration: 1.5) { showingDemo = true }

            Button {
                Haptic.light()
                showingShop = true
            } label: {
                Text("🛍️")
                    .font(.system(size: iconSize + 3))
                    .frame(width: buttonSize, height: buttonSize)
                    .background(.white.opacity(0.15), in: Circle())
                    .overlay(Circle().stroke(AppColor.starGold.opacity(0.6), lineWidth: 1.5))
                    .glow(AppColor.starGold.opacity(0.5), radius: 6)
            }

            // Friends leaderboard — mint, clearly distinct from the gold shop.
            Button {
                Haptic.light()
                showingLeaderboard = true
            } label: {
                Image(systemName: "trophy.fill")
                    .font(.system(size: iconSize - 2, weight: .medium))
                    .foregroundStyle(AppColor.successMint)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(.white.opacity(0.15), in: Circle())
                    .overlay(Circle().stroke(AppColor.successMint.opacity(0.7), lineWidth: 1.5))
                    .glow(AppColor.successMint.opacity(0.45), radius: 5)
            }

        }
    }

    /// The play-minutes badge. Shows "earned / daily-cap" right INSIDE the pill
    /// (just the 🎮 icon — no "דק׳" word, no white caption beneath it). Tapping
    /// opens the popover that spells out the exact numbers.
    private var minutesButton: some View {
        let cap = progress.dailyCap
        let hasMinutes = progress.pendingMinutes > 0
        return Button {
            Haptic.light()
            infoStat = .minutes
        } label: {
            HStack(spacing: 6) {
                Text("🎮").font(.system(size: 18))
                Text(cap.enabled
                     ? "\(progress.minutesEarnedToday)/\(cap.max)"
                     : "\(progress.pendingMinutes)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .contentTransition(.numericText(value: Double(progress.minutesEarnedToday)))
            }
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: hasMinutes
                            ? [AppColor.successMint.opacity(0.4), Color(hex: "118AB2").opacity(0.4)]
                            : [Color.white.opacity(0.12), Color.white.opacity(0.12)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .overlay(Capsule().stroke(hasMinutes ? AppColor.successMint : .white.opacity(0.2),
                                          lineWidth: hasMinutes ? 2 : 1))
            )
            .glow(hasMinutes ? AppColor.successMint : .clear, radius: hasMinutes ? 14 : 0)
        }
        .buttonStyle(.plain)
        .popover(isPresented: popoverBinding(for: .minutes)) { statInfoCard(.minutes) }
    }

    private func topBarStats(compactStats: Bool) -> some View {
        HStack(spacing: compactStats ? 6 : AppSpacing.sm) {
            if compactStats { Spacer(minLength: 0) }

            // (The daily gift 🎁 now floats above the buddy's head — see
            // FloatingCompanion(showGift:) below — so it's no longer in this row.)

            // ⭐ stars — the leaderboard rank (never spent).
            Button {
                Haptic.light()
                infoStat = .stars
            } label: {
                statChip(
                    icon: "star.fill",
                    value: progress.stars,
                    label: nil,
                    color: AppColor.starGold,
                    prominent: false
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: popoverBinding(for: .stars)) { statInfoCard(.stars) }

            // 💎 diamonds — the spendable shop wallet. Tap opens the shop.
            Button {
                Haptic.light()
                infoStat = .diamonds
            } label: {
                statChip(
                    icon: "diamond.fill",
                    emoji: "💎",
                    value: progress.diamonds,
                    label: nil,
                    color: AppColor.diamondBlue,
                    prominent: false
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: popoverBinding(for: .diamonds)) { statInfoCard(.diamonds) }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7),
                   value: progress.dailyChestAvailable)
    }

    // MARK: - Stat info popovers

    private func popoverBinding(for stat: StatInfo) -> Binding<Bool> {
        Binding(
            get: { infoStat == stat },
            set: { isShowing in
                if !isShowing { infoStat = nil }
            }
        )
    }

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

            // Quick jump to the shop, straight from the diamonds explanation
            // (diamonds are what the shop spends).
            if stat == .diamonds {
                Button {
                    Haptic.light()
                    infoStat = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showingShop = true }
                } label: {
                    Text("🛍️ לַחֲנוּת")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .glow(AppColor.starGold, radius: 8)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .padding(20)
        .frame(width: 340)
        .presentationCompactAdaptation(.popover)
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
            var lines = ["יֵשׁ לְךָ עַכְשָׁיו \(progress.pendingMinutes) דַּקּוֹת מִשְׂחָק לְשַׂחֵק."]
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

    private func statChip(icon: String, emoji: String? = nil, value: Int, label: String?, color: Color, prominent: Bool) -> some View {
        HStack(spacing: 6) {
            if let emoji {
                // Use the colorful emoji glyph (e.g. the blue 💎) so it matches
                // the shop exactly, instead of a flat tinted SF symbol.
                Text(emoji).font(.system(size: 16))
            } else {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 16, weight: .semibold))
            }
            Text(value.currencyShort)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .contentTransition(.numericText(value: Double(value)))
            if let label = label {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(.white.opacity(prominent ? 0.25 : 0.15))
                .overlay(Capsule().stroke(color.opacity(prominent ? 0.6 : 0.3), lineWidth: 1.5))
        )
        .glow(color, radius: prominent ? 12 : 0)
    }

    // MARK: - Hero title

    private var heroTitle: some View {
        VStack(spacing: 4) {
            Text("טוֹפִי")
                .font(.system(size: heroTitleSize, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColor.starGold, AppColor.companionGlow, .white],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .glow(AppColor.starGold, radius: 14)
                .scaleEffect(heroAppeared ? 1 : 0.5)
                .opacity(heroAppeared ? 1 : 0)

            Text("בְּחַר עוֹלָם וְהַתְחֵל הַרְפַּתְקָה!")
                .font(.system(size: isCompact ? 16 : 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .opacity(heroAppeared ? 1 : 0)

            // XP bar — small, below subtitle. Tap for an explanation.
            Button {
                Haptic.light()
                showLevelInfo = true
            } label: {
                HStack(spacing: 8) {
                    Text("רָמַת טוֹפִי \(progress.companionLevel)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                    XPBarMini(progress: xpProgress)
                        .frame(width: 100)
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .opacity(heroAppeared ? 1 : 0)
            .padding(.top, 4)
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
                Text("כָּל תְּשׁוּבָה נְכוֹנָה נוֹתֶנֶת נְקֻדּוֹת. כְּשֶׁהַפַּס מִתְמַלֵּא — טוֹפִי עוֹלֶה רָמָה, וְאַתֶּם פּוֹתְחִים עוֹלָמוֹת וְהַפְתָּעוֹת חֲדָשׁוֹת!")
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
            if progress.pendingMinutes > 0 {
                Button {
                    redeemMinutes()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 24))
                        Text("פִּתְחוּ לִי \(progress.pendingMinutes) דַּקּוֹת לְשַׂחֵק")
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
        let minutes = progress.consumePendingMinutes()
        guard minutes > 0 else { return }
        shields.unlock(minutes: minutes)
        progress.startUnlock(minutes: minutes)
        LearningHistoryStore.shared.recordMinutesUsed(minutes)
        // Tell the parent the child just opened screen time (+ how many minutes).
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
