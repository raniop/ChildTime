import SwiftUI
import CoreMotion
import Combine

/// 🫙 A LIVE jar (Rani, 2026-10-24: "חייבים לעשות אותה חיה עם כאילו מים זזים
/// לפי תזוזת המכשיר"). The liquid keeps level with the real world as the
/// device tilts, sloshes past it and settles like a spring, waves harder when
/// shaken, and bubbles rise through it. No motion sensor (the simulator) → a
/// gentle sway, so it never looks frozen.
struct FamilyJar: View {
    /// A full jar fills this much of the glass — the last mark sits below the rim.
    static let headroom = 0.82
    let fill: Double
    /// Marks on the glass, as fractions of a full jar.
    var stages: [Double] = []
    @StateObject private var slosh = JarSlosh()

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height, lid: CGFloat = 18
            ZStack(alignment: .top) {
                Canvas { ctx, size in draw(&ctx, size) }
                    .frame(width: w, height: h - lid)
                    .offset(y: lid)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "D9A06C"), Color(hex: "A86E43")], startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.62, height: 16)
            }
        }
        .onAppear { slosh.start() }
        .onDisappear { slosh.stop() }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        let shape = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 16, style: .continuous)
        ctx.fill(shape, with: .color(.white.opacity(0.12)))
        ctx.clip(to: shape)

        let level = h * (1 - min(fill, 1) * Self.headroom)   // the surface at the jar's middle
        let slope = tan(slosh.angle)
        let amp = 2.2 + 7 * slosh.energy
        func surface(_ x: CGFloat, _ shift: Double) -> CGFloat {
            level - CGFloat(slope) * (x - w / 2)
                + CGFloat(amp * sin(Double(x) / Double(w) * 2 * .pi * 1.3 + slosh.phase + shift))
        }
        func liquid(_ shift: Double) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: h))
            var x: CGFloat = 0
            while x <= w { p.addLine(to: CGPoint(x: x, y: surface(x, shift))); x += 2 }
            p.addLine(to: CGPoint(x: w, y: surface(w, shift)))
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
            return p
        }
        guard fill > 0.005 else {
            ctx.stroke(shape, with: .color(.white.opacity(0.75)), lineWidth: 2.5)
            for f in stages {
                let y = h * (1 - f * Self.headroom)
                var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: w, y: y))
                ctx.stroke(line, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            }
            return
        }
        // Back wave (lighter, out of step) then the front one.
        ctx.fill(liquid(2.1), with: .color(Color(hex: "FFC56B").opacity(0.55)))
        ctx.fill(liquid(0), with: .linearGradient(
            Gradient(colors: [Color(hex: "FFD66B"), Color(hex: "FF9F43")]),
            startPoint: CGPoint(x: 0, y: level - 10), endPoint: CGPoint(x: 0, y: h)))

        // Bubbles rising through the liquid only.
        for b in JarSlosh.bubbles {
            let x = w * b.x
            let top = surface(x, 0) + 6
            let travel = h - top
            guard travel > 10 else { continue }
            let y = h - CGFloat((slosh.time * b.speed + b.seed).truncatingRemainder(dividingBy: 1)) * travel
            let wobble = CGFloat(sin(slosh.time * 3 + b.seed * 9)) * 2
            let r = b.size
            ctx.stroke(Path(ellipseIn: CGRect(x: x + wobble - r, y: y - r, width: 2 * r, height: 2 * r)),
                       with: .color(.white.opacity(0.75)), lineWidth: 1.2)
        }

        // Two stars riding the waves.
        for (fx, shift) in [(0.32, 0.0), (0.7, 1.4)] {
            let x = w * fx
            let star = ctx.resolve(Text(verbatim: "⭐").font(.system(size: 14)))
            ctx.draw(star, at: CGPoint(x: x, y: surface(x, 0) - 2 + CGFloat(sin(slosh.phase + shift)) * 1.5))
        }

        // The stage marks, painted on the glass over the liquid.
        for f in stages {
            let y = h * (1 - f * Self.headroom)
            var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: w, y: y))
            ctx.stroke(line, with: .color(.white.opacity(f <= fill ? 0.55 : 0.85)),
                       style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        }

        // Glass: a highlight and the rim.
        ctx.fill(Path(roundedRect: CGRect(x: w * 0.12, y: h * 0.1, width: 6, height: h * 0.6), cornerRadius: 3),
                 with: .color(.white.opacity(0.28)))
        ctx.stroke(shape, with: .color(.white.opacity(0.75)), lineWidth: 2.5)
    }
}

/// The liquid's physics: a damped spring toward "level with the world".
final class JarSlosh: ObservableObject {
    struct Bubble { let x: CGFloat; let speed: Double; let seed: Double; let size: CGFloat }
    static let bubbles: [Bubble] = [
        Bubble(x: 0.22, speed: 0.32, seed: 0.10, size: 3), Bubble(x: 0.45, speed: 0.24, seed: 0.55, size: 2.2),
        Bubble(x: 0.63, speed: 0.38, seed: 0.30, size: 3.4), Bubble(x: 0.80, speed: 0.28, seed: 0.85, size: 2.4),
        Bubble(x: 0.35, speed: 0.42, seed: 0.70, size: 1.8), Bubble(x: 0.55, speed: 0.30, seed: 0.05, size: 2.8),
    ]
    @Published private(set) var angle = 0.0     // surface tilt on screen, radians
    private(set) var energy = 0.0               // 0…1, how hard it is waving
    private(set) var phase = 0.0
    private(set) var time = 0.0
    private var velocity = 0.0
    private let motion = CMMotionManager()
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 60
            motion.startDeviceMotionUpdates()
        }
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate(); timer = nil
        motion.stopDeviceMotionUpdates()
    }

    private func step() {
        let dt = 1.0 / 60
        time += dt
        var target: Double
        var shake = 0.0
        if let m = motion.deviceMotion {
            // Device rolled clockwise by θ → the world's level reads as θ on screen.
            target = atan2(m.gravity.x, -m.gravity.y)
            let a = m.userAcceleration
            shake = min(1, sqrt(a.x * a.x + a.y * a.y + a.z * a.z) * 1.5)
        } else {
            target = 0.3 * sin(time * 1.1) + 0.12 * sin(time * 2.7)   // simulator: a gentle sway
        }
        target = max(-0.55, min(0.55, target))
        // Underdamped spring: it overshoots the level a little, then settles.
        velocity += ((target - angle) * 55 - velocity * 3.2) * dt
        let next = angle + velocity * dt
        energy = max(energy * 0.97, min(1, abs(velocity) * 0.35 + shake))
        phase += dt * (2.0 + energy * 7)
        angle = next
    }
}

