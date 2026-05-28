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
        ZStack {
            // Backdrop
            world.gradient.gradient
                .ignoresSafeArea()
                .opacity(0.4)
            Color.black.opacity(0.4).ignoresSafeArea()
            SparkleField(count: 25, size: 14)

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                Text(stage == .revealed ? "🎉" : kind.label)
                    .font(stage == .revealed ? .system(size: celebEmojiSize) : titleFont)
                    .foregroundStyle(.white)

                ChestView(kind: kind, stage: stage, size: chestSize)
                    .onTapGesture {
                        if stage == .glowing { openChest() }
                    }
                    .padding(.vertical, AppSpacing.lg)

                if stage == .glowing {
                    Text("לחץ כדי לפתוח!")
                        .font(AppFont.subtitle())
                        .foregroundStyle(.white)
                        .pulse()
                }

                if stage == .revealed {
                    rewardItems
                }

                Spacer()

                if stage == .revealed {
                    actionButtons
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            // Companion in corner
            VStack {
                Spacer()
                HStack {
                    ZStack(alignment: .top) {
                        if let bubble = companion.bubbleText {
                            BubbleSpeech(text: bubble)
                                .offset(x: 80, y: -10)
                        }
                        CompanionView(controller: companion, size: companionSize)
                    }
                    .padding(.leading, AppSpacing.md)
                    Spacer()
                }
            }
            .padding(.bottom, AppSpacing.lg)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: companion.bubbleText)

            Confetti(trigger: confettiTrigger)
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

    // MARK: - Reward items

    private var rewardItems: some View {
        VStack(spacing: AppSpacing.md) {
            if revealedItems >= 1 {
                rewardRow(emoji: "⭐", text: "+\(reward.stars) כוכבים", color: AppColor.starGold)
            }
            if revealedItems >= 2 && reward.gems > 0 {
                rewardRow(emoji: "💎", text: "+\(reward.gems) גבישים", color: AppColor.gemPurple)
            }
            if revealedItems >= 3 && reward.minutes > 0 {
                rewardRow(emoji: "⏱", text: "+\(reward.minutes) דקות משחק", color: AppColor.successMint)
            }
        }
    }

    private func rewardRow(emoji: String, text: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.md) {
            Text(emoji)
                .font(.system(size: 36))
            Text(text)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(color.opacity(0.25), in: RoundedRectangle(cornerRadius: AppRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(color, lineWidth: 2)
        )
        .glow(color, radius: 10)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity).combined(with: .move(edge: .bottom)),
            removal: .opacity
        ))
    }

    private var actionButtons: some View {
        VStack(spacing: AppSpacing.sm) {
            if progress.pendingMinutes > 0 {
                JuicyButton(gradient: AppGradient.castle, glowColor: AppColor.flameOrange) {
                    unlockNow()
                } label: {
                    Label("פתחו לי \(progress.pendingMinutes) דקות 🎮", systemImage: "gamecontroller.fill")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
            }

            Button {
                proceedAfterReward()
            } label: {
                Text("המשך")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(.white.opacity(0.2), in: Capsule())
            }
            .buttonStyle(.juicy)
        }
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
        companion.cheer("שיחקת מצוין!")
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
            companion.wow("טא-דה!")
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
