import SwiftUI

/// Themed floating emoji decorations that match a world's theme.
struct WorldDecorations: View {
    let world: World

    private var emojis: [String] {
        switch world.id {
        case "math_kingdom":
            return ["👑", "🏰", "➕", "➖", "✖️", "➗", "🔢"]
        case "english_land":
            return ["🇬🇧", "🇺🇸", "📖", "🔤", "🌐", "✏️"]
        case "logic_lab":
            return ["🧩", "🔍", "💡", "❓", "🎯", "🎲"]
        case "science_lab":
            return ["🔬", "🧪", "🧬", "🔭", "⚛️", "🦠"]
        case "history_museum":
            return ["🏛️", "⏳", "📜", "🗿", "⚔️", "🏺"]
        case "geo_journey":
            return ["🌍", "🗺️", "🧭", "🏔️", "🌊", "🌋"]
        default:
            return ["✨", "⭐", "🌟"]
        }
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<5, id: \.self) { i in
                FloatingEmoji(
                    text: emojis[i % emojis.count],
                    canvas: geo.size,
                    seed: i
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct FloatingEmoji: View {
    let text: String
    let canvas: CGSize
    let seed: Int

    @State private var float: CGFloat = 0
    @State private var rotation: Double = 0

    private var startX: CGFloat {
        CGFloat((seed * 73) % Int(max(canvas.width, 1).rounded()))
    }

    private var startY: CGFloat {
        CGFloat((seed * 131) % Int(max(canvas.height, 1).rounded()))
    }

    private var size: CGFloat {
        24 + CGFloat((seed * 11) % 16)
    }

    private var duration: Double {
        4 + Double(seed * 3 % 5)
    }

    var body: some View {
        Text(text)
            .font(.system(size: size))
            .opacity(0.35)
            .rotationEffect(.degrees(rotation))
            .position(x: startX, y: startY + float)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    float = CGFloat((seed * 19) % 60) - 30
                }
                withAnimation(.linear(duration: duration * 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

#Preview {
    ZStack {
        AppGradient.castle.ignoresSafeArea()
        WorldDecorations(world: Worlds.all[0])
    }
}
