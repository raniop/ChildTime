import SwiftUI

/// 📱 A real Tofy screen, shrunk into a phone.
///
/// Rani asked for exactly this on the What's-New stories: "אני רוצה שהסטוריז
/// התצוגה של מסך חדש תהיה אמיתית מתוך האפליקציה פשוט מוקטנת קצת". So the card
/// does not draw an impression of a game — it builds the REAL view, lays it
/// out at a reference phone's size, and scales the whole thing down.
///
/// Three things make that safe:
///
/// 1. **It is inert.** `isInertPreview` travels down the environment and the
///    games honour it: the round is dealt so there is something to look at,
///    but no clock ticks, nothing is spoken, nothing is scored and nothing is
///    written. There is no `MiniGameEarnSession`, so there is no ledger to
///    write to in the first place, and hit testing is off, so the only way a
///    game scores — a child touching it — cannot happen.
/// 2. **It is laid out as a phone.** The size class is forced to `.compact`,
///    or on an iPad the games would lay out their iPad form inside a 393pt
///    box and spill out of it.
/// 3. **The scale is set once and never animated.** The repo's rule against
///    `scaleEffect` on text is about ANIMATING one — the text is re-rasterised
///    every frame and blurs for the whole animation. A static downscale is the
///    opposite case: it is how every device mockup is drawn, and it is what
///    "just smaller" means.
struct PhoneFrame<Content: View>: View {
    /// The space the framed phone has to fit inside.
    let box: CGSize
    @ViewBuilder var content: () -> Content

    /// A phone's points — an iPhone 16/15/14's 393 × 852. Fixed on purpose:
    /// the miniature should look the same on every device, and it is a picture
    /// OF a phone, not a reflection of the one in your hand.
    static var reference: CGSize { CGSize(width: 393, height: 852) }

    private var fit: CGFloat {
        guard box.width > 0, box.height > 0 else { return 0.2 }
        return Swift.min(box.width / Self.reference.width, box.height / Self.reference.height)
    }

    var body: some View {
        let radius: CGFloat = 46
        content()
            .frame(width: Self.reference.width, height: Self.reference.height)
            .environment(\.isInertPreview, true)
            .environment(\.horizontalSizeClass, .compact)
            .disabled(true)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 3))
            .scaleEffect(fit)                      // static — never animated
            .frame(width: Self.reference.width * fit, height: Self.reference.height * fit)
            .shadow(color: .black.opacity(0.38), radius: 22 * fit + 6, y: 10 * fit + 3)
    }
}

/// One of the twelve games, as the child really sees it.
struct MiniGameScreenPreview: View {
    let kind: MiniGameKind
    var topic: Topic? = nil
    /// 👶 Force the גן form. Defaults to whoever is using the app.
    var preReader: Bool = PreReaderGames.activeChildIsPreReader
    let box: CGSize

    static var reference: CGSize { PhoneFrame<EmptyView>.reference }

    var body: some View {
        PhoneFrame(box: box) { screen }
    }

    /// The real view, by kind. Every one of them takes the same four things,
    /// and `earn: nil` is what keeps a miniature out of the ledger.
    @ViewBuilder
    private var screen: some View {
        switch kind {
        case .pairs:      PairsGameView(topic: topic, onClose: {}, forcePreReader: preReader)
        case .balloon:    BalloonPopView(topic: topic, onClose: {}, forcePreReader: preReader)
        case .word:       BuildWordView(topic: topic, onClose: {})
        case .crush:      NumberCrushView(topic: topic, onClose: {}, forcePreReader: preReader)
        case .wordSearch: WordSearchView(topic: topic, onClose: {})
        case .lightning:  LightningTrueFalseView(topic: topic, onClose: {})
        case .sort:       SortBasketsView(topic: topic, onClose: {}, forcePreReader: preReader)
        case .pattern:    PatternGameView(topic: topic, onClose: {}, forcePreReader: preReader)
        case .game2048:   Game2048View(topic: topic, onClose: {})
        case .vault:      VaultGameView(topic: topic, onClose: {})
        case .grocery:    GroceryGameView(topic: topic, onClose: {})
        case .balance:    BalanceGameView(topic: topic, onClose: {})
        }
    }
}
