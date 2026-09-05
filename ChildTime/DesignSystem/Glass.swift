import SwiftUI

/// Liquid-glass surfaces — Rani: the whole app moves to this look.
///
/// One modifier, one vocabulary, so every screen reads as the same material:
/// a translucent white pane with real blur behind it, a light edge that brightens
/// toward the top (glass catches light from above), and a soft drop shadow so it
/// floats over the gradient instead of sitting in it. Text on glass is white.
///
/// `tint` lets a pane whisper its own colour (a world card, the warm insight)
/// without falling back to an opaque block — the glass stays glass.
struct GlassPane: ViewModifier {
    var radius: CGFloat = 22
    var strength: Double = 0.14          // pane opacity; 0.09 = quieter, 0.22 = stronger
    var tint: Color? = nil
    var shadow: Bool = true

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    if let tint {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(RadialGradient(colors: [tint.opacity(0.55), .clear],
                                                 center: .topLeading, startRadius: 0, endRadius: 220))
                    }
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(strength + 0.06), .white.opacity(strength - 0.04)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.14)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: shadow ? .black.opacity(0.22) : .clear, radius: 18, y: 10)
    }
}

extension View {
    /// The standard glass card.
    func glassPane(radius: CGFloat = 22, strength: Double = 0.14, tint: Color? = nil, shadow: Bool = true) -> some View {
        modifier(GlassPane(radius: radius, strength: strength, tint: tint, shadow: shadow))
    }
    /// A quieter pane for things INSIDE a glass card (stat tiles, list rows).
    func glassInset(radius: CGFloat = 12) -> some View {
        modifier(GlassPane(radius: radius, strength: 0.09, tint: nil, shadow: false))
    }
}

/// Ink colours for text on glass. `.primary/.secondary` are for opaque surfaces
/// and go dark in light mode — on glass they vanish.
enum GlassInk {
    static let primary   = Color.white
    static let secondary = Color.white.opacity(0.78)
    static let tertiary  = Color.white.opacity(0.58)
    // Semantic tints that stay legible over the gradient.
    static let good = Color(hex: "8CFFC4")
    static let warn = Color(hex: "FFD98A")
    static let weak = Color(hex: "FF9AA0")
}
