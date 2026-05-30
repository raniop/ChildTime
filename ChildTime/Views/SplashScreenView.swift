import SwiftUI

/// An animated welcome splash shown for ~2.5s right after the (static) iOS
/// launch screen, before the app's real content appears. iOS forbids animation
/// or sound in the launch storyboard itself, so this is where טופי comes alive:
/// the mascot bounces in with expanding glow rings, the wordmark rises, sparkles
/// drift, and a short cheerful jingle plays once. Designed to delight kids.
struct SplashScreenView: View {
    /// Called once the intro animation has finished playing.
    var onFinish: () -> Void

    @State private var companion = CompanionController()

    // Animation stages, driven on a short timeline.
    @State private var showRings = false
    @State private var showMascot = false
    @State private var showWordmark = false
    @State private var showTagline = false
    @State private var bgIn = false
    @State private var leaving = false

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs.home()
                .opacity(bgIn ? 1 : 0)
            SparkleField(count: 26, size: 14)
                .opacity(bgIn ? 1 : 0)

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                ZStack {
                    // Expanding celebratory rings behind the mascot.
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(AppColor.starGold.opacity(0.5), lineWidth: 3)
                            .frame(width: 150, height: 150)
                            .scaleEffect(showRings ? 2.6 : 0.2)
                            .opacity(showRings ? 0 : 0.8)
                            .animation(
                                .easeOut(duration: 1.4).delay(Double(i) * 0.18),
                                value: showRings
                            )
                    }

                    CompanionView(controller: companion, size: 150)
                        .scaleEffect(showMascot ? 1 : 0.2)
                        .opacity(showMascot ? 1 : 0)
                }

                VStack(spacing: AppSpacing.sm) {
                    Text("טוֹפִּי")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColor.starGold, AppColor.companionGlow, Color(hex: "FFE082")],
                                startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: AppColor.starGold.opacity(0.5), radius: 14)
                        .scaleEffect(showWordmark ? 1 : 0.7)
                        .opacity(showWordmark ? 1 : 0)
                        .offset(y: showWordmark ? 0 : 20)

                    Text("לוֹמְדִים, מְשַׂחֲקִים, מַרְוִיחִים זְמַן מָסָךְ")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .opacity(showTagline ? 1 : 0)
                        .offset(y: showTagline ? 0 : 12)
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .opacity(leaving ? 0 : 1)
        .task { await runIntro() }
    }

    @MainActor
    private func runIntro() async {
        // Background settles in.
        withAnimation(.easeOut(duration: 0.5)) { bgIn = true }

        // Mascot bursts in with a bouncy spring + rings + sound.
        try? await Task.sleep(nanoseconds: 200_000_000)
        ToneSynth.shared.startMusic()                 // short welcome jingle (once)
        companion.wow()                               // excited pose + sparkle + chime
        withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) { showMascot = true }
        withAnimation { showRings = true }

        // Wordmark rises.
        try? await Task.sleep(nanoseconds: 450_000_000)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { showWordmark = true }

        // Tagline.
        try? await Task.sleep(nanoseconds: 350_000_000)
        withAnimation(.easeOut(duration: 0.45)) { showTagline = true }

        // Hold, then fade out and hand off to the app.
        try? await Task.sleep(nanoseconds: 1_300_000_000)
        withAnimation(.easeIn(duration: 0.45)) { leaving = true }
        try? await Task.sleep(nanoseconds: 480_000_000)
        onFinish()
    }
}

#Preview {
    SplashScreenView(onFinish: {})
        .environment(\.layoutDirection, .rightToLeft)
}
