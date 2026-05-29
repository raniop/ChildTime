import SwiftUI

struct WorldMapView: View {
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var subs: SubscriptionManager
    @Environment(\.horizontalSizeClass) private var hsc

    @State private var companion = CompanionController()
    @State private var selectedWorld: World?
    @State private var showDailyChest = false
    @State private var showingParentGate = false
    @State private var showingDemo = false
    @State private var showingShop = false
    @State private var showingWheel = false
    @State private var showingSmartFeed = false
    @State private var showingChildSettings = false
    @State private var showingPaywall = false
    @State private var lastSeenStars = 0
    @State private var heroAppeared = false

    private var isCompact: Bool { hsc == .compact }
    private var companionSize: CGFloat { isCompact ? 90 : 120 }
    private var heroTitleSize: CGFloat { isCompact ? 36 : 44 }

    @State private var infoStat: StatInfo? = nil

    enum StatInfo: String, Identifiable {
        case score, minutes, stars, gems
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
                                Haptic.light()
                                companion.cheer("יַאלְלָה, הַרְפַּתְקָה חֲכָמָה! 🧠")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showingSmartFeed = true
                                }
                            }
                            .frame(maxWidth: .infinity)

                            ForEach(Worlds.all) { world in
                                WorldCard(
                                    world: world,
                                    isUnlocked: progress.unlockedWorlds.contains(world.id),
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
                size: companionSize,
                topInset: isCompact ? 140 : 90,
                bottomInset: isCompact ? 220 : 200,
                horizontalInset: AppSpacing.lg
            )
        }
        .onAppear {
            lastSeenStars = progress.stars
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                greetIfNeeded()
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                heroAppeared = true
            }
            checkWorldUnlocks()
            // Wheel pops when we return to the map after earning a free spin.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                maybeAutoPresentWheel()
            }
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
            ParentGateView()
        }
        .fullScreenCover(isPresented: $showingShop) {
            ShopView()
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
            // iPhone — stack actions and stats so nothing clips.
            VStack(spacing: 8) {
                topBarActions(buttonSize: 40, avatarSize: 44, iconSize: 18)
                topBarStats(compactStats: true)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
        } else {
            // iPad — one wide row.
            HStack(spacing: AppSpacing.sm) {
                topBarActions(buttonSize: 46, avatarSize: 50, iconSize: 22)
                Spacer()
                topBarStats(compactStats: false)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
        }
    }

    private func topBarActions(buttonSize: CGFloat, avatarSize: CGFloat, iconSize: CGFloat) -> some View {
        HStack(spacing: AppSpacing.sm) {
            // Tapping the avatar opens the child's own basic profile settings.
            // Show the real, cosmetic-wearing avatar (hat/glasses on the head)
            // so purchases are visible right where the child lives.
            if let active = profiles.active {
                Button {
                    Haptic.light()
                    showingChildSettings = true
                } label: {
                    ProfileAvatarView(profile: active, size: buttonSize, headItemsOnly: true)
                }
                .buttonStyle(.plain)
            } else {
                ChildAvatarView(size: buttonSize)
            }

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
                Image(systemName: "bag.fill")
                    .font(.system(size: iconSize - 2, weight: .medium))
                    .foregroundStyle(AppColor.starGold)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(.white.opacity(0.15), in: Circle())
                    .overlay(Circle().stroke(AppColor.starGold.opacity(0.6), lineWidth: 1.5))
                    .glow(AppColor.starGold.opacity(0.5), radius: 6)
            }

            if isCompact { Spacer() }

            // Daily gift lives here — a lively dancing icon, but only when there
            // is actually a gift to claim today. Once opened it disappears for
            // the rest of the day (see `dailyChestAvailable`).
            if progress.dailyChestAvailable {
                DailyGiftBeacon(size: buttonSize + 6) {
                    showDailyChest = true
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7),
                   value: progress.dailyChestAvailable)
    }

    private func topBarStats(compactStats: Bool) -> some View {
        HStack(spacing: compactStats ? 6 : AppSpacing.sm) {
            if compactStats { Spacer(minLength: 0) }

            Button {
                Haptic.light()
                infoStat = .minutes
            } label: {
                MinutesBadge(minutes: progress.pendingMinutes, compact: true)
            }
            .buttonStyle(.plain)
            .popover(isPresented: popoverBinding(for: .minutes)) { statInfoCard(.minutes) }

            Button {
                Haptic.light()
                infoStat = .score
            } label: {
                statChip(
                    icon: "trophy.fill",
                    value: "\(progress.totalScore)",
                    label: nil,
                    color: AppColor.starGold,
                    prominent: false
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: popoverBinding(for: .score)) { statInfoCard(.score) }

            Button {
                Haptic.light()
                infoStat = .stars
            } label: {
                statChip(
                    icon: "star.fill",
                    value: "\(progress.stars)",
                    label: nil,
                    color: AppColor.starGold,
                    prominent: false
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: popoverBinding(for: .stars)) { statInfoCard(.stars) }

            Button {
                Haptic.light()
                infoStat = .gems
            } label: {
                statChip(
                    icon: "diamond.fill",
                    value: "\(progress.gems)",
                    label: nil,
                    color: AppColor.gemPurple,
                    prominent: false
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: popoverBinding(for: .gems)) { statInfoCard(.gems) }
        }
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
        VStack(alignment: .trailing, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(info.emoji)
                    .font(.system(size: 46))
                VStack(alignment: .trailing, spacing: 2) {
                    Text(info.title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(info.subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Text(info.body)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if let tip = info.tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(AppColor.starGold)
                        .font(.system(size: 16))
                    Text(tip)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
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
        case .score:
            return InfoContent(
                emoji: "🏆",
                title: "נִקּוּד",
                subtitle: "סַךְ הַנְּקֻדּוֹת שֶׁלְּךָ",
                body: "נְקֻדּוֹת נִצְבָּרוֹת עַל כָּל תְּשׁוּבָה נְכוֹנָה. שְׁאֵלוֹת קָשׁוֹת יוֹתֵר, רְצָפִים וּשְׁאֵלוֹת זָהָב שָׁווֹת יוֹתֵר נְקֻדּוֹת!",
                tip: "הַנִּקּוּד מַמְשִׁיךְ לַעֲלוֹת כְּכָל שֶׁאַתָּה לוֹמֵד — נַסֵּה לִשְׁבֹּר אֶת הַשִּׂיא שֶׁלְּךָ."
            )
        case .minutes:
            return InfoContent(
                emoji: "🎮",
                title: "דַּקּוֹת מִשְׂחָק",
                subtitle: "מַה שֶּׁצָּבַרְתָּ",
                body: "אֵלֶּה הַדַּקּוֹת שֶׁהִרְוַחְתָּ כְּדֵי לְשַׂחֵק בָּאַפְּלִיקַצְיוֹת שֶׁהַהוֹרֶה אִשֵּׁר. כָּל תְּשׁוּבָה נְכוֹנָה = עוֹד דַּקּוֹת!",
                tip: "לְחַץ עַל 'פִּתְחוּ לִי X דַּקּוֹת' לְמַטָּה כְּדֵי לְהַתְחִיל לְשַׂחֵק."
            )
        case .stars:
            return InfoContent(
                emoji: "⭐",
                title: "כּוֹכָבִים",
                subtitle: "הַהֶשֵּׂגִים שֶׁלְּךָ",
                body: "כּוֹכָבִים מִצְטַבְּרִים עַל כָּל תְּשׁוּבָה נְכוֹנָה. רֶצֶף תְּשׁוּבוֹת נוֹתֵן בּוֹנוּס × 2 וְ-× 3!",
                tip: "כְּכָל שֶׁמִּצְטַבְּרִים יוֹתֵר כּוֹכָבִים, טוֹפִי עוֹלֶה רָמָה."
            )
        case .gems:
            return InfoContent(
                emoji: "💎",
                title: "גְּבִישִׁים",
                subtitle: "הַמַּטְבֵּעַ הַנָּדִיר",
                body: "גְּבִישִׁים נוֹפְלִים לִפְעָמִים מִתְּשׁוּבוֹת נְכוֹנוֹת, וּתְקַבֵּל גַּם בְּקֻפְסַת הַזָּהָב.",
                tip: "בְּקָרוֹב — קוֹסְמֵטִיקָה לְטוֹפִי שֶׁנִּתָּן לִקְנוֹת אִתָּם 🎩"
            )
        }
    }

    private func statChip(icon: String, value: String, label: String?, color: Color, prominent: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 16, weight: .semibold))
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(value) ?? 0))
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

            // XP bar — small, below subtitle
            HStack(spacing: 8) {
                Text("רָמַת טוֹפִי \(progress.companionLevel)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
                XPBarMini(
                    progress: xpProgress
                )
                .frame(width: 100)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white.opacity(0.12), in: Capsule())
            .opacity(heroAppeared ? 1 : 0)
            .padding(.top, 4)
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
