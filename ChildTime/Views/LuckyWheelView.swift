import SwiftUI

/// The Lucky Wheel — a spinning 8-wedge wheel the kid can trigger. Picks
/// a random good prize most of the time, with occasional gentle 'fun
/// missions' as the loser slot.
struct LuckyWheelView: View {
    let onClose: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var cosmetics: CosmeticStore

    @State private var wedges: [WheelPrize] = LuckyWheelCatalog.wedgesForSpin()
    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var winner: WheelPrize? = nil
    @State private var winnerMessage: String = ""
    @State private var confetti = 0
    @State private var stars = 0
    @State private var pulse = false

    private var isCompact: Bool { hsc == .compact }

    var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            // Fit the wheel to the space — never let it crowd out the prize/buttons.
            let wheelSize = min(isCompact ? 380 : 480,
                                proxy.size.height * (landscape ? 0.80 : 0.56),
                                proxy.size.width * (landscape ? 0.46 : 0.98))
            ZStack {
                GlassBackdrop()
                SparkleField(count: 14, size: 11)
                FancyConfetti(trigger: confetti)
                StarBurst(count: 14, color: AppColor.starGold, trigger: stars)

                if landscape {
                    // Wide: wheel on one side, info on the other — nothing scrolls
                    // off the bottom.
                    HStack(spacing: AppSpacing.xxl) {
                        wheelStack(size: wheelSize)
                        infoColumn
                            .frame(maxWidth: 380)
                    }
                    .padding(AppSpacing.xl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            header
                            wheelStack(size: wheelSize)
                                .padding(.vertical, AppSpacing.md)
                            if let prize = winner {
                                winnerCard(prize)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            primaryButton
                            if winner == nil { skipButton }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.xl)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            // After a prize is revealed, a tap ANYWHERE continues — so a kid
            // never has to find/scroll to a button (e.g. on landscape iPad).
            // NOTE: we intentionally do NOT add a "tap anywhere to spin" layer
            // before spinning — it sat on top of the buttons and swallowed the
            // first tap on "skip"/"spin". The wheel itself is tappable to spin
            // (and so is the big button), which matches the on-screen hint.
            .overlay {
                if winner != nil {
                    // Tap anywhere to continue — no on-screen hint text needed.
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptic.light()
                            onClose()
                        }
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            progress.applyDailyRolloverIfNeeded()
            // No room for play-minutes today (cap full) AND tomorrow's bank is
            // full → don't offer minute prizes on the wheel.
            if progress.bonusMinutesRoom() <= 0 {
                wedges = LuckyWheelCatalog.wedgesForSpin(excludeMinutes: true)
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        // Centered title + one line, straight on the backdrop (Rani: no box).
        VStack(spacing: 4) {
            Text("גַּלְגַּל מַזָּל!")
                .font(.system(size: isCompact ? 30 : 40, weight: .black, design: .rounded))
                .foregroundStyle(GlassInk.primary)
                .shadow(color: .black.opacity(0.18), radius: 7, y: 2)
            Text(winner == nil ? "הַקֵּשׁ עַל הַגַּלְגַּל כְּדֵי לְסוֹבֵב ✨" : "אֵיזֶה כֵּיף! 🎉")
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    /// The header + prize + buttons column (used beside the wheel in landscape).
    private var infoColumn: some View {
        VStack(spacing: AppSpacing.lg) {
            header
            if let prize = winner {
                winnerCard(prize)
                    .transition(.scale.combined(with: .opacity))
            }
            primaryButton
            if winner == nil { skipButton }
        }
    }

    private func wheelStack(size wheelSize: CGFloat) -> some View {
        ZStack {
            // The wheel
            WheelShape(wedges: wedges, size: wheelSize, rotation: rotation)
                .rotationEffect(.degrees(rotation))
                .animation(.easeOut(duration: 3.4), value: rotation)
                .shadow(color: .black.opacity(0.3), radius: 14, y: 4)
                .scaleEffect(pulse && winner == nil && !isSpinning ? 1.02 : 1.0)
                .onTapGesture { spin() }

            // Center hub
            // Glass hub
            Circle()
                .fill(.white.opacity(0.26))
                .frame(width: wheelSize * 0.18, height: wheelSize * 0.18)
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)

            // Indicator arrow at the top of the wheel
            VStack {
                Triangle()
                    .fill(.white)
                    .frame(width: 26, height: 30)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                    .offset(y: 8)
                Spacer()
            }
            .frame(width: wheelSize, height: wheelSize)
        }
        .frame(width: wheelSize, height: wheelSize)
        // The wheel is GEOMETRY: in the app's RTL environment SwiftUI mirrors
        // `rotationEffect`, so the wheel spun counter-clockwise and stopped one
        // wedge away from the prize it had actually granted (Rani: "החץ על חד-קרן
        // ורושם 50 יהלומים"). Drawn LTR, the landing maths and the pointer agree,
        // and the labels' counter-rotation keeps them upright.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func winnerCard(_ prize: WheelPrize) -> some View {
        VStack(spacing: 10) {
            Text(prize.emoji)
                .font(.system(size: 54))
            Text(prize.isPenalty ? "מְשִׂימָה מִשְׁפַּחְתִּית 🤗" : "זָכִיתָ!")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(prize.isPenalty ? AppColor.companionGlow : AppColor.starGold)
            Text(prize.label)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if !winnerMessage.isEmpty {
                Text(winnerMessage)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: 420)
        // The prize pane: glass with a whisper of gold (or the softer glow for a
        // "next time" spin) — the one warm pane on the screen.
        .glassPane(radius: 22, tint: prize.isPenalty ? AppColor.companionGlow : Color(hex: "FFD23F"))
    }

    private var primaryButton: some View {
        let label: String = {
            if winner != nil { return "אַחְלָה — סְגוֹר" }
            if isSpinning   { return "מִסְתּוֹבֵב…" }
            return "סוֹבֵב!"
        }()
        return Button {
            if winner != nil { onClose() }
            else { spin() }
        } label: {
            Text(label)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .ctaGlass(Color(hex: "5E60CE"), Color(hex: "3E8BF0"))
        }
        .buttonStyle(.juicy)
        .frame(maxWidth: 480)
        .disabled(isSpinning && winner == nil)
        .opacity(isSpinning && winner == nil ? 0.6 : 1)
    }

    private var skipButton: some View {
        Button {
            Haptic.light()
            onClose()
        } label: {
            Text(winner == nil ? "דַּלֵּג הַפַּעַם" : "סְגוֹר")
                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassInk.primary)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Capsule().fill(.white.opacity(0.14)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.30), lineWidth: 1))
        }
        .padding(.top, 4)
    }

    // MARK: - Spin logic

    private func spin() {
        guard !isSpinning, winner == nil else { return }
        // No wedges → nothing to spin (and `Int.random(in: 0..<0)` / ÷0 would crash).
        guard !wedges.isEmpty else { return }
        isSpinning = true
        AppAnalytics.wheelSpin(bonus: ProgressStore.shared.pendingBonusWheel)
        SoundPlayer.shared.play(.portalAppear)
        Haptic.medium()

        // Pick the winning wedge first, then spin to land on it.
        let winningIndex = Int.random(in: 0..<wedges.count)
        let degreesPerWedge = 360.0 / Double(wedges.count)
        // Each wedge's CENTER (with the indicator at 12 o'clock = -90°).
        // We need the final rotation so that `winningIndex` ends up under
        // the indicator.
        let extraTurns = 5.0 * 360.0
        let targetCenterAngle = Double(winningIndex) * degreesPerWedge + degreesPerWedge / 2
        let landingRotation = extraTurns + (360 - targetCenterAngle)
        rotation = landingRotation

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            let prize = wedges[winningIndex]
            winnerMessage = prize.apply()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                winner = prize
            }
            isSpinning = false
            SoundPlayer.shared.play(prize.isPenalty ? .wrongSoft : .levelUp)
            Haptic.success()
            if !prize.isPenalty {
                confetti += 1
                stars += 1
            }
        }
    }
}

// MARK: - Wheel shape

private struct WheelShape: View {
    let wedges: [WheelPrize]
    let size: CGFloat
    /// The wheel's current spin — each label counter-rotates by it so the
    /// words stay upright and readable wherever the wheel stops.
    var rotation: Double = 0

    var body: some View {
        ZStack {
            // Wedges first, then EVERY label above ALL the fills — a label that
            // sat inside its own wedge's ZStack was covered by the next wedge's
            // translucent fill and read washed-out (Rani: "לא רואים ברור").
            ForEach(Array(wedges.enumerated()), id: \.offset) { idx, prize in
                wedgeFill(at: idx, prize: prize)
            }
            ForEach(Array(wedges.enumerated()), id: \.offset) { idx, prize in
                wedgeLabel(at: idx, prize: prize)
            }
            // Rim
            // Glass rim: a light edge, not a gold band — the wedges are the colour.
            Circle()
                .stroke(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.5)],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 7)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
        }
        .frame(width: size, height: size)
        // Geometry, not text: the wheel is drawn LTR so `.offset(x:)` puts each
        // label on ITS wedge — in the app's RTL environment the offsets mirrored
        // and every label landed on the opposite wedge.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func wedgeAngles(_ index: Int) -> (start: Angle, end: Angle, mid: Angle) {
        let per = 360.0 / Double(wedges.count)
        return (Angle.degrees(Double(index) * per - 90),
                Angle.degrees(Double(index + 1) * per - 90),
                Angle.degrees(Double(index) * per + per / 2 - 90))
    }

    private func wedgeFill(at index: Int, prize: WheelPrize) -> some View {
        let (startAngle, endAngle, _) = wedgeAngles(index)
        return ZStack {
            // Glass wedge: a translucent pane with the prize colour glowing
            // through it (same idea as the world tiles), white seams between.
            WedgePath(startAngle: startAngle, endAngle: endAngle)
                .fill(.white.opacity(0.16))
            WedgePath(startAngle: startAngle, endAngle: endAngle)
                .fill(RadialGradient(colors: [prize.color.opacity(0.85), prize.color.opacity(0.45)],
                                     center: .center, startRadius: size * 0.1, endRadius: size * 0.5))
            WedgePath(startAngle: startAngle, endAngle: endAngle)
                .stroke(.white.opacity(0.75), lineWidth: 2)
        }
        .frame(width: size, height: size)
    }

    private func wedgeLabel(at index: Int, prize: WheelPrize) -> some View {
        let midAngle = wedgeAngles(index).mid
        // Wedge content — emoji + short label, centered on the wedge bisector.
        return VStack(spacing: 4) {
                Text(prize.emoji)
                    .font(.system(size: size * 0.09))
                Text(prize.label)
                    .font(.system(size: size * 0.038, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: size * 0.25)
                    .minimumScaleFactor(0.6)
            }
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            // Upright, never rotated: a radially rotated Hebrew label turns into
            // mirror-writing on the far half of the wheel.
            .environment(\.layoutDirection, .rightToLeft)   // the Hebrew label itself
            .rotationEffect(.degrees(-rotation))              // upright at rest AND while spinning
            .offset(
                x: cos(midAngle.radians) * size * 0.33,
                y: sin(midAngle.radians) * size * 0.33
            )
            .frame(width: size, height: size)
    }
}

private struct WedgePath: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    LuckyWheelView { }
        .environmentObject(ProgressStore.shared)
        .environmentObject(CosmeticStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
