import SwiftUI

/// A glass home tile for a feature (טופי טיים, משחקים) — the twin of
/// `WorldCard`: same shell, same rhythm, its own colour glowing behind the glass.
struct FeatureCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let gradient: LinearGradient
    let glowColor: Color
    /// Optional corner badge — e.g. the games warm-up "3/10 ✅".
    var badge: String? = nil
    /// Footer line; a nil `footFrac` draws a full decorative track.
    var foot: String = "✨ מֻתְאָם לְךָ"
    var footFrac: Double? = nil
    let onTap: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HomeTileHeader(emoji: emoji, badge: badge)
                HomeTileText(title: title, subtitle: subtitle)
                Spacer(minLength: 6)
                HomeTileFoot(label: foot, frac: footFrac)
            }
            .homeTileChrome(tint: glowColor, compact: hsc == .compact)
        }
        .buttonStyle(.juicy)
    }
}
