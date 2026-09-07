import SwiftUI

struct LevelUpView: View {
    let newLevel: Int
    let onContinue: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    @StateObject private var companion = CompanionController()
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
                GlassBackdrop()
                SparkleField(count: 40, size: 16)
                FancyConfetti(trigger: confettiTrigger)

                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        Spacer(minLength: AppSpacing.lg)

                        CompanionView(controller: companion, size: companionSize)
                            .scaleEffect(scale)
                            .glow(AppColor.starGold, radius: 40)

                        if titleVisible {
                            VStack(spacing: AppSpacing.md) {
                                Text("עָלִיתָ רָמָה!")
                                    .font(.system(size: titleFontSize, weight: .heavy, design: .rounded))
                                    .foregroundStyle(AppColor.starGold)
                                    .glow(AppColor.starGold, radius: 20)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.6)
                                    .transition(.scale.combined(with: .opacity))

                                Text("רָמָה \(newLevel)")
                                    .font(.system(size: levelFontSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .transition(.scale.combined(with: .opacity))

                                Text("+\(RewardEngine.levelUpDiamonds(newLevel)) 💎 בּוֹנוּס לַחֲנוּת!")
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                    .foregroundStyle(AppColor.starGold)
                                    .padding(.top, AppSpacing.sm)
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

                        Button { Haptic.light(); onContinue() } label: {
                            Text("הַמְשֵׁךְ")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .ctaGlass(Color(hex: "5E60CE"), Color(hex: "3E8BF0"))
                        }
                        .buttonStyle(.juicy)
                        .frame(maxWidth: 420)
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
        case 5: return "🥉 מִסְגֶּרֶת בְּרוֹנְזָה לָאַוָּטָאר!"
        case 10: return "🥈 מִסְגֶּרֶת כֶּסֶף לָאַוָּטָאר!"
        case 20: return "🥇 מִסְגֶּרֶת זָהָב לָאַוָּטָאר!"
        default: return nil
        }
    }
}

#Preview {
    LevelUpView(newLevel: 5, onContinue: {})
        .environment(\.layoutDirection, .rightToLeft)
}
