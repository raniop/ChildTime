import SwiftUI

struct DemoView: View {
    @State private var companion = CompanionController()
    @State private var burstTrigger = 0
    @State private var confettiTrigger = 0
    @State private var rumbleTrigger = 0

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()

            SparkleField(count: 25, size: 14)

            VStack(spacing: AppSpacing.xl) {
                header

                ScrollView {
                    VStack(spacing: AppSpacing.xxl) {
                        companionSection
                        Divider().background(.white.opacity(0.3))
                        buttonsSection
                        Divider().background(.white.opacity(0.3))
                        effectsSection
                        Divider().background(.white.opacity(0.3))
                        textStylesSection
                    }
                    .padding(.bottom, 60)
                }
            }
            .padding()

            // Overlays
            StarBurst(trigger: burstTrigger)
            Confetti(trigger: confettiTrigger)
        }
        .rumble(trigger: rumbleTrigger)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var header: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("קופיקו")
                .heroStyle()
                .glow(AppColor.starGold, radius: 16)
            Text("Phase A — Foundation Demo")
                .subtitleStyle()
        }
    }

    private var companionSection: some View {
        VStack(spacing: AppSpacing.lg) {
            sectionTitle("קופיקו — Companion")
            ZStack(alignment: .top) {
                CompanionView(controller: companion)
                if let text = companion.bubbleText {
                    BubbleSpeech(text: text)
                        .offset(x: -100, y: -10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 280)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: companion.bubbleText)

            HStack(spacing: AppSpacing.sm) {
                miniBtn("idle")    { companion.state = .idle; companion.bubbleText = nil }
                miniBtn("cheer")   { companion.cheer("יש!") }
                miniBtn("hype")    { companion.hype("🔥 אש!") }
                miniBtn("wow")     { companion.wow("וואו!") }
                miniBtn("console") { companion.console("כמעט!") }
            }
        }
    }

    private var buttonsSection: some View {
        VStack(spacing: AppSpacing.lg) {
            sectionTitle("JuicyButtons")
            JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                companion.cheer("יאללה!")
            } label: {
                Label("יאללה!", systemImage: "play.fill")
            }
            JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {
                companion.cheer("בוא נתחיל")
            } label: {
                Text("בוא נתחיל")
            }
            JuicyButton(gradient: AppGradient.castle, glowColor: AppColor.flameOrange) {
                burstTrigger += 1
                companion.wow("פתחו לי דקות!")
            } label: {
                Label("פתח 10 דקות", systemImage: "gamecontroller.fill")
            }
        }
    }

    private var effectsSection: some View {
        VStack(spacing: AppSpacing.lg) {
            sectionTitle("Effects")

            HStack(spacing: AppSpacing.md) {
                effectBtn("⭐ StarBurst") {
                    burstTrigger += 1
                    SoundPlayer.shared.play(.correctSmall)
                    Haptic.light()
                }
                effectBtn("🎉 Confetti") {
                    confettiTrigger += 1
                    SoundPlayer.shared.play(.correctBig)
                    Haptic.success()
                }
                effectBtn("📳 Rumble") {
                    rumbleTrigger += 1
                    SoundPlayer.shared.play(.streakUp)
                    Haptic.heavy()
                }
            }

            HStack(spacing: AppSpacing.lg) {
                Text("✨")
                    .font(.system(size: 48))
                    .float()
                Text("⭐")
                    .font(.system(size: 48))
                    .pulse()
                Text("🎁")
                    .font(.system(size: 48))
                    .glow(AppColor.starGold, radius: 14)
            }

            // Shimmer example
            Text("Shimmer")
                .font(AppFont.title())
                .foregroundStyle(AppColor.starGold)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.md)
                .background(.white.opacity(0.1), in: Capsule())
                .shimmer()
        }
    }

    private var textStylesSection: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.md) {
            sectionTitle("Typography")
            Text("Hero — קופיקו").font(AppFont.hero()).minimumScaleFactor(0.4)
            Text("Title — ממלכת המספרים").font(AppFont.title())
            Text("Question — 7 + 5 = ?").font(AppFont.question())
            Text("Option — 12").font(AppFont.option())
            Text("Subtitle — משנה הוראות").font(AppFont.subtitle()).foregroundStyle(AppColor.textSecondary)
            Text("Body — טקסט גוף רגיל").font(AppFont.body())
            Text("Caption — מטא").font(AppFont.caption()).foregroundStyle(AppColor.textSecondary)
        }
        .foregroundStyle(AppColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s)
            .font(AppFont.subtitle())
            .foregroundStyle(AppColor.starGold)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func miniBtn(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(.white.opacity(0.18), in: Capsule())
            .foregroundStyle(.white)
            .font(.system(size: 14, weight: .semibold))
    }

    private func effectBtn(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: AppRadius.medium))
            .foregroundStyle(.white)
            .font(.system(size: 16, weight: .semibold))
    }
}

#Preview {
    DemoView()
}
