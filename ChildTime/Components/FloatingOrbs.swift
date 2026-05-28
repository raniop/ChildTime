import SwiftUI

/// Animated, slowly drifting blurred orbs that create a magical, alive background.
/// Each orb moves on its own slow path in a continuous loop.
struct FloatingOrbs: View {
    var colors: [Color]
    var count: Int = 6
    var maxSize: CGFloat = 260
    var opacity: Double = 0.45

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    Orb(
                        color: colors[i % colors.count],
                        canvas: geo.size,
                        maxSize: maxSize,
                        opacity: opacity,
                        seed: i
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Orb: View {
    let color: Color
    let canvas: CGSize
    let maxSize: CGFloat
    let opacity: Double
    let seed: Int

    @State private var animateID: Bool = false

    private var size: CGFloat {
        let base = maxSize * 0.5
        let variance = maxSize * 0.5
        return base + CGFloat((seed * 37) % Int(variance))
    }

    private var startPoint: CGPoint {
        let x = CGFloat((seed * 71) % Int(canvas.width.rounded()))
        let y = CGFloat((seed * 113) % Int(canvas.height.rounded()))
        return CGPoint(x: x, y: y)
    }

    private var endPoint: CGPoint {
        let x = CGFloat((seed * 197 + 313) % Int(canvas.width.rounded()))
        let y = CGFloat((seed * 251 + 419) % Int(canvas.height.rounded()))
        return CGPoint(x: x, y: y)
    }

    private var duration: Double {
        12 + Double(seed * 7 % 10)
    }

    var body: some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 50)
            .position(animateID ? endPoint : startPoint)
            .animation(
                .easeInOut(duration: duration).repeatForever(autoreverses: true),
                value: animateID
            )
            .onAppear { animateID = true }
    }
}

extension FloatingOrbs {
    static func home() -> FloatingOrbs {
        FloatingOrbs(
            colors: [
                AppColor.dreamyIndigo,
                AppColor.dreamyTeal,
                AppColor.gemPurple,
                AppColor.companionGlow
            ],
            count: 6
        )
    }

    static func castle() -> FloatingOrbs {
        FloatingOrbs(
            colors: [
                Color(hex: "FF6B9D"),
                Color(hex: "FFB84D"),
                Color(hex: "FF8B94"),
                AppColor.starGold
            ],
            count: 5
        )
    }

    static func tower() -> FloatingOrbs {
        FloatingOrbs(
            colors: [
                Color(hex: "5E2BFF"),
                Color(hex: "9B5DE5"),
                Color(hex: "F15BB5"),
                Color(hex: "2E1A6B")
            ],
            count: 5
        )
    }

    static func valley() -> FloatingOrbs {
        FloatingOrbs(
            colors: [
                Color(hex: "0AAE6B"),
                Color(hex: "48BFE3"),
                Color(hex: "06D6A0"),
                Color(hex: "FFD23F")
            ],
            count: 5
        )
    }

    static func galaxy() -> FloatingOrbs {
        FloatingOrbs(
            colors: [
                Color(hex: "9B5DE5"),
                Color(hex: "C04EE8"),
                Color(hex: "FF6B9D"),
                Color(hex: "48BFE3"),
                Color(hex: "FFD23F")
            ],
            count: 6
        )
    }

    // MARK: - Topic-specific orb palettes (6 worlds)

    static func englishWorld() -> FloatingOrbs {
        FloatingOrbs(
            colors: [Color(hex: "1E3A8A"), Color(hex: "DC2626"), Color(hex: "FFFFFF").opacity(0.6), Color(hex: "FBBF24")],
            count: 5
        )
    }

    static func logicWorld() -> FloatingOrbs {
        FloatingOrbs(
            colors: [Color(hex: "7C4DFF"), Color(hex: "00BCD4"), Color(hex: "F15BB5"), Color(hex: "FFD23F")],
            count: 5
        )
    }

    static func scienceWorld() -> FloatingOrbs {
        FloatingOrbs(
            colors: [Color(hex: "00C853"), Color(hex: "2962FF"), Color(hex: "00BCD4"), Color(hex: "AEEA00")],
            count: 5
        )
    }

    static func historyWorld() -> FloatingOrbs {
        FloatingOrbs(
            colors: [Color(hex: "8D6E63"), Color(hex: "FFC107"), Color(hex: "BF360C"), Color(hex: "FBE5A1")],
            count: 5
        )
    }

    static func geographyWorld() -> FloatingOrbs {
        FloatingOrbs(
            colors: [Color(hex: "0AAE6B"), Color(hex: "00ACC1"), Color(hex: "1565C0"), Color(hex: "FFD23F")],
            count: 5
        )
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        FloatingOrbs.home()
        SparkleField(count: 20, size: 14)
    }
}
