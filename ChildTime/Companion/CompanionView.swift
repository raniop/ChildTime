import SwiftUI

struct CompanionView: View {
    var controller: CompanionController
    var size: CGFloat = 140

    @State private var float: CGFloat = 0
    @State private var blinkClosed: Bool = false
    @State private var spin: Double = 0

    var body: some View {
        ZStack {
            // Soft glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColor.companionGlow.opacity(0.7), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size
                    )
                )
                .frame(width: size * 1.8, height: size * 1.8)
                .blur(radius: 16)

            // Sparkles around
            if controller.state == .hype || controller.state == .wow {
                SparkleField(count: 12, size: 12)
                    .frame(width: size * 1.6, height: size * 1.6)
            }

            // Body
            spark
                .rotationEffect(.degrees(spin))
                .scaleEffect(currentScale)
                .offset(y: float)
        }
        .frame(width: size * 1.8, height: size * 1.8)
        .onAppear {
            startFloat()
            startBlinkLoop()
        }
        .onChange(of: controller.state) { _, new in
            handleStateChange(new)
        }
    }

    private var spark: some View {
        ZStack {
            // Main body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "FFE082"), AppColor.companionBody, Color(hex: "FF9F1C")],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: size * 0.05,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 2)
                        .blur(radius: 1)
                )

            // Cheek blush
            HStack(spacing: size * 0.4) {
                Circle().fill(Color(hex: "FF8B94").opacity(0.45))
                    .frame(width: size * 0.15, height: size * 0.15)
                    .blur(radius: 2)
                Circle().fill(Color(hex: "FF8B94").opacity(0.45))
                    .frame(width: size * 0.15, height: size * 0.15)
                    .blur(radius: 2)
            }
            .offset(y: size * 0.12)

            // Eyes
            HStack(spacing: size * 0.18) {
                eye
                eye
            }
            .offset(y: -size * 0.05)

            // Mouth
            mouth
                .offset(y: size * 0.18)
        }
    }

    private var eye: some View {
        ZStack {
            Capsule()
                .fill(Color(hex: "2B2D42"))
                .frame(
                    width: size * 0.13,
                    height: blinkClosed ? 2 : eyeHeight
                )
                .animation(.easeInOut(duration: 0.08), value: blinkClosed)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: eyeHeight)
            if !blinkClosed && eyeHeight > size * 0.1 {
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.04, height: size * 0.04)
                    .offset(x: size * 0.025, y: -size * 0.04)
            }
        }
    }

    private var eyeHeight: CGFloat {
        switch controller.state {
        case .wow: return size * 0.22
        case .console, .sleep: return size * 0.08
        default: return size * 0.16
        }
    }

    private var mouth: some View {
        Group {
            switch controller.state {
            case .wow:
                Circle()
                    .fill(Color(hex: "2B2D42"))
                    .frame(width: size * 0.12, height: size * 0.12)
            case .console:
                MouthShape(curveUp: false)
                    .stroke(Color(hex: "2B2D42"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size * 0.2, height: size * 0.08)
            default:
                MouthShape(curveUp: true)
                    .stroke(Color(hex: "2B2D42"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size * 0.22, height: size * 0.08)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: controller.state)
    }

    private var currentScale: CGFloat {
        switch controller.state {
        case .cheer: return 1.12
        case .hype: return 1.06
        case .wow: return 1.2
        case .console: return 0.96
        case .sleep: return 0.92
        case .idle: return 1.0
        }
    }

    // MARK: - Animation triggers

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
                try? await Task.sleep(nanoseconds: 130_000_000)
                blinkClosed = false
            }
        }
    }

    private func handleStateChange(_ new: CompanionState) {
        switch new {
        case .cheer:
            withAnimation(Motion.bouncy) {
                float = -20
            }
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
            withAnimation(Motion.bouncy) {
                float = -16
            }
        case .console:
            withAnimation(Motion.gentle) {
                float = 4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(Motion.gentle) { float = -6 }
            }
        default:
            break
        }
    }
}

private struct MouthShape: Shape {
    /// `curveUp == true` produces a smile (corners up, middle dips down).
    /// `curveUp == false` produces a frown (corners down, middle bulges up).
    var curveUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if curveUp {
            // Smile in SwiftUI's y-down coords: start/end at y=0 (top), control below
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: 0),
                control: CGPoint(x: rect.width / 2, y: rect.height * 2)
            )
        } else {
            // Frown: start/end at y=height (bottom), control above
            path.move(to: CGPoint(x: 0, y: rect.height))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: rect.height),
                control: CGPoint(x: rect.width / 2, y: -rect.height)
            )
        }
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
                        Button("cheer")   { c.cheer("יש!") }
                        Button("hype")    { c.hype("🔥 אש!") }
                        Button("wow")     { c.wow("וואו! פורטל!") }
                        Button("console") { c.console("כמעט!") }
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
