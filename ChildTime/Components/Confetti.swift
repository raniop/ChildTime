import SwiftUI

struct Confetti: View {
    var trigger: Int
    var count: Int = 60

    @State private var animateID: Int = -1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    ConfettiPiece(
                        startX: CGFloat.random(in: 0...geo.size.width),
                        fall: geo.size.height + 100,
                        delay: Double.random(in: 0...0.4),
                        animateID: animateID,
                        index: i
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, new in
            animateID = new
        }
    }
}

private struct ConfettiPiece: View {
    let startX: CGFloat
    let fall: CGFloat
    let delay: Double
    let animateID: Int
    let index: Int

    @State private var y: CGFloat = -80
    @State private var rot: Double = 0
    @State private var opacity: Double = 0

    private let palette: [Color] = [
        AppColor.starGold,
        AppColor.gemPurple,
        AppColor.successMint,
        AppColor.flameOrange,
        AppColor.companionGlow,
        .white
    ]

    var body: some View {
        Rectangle()
            .fill(palette[index % palette.count])
            .frame(width: 8, height: 14)
            .rotationEffect(.degrees(rot))
            .position(x: startX, y: y)
            .opacity(opacity)
            .onChange(of: animateID) { _, _ in
                y = -80
                rot = 0
                opacity = 1
                withAnimation(.easeIn(duration: 2.0).delay(delay)) {
                    y = fall
                    rot = Double.random(in: 360...1080)
                }
                withAnimation(.easeIn(duration: 0.5).delay(delay + 1.5)) {
                    opacity = 0
                }
            }
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        Confetti(trigger: 1)
    }
}
