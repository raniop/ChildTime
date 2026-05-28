import SwiftUI

struct WorldUnlockView: View {
    let world: World
    let onContinue: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    @State private var companion = CompanionController()
    @State private var confettiTrigger = 0
    @State private var stage: Int = 0

    private var isCompact: Bool { hsc == .compact }
    private var emojiSize: CGFloat { isCompact ? 130 : 180 }
    private var subtitleFontSize: CGFloat { isCompact ? 26 : 32 }
    private var titleFontSize: CGFloat { isCompact ? 42 : 56 }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                world.gradient.gradient.ignoresSafeArea()
                SparkleField(count: 50, size: 16)
                Confetti(trigger: confettiTrigger)

                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        Spacer(minLength: AppSpacing.lg)

                        Text(world.emoji)
                            .font(.system(size: emojiSize))
                            .scaleEffect(stage >= 1 ? 1.2 : 0.5)
                            .opacity(stage >= 1 ? 1 : 0)
                            .glow(world.glowColor, radius: 40)
                            .animation(.spring(response: 0.7, dampingFraction: 0.5), value: stage)

                        if stage >= 2 {
                            VStack(spacing: AppSpacing.md) {
                                Text("עולם חדש נפתח!")
                                    .font(.system(size: subtitleFontSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.7)
                                    .transition(.scale.combined(with: .opacity))

                                Text(world.name)
                                    .font(.system(size: titleFontSize, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .glow(world.glowColor, radius: 20)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.5)
                                    .padding(.horizontal, AppSpacing.lg)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }

                        if stage >= 3 {
                            JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                                onContinue()
                            } label: {
                                Text("בוא נחקור!")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, AppSpacing.lg)
                            .transition(.opacity)
                        }

                        Color.clear.frame(height: AppSpacing.lg)
                    }
                    .frame(minHeight: proxy.size.height, alignment: .center)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear { runSequence() }
    }

    private func runSequence() {
        SoundPlayer.shared.play(.worldUnlock)
        Haptic.heavy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { stage = 1 }
            companion.wow()
            confettiTrigger += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { stage = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation { stage = 3 }
        }
    }
}

#Preview {
    WorldUnlockView(world: Worlds.all[1], onContinue: {})
        .environment(\.layoutDirection, .rightToLeft)
}
