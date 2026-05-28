import SwiftUI

// MARK: - .float()  — gentle continuous up/down

struct FloatModifier: ViewModifier {
    var amplitude: CGFloat = 4
    @State private var phase: Bool = false

    func body(content: Content) -> some View {
        content
            .offset(y: phase ? -amplitude : amplitude)
            .animation(Motion.float, value: phase)
            .onAppear { phase.toggle() }
    }
}

extension View {
    func float(amplitude: CGFloat = 4) -> some View {
        modifier(FloatModifier(amplitude: amplitude))
    }
}

// MARK: - .pulse()  — opacity breathing

struct PulseModifier: ViewModifier {
    var min: Double = 0.6
    @State private var phase: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(phase ? 1.0 : min)
            .animation(Motion.pulse, value: phase)
            .onAppear { phase.toggle() }
    }
}

extension View {
    func pulse(min: Double = 0.6) -> some View {
        modifier(PulseModifier(min: min))
    }
}

// MARK: - .glow(color:)

struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: radius)
            .shadow(color: color.opacity(0.4), radius: radius / 2)
    }
}

extension View {
    func glow(_ color: Color, radius: CGFloat = 20) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - .shimmer()  — light sweep across surface

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width)
                }
                .mask(content)
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(Motion.shimmer) {
                    phase = 2
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - .rumble(trigger:)  — small shake animation

struct RumbleModifier: ViewModifier {
    var trigger: Int
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, _ in
                withAnimation(.easeInOut(duration: 0.05).repeatCount(6, autoreverses: true)) {
                    offset = 3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        offset = 0
                    }
                }
            }
    }
}

extension View {
    func rumble(trigger: Int) -> some View {
        modifier(RumbleModifier(trigger: trigger))
    }
}

// MARK: - JuicyPressStyle — tap → squish → snap

struct JuicyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == JuicyPressStyle {
    static var juicy: JuicyPressStyle { JuicyPressStyle() }
}
