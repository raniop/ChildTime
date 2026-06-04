import SwiftUI

struct DailyChestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore

    @State private var stage: ChestStage = .closed
    @State private var revealed: Int = 0
    @State private var reward: ChestReward = ChestReward(stars: 0, diamonds: 0, minutes: 0)
    @StateObject private var companion = CompanionController()
    @State private var confettiTrigger = 0
    /// Shown when some/all won minutes were banked for tomorrow (daily cap full).
    @State private var bankedNote: String? = nil

    private var isCompact: Bool { hsc == .compact }
    private var chestSize: CGFloat { isCompact ? 120 : 150 }
    private var companionSize: CGFloat { isCompact ? 70 : 90 }

    /// The child's OWN chosen character (falls back to the default if none).
    private var childCharacter: Character3D {
        ProfileStore.shared.active?.character ?? Character3DCatalog.find(Character3DCatalog.defaultID)
    }

    var body: some View {
        ZStack {
            AppGradient.portal.ignoresSafeArea()
            SparkleField(count: 30, size: 16)
            Confetti(trigger: confettiTrigger)

            // Celebratory content scrolls; the "המשך" button is pinned to the
            // bottom (outside the scroll) so it's always visible — even on a short
            // landscape-iPad height where the chest + rewards would otherwise push
            // it off-screen.
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer(minLength: AppSpacing.lg)

                        Text("קֻפְסַת קֶסֶם יוֹמִית")
                            .font(.system(size: isCompact ? 34 : 48, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, AppSpacing.md)
                            .frame(maxWidth: .infinity)
                            .glow(AppColor.gemPurple, radius: 12)

                        ChestView(kind: .magic, stage: stage, size: chestSize)
                            .onTapGesture {
                                if stage == .glowing { open() }
                            }
                            .padding(.vertical, AppSpacing.md)

                        if stage == .glowing {
                            Text("לַחֲצוּ לִפְתִיחָה!")
                                .font(AppFont.subtitle())
                                .foregroundStyle(.white)
                                .pulse()
                        }

                        if stage == .revealed {
                            VStack(spacing: AppSpacing.md) {
                                if revealed >= 1 {
                                    row(emoji: "⭐", text: "+\(reward.stars) כּוֹכָבִים")
                                        .transition(.scale.combined(with: .opacity))
                                }
                                if revealed >= 1 && reward.diamonds > 0 {
                                    row(emoji: "💎", text: "+\(reward.diamonds) יַהֲלוֹמִים", glow: AppColor.gemPurple)
                                        .transition(.scale.combined(with: .opacity))
                                }
                                if revealed >= 2 && reward.minutes > 0 {
                                    row(emoji: "⏱", text: "+\(reward.minutes) דַּקּוֹת")
                                        .transition(.scale.combined(with: .opacity))
                                }
                                if revealed >= 2, let note = bankedNote {
                                    Text(note)
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, AppSpacing.md)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            // Constrain the column so the three reward rows are the
                            // same width (and don't stretch across a wide iPad).
                            .frame(maxWidth: isCompact ? .infinity : 360)
                        }

                        Spacer(minLength: AppSpacing.lg)
                            // Anchor: as each reward reveals, auto-scroll here so a
                            // kid never has to scroll to see what they won.
                            .id("rewardsBottom")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.lg)
                }
                .scrollIndicators(.hidden)
                .onChangeCompat(of: revealed) { _, _ in
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo("rewardsBottom", anchor: .bottom)
                    }
                }
                }

                if stage == .revealed {
                    JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                        dismiss()
                    } label: {
                        Text("הַמְשֵׁךְ")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: isCompact ? .infinity : 360)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
                }
            }

            // Companion — the child's OWN chosen character, greeting from a
            // bubble stacked right above it so its tail points down at the avatar.
            VStack {
                Spacer()
                HStack {
                    VStack(spacing: -4) {
                        if let bubble = companion.bubbleText {
                            BubbleSpeech(text: bubble)
                                .transition(.scale.combined(with: .opacity))
                        }
                        CharacterView(character: childCharacter, animated: true)
                            .id(childCharacter.id)
                            .frame(width: companionSize, height: companionSize * 1.3)
                    }
                    .padding(.leading, AppSpacing.lg)
                    Spacer()
                }
            }
            .padding(.bottom, AppSpacing.lg)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: companion.bubbleText)

            // Tap ANYWHERE to open while glowing — not only on the chest.
            if stage == .glowing {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { open() }
            }
        }
        .onAppear {
            progress.applyDailyRolloverIfNeeded()
            reward = RewardEngine.chestContents(kind: .magic, correctInSession: 0, minutesPerCorrect: 0)
            // No room for play-minutes (today's cap full AND tomorrow's bank full)
            // → don't promise minutes; give a few extra stars instead.
            if progress.bonusMinutesRoom() <= 0 {
                reward = ChestReward(stars: reward.stars + 5, diamonds: reward.diamonds + 5,
                                     minutes: 0, cosmeticID: reward.cosmeticID)
            }
            companion.cheer("חִכִּיתִי לְךָ!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                stage = .glowing
            }
        }
        // fullScreenCover content doesn't inherit the app root's RTL direction.
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func row(emoji: String, text: String, glow: Color = AppColor.starGold) -> some View {
        HStack(spacing: AppSpacing.md) {
            Text(emoji).font(.system(size: 36))
            Text(text)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        // Fill the column so all three reward rows share one width.
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: AppRadius.medium))
        .glow(glow, radius: 8)
    }

    private func open() {
        AppAnalytics.chestOpened(kind: "daily")
        SoundPlayer.shared.play(.chestOpen)
        Haptic.heavy()
        stage = .opening
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            stage = .revealed
            confettiTrigger += 1
            companion.wow("טָא-דָה!")
            let grant = progress.applyChestReward(reward)
            if grant.bankedForTomorrow > 0 {
                bankedNote = "הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי! \(grant.bankedForTomorrow) דַּקּוֹת נִשְׁמְרוּ לְמָחָר 🎁 (\(progress.carryOverMinutes)/\(ProgressStore.maxCarryOverMinutes))"
            }
            progress.openDailyChest()
            revealItems()
        }
    }

    private func revealItems() {
        let delays: [TimeInterval] = [0.3, 1.0, 1.6]
        for (i, d) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + d) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    revealed = i + 1
                }
                SoundPlayer.shared.play(.streakUp)
            }
        }
    }
}

#Preview {
    DailyChestView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
