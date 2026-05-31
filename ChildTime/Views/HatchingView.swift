import SwiftUI

struct HatchingView: View {
    let onContinue: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    @State private var stage: Int = 0

    // Egg animation state.
    @State private var wobble: Double = 0           // idle rocking
    @State private var shake: CGFloat = 0           // tap jitter
    @State private var crackProgress: CGFloat = 0   // 0→1 draws the crack
    @State private var topOffset: CGFloat = 0       // top shell flying up
    @State private var topRot: Double = 0
    @State private var topOpacity: Double = 1
    @State private var bottomTilt: Double = 0
    @State private var flash: Double = 0
    @State private var splitOpen: Bool = false      // shells separated yet?

    // Companion emerging.
    @State private var companion = CompanionController()
    @State private var companionVisible = false
    @State private var companionScale: CGFloat = 0.2
    @State private var companionOffsetY: CGFloat = 0
    @State private var bubbleVisible = false

    @State private var confettiTrigger = 0
    @State private var burstTrigger = 0

    private var isCompact: Bool { hsc == .compact }
    private var eggW: CGFloat { isCompact ? 150 : 200 }
    private var eggH: CGFloat { eggW * 1.32 }
    private var companionSize: CGFloat { isCompact ? 130 : 170 }
    private var ctaSize: CGFloat { isCompact ? 22 : 26 }

    // Shared crack geometry so the split edge and the crack line line up.
    private let teeth = 7
    private let splitRatio: CGFloat = 0.46
    private let toothRatio: CGFloat = 0.05

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColor.dreamyIndigo, .black, AppColor.gemPurple],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            SparkleField(count: 32, size: 16)
            Confetti(trigger: confettiTrigger)
            StarBurst(count: 18, color: AppColor.starGold, trigger: burstTrigger)

            VStack(spacing: AppSpacing.lg) {
                Spacer()
                eggStack
                    .frame(height: 320)

                if bubbleVisible {
                    BubbleSpeech(text: "הֵיי! חִכִּיתִי לְךָ... אֲנִי טוֹפִּי! 💫")
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                if stage >= 4 {
                    JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                        onContinue()
                    } label: {
                        Text("בּוֹאוּ נֵצֵא לְהַרְפַּתְקָה!")
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
                    Text("לַחֲצוּ עַל הַבֵּיצָה")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .pulse()
                        .padding(.bottom, 180)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if stage == 0 { startHatching() }
        }
        .onAppear {
            // Gentle idle rocking until tapped.
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                wobble = 5
            }
        }
    }

    // MARK: - Egg

    private var eggStack: some View {
        ZStack {
            // Warm glow behind.
            Circle()
                .fill(RadialGradient(colors: [AppColor.starGold.opacity(0.55), .clear],
                                     center: .center, startRadius: 0, endRadius: eggW))
                .frame(width: eggW * 2.2, height: eggW * 2.2)
                .blur(radius: 22)

            ZStack {
                // Bottom shell (front of the companion so it "emerges").
                eggFill
                    .clipShape(ShellMask(top: false, teeth: teeth, splitRatio: splitRatio, toothRatio: toothRatio))
                    .rotationEffect(.degrees(bottomTilt), anchor: .bottom)
                    .zIndex(3)

                // The companion rising out of the shell.
                if companionVisible {
                    CompanionView(controller: companion, size: companionSize)
                        .scaleEffect(companionScale)
                        .offset(y: companionOffsetY)
                        .zIndex(2)
                }

                // Top shell — lifts, tilts and flies up on hatch.
                eggFill
                    .clipShape(ShellMask(top: true, teeth: teeth, splitRatio: splitRatio, toothRatio: toothRatio))
                    .offset(y: topOffset)
                    .rotationEffect(.degrees(topRot))
                    .opacity(topOpacity)
                    .zIndex(splitOpen ? 4 : 1)

                // Jagged crack line drawn before the split.
                if stage >= 2 && !splitOpen {
                    CrackLine(teeth: teeth, splitRatio: splitRatio, toothRatio: toothRatio)
                        .trim(from: 0, to: crackProgress)
                        .stroke(Color(hex: "6E4B1A").opacity(0.8),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: eggW, height: eggH)
                        .zIndex(5)
                }
            }
            .frame(width: eggW, height: eggH)
            .offset(x: shake)
            .rotationEffect(.degrees(stage == 0 ? wobble : 0), anchor: .bottom)

            // Bright flash at the moment of hatching.
            Circle()
                .fill(RadialGradient(colors: [.white, .white.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: eggW))
                .frame(width: eggW * 2.4, height: eggW * 2.4)
                .scaleEffect(0.4 + flash)
                .opacity(flash)
                .allowsHitTesting(false)
        }
    }

    /// The egg's body fill — cream gradient with a few speckles + highlight.
    private var eggFill: some View {
        ZStack {
            EggShape()
                .fill(LinearGradient(colors: [Color(hex: "FFFDF5"), Color(hex: "FBE7BC"), Color(hex: "F1CE92")],
                                     startPoint: .top, endPoint: .bottom))
            // Speckles.
            ForEach(Array(speckles.enumerated()), id: \.offset) { _, s in
                Ellipse()
                    .fill(Color(hex: "D7AE62").opacity(0.55))
                    .frame(width: eggW * s.size, height: eggW * s.size * 0.8)
                    .position(x: eggW * s.x, y: eggH * s.y)
            }
            // Soft top-left highlight for a 3D feel.
            Ellipse()
                .fill(.white.opacity(0.35))
                .frame(width: eggW * 0.3, height: eggH * 0.22)
                .blur(radius: 8)
                .position(x: eggW * 0.36, y: eggH * 0.28)
        }
        .frame(width: eggW, height: eggH)
        .overlay(EggShape().stroke(Color(hex: "E4C385").opacity(0.7), lineWidth: 2))
        .compositingGroup()
        .shadow(color: .black.opacity(0.25), radius: 8, y: 6)
    }

    private var speckles: [(x: CGFloat, y: CGFloat, size: CGFloat)] {
        [(0.34, 0.5, 0.10), (0.62, 0.4, 0.07), (0.5, 0.66, 0.09),
         (0.7, 0.62, 0.06), (0.4, 0.78, 0.05)]
    }

    // MARK: - Hatch sequence

    private func startHatching() {
        stage = 1
        wobble = 0
        SoundPlayer.shared.play(.streakUp)
        Haptic.medium()

        // 1) A few hard shakes.
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                withAnimation(.easeInOut(duration: 0.07).repeatCount(5, autoreverses: true)) {
                    shake = 14
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { shake = 0 }
                Haptic.medium()
                SoundPlayer.shared.play(.uiTap)
            }
        }

        // 2) Crack draws across the shell.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            stage = 2
            SoundPlayer.shared.play(.portalAppear)
            Haptic.heavy()
            withAnimation(.easeOut(duration: 0.5)) { crackProgress = 1 }
            // A little jolt as it cracks.
            withAnimation(.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) { shake = 8 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shake = 0 }
        }

        // 3) Split! Top flies up, Tofy bursts out.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
            stage = 3
            splitOpen = true
            flash = 0.95
            withAnimation(.easeOut(duration: 0.5)) { flash = 0 }
            burstTrigger += 1
            confettiTrigger += 1
            SoundPlayer.shared.play(.companionCheer)
            Haptic.success()

            // Top shell launches upward, tilting and fading.
            withAnimation(.easeOut(duration: 0.7)) {
                topOffset = -eggH * 1.1
                topRot = -28
                topOpacity = 0
                bottomTilt = -3
            }

            // Tofy pops out of the bottom shell and rises.
            companionVisible = true
            companionScale = 0.2
            companionOffsetY = eggH * 0.12
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                companionScale = 1.0
                companionOffsetY = -eggH * 0.32
            }
            companion.cheer()
        }

        // 4) Bubble + continue.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { bubbleVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation { stage = 4 }
        }
    }
}

// MARK: - Egg shapes

/// A classic egg outline — rounded bottom, gently tapered top.
struct EggShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        let cx = r.midX
        p.move(to: CGPoint(x: cx, y: r.maxY))
        p.addCurve(to: CGPoint(x: cx, y: r.minY),
                   control1: CGPoint(x: r.minX, y: r.maxY - h * 0.16),
                   control2: CGPoint(x: r.minX + w * 0.13, y: r.minY))
        p.addCurve(to: CGPoint(x: cx, y: r.maxY),
                   control1: CGPoint(x: r.maxX - w * 0.13, y: r.minY),
                   control2: CGPoint(x: r.maxX, y: r.maxY - h * 0.16))
        p.closeSubpath()
        return p
    }
}

/// A rectangular mask whose dividing edge is a zigzag — used to clip the egg
/// fill into a top and bottom shell that fit together along the crack.
struct ShellMask: Shape {
    let top: Bool
    let teeth: Int
    let splitRatio: CGFloat
    let toothRatio: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        let midY = r.height * splitRatio
        let toothH = r.height * toothRatio
        let step = r.width / CGFloat(teeth)

        func zigzag() {
            for i in 0..<teeth {
                let x = r.minX + step * (CGFloat(i) + 0.5)
                let y = midY + (i % 2 == 0 ? -toothH : toothH)
                p.addLine(to: CGPoint(x: x, y: y))
            }
            p.addLine(to: CGPoint(x: r.maxX, y: midY))
        }

        if top {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: midY))
            zigzag()
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: midY))
            zigzag()
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        }
        p.closeSubpath()
        return p
    }
}

/// The jagged crack line that draws across the egg before it splits.
struct CrackLine: Shape {
    let teeth: Int
    let splitRatio: CGFloat
    let toothRatio: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        let midY = r.height * splitRatio
        let toothH = r.height * toothRatio
        let step = r.width / CGFloat(teeth)
        p.move(to: CGPoint(x: r.minX, y: midY))
        for i in 0..<teeth {
            let x = r.minX + step * (CGFloat(i) + 0.5)
            let y = midY + (i % 2 == 0 ? -toothH : toothH)
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: midY))
        return p
    }
}

#Preview {
    HatchingView(onContinue: {})
        .environment(\.layoutDirection, .rightToLeft)
}
