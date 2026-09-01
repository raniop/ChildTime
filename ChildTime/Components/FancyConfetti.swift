import SwiftUI

/// 🎊 Gentle, physical confetti (Rani's spec): every piece is LAUNCHED from the
/// bottom edge, arcs up like a popper shot, then drifts slowly down while
/// swaying — and fades out instead of piling up. Pure SwiftUI (same proven
/// technique as the rising balloons), sparse and delicate by design.
struct FancyConfetti: View {
    /// -1 (default) → fire once on appear (the celebration screens).
    /// Any other value → the old `Confetti` semantics: idle until `trigger`
    /// CHANGES, refiring on every change (game wins, chests, level-ups…).
    var trigger: Int = -1
    /// Total pieces — gentle but festive (Rani: "קצת יותר קונפטי").
    var pieces: Int = 55

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<pieces, id: \.self) { i in
                LaunchedPiece(index: i, canvas: geo.size, trigger: trigger)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private struct LaunchedPiece: View {
    let index: Int
    let canvas: CGSize
    let trigger: Int

    /// Bumped on every (re)fire — in-flight phase-2 closures from an older
    /// burst check it and bail, so a refire never mixes two flights.
    @State private var generation = 0
    @State private var pos = CGPoint(x: -100, y: -100)
    @State private var rot: Double = 0
    @State private var sway: CGFloat = 0
    @State private var opacity: Double = 0

    private static let palette: [Color] = [
        Color(hex: "FFD23F"),   // gold
        Color(hex: "9B5DE5"),   // purple
        Color(hex: "06D6A0"),   // mint
        Color(hex: "FF6B6B"),   // coral
        Color(hex: "48BFE3"),   // sky
        .white,
    ]

    /// Deterministic per-piece "randomness" — stable across re-renders.
    private func rnd(_ salt: Int) -> Double {
        let x = sin(Double(index * 37 + salt * 101) * 12.9898) * 43758.5453
        return x - x.rounded(.down)
    }

    var body: some View {
        piece
            .rotationEffect(.degrees(rot))
            .offset(x: sway)
            .position(pos)
            .opacity(opacity)
            .onAppear { if trigger == -1 { fire() } }
            .onChangeCompat(of: trigger) { _, _ in fire() }
    }

    private func fire() {
        generation += 1
        withTransaction(Transaction(animation: nil)) {
            opacity = 0
            rot = 0
            sway = 0
        }
        launch()
    }

    @ViewBuilder
    private var piece: some View {
        let color = Self.palette[index % Self.palette.count]
        switch index % 3 {
        case 0:  RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 10, height: 7)
        case 1:  Circle().fill(color).frame(width: 7, height: 7)
        default: RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 5, height: 13)
        }
    }

    private func launch() {
        // Two party poppers at the SIDE edges, ~30% up from the bottom (Rani) —
        // even pieces fire from the left, odd from the right, arcing inward.
        let fromLeft = index % 2 == 0
        let startX: CGFloat = fromLeft ? -24 : canvas.width + 24
        let startY = canvas.height * (0.60 + 0.18 * rnd(14))
        let apexX = canvas.width * (fromLeft ? 0.18 + 0.52 * rnd(2)
                                             : 0.82 - 0.52 * rnd(2))
        let apexY = canvas.height * (0.10 + 0.38 * rnd(3))
        let endX = apexX + CGFloat(rnd(4) - 0.5) * 110
        let launchDelay = rnd(5) * 1.3
        let upDuration = 0.7 + rnd(6) * 0.4
        let fallDuration = 4.5 + rnd(7) * 2.0
        let g = generation

        withTransaction(Transaction(animation: nil)) {
            pos = CGPoint(x: startX, y: startY)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + launchDelay) {
            guard g == generation else { return }   // superseded by a refire
            opacity = 1
            // 🚀 up: fast out of the "popper", easing off toward the apex…
            withAnimation(.easeOut(duration: upDuration)) {
                pos = CGPoint(x: apexX, y: apexY)
            }
            // …spinning the whole flight…
            withAnimation(.linear(duration: upDuration + fallDuration)) {
                rot = (rnd(8) > 0.5 ? 1 : -1) * (540 + rnd(9) * 540)
            }
            // …and swaying side to side on the way down.
            withAnimation(.easeInOut(duration: 1.2 + rnd(10) * 0.6).repeatForever(autoreverses: true)) {
                sway = CGFloat(10 + rnd(11) * 12) * (rnd(12) > 0.5 ? 1 : -1)
            }
            // 🍂 down: slow, gentle drift — fading out along the way.
            DispatchQueue.main.asyncAfter(deadline: .now() + upDuration) {
                guard g == generation else { return }
                withAnimation(.easeIn(duration: fallDuration)) {
                    pos = CGPoint(x: endX, y: canvas.height * (0.75 + 0.2 * rnd(13)))
                }
                withAnimation(.linear(duration: fallDuration * 0.6).delay(fallDuration * 0.35)) {
                    opacity = 0
                }
            }
        }
    }
}
