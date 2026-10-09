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

    /// When the current burst was fired; nil = nothing in the air.
    @State private var firedAt: Date?

    /// The longest flight (delay + up + fall) — after it the canvas goes idle.
    private static let flight: TimeInterval = 1.3 + 1.1 + 6.5

    // ⚡ ONE canvas, drawn per display frame only while a burst is in the air.
    // It was 55 SwiftUI views, each with its own state and an endless sway
    // animation that never stopped after the piece faded — on the question
    // screen the whole layer kept animating forever after the first confetti,
    // and the screen flickered and lagged (Rani). Same flight, same look.
    var body: some View {
        TimelineView(.animation(paused: firedAt == nil)) { timeline in
            Canvas { ctx, size in
                guard let start = firedAt else { return }
                let t = timeline.date.timeIntervalSince(start)
                for i in 0..<pieces { Self.draw(i, at: t, in: size, ctx: &ctx) }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear { if trigger == -1 { fire() } }
        .onChangeCompat(of: trigger) { _, _ in fire() }
    }

    private func fire() {
        let now = Date()
        firedAt = now
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flight + 0.2) {
            if firedAt == now { firedAt = nil }   // a newer burst keeps the canvas live
        }
    }

    private static let palette: [Color] = [
        Color(hex: "FFD23F"),   // gold
        Color(hex: "9B5DE5"),   // purple
        Color(hex: "06D6A0"),   // mint
        Color(hex: "FF6B6B"),   // coral
        Color(hex: "48BFE3"),   // sky
        .white,
    ]

    /// Deterministic per-piece "randomness".
    private static func rnd(_ index: Int, _ salt: Int) -> Double {
        let x = sin(Double(index * 37 + salt * 101) * 12.9898) * 43758.5453
        return x - x.rounded(.down)
    }

    /// FOUR party poppers (Rani): two at the side edges ~30% up from the bottom
    /// arcing inward, two on the bottom edge shooting up — then a slow, swaying
    /// drift down that fades out.
    private static func draw(_ i: Int, at t: TimeInterval, in size: CGSize, ctx: inout GraphicsContext) {
        let r = { (salt: Int) in rnd(i, salt) }
        let w = size.width, h = size.height
        let startX: CGFloat, startY: CGFloat, apexX: CGFloat
        switch i % 4 {
        case 0:  startX = -24;    startY = h * (0.60 + 0.18 * r(14)); apexX = w * (0.18 + 0.52 * r(2))
        case 1:  startX = w + 24; startY = h * (0.60 + 0.18 * r(14)); apexX = w * (0.82 - 0.52 * r(2))
        case 2:  startX = w * 0.25; startY = h + 24; apexX = w * (0.10 + 0.55 * r(2))
        default: startX = w * 0.75; startY = h + 24; apexX = w * (0.90 - 0.55 * r(2))
        }
        let apexY = h * (0.10 + 0.38 * r(3))
        let endX = apexX + CGFloat(r(4) - 0.5) * 110
        let endY = h * (0.75 + 0.2 * r(13))
        let delay = r(5) * 1.3
        let up = 0.7 + r(6) * 0.4
        let fall = 4.5 + r(7) * 2.0

        let tp = t - delay
        guard tp >= 0, tp <= up + fall else { return }
        var pos: CGPoint
        var alpha = 1.0
        if tp < up {
            let k = tp / up, e = 1 - (1 - k) * (1 - k)            // ease-out
            pos = CGPoint(x: startX + (apexX - startX) * e, y: startY + (apexY - startY) * e)
        } else {
            let f = (tp - up) / fall, e = f * f                    // ease-in
            pos = CGPoint(x: apexX + (endX - apexX) * e, y: apexY + (endY - apexY) * e)
            alpha = 1 - min(1, max(0, (f - 0.35) / 0.6))
        }
        guard alpha > 0.01 else { return }
        let period = 1.2 + r(10) * 0.6
        let amp = CGFloat(10 + r(11) * 12) * (r(12) > 0.5 ? 1 : -1)
        pos.x += amp * CGFloat(sin(tp / period * .pi))
        let spin = (r(8) > 0.5 ? 1.0 : -1.0) * (540 + r(9) * 540) * (tp / (up + fall))

        var layer = ctx
        layer.opacity = alpha
        layer.translateBy(x: pos.x, y: pos.y)
        layer.rotate(by: .degrees(spin))
        let color = palette[i % palette.count]
        switch i % 3 {
        case 0:  layer.fill(Path(roundedRect: CGRect(x: -5, y: -3.5, width: 10, height: 7), cornerRadius: 1.5), with: .color(color))
        case 1:  layer.fill(Path(ellipseIn: CGRect(x: -3.5, y: -3.5, width: 7, height: 7)), with: .color(color))
        default: layer.fill(Path(roundedRect: CGRect(x: -2.5, y: -6.5, width: 5, height: 13), cornerRadius: 1.5), with: .color(color))
        }
    }
}
