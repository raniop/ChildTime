import SwiftUI

struct Sparkle: View {
    var size: CGFloat = 16
    var color: Color = AppColor.starGold
    @State private var phase: Bool = false

    var body: some View {
        Image(systemName: "sparkle")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
            .rotationEffect(.degrees(phase ? 0 : 30))
            .opacity(phase ? 0.4 : 1)
            .scaleEffect(phase ? 0.7 : 1.1)
            .animation(Motion.pulse, value: phase)
            .onAppear { phase.toggle() }
    }
}

struct SparkleField: View {
    var count: Int = 8
    var size: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<count, id: \.self) { i in
                Sparkle(size: size * CGFloat.random(in: 0.6...1.3),
                        color: [AppColor.starGold, AppColor.companionGlow, .white].randomElement()!)
                    .position(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height)
                    )
                    .opacity(0.7)
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        SparkleField(count: 30, size: 18)
    }
}
