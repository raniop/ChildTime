import SwiftUI

enum ChestStage: Equatable {
    case closed
    case glowing       // pulsing, "tap to open"
    case opening       // shake + crack
    case revealed
}

/// A juicy, kid-delighting treasure chest. Builds anticipation while glowing
/// (bobbing, rocking, breathing glow, rotating god-rays, orbiting sparkles),
/// then erupts on open with a white flash, an expanding shockwave, and a burst
/// of stars + confetti flying outward. The whole reward "lands" with a big
/// bouncy pop. Public API is unchanged (kind, stage, size).
struct ChestView: View {
    let kind: ChestKind
    let stage: ChestStage
    let size: CGFloat

    @State private var shake: CGFloat = 0
    @State private var glowScale: CGFloat = 1
    @State private var bob: CGFloat = 0
    @State private var rock: Double = 0
    @State private var rayRotation: Double = 0
    @State private var pop: CGFloat = 1
    @State private var flash: Double = 0
    @State private var ringTrigger: Int = 0
    @State private var burstTrigger: Int = 0
    @State private var orbit: Double = 0

    private var active: Bool { stage != .closed }

    var body: some View {
        ZStack {
            // 1. Rotating god-rays behind everything.
            rays
                .opacity(active ? (stage == .revealed ? 0.9 : 0.6) : 0)
                .animation(.easeInOut(duration: 0.5), value: active)

            // 2. Soft breathing glow blob.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(0.75), .clear],
                        center: .center, startRadius: 0, endRadius: size * 1.2)
                )
                .frame(width: size * 2.4, height: size * 2.4)
                .blur(radius: 24)
                .scaleEffect(glowScale)
                .opacity(stage == .closed ? 0.5 : 1.0)

            // 3. Expanding shockwave rings (fire on open).
            shockwave

            // 4. Orbiting sparkles around the chest.
            if active { orbitingSparkles }

            // 5. The chest itself — a drawn treasure chest whose lid lifts open.
            //    Bobbing + rocking while glowing, then a bouncy pop.
            TreasureChest(palette: palette,
                          open: stage == .opening || stage == .revealed,
                          size: size)
                .shadow(color: glowColor.opacity(0.6), radius: 12, y: 6)
                .offset(x: shake, y: bob)
                .rotationEffect(.degrees(rock))
                .scaleEffect(pop)

            // 6. Bright flash at the moment of opening.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, .white.opacity(0)],
                        center: .center, startRadius: 0, endRadius: size * 1.3)
                )
                .frame(width: size * 2.6, height: size * 2.6)
                .scaleEffect(0.4 + flash * 1.2)
                .opacity(flash)
                .allowsHitTesting(false)

            // 7. Particle explosion (stars + confetti) flying outward.
            ChestBurst(trigger: burstTrigger, color: glowColor, size: size)
                .allowsHitTesting(false)
        }
        .frame(width: size * 2.6, height: size * 2.6)
        .onAppear {
            startRayLoop()
            startOrbitLoop()
            startStageAnimation()
        }
        .onChange(of: stage) { _, _ in startStageAnimation() }
    }

    // MARK: - Layers

    private var rays: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [glowColor.opacity(0), glowColor.opacity(0.55)],
                            startPoint: .bottom, endPoint: .top)
                    )
                    .frame(width: size * 0.12, height: size * 1.5)
                    .offset(y: -size * 0.78)
                    .rotationEffect(.degrees(Double(i) / 12 * 360))
            }
        }
        .frame(width: size * 2.6, height: size * 2.6)
        .rotationEffect(.degrees(rayRotation))
        .blur(radius: 1.5)
    }

    private var shockwave: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                ShockwaveRing(trigger: ringTrigger, delay: Double(i) * 0.12,
                              color: glowColor, baseSize: size)
            }
        }
    }

    private var orbitingSparkles: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let a = orbit + Double(i) / 4 * 360
                Image(systemName: "sparkle")
                    .font(.system(size: size * (i % 2 == 0 ? 0.16 : 0.11)))
                    .foregroundStyle(i % 2 == 0 ? AppColor.starGold : .white)
                    .offset(x: cos(a * .pi / 180) * size * 0.95,
                            y: sin(a * .pi / 180) * size * 0.78)
                    .opacity(0.9)
            }
        }
    }

    private var glowColor: Color {
        switch kind {
        case .wood: return AppColor.companionGlow
        case .gold: return AppColor.starGold
        case .magic: return AppColor.gemPurple
        case .legendary: return Color(hex: "FF6B9D")
        }
    }

    private var palette: ChestPalette {
        switch kind {
        case .wood:
            return ChestPalette(bodyTop: Color(hex: "A9743F"), bodyBottom: Color(hex: "6E4621"),
                                metal: Color(hex: "FFD23F"), metalDark: Color(hex: "C9961F"),
                                glow: AppColor.companionGlow)
        case .gold:
            return ChestPalette(bodyTop: Color(hex: "FFDE7A"), bodyBottom: Color(hex: "E0A82E"),
                                metal: Color(hex: "FFF3C4"), metalDark: Color(hex: "C9961F"),
                                glow: AppColor.starGold)
        case .magic:
            return ChestPalette(bodyTop: Color(hex: "8B6BE6"), bodyBottom: Color(hex: "4B2E9E"),
                                metal: Color(hex: "E7C9FF"), metalDark: Color(hex: "8E5BD0"),
                                glow: AppColor.gemPurple)
        case .legendary:
            return ChestPalette(bodyTop: Color(hex: "FF8FB4"), bodyBottom: Color(hex: "C03A6E"),
                                metal: Color(hex: "FFE08A"), metalDark: Color(hex: "D98BA6"),
                                glow: Color(hex: "FF6B9D"))
        }
    }

    // MARK: - Animation

    private func startRayLoop() {
        withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
            rayRotation = 360
        }
    }

    private func startOrbitLoop() {
        withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
            orbit = 360
        }
    }

    private func startStageAnimation() {
        switch stage {
        case .closed:
            shake = 0; glowScale = 1; bob = 0; rock = 0; pop = 1; flash = 0

        case .glowing:
            // Eager anticipation: breathe the glow, bob up and down, gently rock.
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glowScale = 1.18
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                bob = -size * 0.06
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                rock = 5
            }

        case .opening:
            // Stop the idle bob/rock, shiver hard, then flash + shockwave + burst.
            bob = 0; rock = 0
            withAnimation(.easeInOut(duration: 0.05).repeatCount(8, autoreverses: true)) {
                shake = 6
            }
            // Anticipation squash before the pop.
            withAnimation(.easeIn(duration: 0.28)) { pop = 0.82 }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                shake = 0
                ringTrigger += 1
                burstTrigger += 1
                // White flash blooms and fades.
                flash = 0.95
                withAnimation(.easeOut(duration: 0.45)) { flash = 0 }
                // Big bouncy pop.
                withAnimation(.spring(response: 0.45, dampingFraction: 0.45)) { pop = 1.25 }
            }

        case .revealed:
            shake = 0
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { pop = 1.12 }
            // Keep a gentle living bob after it's open.
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                bob = -size * 0.04
            }
        }
    }
}

// MARK: - Shockwave ring

private struct ShockwaveRing: View {
    let trigger: Int
    let delay: Double
    let color: Color
    let baseSize: CGFloat

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .stroke(color.opacity(0.9), lineWidth: 5)
            .frame(width: baseSize * 1.4, height: baseSize * 1.4)
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: trigger) { _, _ in
                scale = 0.3
                opacity = 0.85
                withAnimation(.easeOut(duration: 0.8).delay(delay)) {
                    scale = 2.4
                    opacity = 0
                }
            }
    }
}

// MARK: - Particle burst (stars + confetti)

private struct ChestBurst: View {
    let trigger: Int
    let color: Color
    let size: CGFloat

    private let glyphs = ["⭐️", "✨", "🎉", "💫", "🌟"]

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                BurstParticle(
                    index: i,
                    glyph: glyphs[i % glyphs.count],
                    color: color,
                    spread: size * 1.5,
                    trigger: trigger
                )
            }
        }
    }
}

private struct BurstParticle: View {
    let index: Int
    let glyph: String
    let color: Color
    let spread: CGFloat
    let trigger: Int

    @State private var t: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var spin: Double = 0

    var body: some View {
        // Deterministic-ish per-particle variation so the burst feels organic.
        let angle = (Double(index) / 16.0) * .pi * 2 + Double(index % 3) * 0.2
        let distance = spread * (0.7 + CGFloat(index % 4) * 0.12)
        return Text(glyph)
            .font(.system(size: 22 + CGFloat(index % 3) * 8))
            .rotationEffect(.degrees(spin))
            .offset(x: cos(angle) * distance * t,
                    y: sin(angle) * distance * t - (t * 18))  // slight upward drift
            .scaleEffect(0.4 + t * 0.9)
            .opacity(opacity)
            .onChange(of: trigger) { _, _ in
                t = 0; opacity = 1; spin = 0
                withAnimation(.easeOut(duration: 0.9)) {
                    t = 1
                    spin = Double((index % 2 == 0) ? 220 : -220)
                }
                withAnimation(.easeIn(duration: 0.9).delay(0.45)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Drawn treasure chest

struct ChestPalette {
    let bodyTop: Color
    let bodyBottom: Color
    let metal: Color
    let metalDark: Color
    let glow: Color
}

/// A classic treasure chest drawn with shapes (wood body, metal bands, a gold
/// lock, gems) whose domed lid lifts open. Themed by `palette` so wood / gold /
/// magic / legendary chests each look distinct.
struct TreasureChest: View {
    let palette: ChestPalette
    let open: Bool
    let size: CGFloat

    var body: some View {
        let s = size
        let bodyH = s * 0.5
        let lidH = s * 0.34
        let w = s * 0.92

        ZStack {
            // Glow + treasure spilling out of the open chest.
            if open {
                Ellipse()
                    .fill(RadialGradient(
                        colors: [.white, palette.metal.opacity(0.0)],
                        center: .center, startRadius: 0, endRadius: w * 0.5))
                    .frame(width: w * 0.95, height: bodyH * 1.1)
                    .offset(y: -bodyH * 0.55)
                    .blur(radius: 1)
                gems(width: w, bodyH: bodyH)
                    .offset(y: -bodyH * 0.5)
            }

            // Chest body.
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.07, style: .continuous)
                    .fill(LinearGradient(colors: [palette.bodyTop, palette.bodyBottom],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: s * 0.07, style: .continuous)
                            .stroke(palette.metalDark.opacity(0.5), lineWidth: s * 0.015)
                    )
                // Vertical wood seams.
                HStack(spacing: w * 0.28) {
                    ForEach(0..<2, id: \.self) { _ in
                        Rectangle().fill(palette.bodyBottom.opacity(0.35)).frame(width: s * 0.012)
                    }
                }
                // Center metal strap + lock.
                Rectangle()
                    .fill(LinearGradient(colors: [palette.metal, palette.metalDark],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: s * 0.12)
                lock(s: s)
            }
            .frame(width: w, height: bodyH)
            .offset(y: s * 0.18)

            // Domed lid, hinged at its bottom edge so it swings open.
            ZStack {
                ChestLidShape()
                    .fill(LinearGradient(colors: [palette.bodyTop, palette.bodyBottom],
                                         startPoint: .top, endPoint: .bottom))
                ChestLidShape()
                    .stroke(palette.metalDark.opacity(0.5), lineWidth: s * 0.015)
                // Metal rim along the lid base + center strap.
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(LinearGradient(colors: [palette.metal, palette.metalDark],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: s * 0.07)
                }
                Rectangle()
                    .fill(LinearGradient(colors: [palette.metal, palette.metalDark],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: s * 0.12)
            }
            .frame(width: w, height: lidH)
            .offset(y: s * 0.18 - bodyH * 0.5 - lidH * 0.5 + s * 0.02)
            .rotation3DEffect(.degrees(open ? -118 : 0),
                              axis: (x: 1, y: 0, z: 0),
                              anchor: .bottom, anchorZ: 0, perspective: 0.6)
        }
        .frame(width: s, height: s)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: open)
    }

    private func lock(s: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.02, style: .continuous)
                .fill(LinearGradient(colors: [palette.metal, palette.metalDark],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.16, height: s * 0.14)
                .overlay(
                    RoundedRectangle(cornerRadius: s * 0.02)
                        .stroke(.black.opacity(0.18), lineWidth: 1)
                )
            // Keyhole.
            Circle().fill(.black.opacity(0.55)).frame(width: s * 0.04, height: s * 0.04)
                .offset(y: -s * 0.01)
        }
    }

    private func gems(width w: CGFloat, bodyH: CGFloat) -> some View {
        HStack(spacing: w * 0.06) {
            gem(Color(hex: "06D6A0"), w * 0.12)
            gem(Color(hex: "FF5C8A"), w * 0.15).offset(y: -bodyH * 0.06)
            gem(Color(hex: "48BFE3"), w * 0.11)
        }
    }

    private func gem(_ c: Color, _ d: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [.white, c],
                                 center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: d))
            .frame(width: d, height: d)
            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
            .shadow(color: c.opacity(0.6), radius: 4)
    }
}

/// A rectangle with a rounded (domed) top — the chest lid.
struct ChestLidShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let radius = min(r.width * 0.5, r.height)
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        p.addQuadCurve(to: CGPoint(x: r.minX + radius, y: r.minY),
                       control: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + radius),
                       control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    struct DemoChest: View {
        @State private var stage: ChestStage = .glowing
        var body: some View {
            ZStack {
                AppGradient.dreamy.ignoresSafeArea()
                VStack(spacing: 40) {
                    ChestView(kind: .gold, stage: stage, size: 160)
                    Button("פתח") {
                        stage = .opening
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { stage = .revealed }
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
    return DemoChest()
}
