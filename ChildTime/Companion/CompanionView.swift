import SwiftUI

struct CompanionView: View {
    var controller: CompanionController
    var size: CGFloat = 140

    @State private var float: CGFloat = 0
    @State private var blinkClosed: Bool = false
    @State private var spin: Double = 0
    @State private var breathe: Bool = false
    @State private var ambientOrbit: Double = 0
    @State private var magicStarBounce: Bool = false

    var body: some View {
        ZStack {
            // 1. Outer breathing halo (always)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColor.companionGlow.opacity(0.55), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.95
                    )
                )
                .frame(width: size * 2.1, height: size * 2.1)
                .blur(radius: 18)
                .scaleEffect(breathe ? 1.08 : 0.94)

            // 2. Ambient orbiting sparkles (always on, subtle)
            ambientSparkles

            // 3. Big sparkle field for excited states
            if controller.state == .hype || controller.state == .wow {
                SparkleField(count: 14, size: 14)
                    .frame(width: size * 1.6, height: size * 1.6)
            }

            // 4. Magic accent star floating above the head
            magicAccent

            // 5. Body
            spark
                .rotationEffect(.degrees(spin))
                .scaleEffect(currentScale)
                .offset(y: float)
        }
        .frame(width: size * 1.8, height: size * 1.8)
        .onAppear {
            startFloat()
            startBlinkLoop()
            startBreathing()
            startAmbientOrbit()
            startMagicStarBounce()
        }
        .onChange(of: controller.state) { _, new in
            handleStateChange(new)
        }
    }

    // MARK: - Body composition

    private var spark: some View {
        ZStack {
            // Main body — radial gradient with rich depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "FFF3C4"),   // bright cream highlight
                            Color(hex: "FFE082"),
                            AppColor.companionBody,
                            Color(hex: "FF9F1C"),
                            Color(hex: "E07A0F")    // darker edge
                        ],
                        center: UnitPoint(x: 0.32, y: 0.30),
                        startRadius: size * 0.05,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    // Inner soft ring for that "fluffy" feeling
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 3)
                        .blur(radius: 1.5)
                )

            // Top-left primary shine
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.7), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.18
                    )
                )
                .frame(width: size * 0.36, height: size * 0.36)
                .offset(x: -size * 0.21, y: -size * 0.22)
                .blur(radius: 2)

            // Cheek blush — more prominent
            HStack(spacing: size * 0.42) {
                Circle()
                    .fill(Color(hex: "FF8B94").opacity(0.55))
                    .frame(width: size * 0.18, height: size * 0.13)
                    .blur(radius: 2.5)
                Circle()
                    .fill(Color(hex: "FF8B94").opacity(0.55))
                    .frame(width: size * 0.18, height: size * 0.13)
                    .blur(radius: 2.5)
            }
            .offset(y: size * 0.12)

            // Eyes
            HStack(spacing: size * 0.24) {
                eye
                eye
            }
            .offset(y: -size * 0.05)

            // Mouth
            mouth
                .offset(y: size * 0.17)
        }
    }

    // MARK: - Eyes (anime-style with double highlight)

    private var eye: some View {
        ZStack {
            // Pupil — big, soft black
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "2B2D42"), Color(hex: "0F1020")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(
                    width: size * 0.20,
                    height: blinkClosed ? 3 : eyeHeight
                )
                .animation(.easeInOut(duration: 0.08), value: blinkClosed)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: eyeHeight)

            if !blinkClosed && eyeHeight > size * 0.1 {
                // Primary highlight (large, top-right)
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.072, height: size * 0.072)
                    .offset(x: size * 0.04, y: -size * 0.045)

                // Secondary highlight (smaller, bottom-left)
                Circle()
                    .fill(.white.opacity(0.75))
                    .frame(width: size * 0.035, height: size * 0.035)
                    .offset(x: -size * 0.035, y: size * 0.04)

                // Tiny glint
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: size * 0.018, height: size * 0.018)
                    .offset(x: -size * 0.005, y: -size * 0.025)
            }
        }
    }

    private var eyeHeight: CGFloat {
        switch controller.state {
        case .wow: return size * 0.27
        case .console, .sleep: return size * 0.10
        case .cheer, .hype: return size * 0.22
        default: return size * 0.20
        }
    }

    // MARK: - Mouth

    private var mouth: some View {
        Group {
            switch controller.state {
            case .wow:
                // Open round "O" of surprise with tongue hint
                ZStack {
                    Capsule()
                        .fill(Color(hex: "1A1A2E"))
                        .frame(width: size * 0.18, height: size * 0.14)
                    Circle()
                        .fill(Color(hex: "FF6B6B"))
                        .frame(width: size * 0.10, height: size * 0.05)
                        .offset(y: size * 0.03)
                }
            case .cheer, .hype:
                // Big open happy smile with tongue
                ZStack {
                    OpenSmileShape()
                        .fill(Color(hex: "1A1A2E"))
                        .frame(width: size * 0.32, height: size * 0.18)
                    Circle()
                        .fill(Color(hex: "FF6B6B"))
                        .frame(width: size * 0.14, height: size * 0.07)
                        .offset(y: size * 0.04)
                        .mask(
                            OpenSmileShape()
                                .frame(width: size * 0.32, height: size * 0.18)
                        )
                }
            case .console:
                // Soft frown
                MouthCurve(curveUp: false)
                    .stroke(Color(hex: "1A1A2E"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: size * 0.22, height: size * 0.08)
            case .sleep:
                // Tiny line, mostly closed
                Capsule()
                    .fill(Color(hex: "1A1A2E"))
                    .frame(width: size * 0.10, height: 3)
            case .idle:
                // Closed-mouth smile
                MouthCurve(curveUp: true)
                    .stroke(Color(hex: "1A1A2E"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: size * 0.26, height: size * 0.09)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: controller.state)
    }

    // MARK: - Ambient sparkles (always orbiting)

    private var ambientSparkles: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                let baseAngle = Double(i) * (.pi * 2 / 5)
                let angle = baseAngle + ambientOrbit
                let radius = size * 0.78
                Image(systemName: "sparkle")
                    .font(.system(size: 10 + CGFloat(i % 2) * 4))
                    .foregroundStyle(
                        [AppColor.starGold, AppColor.companionGlow, .white]
                            .randomElement() ?? AppColor.starGold
                    )
                    .offset(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius * 0.6
                    )
                    .opacity(0.85)
            }
        }
    }

    // MARK: - Magic accent (sparkle floating above head)

    private var magicAccent: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(AppColor.starGold)
            .glow(AppColor.starGold, radius: 6)
            .scaleEffect(magicStarBounce ? 1.25 : 0.9)
            .offset(y: -size * 0.62 + (magicStarBounce ? -4 : 4))
    }

    // MARK: - Scale

    private var currentScale: CGFloat {
        switch controller.state {
        case .cheer: return 1.14
        case .hype: return 1.08
        case .wow: return 1.22
        case .console: return 0.95
        case .sleep: return 0.92
        case .idle: return 1.0
        }
    }

    // MARK: - Loops

    private func startFloat() {
        withAnimation(Motion.float) {
            float = -6
        }
    }

    private func startBlinkLoop() {
        Task {
            while !Task.isCancelled {
                let pause = Double.random(in: 3...5)
                try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
                blinkClosed = true
                try? await Task.sleep(nanoseconds: 140_000_000)
                blinkClosed = false
            }
        }
    }

    private func startBreathing() {
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            breathe = true
        }
    }

    private func startAmbientOrbit() {
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            ambientOrbit = .pi * 2
        }
    }

    private func startMagicStarBounce() {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            magicStarBounce = true
        }
    }

    // MARK: - State transitions

    private func handleStateChange(_ new: CompanionState) {
        switch new {
        case .cheer:
            withAnimation(Motion.bouncy) { float = -22 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(Motion.bouncy) { float = -6 }
            }
        case .hype:
            withAnimation(.linear(duration: 0.3).repeatCount(3)) {
                spin = 360
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                spin = 0
            }
        case .wow:
            withAnimation(Motion.bouncy) { float = -18 }
        case .console:
            withAnimation(Motion.gentle) { float = 4 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(Motion.gentle) { float = -6 }
            }
        default:
            break
        }
    }
}

// MARK: - Shapes

private struct MouthCurve: Shape {
    /// `curveUp == true` produces a smile (corners up, middle dips down).
    var curveUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if curveUp {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: 0),
                control: CGPoint(x: rect.width / 2, y: rect.height * 2)
            )
        } else {
            path.move(to: CGPoint(x: 0, y: rect.height))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: rect.height),
                control: CGPoint(x: rect.width / 2, y: -rect.height)
            )
        }
        return path
    }
}

/// A wider open smile that looks like a happy mouth with curved bottom lip.
private struct OpenSmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = rect.height * 0.5
        path.move(to: CGPoint(x: 0, y: r))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: r),
            control: CGPoint(x: rect.width / 2, y: -r * 0.6)
        )
        path.addQuadCurve(
            to: CGPoint(x: 0, y: r),
            control: CGPoint(x: rect.width / 2, y: rect.height * 1.5)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    struct DemoWrapper: View {
        @State var c = CompanionController()
        var body: some View {
            ZStack {
                AppGradient.dreamy.ignoresSafeArea()
                VStack(spacing: 24) {
                    CompanionView(controller: c)
                    if let text = c.bubbleText {
                        BubbleSpeech(text: text)
                    }
                    Spacer()
                    HStack {
                        Button("idle")    { c.state = .idle; c.bubbleText = nil }
                        Button("cheer")   { c.cheer("יֵשׁ!") }
                        Button("hype")    { c.hype("🔥 אֵשׁ!") }
                        Button("wow")     { c.wow("וָואוּ!") }
                        Button("console") { c.console("כִּמְעַט!") }
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
                .padding()
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
    return DemoWrapper()
}
