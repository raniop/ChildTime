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

    // Rani (comparing the build to the approved mockup): "הזכוכית ממש לא נראית
    // כמו שהצגת". The system material was the culprit — in light mode
    // `.ultraThinMaterial` is a milky white frost that washes the gradient out,
    // so every pane read as a pale grey slab. The mockup's glass is exactly
    // `rgba(255,255,255,.14)` over the vivid gradient with a light edge and a
    // 1-px top highlight — so that is what this draws, with no material at all.
    // The backdrop is a smooth gradient + soft orbs, so a blur adds nothing
    // visible there and costs the saturation the design lives on.
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                ZStack {
                    shape.fill(.white.opacity(strength))
                    if let tint {
                        // A whisper of the colour (Rani: "הם שקופות" — the mockup's
                        // tiles are glass first; the tint only hints at the world).
                        shape.fill(RadialGradient(colors: [tint.opacity(0.30), .clear],
                                                  center: UnitPoint(x: 0.3, y: 0.2),
                                                  startRadius: 0, endRadius: 190))
                    }
                    // Inset top highlight — the sheet catches light from above.
                    shape.fill(LinearGradient(colors: [.white.opacity(0.28), .clear],
                                              startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.12)))
                }
            }
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.22)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .clipShape(shape)
            .shadow(color: shadow ? .black.opacity(0.28) : .clear, radius: 14, y: 8)
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


extension View {
    /// A `Form`/`List` on the brand gradient with glass rows. Forces the dark
    /// colour scheme for the subtree so `.primary/.secondary` (and every stock
    /// control) resolve to light ink on the gradient — the cheapest correct way
    /// to move a hundred-line settings screen to glass without touching each row.
    func glassForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                    .padding(.vertical, 2)
            )
            .background(GlassBackdrop())
            .environment(\.colorScheme, .dark)
            .tint(.white)
    }

    /// Legacy card subtrees: glass shell + dark scheme so their `.secondary`
    /// text turns light. Use where re-inking every label isn't worth it.
    func legacyGlassCard(radius: CGFloat = 22) -> some View {
        self.environment(\.colorScheme, .dark).glassPane(radius: radius)
    }
}

/// The backdrop from the approved mockups, one to one: the brand gradient
/// (#7A5CFF → #5E60CE → #3E8BF0, top-right to bottom-left) with a pink orb
/// glowing at the upper-left and a teal one at the lower-right, both heavily
/// blurred. Every glass screen sits on this — the panes are 14 % white, so
/// THIS is what gives them their colour.
struct GlassBackdrop: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(colors: [Color(hex: "7A5CFF"), Color(hex: "5E60CE"), Color(hex: "3E8BF0")],
                               startPoint: UnitPoint(x: 0.62, y: 0), endPoint: UnitPoint(x: 0.38, y: 1))
                Circle().fill(Color(hex: "FF7BD3"))
                    .frame(width: 280, height: 280)
                    .blur(radius: 44)
                    .opacity(0.8)
                    .position(x: 40, y: 250)
                Circle().fill(Color(hex: "37E2D5"))
                    .frame(width: 320, height: 320)
                    .blur(radius: 44)
                    .opacity(0.8)
                    .position(x: g.size.width - 30, y: g.size.height - 200)
            }
        }
        .ignoresSafeArea()
    }
}
