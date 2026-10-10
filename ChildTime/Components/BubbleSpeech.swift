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
    /// Draw the little downward tail. Off for a clean tail-less bubble (e.g. the
    /// wandering home companion, where the bubble just floats above the avatar).
    var showTail: Bool = true
    /// Reveal the words one-by-one (typewriter), as if the companion is speaking.
    var animated: Bool = true
    /// Seconds between each revealed word.
    var perWord: Double = 0.16
    /// Take exactly the words' own width (one line) instead of stretching to
    /// what is offered — for a bubble that must touch the one who speaks.
    var hugs: Bool = false

    @State private var shownWords: Int = 0
    @Environment(\.layoutDirection) private var layoutDirection

    /// A tail on the side (`.trailing` = the SCREEN's right, `.leading` = its
    /// left — the shape is drawn left-to-right): for a bubble standing beside
    /// the one who speaks (the quiz buddy, Rani 2026-10-10).
    private var sideTail: Bool { showTail && (pointDirection == .leading || pointDirection == .trailing) }
    /// The layout edge that is that screen side.
    private var sideTailEdge: Edge.Set {
        (pointDirection == .trailing) == (layoutDirection == .leftToRight) ? .trailing : .leading
    }

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
        .padding(.bottom, showTail && !sideTail ? 8 : 0)   // reserve room for the tail
        .padding(sideTailEdge, sideTail ? 10 : 0)
        .background {
            BubbleShape(pointDirection: pointDirection, tailInsetFromRight: tailInsetFromRight, tailInsetFromLeft: tailInsetFromLeft, showTail: showTail)
                .fill(.white)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                // Pin the shape's coordinates to LTR so the tail position is
                // deterministic (RTL would mirror it to the wrong side).
                .environment(\.layoutDirection, .leftToRight)
        }
        .frame(maxWidth: hugs ? nil : 260)
        .fixedSize(horizontal: hugs, vertical: false)
        .onAppear { startTyping() }
        .onChangeCompat(of: text) { _, _ in startTyping() }
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
    var showTail: Bool = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 18
        let side = showTail && (pointDirection == .leading || pointDirection == .trailing)
        let tailH: CGFloat = showTail && !side ? 11 : 0
        let tailW: CGFloat = 22

        // Body fills everything except the reserved tail strip at the bottom
        // (or, for a side tail, at that side).
        var body = CGRect(x: rect.minX, y: rect.minY,
                          width: rect.width, height: rect.height - tailH)
        if side {
            let depth: CGFloat = 10
            body.size.width -= depth
            if pointDirection == .leading { body.origin.x += depth }
        }
        path.addRoundedRect(in: body, cornerSize: CGSize(width: r, height: r))

        // A side tail at the body's middle, pointing out sideways.
        if side {
            let cy = body.midY
            let half: CGFloat = 9
            if pointDirection == .trailing {
                path.move(to: CGPoint(x: body.maxX - 1, y: cy - half))
                path.addLine(to: CGPoint(x: rect.maxX, y: cy))
                path.addLine(to: CGPoint(x: body.maxX - 1, y: cy + half))
            } else {
                path.move(to: CGPoint(x: body.minX + 1, y: cy - half))
                path.addLine(to: CGPoint(x: rect.minX, y: cy))
                path.addLine(to: CGPoint(x: body.minX + 1, y: cy + half))
            }
            path.closeSubpath()
        }

        // A clean downward tail whose base sits flush ON the body's bottom edge
        // (1pt overlap) so it merges seamlessly — no notch, no gap.
        if showTail && pointDirection == .bottom {
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
            BubbleSpeech(text: tr("הֵיי! אֲנִי טוֹפִי! בּוֹא נֵצֵא לְהַרְפַּתְקָה"))
            BubbleSpeech(text: tr("וָואוּ! 5 בָּרֶצֶף 🔥"))
            BubbleSpeech(text: tr("כִּמְעַט!"))
        }
        .padding()
    }
    .environment(\.layoutDirection, .app)
}
