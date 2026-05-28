import SwiftUI

struct LevelUpView: View {
    let newLevel: Int
    let onContinue: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    @State private var companion = CompanionController()
    @State private var confettiTrigger: Int = 0
    @State private var scale: CGFloat = 0.3
    @State private var titleVisible = false

    private var isCompact: Bool { hsc == .compact }
    private var companionSize: CGFloat { isCompact ? 120 : 160 }
    private var titleFontSize: CGFloat { isCompact ? 46 : 64 }
    private var levelFontSize: CGFloat { isCompact ? 28 : 36 }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color.black, AppColor.gemPurple.opacity(0.7), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                SparkleField(count: 40, size: 16)
                Confetti(trigger: confettiTrigger)

                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        Spacer(minLength: AppSpacing.lg)

                        CompanionView(controller: companion, size: companionSize)
                            .scaleEffect(scale)
                            .glow(AppColor.starGold, radius: 40)

                        if titleVisible {
                            VStack(spacing: AppSpacing.md) {
                                Text("עלית רמה!")
                                    .font(.system(size: titleFontSize, weight: .heavy, design: .rounded))
                                    .foregroundStyle(AppColor.starGold)
                                    .glow(AppColor.starGold, radius: 20)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.6)
                                    .transition(.scale.combined(with: .opacity))

                                Text("רמה \(newLevel)")
                                    .font(.system(size: levelFontSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .transition(.scale.combined(with: .opacity))

                                if let perk = perkForLevel(newLevel) {
                                    Text(perk)
                                        .font(.system(size: 22, weight: .medium, design: .rounded))
                                        .foregroundStyle(AppColor.companionGlow)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, AppSpacing.sm)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, AppSpacing.lg)
                        }

                        JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                            onContinue()
                        } label: {
                            Text("המשך")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .opacity(titleVisible ? 1 : 0)
                        .animation(.easeIn(duration: 0.4), value: titleVisible)

                        Color.clear.frame(height: AppSpacing.lg)
                    }
                    .frame(minHeight: proxy.size.height, alignment: .center)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        SoundPlayer.shared.play(.levelUp)
        Haptic.heavy()
        companion.wow()
        withAnimation(.spring(response: 0.7, dampingFraction: 0.5)) {
            scale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                titleVisible = true
            }
            confettiTrigger += 1
        }
    }

    private func perkForLevel(_ lvl: Int) -> String? {
        switch lvl {
        case 5: return "🎩 כובע נפתח!"
        case 10: return "✨ כנפיים נפתחות!"
        case 20: return "🌈 צבעים נדירים!"
        default: return nil
        }
    }
}

#Preview {
    LevelUpView(newLevel: 5, onContinue: {})
        .environment(\.layoutDirection, .rightToLeft)
}
