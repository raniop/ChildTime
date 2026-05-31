import SwiftUI

/// A drawn, full-body "buddy" character with real anatomy and anchor slots, so
/// cosmetics actually sit ON it (a hat on the head, glasses over the eyes, a
/// shirt on the torso, something held in the hand) instead of floating around a
/// photo. Procedural (no art assets) and lightly animated — breathes, blinks,
/// and gives an occasional wave — so it reads as a living game character.
struct DressUpCharacter: View {
    /// Equipped cosmetics to wear.
    var items: [CosmeticItem] = []
    /// Body tint (future: player-customizable).
    var bodyColor: Color = AppColor.companionBody
    /// Overall width; height is derived.
    var size: CGFloat = 240
    var animated: Bool = true

    @State private var breathe = false
    @State private var blink = false
    @State private var wave = false

    private var H: CGFloat { size * 1.18 }

    private func item(_ c: CosmeticCategory) -> CosmeticItem? {
        items.first { $0.category == c }
    }

    var body: some View {
        ZStack {
            // Soft glow behind the buddy.
            Circle()
                .fill(RadialGradient(colors: [AppColor.companionGlow.opacity(0.5), .clear],
                                     center: .center, startRadius: 0, endRadius: size * 0.75))
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: 16)
                .scaleEffect(breathe ? 1.05 : 0.97)

            // ---- back-layer cosmetics ----
            if let v = item(.vehicle) { worn(v, y: 0.50, scale: 0.72) }
            if let b = item(.backpack) { worn(b, x: -0.34, y: 0.04, scale: 0.36, rotate: -8) }

            // ---- legs / feet ----
            HStack(spacing: size * 0.16) {
                foot; foot
            }
            .offset(y: size * 0.46)

            if let sh = item(.shoes) {
                HStack(spacing: size * 0.10) { wornRaw(sh, scale: 0.22); wornRaw(sh, scale: 0.22) }
                    .offset(y: size * 0.52)
            }

            // ---- arms (one waves) ----
            arm(left: true)
            arm(left: false)

            // ---- body ----
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(hex: "FFF3C4"), bodyColor, Color(hex: "F5921E")],
                        center: .init(x: 0.38, y: 0.32), startRadius: 2, endRadius: size * 0.5))
                    .frame(width: size * 0.78, height: size * 0.78)
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 2))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
                face
            }
            .offset(y: -size * 0.04)
            .scaleEffect(x: breathe ? 1.02 : 1.0, y: breathe ? 0.98 : 1.0, anchor: .bottom)

            // shirt sits on the lower torso
            if let s = item(.shirt) { worn(s, y: 0.16, scale: 0.46) }
            if let p = item(.pants) { worn(p, y: 0.34, scale: 0.40) }

            // ---- face-layer cosmetics ----
            if let g = item(.glasses) { worn(g, y: -0.10, scale: 0.42) }
            if let a = item(.accessory) { worn(a, x: 0.40, y: 0.10, scale: 0.26, rotate: -6) }
            if let h = item(.hat) { worn(h, y: -0.40, scale: 0.46) }
        }
        .frame(width: size, height: H)
        .onAppear { startIdle() }
    }

    // MARK: - Body parts

    private var foot: some View {
        Ellipse()
            .fill(bodyColor.opacity(0.95))
            .frame(width: size * 0.16, height: size * 0.10)
            .overlay(Ellipse().stroke(.white.opacity(0.2), lineWidth: 1))
    }

    private func arm(left: Bool) -> some View {
        Capsule()
            .fill(bodyColor)
            .frame(width: size * 0.10, height: size * 0.26)
            .rotationEffect(.degrees(left ? 24 : (wave ? -50 : -24)),
                            anchor: .top)
            .offset(x: (left ? -1 : 1) * size * 0.34, y: size * 0.04)
            .animation(.easeInOut(duration: 0.4), value: wave)
    }

    private var face: some View {
        ZStack {
            // eyes
            HStack(spacing: size * 0.16) {
                eye; eye
            }
            .offset(y: -size * 0.05)
            // blush
            HStack(spacing: size * 0.30) {
                blush; blush
            }
            .offset(y: size * 0.04)
            // smile
            SmileShape()
                .stroke(Color(hex: "1b1340"), style: StrokeStyle(lineWidth: size * 0.022, lineCap: .round))
                .frame(width: size * 0.22, height: size * 0.12)
                .offset(y: size * 0.10)
        }
    }

    private var eye: some View {
        ZStack {
            Capsule()
                .fill(Color(hex: "1b1340"))
                .frame(width: size * 0.07, height: blink ? size * 0.012 : size * 0.10)
            if !blink {
                Circle().fill(.white).frame(width: size * 0.022, height: size * 0.022)
                    .offset(x: size * 0.012, y: -size * 0.022)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: blink)
    }

    private var blush: some View {
        Ellipse().fill(Color(hex: "FF8FA3").opacity(0.55))
            .frame(width: size * 0.08, height: size * 0.05)
    }

    // MARK: - Cosmetic rendering

    /// A cosmetic worn at a body-relative anchor (offsets in units of `size`).
    @ViewBuilder
    private func worn(_ item: CosmeticItem, x: CGFloat = 0, y: CGFloat, scale: CGFloat, rotate: Double = 0) -> some View {
        wornRaw(item, scale: scale)
            .rotationEffect(.degrees(rotate))
            .offset(x: x * size, y: y * size)
    }

    @ViewBuilder
    private func wornRaw(_ item: CosmeticItem, scale: CGFloat) -> some View {
        let s = size * scale
        switch item.render {
        case .image(let name):
            Image(name).resizable().scaledToFit().frame(width: s, height: s)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        case .symbol(let sym):
            Image(systemName: sym)
                .font(.system(size: s * 0.72, weight: .semibold))
                .foregroundStyle(item.category == .glasses ? Color.black.opacity(0.82) : .primary)
                .frame(width: s, height: s)
        case .emoji(let e):
            Text(e).font(.system(size: s))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
    }

    // MARK: - Idle animation

    private func startIdle() {
        guard animated else { return }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { breathe = true }
        scheduleBlink()
        scheduleWave()
    }
    private func scheduleBlink() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2.5...5)) {
            blink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { blink = false }
            scheduleBlink()
        }
    }
    private func scheduleWave() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 4...8)) {
            wave = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { wave = false }
            scheduleWave()
        }
    }
}

/// A gentle upward smile arc.
private struct SmileShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY * 1.6))
        return p
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        DressUpCharacter(items: [], size: 240)
    }
}
