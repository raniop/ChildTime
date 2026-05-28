import SwiftUI

struct HatchingView: View {
    let onContinue: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    @State private var stage: Int = 0
    @State private var shake: CGFloat = 0
    @State private var eggScale: CGFloat = 1.0
    @State private var eggOpacity: Double = 1.0
    @State private var companion = CompanionController()
    @State private var companionVisible = false
    @State private var bubbleVisible = false
    @State private var confettiTrigger = 0
    @State private var burstTrigger = 0

    private var isCompact: Bool { hsc == .compact }
    private var eggSize: CGFloat { isCompact ? 150 : 200 }
    private var companionSize: CGFloat { isCompact ? 140 : 180 }
    private var ctaSize: CGFloat { isCompact ? 22 : 26 }

    var body: some View {
        ZStack {
            // Dreamy backdrop
            LinearGradient(
                colors: [AppColor.dreamyIndigo, .black, AppColor.gemPurple],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            SparkleField(count: 35, size: 16)
            Confetti(trigger: confettiTrigger)
            StarBurst(count: 16, color: AppColor.starGold, trigger: burstTrigger)

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                ZStack {
                    if !companionVisible {
                        Text("🥚")
                            .font(.system(size: eggSize))
                            .offset(x: shake)
                            .scaleEffect(eggScale)
                            .opacity(eggOpacity)
                            .glow(AppColor.starGold, radius: 40)
                    } else {
                        CompanionView(controller: companion, size: companionSize)
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                }
                .frame(height: 300)

                if bubbleVisible {
                    BubbleSpeech(text: "היי! חיכיתי לך... אני ניצוץ! 💫")
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                if stage >= 4 {
                    JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                        onContinue()
                    } label: {
                        Text("בוא נצא להרפתקה!")
                            .font(.system(size: ctaSize, weight: .heavy, design: .rounded))
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.xl)
                    .transition(.opacity)
                }
            }

            if stage == 0 {
                VStack {
                    Spacer()
                    Text("טאפ על הביצה")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .pulse()
                        .padding(.bottom, 200)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if stage == 0 { startHatching() }
        }
    }

    private func startHatching() {
        stage = 1
        SoundPlayer.shared.play(.streakUp)
        Haptic.medium()

        // Shake 3 times
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                withAnimation(.easeInOut(duration: 0.08).repeatCount(4, autoreverses: true)) {
                    shake = 12
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    shake = 0
                }
                Haptic.medium()
                SoundPlayer.shared.play(.uiTap)
            }
        }

        // Crack/grow
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            stage = 2
            withAnimation(.easeOut(duration: 0.5)) {
                eggScale = 1.3
            }
            burstTrigger += 1
            SoundPlayer.shared.play(.portalAppear)
        }

        // Burst → companion appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            stage = 3
            withAnimation(.easeOut(duration: 0.4)) {
                eggOpacity = 0
                eggScale = 2.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                    companionVisible = true
                }
                SoundPlayer.shared.play(.companionCheer)
                Haptic.success()
                confettiTrigger += 1
                companion.cheer()
            }
        }

        // Bubble + continue button
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                bubbleVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            withAnimation {
                stage = 4
            }
        }
    }
}

#Preview {
    HatchingView(onContinue: {})
        .environment(\.layoutDirection, .rightToLeft)
}
