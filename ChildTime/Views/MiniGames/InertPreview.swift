import SwiftUI

/// 🖼 "A real screen, just smaller."
///
/// Rani, on the What's-New stories: "אני רוצה שהסטוריז התצוגה של מסך חדש
/// תהיה אמיתית מתוך האפליקציה פשוט מוקטנת קצת" — so a story card does not
/// draw a stylised impression of a game, it renders the REAL view at a real
/// phone's size and scales it down inside a device frame.
///
/// A real view on a card must not behave like a real view in a child's hands.
/// This flag travels down the environment from `PhoneFrame`, and everything
/// that would reach outside its own pixels checks it first: no round is
/// scored, no clock advances, nothing is spoken, nothing is written.
///
/// It is an environment value rather than a parameter on purpose — the pieces
/// that speak and tick are shared components nested several levels inside the
/// games, and threading a flag through every one of them is how you miss one.
private struct InertPreviewKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// True when this view is a decorative miniature, not a screen being used.
    var isInertPreview: Bool {
        get { self[InertPreviewKey.self] }
        set { self[InertPreviewKey.self] = newValue }
    }
}

extension View {
    /// `glassPane`, unless the content is something that already draws its own
    /// frame — a phone mockup, say.
    @ViewBuilder
    func glassPaneUnless(_ skip: Bool, radius: CGFloat) -> some View {
        if skip { self } else { self.glassPane(radius: radius) }
    }
}
