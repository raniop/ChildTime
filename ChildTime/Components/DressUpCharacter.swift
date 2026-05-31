import SwiftUI

/// A drawn, full-body "buddy" character with real anatomy and anchor slots, so
/// cosmetics actually sit ON it (a hat on the head, glasses over the eyes, a
/// shirt on the torso, something held in the hand) instead of floating around a
/// photo. Procedural (no art assets) and lightly animated — breathes, blinks,
/// and gives an occasional wave — so it reads as a living game character.
struct DressUpCharacter: View {
    /// Equipped cosmetics to wear.
    var items: [CosmeticItem] = []
    /// Body tint (player-customizable in the future).
    var bodyColor: Color = AppColor.companionBody
    /// Overall width; height is derived.
    var size: CGFloat = 240
    var animated: Bool = true

    @State private var breathe = false
    @State private var blink = false
    @State private var wave = false

    // Character canvas is size × size*1.35 (room for legs/feet + a hat).
    private var H: CGFloat { size * 1.35 }
    private var bodyW: CGFloat { size * 0.74 }
    private var bodyH: CGFloat { size * 0.92 }

    private func item(_ c: CosmeticCategory) -> CosmeticItem? { items.first { $0.category == c } }

    var body: some View {
        ZStack {
            // Soft glow.
            Circle()
                .fill(RadialGradient(colors: [AppColor.companionGlow.opacity(0.45), .clear],
                                     center: .center, startRadius: 0, endRadius: size * 0.7))
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: 16)
                .scaleEffect(breathe ? 1.04 : 0.98)

            // Back-layer cosmetics.
            if let v = item(.vehicle)  { worn(v, y: 0.46, scale: 0.74) }
            if let b = item(.backpack) { worn(b, x: -0.33, y: 0.02, scale: 0.36, rotate: -8) }

            legs
            arm(left: true)
            arm(left: false)

            // ---- body (egg-shaped: tapered head on top, round belly below) ----
            ZStack {
                EggShape()
                    .fill(RadialGradient(
                        colors: [Color(hex: "FFF6D8"), bodyColor, Color(hex: "EE8E1E")],
                        center: .init(x: 0.4, y: 0.32), startRadius: 4, endRadius: bodyH * 0.7))
                    .overlay(EggShape().stroke(.white.opacity(0.25), lineWidth: 2))
                    .frame(width: bodyW, height: bodyH)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
                face.offset(y: -bodyH * 0.16)
            }
            .offset(y: -size * 0.06)
            .scaleEffect(x: breathe ? 1.02 : 1.0, y: breathe ? 0.98 : 1.0, anchor: .bottom)

            // Torso cosmetics. The shirt is drawn as VECTOR so it fits the body
            // (an emoji shirt just floats); other items use their render.
            if let p = item(.pants) { worn(p, y: 0.20, scale: 0.40) }
            if item(.shirt) != nil { vectorShirt.offset(y: size * 0.10) }

            if let sh = item(.shoes) {
                HStack(spacing: size * 0.12) { wornRaw(sh, scale: 0.20); wornRaw(sh, scale: 0.20) }
                    .offset(y: size * 0.56)
            }

            // Face + head cosmetics.
            if let g = item(.glasses) { worn(g, y: -0.22, scale: 0.40) }
            if let a = item(.accessory) { worn(a, x: 0.40, y: 0.10, scale: 0.24, rotate: -6) }
            if let h = item(.hat) { worn(h, y: -0.52, scale: 0.40) }
        }
        .frame(width: size, height: H)
        .onAppear { startIdle() }
    }

    // MARK: - Limbs

    private var legs: some View {
        HStack(spacing: size * 0.10) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: -size * 0.01) {
                    Capsule().fill(bodyColor).frame(width: size * 0.12, height: size * 0.20)
                    Ellipse().fill(bodyColor)
                        .frame(width: size * 0.18, height: size * 0.10)
                        .overlay(Ellipse().stroke(.white.opacity(0.2), lineWidth: 1))
                }
            }
        }
        .offset(y: size * 0.42)
    }

    private func arm(left: Bool) -> some View {
        // Short, stubby arm that HANGS along the body. Shoulder tucks under the
        // body (arms draw behind it), so it reads as attached, not floating.
        VStack(spacing: -size * 0.012) {
            Capsule().fill(bodyColor).frame(width: size * 0.10, height: size * 0.17)
            Circle().fill(bodyColor).frame(width: size * 0.11, height: size * 0.11)   // hand
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
        }
        .rotationEffect(.degrees(left ? 12 : (wave ? -60 : -12)), anchor: .top)
        .offset(x: (left ? -1 : 1) * size * 0.30, y: size * 0.06)
        .animation(.easeInOut(duration: 0.4), value: wave)
    }

    /// A cohesive vector t-shirt (neckline, shoulders, short sleeves, body) that
    /// actually reads as worn — unlike a floating emoji or a blue blob.
    private var vectorShirt: some View {
        let w = size * 0.56
        let h = size * 0.34
        let c = Color(hex: "5AA9E6")
        return ShirtShape()
            .fill(LinearGradient(colors: [c, c.opacity(0.82)], startPoint: .top, endPoint: .bottom))
            .overlay(ShirtShape().stroke(.white.opacity(0.3), lineWidth: 1.5))
            .frame(width: w, height: h)
            .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
    }

    // MARK: - Face

    private var face: some View {
        ZStack {
            HStack(spacing: size * 0.15) { eye; eye }
            HStack(spacing: size * 0.32) { blush; blush }.offset(y: size * 0.07)
            SmileShape()
                .stroke(Color(hex: "1b1340"), style: StrokeStyle(lineWidth: size * 0.022, lineCap: .round))
                .frame(width: size * 0.22, height: size * 0.11)
                .offset(y: size * 0.13)
        }
    }

    private var eye: some View {
        ZStack {
            Capsule().fill(Color(hex: "1b1340"))
                .frame(width: size * 0.075, height: blink ? size * 0.012 : size * 0.105)
            if !blink {
                Circle().fill(.white).frame(width: size * 0.024, height: size * 0.024)
                    .offset(x: size * 0.013, y: -size * 0.024)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: blink)
    }

    private var blush: some View {
        Ellipse().fill(Color(hex: "FF8FA3").opacity(0.5))
            .frame(width: size * 0.085, height: size * 0.05)
    }

    // MARK: - Cosmetic rendering

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
        scheduleBlink(); scheduleWave()
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

/// A simple t-shirt silhouette: neckline dip, shoulders, short sleeves, body.
private struct ShirtShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * w, y: r.minY + y * h) }
        var path = Path()
        path.move(to: p(0.30, 0.04))                                   // left neck
        path.addQuadCurve(to: p(0.70, 0.04), control: p(0.50, 0.20))   // neckline dip
        path.addLine(to: p(0.80, 0.04))                                // right shoulder
        path.addLine(to: p(1.00, 0.30))                                // right sleeve tip
        path.addLine(to: p(0.82, 0.46))                                // right sleeve hem
        path.addLine(to: p(0.76, 0.38))                                // right armpit
        path.addLine(to: p(0.80, 1.00))                                // right body hem
        path.addLine(to: p(0.20, 1.00))                                // left body hem
        path.addLine(to: p(0.24, 0.38))                                // left armpit
        path.addLine(to: p(0.18, 0.46))                                // left sleeve hem
        path.addLine(to: p(0.00, 0.30))                                // left sleeve tip
        path.addLine(to: p(0.20, 0.04))                                // left shoulder
        path.closeSubpath()
        return path
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
        DressUpCharacter(size: 240)
    }
}
