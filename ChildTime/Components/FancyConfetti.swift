import SwiftUI

/// 🎊 Gentle, physical confetti (Rani's spec): every piece is LAUNCHED from the
/// bottom edge, arcs up like a popper shot, then drifts slowly down while
/// swaying — and fades out instead of piling up. Pure SwiftUI (same proven
/// technique as the rising balloons), sparse and delicate by design.
struct FancyConfetti: View {
    /// Total pieces — gentle but festive (Rani: "קצת יותר קונפטי").
    var pieces: Int = 55

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<pieces, id: \.self) { i in
                LaunchedPiece(index: i, canvas: geo.size)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private struct LaunchedPiece: View {
    let index: Int
    let canvas: CGSize

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
            .onAppear { launch() }
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
        let startX = canvas.width * (0.08 + 0.84 * rnd(1))
        let apexX = startX + CGFloat(rnd(2) - 0.5) * 120
        let apexY = canvas.height * (0.12 + 0.38 * rnd(3))
        let endX = apexX + CGFloat(rnd(4) - 0.5) * 90
        let launchDelay = rnd(5) * 1.3
        let upDuration = 0.7 + rnd(6) * 0.4
        let fallDuration = 4.5 + rnd(7) * 2.0

        pos = CGPoint(x: startX, y: canvas.height + 30)

        DispatchQueue.main.asyncAfter(deadline: .now() + launchDelay) {
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
