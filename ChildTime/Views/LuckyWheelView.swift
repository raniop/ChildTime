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
    private var wheelSize: CGFloat { isCompact ? 300 : 420 }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppGradient.dreamy.ignoresSafeArea()
                FloatingOrbs(
                    colors: [AppColor.gemPurple, AppColor.starGold, AppColor.companionGlow],
                    count: 6, maxSize: 280, opacity: 0.45
                )
                SparkleField(count: 30, size: 14)
                Confetti(trigger: confetti)
                StarBurst(count: 14, color: AppColor.starGold, trigger: stars)

                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        header

                        wheelStack
                            .padding(.vertical, AppSpacing.md)

                        if let prize = winner {
                            winnerCard(prize)
                                .transition(.scale.combined(with: .opacity))
                        }

                        primaryButton

                        skipButton
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.xl)
                    // No flexible Spacer inside — let this frame center the block.
                    .frame(minHeight: proxy.size.height, alignment: .center)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            // After a prize is revealed, a tap ANYWHERE continues — so a kid
            // never has to find/scroll to a button (e.g. on landscape iPad).
            .overlay {
                if winner != nil {
                    VStack {
                        Spacer()
                        Text("לַחֲצוּ בְּכָל מָקוֹם כְּדֵי לְהַמְשִׁיךְ 👆")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(.bottom, 48)
                            .pulse()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptic.light()
                        onClose()
                    }
                    .transition(.opacity)
                } else if !isSpinning {
                    // Before spinning, a tap ANYWHERE spins too — not only on
                    // the wheel itself.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { spin() }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 4) {
            Text("🎡")
                .font(.system(size: isCompact ? 44 : 56))
            Text("גַּלְגַּל מַזָּל!")
                .font(.system(size: isCompact ? 32 : 44, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColor.starGold, AppColor.companionGlow, Color(hex: "FFE082")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: AppColor.starGold.opacity(0.7), radius: 10)
            if winner == nil {
                Text("הַקֵּשׁ עַל הַגַּלְגַּל כְּדֵי לְסוֹבֵב")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var wheelStack: some View {
        ZStack {
            // The wheel
            WheelShape(wedges: wedges, size: wheelSize)
                .rotationEffect(.degrees(rotation))
                .animation(.easeOut(duration: 3.4), value: rotation)
                .shadow(color: .black.opacity(0.3), radius: 14, y: 4)
                .scaleEffect(pulse && winner == nil && !isSpinning ? 1.02 : 1.0)
                .onTapGesture { spin() }

            // Center hub
            Circle()
                .fill(LinearGradient(
                    colors: [.white, Color(hex: "FFD166")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: wheelSize * 0.18, height: wheelSize * 0.18)
                .overlay(Circle().stroke(AppColor.starGold, lineWidth: 3))
                .shadow(color: .black.opacity(0.3), radius: 6)
                .overlay(Text("🎁").font(.system(size: wheelSize * 0.09)))

            // Indicator arrow at the top of the wheel
            VStack {
                Triangle()
                    .fill(AppColor.starGold)
                    .frame(width: 28, height: 32)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                    .offset(y: 8)
                Spacer()
            }
            .frame(width: wheelSize, height: wheelSize)
        }
        .frame(width: wheelSize, height: wheelSize)
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
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .stroke(prize.isPenalty
                                ? AppColor.companionGlow.opacity(0.5)
                                : AppColor.starGold.opacity(0.7),
                                lineWidth: 2)
                )
        )
        .glow(prize.isPenalty ? AppColor.companionGlow : AppColor.starGold, radius: 14)
    }

    private var primaryButton: some View {
        let label: String = {
            if winner != nil { return "אַחְלָה — סְגֹר" }
            if isSpinning   { return "מִסְתּוֹבֵב…" }
            return "סוֹבֵב!"
        }()
        return JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
            if winner != nil { onClose() }
            else { spin() }
        } label: {
            Text(label).font(.system(size: 22, weight: .heavy, design: .rounded))
        }
        .disabled(isSpinning && winner == nil)
        .opacity(isSpinning && winner == nil ? 0.6 : 1)
    }

    private var skipButton: some View {
        Button {
            Haptic.light()
            onClose()
        } label: {
            Text(winner == nil ? "דַּלֵּג הַפַּעַם" : "סְגֹר")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .underline()
        }
        .padding(.top, 4)
    }

    // MARK: - Spin logic

    private func spin() {
        guard !isSpinning, winner == nil else { return }
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

    var body: some View {
        ZStack {
            // Wedges
            ForEach(Array(wedges.enumerated()), id: \.offset) { idx, prize in
                wedgeView(at: idx, prize: prize)
            }
            // Rim
            Circle()
                .stroke(LinearGradient(
                    colors: [AppColor.starGold, .white, AppColor.starGold],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ), lineWidth: 6)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }

    private func wedgeView(at index: Int, prize: WheelPrize) -> some View {
        let count = wedges.count
        let degreesPerWedge = 360.0 / Double(count)
        let startAngle = Angle.degrees(Double(index) * degreesPerWedge - 90)
        let endAngle = Angle.degrees(Double(index + 1) * degreesPerWedge - 90)
        let midAngle = Angle.degrees(Double(index) * degreesPerWedge + degreesPerWedge / 2 - 90)

        return ZStack {
            WedgePath(startAngle: startAngle, endAngle: endAngle)
                .fill(LinearGradient(
                    colors: [prize.color, prize.color.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(
                    WedgePath(startAngle: startAngle, endAngle: endAngle)
                        .stroke(.white.opacity(0.5), lineWidth: 2)
                )

            // Wedge content — emoji + short label, oriented along the radius.
            VStack(spacing: 2) {
                Text(prize.emoji)
                    .font(.system(size: size * 0.08))
                Text(prize.label)
                    .font(.system(size: size * 0.035, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: size * 0.22)
                    .minimumScaleFactor(0.6)
            }
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            // Place the label out along the wedge radius.
            .offset(
                x: cos(midAngle.radians) * size * 0.30,
                y: sin(midAngle.radians) * size * 0.30
            )
        }
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
