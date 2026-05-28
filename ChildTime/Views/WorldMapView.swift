import SwiftUI

struct WorldMapView: View {
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @Environment(\.horizontalSizeClass) private var hsc

    @State private var companion = CompanionController()
    @State private var selectedWorld: World?
    @State private var showDailyChest = false
    @State private var showingParentGate = false
    @State private var showingDemo = false
    @State private var lastSeenStars = 0
    @State private var heroAppeared = false

    private var isCompact: Bool { hsc == .compact }
    private var companionSize: CGFloat { isCompact ? 90 : 120 }
    private var heroTitleSize: CGFloat { isCompact ? 36 : 44 }

    @State private var infoStat: StatInfo? = nil

    enum StatInfo: String, Identifiable {
        case minutes, stars, gems
        var id: String { rawValue }
    }

    private var worldGridColumns: [GridItem] {
        // Adaptive: each card 170-220pt wide. Phones get 2 columns, iPads 3.
        [GridItem(.adaptive(minimum: 170, maximum: 220), spacing: AppSpacing.md)]
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
                            ForEach(Worlds.all) { world in
                                WorldCard(
                                    world: world,
                                    isUnlocked: progress.unlockedWorlds.contains(world.id),
                                    currentRoom: progress.progress(in: world.id),
                                    starsHeld: progress.stars
                                ) {
                                    selectedWorld = world
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, 260)
                }
            }

            // Bottom CTAs floating panel
            VStack {
                Spacer()
                bottomCTAs
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
            }

            // Companion wanders the screen and is also draggable
            FloatingCompanion(
                controller: companion,
                size: companionSize,
                topInset: 90,
                bottomInset: isCompact ? 160 : 200,
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

    private var topBar: some View {
        HStack(spacing: AppSpacing.sm) {
            // Settings button
            Button {
                showingParentGate = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.15), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
            }
            .onLongPressGesture(minimumDuration: 1.5) { showingDemo = true }

            Spacer()

            // Primary stats — tap each chip for an explanation popover.
            HStack(spacing: AppSpacing.sm) {
                Button {
                    Haptic.light()
                    infoStat = .minutes
                } label: {
                    MinutesBadge(minutes: progress.pendingMinutes, compact: isCompact)
                }
                .buttonStyle(.plain)
                .popover(isPresented: popoverBinding(for: .minutes)) { statInfoCard(.minutes) }

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
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
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
        VStack(alignment: .trailing, spacing: 12) {
            HStack(spacing: 10) {
                Text(info.emoji)
                    .font(.system(size: 44))
                VStack(alignment: .trailing, spacing: 2) {
                    Text(info.title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(info.subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(info.body)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if let tip = info.tip {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(AppColor.starGold)
                    Text(tip)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .padding(20)
        .frame(maxWidth: 320)
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
            return InfoContent(
                emoji: "🎮",
                title: "דקות משחק",
                subtitle: "מה שצברת",
                body: "אלה הדקות שהרווחת כדי לשחק באפליקציות שההורה אישר. כל תשובה נכונה = עוד דקות!",
                tip: "לחץ על 'פתחו לי X דקות' למטה כדי להתחיל לשחק."
            )
        case .stars:
            return InfoContent(
                emoji: "⭐",
                title: "כוכבים",
                subtitle: "ההישגים שלך",
                body: "כוכבים מצטברים על כל תשובה נכונה. רצף תשובות נותן בונוס × 2 ו-× 3!",
                tip: "ככל שמצטברים יותר כוכבים, טופי עולה רמה."
            )
        case .gems:
            return InfoContent(
                emoji: "💎",
                title: "גבישים",
                subtitle: "המטבע הנדיר",
                body: "גבישים נופלים לפעמים מתשובות נכונות, ותקבל גם בקופסת הזהב.",
                tip: "בקרוב — קוסמטיקה לטופי שניתן לקנות איתם 🎩"
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
            Text("טופי")
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

            Text("בחר עולם והתחל הרפתקה!")
                .font(.system(size: isCompact ? 16 : 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .opacity(heroAppeared ? 1 : 0)

            // XP bar — small, below subtitle
            HStack(spacing: 8) {
                Text("רמת טופי \(progress.companionLevel)")
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
            if progress.dailyChestAvailable {
                Button {
                    showDailyChest = true
                } label: {
                    HStack(spacing: 12) {
                        Text("🎁").font(.system(size: 32))
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("קופסה יומית!")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                            Text("מחכה לך")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Spacer()
                        Image(systemName: "chevron.left.circle.fill").font(.system(size: 24))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppGradient.portal)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                    .glow(AppColor.gemPurple, radius: 14)
                    .pulse(min: 0.9)
                }
                .buttonStyle(.juicy)
            }

            if progress.pendingMinutes > 0 {
                JuicyButton(
                    gradient: AppGradient.castle,
                    glowColor: AppColor.flameOrange
                ) {
                    redeemMinutes()
                } label: {
                    Label("פתחו לי \(progress.pendingMinutes) דקות לשחק", systemImage: "gamecontroller.fill")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                }
            }
        }
    }

    // MARK: - Actions

    private func greetIfNeeded() {
        if progress.dayStreak == 0 {
            companion.cheer("היי! יאללה להרפתקה 🌟")
        } else if progress.dayStreak == 1 {
            companion.cheer("ברוך הבא! 👋")
        } else {
            companion.cheer("חזרת! \(progress.dayStreak) ימים ברצף 🔥")
        }
    }

    private func checkWorldUnlocks() {
        for world in Worlds.all where !progress.unlockedWorlds.contains(world.id) {
            if progress.canUnlock(world: world) {
                progress.unlockWorld(world.id)
                companion.wow("\(world.emoji) \(world.name) נפתח!")
            }
        }
    }

    private func redeemMinutes() {
        let minutes = progress.consumePendingMinutes()
        guard minutes > 0 else { return }
        shields.unlock(minutes: minutes)
        progress.startUnlock(minutes: minutes)
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
        .environment(\.layoutDirection, .rightToLeft)
}
