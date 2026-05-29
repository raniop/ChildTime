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
        path.addRoundedRect(in: rect.insetBy(dx: 0, dy: 8), cornerSize: CGSize(width: r, height: r))

        // Triangle tail at bottom-trailing
        if pointDirection == .bottom {
            let tip = CGPoint(x: rect.maxX - 30, y: rect.maxY)
            let baseL = CGPoint(x: rect.maxX - 50, y: rect.maxY - 12)
            let baseR = CGPoint(x: rect.maxX - 20, y: rect.maxY - 12)
            path.move(to: baseL)
            path.addLine(to: tip)
            path.addLine(to: baseR)
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
