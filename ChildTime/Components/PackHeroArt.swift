import SwiftUI

/// ⚽ A pack's emoji as hero art: the symbol floating in its own colour, lit
/// from behind.
///
/// It replaces the flat rounded rectangle this used to be — a 120pt slab of
/// one tint with a white hairline and a small emoji marooned in the middle,
/// which read as an empty box rather than as artwork. The halo keeps the
/// pack's colours, fills the same space, and has no edge to look boxy.
struct PackHeroArt: View {
    let emoji: String
    let colors: [Color]
    var size: CGFloat = 64
    /// The whole block's height; the halo scales with it.
    var height: CGFloat = 120

    var body: some View {
        ZStack {
            // Two offset blooms, so the light has a direction instead of
            // sitting as one flat disc behind the symbol.
            bloom(colors.first ?? .white)
                .frame(width: height * 0.95, height: height * 0.95)
                .offset(x: -height * 0.1, y: -height * 0.08)
            bloom(colors.last ?? .white)
                .frame(width: height * 0.8, height: height * 0.8)
                .offset(x: height * 0.12, y: height * 0.1)
            Text(emoji)
                .font(.system(size: size))
                .shadow(color: (colors.first ?? .white).opacity(0.55), radius: size * 0.28)
                .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private func bloom(_ color: Color) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.55), color.opacity(0.14), .clear],
                                 center: .center, startRadius: 0, endRadius: height * 0.45))
            .blur(radius: height * 0.09)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 24) {
            PackHeroArt(emoji: "⚽", colors: [Color(hex: "8CFFC4"), Color(hex: "7CF3FF")])
            PackHeroArt(emoji: "🦖", colors: [Color(hex: "FFB84D"), Color(hex: "FF6B9D")], size: 44, height: 84)
        }
        .padding()
    }
}
