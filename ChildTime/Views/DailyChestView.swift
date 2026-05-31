import SwiftUI

struct DailyChestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore

    @State private var stage: ChestStage = .closed
    @State private var revealed: Int = 0
    @State private var reward: ChestReward = ChestReward(stars: 0, gems: 0, minutes: 0)
    @State private var companion = CompanionController()
    @State private var confettiTrigger = 0

    private var isCompact: Bool { hsc == .compact }
    private var chestSize: CGFloat { isCompact ? 130 : 180 }
    private var companionSize: CGFloat { isCompact ? 70 : 90 }

    var body: some View {
        ZStack {
            AppGradient.portal.ignoresSafeArea()
            SparkleField(count: 30, size: 16)
            Confetti(trigger: confettiTrigger)

            VStack(spacing: AppSpacing.lg) {
                Spacer()

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
                    .padding(.vertical, AppSpacing.lg)

                if stage == .glowing {
                    Text("לַחֲצוּ לִפְתִיחָה!")
                        .font(AppFont.subtitle())
                        .foregroundStyle(.white)
                        .pulse()
                }

                if stage == .revealed {
                    VStack(spacing: AppSpacing.md) {
                        if revealed >= 1 {
                            row(emoji: "⭐", text: "+\(reward.stars + reward.gems) כּוֹכָבִים")
                                .transition(.scale.combined(with: .opacity))
                        }
                        if revealed >= 2 {
                            row(emoji: "⏱", text: "+\(reward.minutes) דַּקּוֹת")
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding()
                }

                Spacer()

                if stage == .revealed {
                    JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                        dismiss()
                    } label: {
                        Text("הַמְשֵׁךְ")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
                }
            }

            // Companion
            VStack {
                Spacer()
                HStack {
                    ZStack(alignment: .top) {
                        if let bubble = companion.bubbleText {
                            BubbleSpeech(text: bubble).offset(x: 80, y: -10)
                        }
                        CompanionView(controller: companion, size: companionSize)
                    }
                    .padding(.leading, AppSpacing.md)
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
            reward = RewardEngine.chestContents(kind: .magic, correctInSession: 0, minutesPerCorrect: 0)
            companion.cheer("חִכִּיתִי לְךָ!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                stage = .glowing
            }
        }
    }

    private func row(emoji: String, text: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Text(emoji).font(.system(size: 36))
            Text(text)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: AppRadius.medium))
        .glow(AppColor.starGold, radius: 8)
    }

    private func open() {
        SoundPlayer.shared.play(.chestOpen)
        Haptic.heavy()
        stage = .opening
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            stage = .revealed
            confettiTrigger += 1
            companion.wow("טָא-דָה!")
            progress.applyChestReward(reward)
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
