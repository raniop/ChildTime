import SwiftUI

struct StarBurst: View {
    var count: Int = 8
    var color: Color = AppColor.starGold
    var trigger: Int

    @State private var animateID: Int = -1

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let angle = (Double(i) / Double(count)) * .pi * 2
                StarParticle(angle: angle, color: color, animateID: animateID, particleIndex: i)
            }
        }
        .onChange(of: trigger) { _, new in
            animateID = new
        }
    }
}

private struct StarParticle: View {
    let angle: Double
    let color: Color
    let animateID: Int
    let particleIndex: Int

    @State private var t: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Image(systemName: "star.fill")
            .foregroundStyle(color)
            .font(.system(size: 18))
            .offset(
                x: cos(angle) * 60 * t,
                y: sin(angle) * 60 * t
            )
            .opacity(opacity)
            .scaleEffect(1 - 0.3 * t)
            .onChange(of: animateID) { _, _ in
                t = 0
                opacity = 1
                withAnimation(.easeOut(duration: 0.7)) {
                    t = 1
                    opacity = 0
                }
            }
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        StarBurst(trigger: 1)
            .frame(width: 200, height: 200)
    }
}
