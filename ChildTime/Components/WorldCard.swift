import SwiftUI

/// Compact glass tile for a learning world — the approved "מסך הילד — זכוכית"
/// look: a translucent pane with a whisper of the world's own colour glowing
/// behind it (math cool, money gold), emoji → title → topic → a footer with the
/// room count and a progress track. Right-aligned, like everything Hebrew.
///
/// Subscription-gated worlds stay tappable (the tap opens the parent-gated
/// paywall) and wear a small "👑 טופי+" badge — never a lock or grey-out.
struct WorldCard: View {
    let world: World
    let isUnlocked: Bool
    let currentRoom: Int
    let starsHeld: Int
    var subscriptionLocked: Bool = false
    let onTap: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    private var isCompact: Bool { hsc == .compact }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HomeTileHeader(emoji: world.emoji,
                               badge: subscriptionLocked ? "👑 טוֹפִי+" : nil)
                HomeTileText(title: world.name,
                             subtitle: world.isBonusWorld ? "כָּל הַנּוֹשְׂאִים · דַּקּוֹת כְּפוּלוֹת" : world.topic.displayName)
                Spacer(minLength: 6)
                HomeTileFoot(label: "חֶדֶר \(max(1, min(currentRoom + 1, world.rooms)))/\(world.rooms)",
                             frac: Double(currentRoom) / Double(max(1, world.rooms)))
            }
            .homeTileChrome(tint: world.glowColor, compact: isCompact)
        }
        .buttonStyle(.juicy)
        // Star-locked worlds are inert; subscription-locked ones stay tappable so
        // the tap can open the paywall.
        .disabled(!isUnlocked && !subscriptionLocked)
    }
}

// MARK: - Shared tile pieces (WorldCard + FeatureCard read as one family)

struct HomeTileHeader: View {
    let emoji: String
    var badge: String? = nil
    @Environment(\.horizontalSizeClass) private var hsc
    var body: some View {
        HStack(alignment: .top) {
            Text(emoji)
                .font(.system(size: hsc == .compact ? 34 : 40))
                .shadow(color: .black.opacity(0.25), radius: 5, y: 4)
            Spacer(minLength: 0)
            if let badge {
                Text(badge)
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.24)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.32), lineWidth: 1))
            }
        }
    }
}

struct HomeTileText: View {
    let title: String
    let subtitle: String
    @Environment(\.horizontalSizeClass) private var hsc
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: hsc == .compact ? 15 : 17, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassInk.primary)
                .lineLimit(2).minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
            Text(subtitle)
                .font(.system(size: hsc == .compact ? 11 : 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .lineLimit(2).minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Footer: a short label and a thin white track (frac 0…1). `frac == nil`
/// draws a full decorative track — for tiles that have no progress of their own.
struct HomeTileFoot: View {
    let label: String
    var frac: Double? = 0
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .layoutPriority(1)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule().fill(.white)
                        .frame(width: frac == nil ? g.size.width : max(0, g.size.width * min(1, max(0, frac ?? 0))))
                }
            }
            .frame(height: 5)
        }
    }
}

extension View {
    /// The tile's glass shell — fixed height so every tile in the grid is a twin.
    func homeTileChrome(tint: Color, compact: Bool) -> some View {
        self
            .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 150 : 176)
            .glassPane(radius: 22, tint: tint)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        FloatingOrbs.home()
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            WorldCard(world: Worlds.all[0], isUnlocked: true,  currentRoom: 4, starsHeld: 47, onTap: {})
            WorldCard(world: Worlds.all[1], isUnlocked: true,  currentRoom: 0, starsHeld: 47, subscriptionLocked: true, onTap: {})
        }
        .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
