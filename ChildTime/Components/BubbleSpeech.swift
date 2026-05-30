import SwiftUI

struct BubbleSpeech: View {
    let text: String
    var pointDirection: Edge = .bottom

    var body: some View {
        Text(text)
            .font(AppFont.bubble())
            .foregroundStyle(AppColor.textOnLight)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .padding(.bottom, 8)   // reserve room for the tail
            .background {
                BubbleShape(pointDirection: pointDirection)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .frame(maxWidth: 260)
    }
}

struct BubbleShape: Shape {
    var pointDirection: Edge = .bottom

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 18
        let tailH: CGFloat = 11
        let tailW: CGFloat = 22

        // Body fills everything except the reserved tail strip at the bottom.
        let body = CGRect(x: rect.minX, y: rect.minY,
                          width: rect.width, height: rect.height - tailH)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: r, height: r))

        // A clean downward tail, centered, whose base sits flush ON the body's
        // bottom edge (1pt overlap) so it merges seamlessly — no notch, no gap.
        if pointDirection == .bottom {
            let cx = rect.midX
            let baseY = body.maxY
            path.move(to: CGPoint(x: cx - tailW / 2, y: baseY - 1))
            path.addLine(to: CGPoint(x: cx, y: baseY + tailH))
            path.addLine(to: CGPoint(x: cx + tailW / 2, y: baseY - 1))
            path.closeSubpath()
        }
        return path
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 24) {
            BubbleSpeech(text: "הֵיי! אֲנִי טוֹפִּי! בּוֹא נֵצֵא לְהַרְפַּתְקָה")
            BubbleSpeech(text: "וָואוּ! 5 בָּרֶצֶף 🔥")
            BubbleSpeech(text: "כִּמְעַט!")
        }
        .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
