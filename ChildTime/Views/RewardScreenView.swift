import SwiftUI

struct RewardScreenView: View {
    let kind: ChestKind
    let correctInSession: Int
    let world: World
    let startedLevel: Int
    let onDismiss: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var shields: ShieldManager

    private var isCompact: Bool { hsc == .compact }
    private var chestSize: CGFloat { isCompact ? 130 : 180 }
    private var celebEmojiSize: CGFloat { isCompact ? 60 : 80 }
    private var titleFont: Font {
        isCompact ? .system(size: 36, weight: .bold, design: .rounded) : .system(size: 56, weight: .bold, design: .rounded)
    }
    private var companionSize: CGFloat { isCompact ? 64 : 80 }

    @State private var stage: ChestStage = .closed
    @State private var revealedItems: Int = 0
    @State private var reward: ChestReward = ChestReward(stars: 0, gems: 0, minutes: 0)
    @State private var companion = CompanionController()
    @State private var confettiTrigger = 0
    @State private var goLevelUp = false
    @State private var goWorldUnlock: World?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Backdrop — richer, more festive
                world.gradient.gradient
                    .ignoresSafeArea()
                    .opacity(0.45)
                Color.black.opacity(0.35).ignoresSafeArea()
                FloatingOrbs(
                    colors: [AppColor.starGold, AppColor.companionGlow, AppColor.gemPurple],
                    count: 5, maxSize: 280, opacity: 0.35
                )
                SparkleField(count: 28, size: 16)

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: AppSpacing.lg)

                        // Hero title + chest stack
                        VStack(spacing: AppSpacing.md) {
                            heroTitle
                            chestBlock
                            if stage == .glowing {
                                Text("לְחַץ כְּדֵי לִפְתֹּחַ! ✨")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .shadow(color: AppColor.starGold.opacity(0.7), radius: 8)
                                    .pulse()
                            }
                        }

                        if stage == .revealed {
                            Spacer(minLength: AppSpacing.lg)
                            rewardItems
                                .frame(maxWidth: isCompact ? .infinity : 420)
                                .padding(.horizontal, AppSpacing.lg)

                            Spacer(minLength: AppSpacing.lg)
                            actionButtons
                                .frame(maxWidth: isCompact ? .infinity : 420)
                                .padding(.horizontal, AppSpacing.lg)
                        }

                        // Floor for the companion
                        Spacer(minLength: companionSize + 40)
                    }
                    .frame(minHeight: proxy.size.height, alignment: .center)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)

                // Companion in corner — positioned so it never overlaps
                // the CTA stack.
                companionCorner
                    .padding(.bottom, AppSpacing.md)
                    .padding(.leading, AppSpacing.md)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .bottomLeading)
                    .allowsHitTesting(true)

                Confetti(trigger: confettiTrigger)
            }
        }
        .onAppear { startSequence() }
        .fullScreenCover(isPresented: $goLevelUp) {
            LevelUpView(newLevel: progress.companionLevel) {
                goLevelUp = false
                onDismiss()
            }
        }
        .fullScreenCover(item: $goWorldUnlock) { world in
            WorldUnlockView(world: world) {
                goWorldUnlock = nil
                onDismiss()
            }
        }
    }

    // MARK: - Hero header

    private var heroTitle: some View {
        VStack(spacing: 4) {
            if stage == .revealed {
                Text("🎉")
                    .font(.system(size: celebEmojiSize))
                    .shadow(color: AppColor.starGold.opacity(0.6), radius: 10)
                Text("אֵיזֶה נִצָּחוֹן!")
                    .font(.system(size: isCompact ? 30 : 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColor.starGold, AppColor.companionGlow,
                                     Color(hex: "FFE082")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: AppColor.starGold.opacity(0.7), radius: 12)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                    .multilineTextAlignment(.center)
            } else {
                Text(kind.label)
                    .font(.system(size: isCompact ? 28 : 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private var chestBlock: some View {
        ZStack {
            // Glow halo behind the chest — much more dramatic than the
            // bare emoji backdrop.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColor.starGold.opacity(0.5),
                            AppColor.starGold.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: chestSize * 0.9
                    )
                )
                .frame(width: chestSize * 1.6, height: chestSize * 1.6)
                .opacity(stage == .closed ? 0.3 : 0.85)

            ChestView(kind: kind, stage: stage, size: chestSize)
                .onTapGesture {
                    if stage == .glowing { openChest() }
                }
        }
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Companion corner

    private var companionCorner: some View {
        ZStack(alignment: .topLeading) {
            if let bubble = companion.bubbleText {
                BubbleSpeech(text: bubble)
                    .offset(x: companionSize * 0.7, y: -companionSize * 0.2)
                    .transition(.scale.combined(with: .opacity))
            }
            CompanionView(controller: companion, size: companionSize)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: companion.bubbleText)
    }

    // MARK: - Reward items

    private var rewardItems: some View {
        VStack(spacing: 10) {
            if revealedItems >= 1 {
                rewardPill(emoji: "⭐", value: reward.stars, label: "כּוֹכָבִים", color: AppColor.starGold)
            }
            if revealedItems >= 2 && reward.gems > 0 {
                rewardPill(emoji: "💎", value: reward.gems, label: "גְּבִישִׁים", color: AppColor.gemPurple)
            }
            if revealedItems >= 3 && reward.minutes > 0 {
                rewardPill(emoji: "⏱", value: reward.minutes, label: "דַּקּוֹת מִשְׂחָק", color: AppColor.successMint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// One reward as a centered pill: ⭐  +3  כוכבים
    private func rewardPill(emoji: String, value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 26))
                .shadow(color: color.opacity(0.8), radius: 6)
            Text("+\(value)")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.white.opacity(0.10))
                .overlay(
                    Capsule()
                        .fill(LinearGradient(
                            colors: [color.opacity(0.35), color.opacity(0.15)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                )
                .overlay(
                    Capsule().stroke(color.opacity(0.85), lineWidth: 2)
                )
        )
        .glow(color, radius: 10)
        .frame(maxWidth: .infinity, alignment: .center)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity).combined(with: .move(edge: .bottom)),
            removal: .opacity
        ))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if progress.pendingMinutes > 0 {
                JuicyButton(gradient: AppGradient.castle, glowColor: AppColor.flameOrange) {
                    unlockNow()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                        Text("פִּתְחוּ לִי \(progress.pendingMinutes) דַּק' 🎮")
                    }
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                }
            }

            Button {
                proceedAfterReward()
            } label: {
                Text("הַמְשֵׁךְ")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.juicy)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Sequence

    private func startSequence() {
        // Pre-compute reward
        reward = RewardEngine.chestContents(
            kind: kind,
            correctInSession: correctInSession,
            minutesPerCorrect: settings.minutesPerCorrect
        )
        SoundPlayer.shared.play(.chestOpen)
        companion.cheer("שִׂחַקְתָּ מְצֻיָּן!")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            stage = .glowing
        }
    }

    private func openChest() {
        SoundPlayer.shared.play(.chestOpen)
        Haptic.heavy()
        stage = .opening
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            stage = .revealed
            confettiTrigger += 1
            companion.wow("טָא-דָה!")
            revealItemsOneByOne()
            applyReward()
        }
    }

    private func revealItemsOneByOne() {
        let delays: [TimeInterval] = [0.3, 1.0, 1.6]
        for (i, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    revealedItems = i + 1
                }
                SoundPlayer.shared.play(.streakUp)
                Haptic.light()
            }
        }
    }

    private func applyReward() {
        // The session "earned" minutes were already added per-correct. Here we add chest extras.
        let extraMinutes = max(0, reward.minutes - correctInSession * settings.minutesPerCorrect)
        let chestOnly = ChestReward(
            stars: reward.stars,
            gems: reward.gems,
            minutes: extraMinutes,
            cosmeticID: reward.cosmeticID
        )
        progress.applyChestReward(chestOnly)
        progress.advanceRoom(in: world.id)
    }

    private func unlockNow() {
        let minutes = progress.consumePendingMinutes()
        guard minutes > 0 else { return }
        shields.unlock(minutes: minutes)
        progress.startUnlock(minutes: minutes)
        onDismiss()
    }

    private func proceedAfterReward() {
        // Level up?
        if progress.companionLevel > startedLevel {
            goLevelUp = true
            return
        }
        // New world unlocked?
        for w in Worlds.all where w.id != world.id {
            if !progress.unlockedWorlds.contains(w.id) && progress.canUnlock(world: w) {
                progress.unlockWorld(w.id)
                goWorldUnlock = w
                return
            }
        }
        onDismiss()
    }
}

extension ParentSettings {
    fileprivate var minutesPerCorrect: Int { minutesPerCorrectAnswer }
}

#Preview {
    RewardScreenView(
        kind: .gold,
        correctInSession: 4,
        world: Worlds.all[0],
        startedLevel: 1,
        onDismiss: {}
    )
    .environmentObject(ParentSettings.shared)
    .environmentObject(ProgressStore.shared)
    .environmentObject(ShieldManager.shared)
    .environment(\.layoutDirection, .rightToLeft)
}
