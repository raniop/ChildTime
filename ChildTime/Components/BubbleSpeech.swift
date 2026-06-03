import SwiftUI

struct BubbleSpeech: View {
    let text: String
    var pointDirection: Edge = .bottom
    /// Distance of the downward tail's center from the bubble's RIGHT edge. nil =
    /// centered. Set it (≈ avatar radius) to point at an avatar sitting under the
    /// bubble's right edge.
    var tailInsetFromRight: CGFloat? = nil
    /// Same, but measured from the bubble's LEFT edge — for an avatar sitting
    /// under the bubble's left edge. Takes priority over `tailInsetFromRight`.
    var tailInsetFromLeft: CGFloat? = nil
    /// Reveal the words one-by-one (typewriter), as if the companion is speaking.
    var animated: Bool = true
    /// Seconds between each revealed word.
    var perWord: Double = 0.16

    @State private var shownWords: Int = 0

    private var words: [Substring] {
        text.split(separator: " ", omittingEmptySubsequences: false)
    }
    private var shownText: String {
        guard animated else { return text }
        return words.prefix(shownWords).joined(separator: " ")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // An invisible copy of the FULL line fixes the bubble's size so it
            // never grows/jumps as words appear — the words just fill it in.
            Text(text).opacity(0).accessibilityHidden(true)
            Text(shownText)
        }
        .font(AppFont.bubble())
        .foregroundStyle(AppColor.textOnLight)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .padding(.bottom, 8)   // reserve room for the tail
        .background {
            BubbleShape(pointDirection: pointDirection, tailInsetFromRight: tailInsetFromRight, tailInsetFromLeft: tailInsetFromLeft)
                .fill(.white)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                // Pin the shape's coordinates to LTR so the tail position is
                // deterministic (RTL would mirror it to the wrong side).
                .environment(\.layoutDirection, .leftToRight)
        }
        .frame(maxWidth: 260)
        .onAppear { startTyping() }
        .onChange(of: text) { _, _ in startTyping() }
    }

    private func startTyping() {
        guard animated else { return }
        let total = words.count
        shownWords = total <= 1 ? total : 0
        guard total > 1 else { return }
        for i in 1...total {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * perWord) {
                // Ignore stale timers from a previous phrase.
                guard i <= words.count else { return }
                withAnimation(.easeOut(duration: 0.14)) { shownWords = i }
            }
        }
    }
}

struct BubbleShape: Shape {
    var pointDirection: Edge = .bottom
    var tailInsetFromRight: CGFloat? = nil
    var tailInsetFromLeft: CGFloat? = nil

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 18
        let tailH: CGFloat = 11
        let tailW: CGFloat = 22

        // Body fills everything except the reserved tail strip at the bottom.
        let body = CGRect(x: rect.minX, y: rect.minY,
                          width: rect.width, height: rect.height - tailH)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: r, height: r))

        // A clean downward tail whose base sits flush ON the body's bottom edge
        // (1pt overlap) so it merges seamlessly — no notch, no gap.
        if pointDirection == .bottom {
            let cx: CGFloat = {
                let lo = rect.minX + r + tailW / 2
                let hi = rect.maxX - r - tailW / 2
                if let inset = tailInsetFromLeft {
                    return min(max(lo, rect.minX + inset), hi)
                }
                if let inset = tailInsetFromRight {
                    return min(max(lo, rect.maxX - inset), hi)
                }
                return rect.midX
            }()
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
