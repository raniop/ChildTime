import SwiftUI

struct WorldDetailView: View {
    let world: World
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var profiles: ProfileStore

    @State private var companion = CompanionController()
    @State private var startSession = false
    @State private var heroAppeared = false

    private var isCompact: Bool { hsc == .compact }
    private var heroEmojiSize: CGFloat { isCompact ? 96 : 140 }
    private var worldNameSize: CGFloat { isCompact ? 36 : 50 }
    private var companionSize: CGFloat { isCompact ? 70 : 90 }
    private var ctaSize: CGFloat { isCompact ? 30 : 38 }

    var currentRoom: Int { progress.progress(in: world.id) }
    var rewardPerCorrect: Int { settings.minutesPerCorrectAnswer }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Themed layered background
                world.gradient.gradient.ignoresSafeArea()
                themedOrbs
                WorldDecorations(world: world)
                    .opacity(0.5)
                SparkleField(count: 20, size: 13)

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.sm)

                    Spacer(minLength: AppSpacing.lg)

                    heroBlock

                    // Flexible middle — the buddy roams here (overlay below). The
                    // generous Spacer + the wandering avatar fill this band.
                    Spacer(minLength: AppSpacing.xxl)

                    missionCard
                        .padding(.horizontal, AppSpacing.lg)

                    startButton
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.md)

                    Spacer(minLength: AppSpacing.xl)
                }

                // The child's avatar buddy wanders — but ONLY the middle band
                // (insets keep it clear of the hero text above and the mission
                // card / Start button below, so it never covers anything tappable).
                FloatingCompanion(
                    controller: companion,
                    profile: profiles.active,
                    onTap: {
                        Haptic.light()
                        companion.cheer("יַאללָה! 🚀")
                    },
                    size: companionSize,
                    topInset: geo.size.height * 0.47,
                    bottomInset: geo.size.height * 0.37,
                    horizontalInset: AppSpacing.xl
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.55)) {
                heroAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                companion.cheer("מוּכָן לְחֶדֶר \(currentRoom + 1)?")
            }
        }
        .fullScreenCover(isPresented: $startSession) {
            QuestionRunnerView(world: world, purpose: .earnTime)
                .onDisappear { dismiss() }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            .buttonStyle(.juicy)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundStyle(AppColor.starGold)
                    .font(.system(size: 18))
                Text("\(progress.stars)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(AppColor.starGold.opacity(0.5), lineWidth: 1.5))
        }
    }

    // MARK: - Hero

    private var heroBlock: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                // Soft colored halo for depth.
                Circle()
                    .fill(RadialGradient(colors: [world.glowColor.opacity(0.55), .clear],
                                         center: .center, startRadius: 4, endRadius: heroEmojiSize))
                    .frame(width: heroEmojiSize * 1.9, height: heroEmojiSize * 1.9)
                    .blur(radius: 14)
                // Glass pedestal disc the emoji sits on.
                Circle()
                    .fill(.white.opacity(0.10))
                    .frame(width: heroEmojiSize * 1.42, height: heroEmojiSize * 1.42)
                    .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1.5))
                Text(world.emoji)
                    .font(.system(size: heroEmojiSize))
                    .float(amplitude: 8)
                    .shadow(color: world.glowColor.opacity(0.9), radius: 28)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 6)
            }
            .scaleEffect(heroAppeared ? 1 : 0.35)
            .rotationEffect(.degrees(heroAppeared ? 0 : -18))

            Text(world.name)
                .font(.system(size: worldNameSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                .scaleEffect(heroAppeared ? 1 : 0.7)
                .opacity(heroAppeared ? 1 : 0)

            roomProgress
                .opacity(heroAppeared ? 1 : 0)
        }
    }

    /// Progress as a row of pips (current room elongated) + a labeled pill.
    private var roomProgress: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: 5) {
                ForEach(0..<world.rooms, id: \.self) { i in
                    Capsule()
                        .fill(i < currentRoom ? AppColor.starGold
                              : i == currentRoom ? Color.white
                              : Color.white.opacity(0.30))
                        .frame(width: i == currentRoom ? 20 : 7, height: 7)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 13, weight: .semibold))
                Text("חֶדֶר \(currentRoom + 1) מִתּוֹךְ \(world.rooms)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.white.opacity(0.15), in: Capsule())
        }
    }

    // MARK: - Mission card

    private var missionCard: some View {
        VStack(spacing: AppSpacing.md) {
            rewardRow("🎁", "\(settings.questionsPerSession) שְׁאֵלוֹת → קֻפְסַת הַפְתָּעָה")
            rewardRow("🎮", "כָּל \(settings.batchAnswers) נְכוֹנוֹת = \(settings.batchMinutes) דַּקּוֹת מִשְׂחָק")
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial.opacity(0.75), in: RoundedRectangle(cornerRadius: AppRadius.large))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.large).stroke(.white.opacity(0.25), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 6)
    }

    private func rewardRow(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Text(emoji)
                .font(.system(size: 24))
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            Text(text)
                .font(.system(size: isCompact ? 16 : 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Start

    private var startButton: some View {
        JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
            companion.cheer("יַאללָה!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                startSession = true
            }
        } label: {
            Label("יַאללָה! 🚀", systemImage: "play.fill")
                .font(.system(size: ctaSize, weight: .heavy, design: .rounded))
        }
    }

    @ViewBuilder
    private var themedOrbs: some View {
        switch world.id {
        case "math_kingdom":    FloatingOrbs.castle()
        case "english_land":    FloatingOrbs.englishWorld()
        case "logic_lab":       FloatingOrbs.logicWorld()
        case "science_lab":     FloatingOrbs.scienceWorld()
        case "history_museum":  FloatingOrbs.historyWorld()
        case "geo_journey":     FloatingOrbs.geographyWorld()
        default:                FloatingOrbs.home()
        }
    }
}

#Preview {
    WorldDetailView(world: Worlds.all[0])
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(ProfileStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
