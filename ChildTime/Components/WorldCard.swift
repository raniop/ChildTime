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
    /// e.g. "✨ חָדָשׁ!" on a pack the child hasn't opened yet (wins over 👑).
    var badgeOverride: String? = nil
    /// Replaces the "חֶדֶר N/10" foot — a locked world the child already played
    /// ("חֶדֶר 6/10 · רוֹצֶה לְהַמְשִׁיךְ?") after a gift ended.
    var footOverride: String? = nil
    /// First-day glow on a freshly gifted pack — the border and badge breathe.
    var pulse: Bool = false
    /// 🏆 0 bronze · 1 silver · 2 gold · 3 champion (ProgressStore.worldTier).
    var tier: Int = 0
    /// Played here at all → the tier badge and rim.
    var visited: Bool = true
    /// THE one world Tofy recommends next (never visited) → gold dashed rim,
    /// "עוֹד לֹא בִּקַּרְתְּ" and the first-visit 💎. One world, not all of them.
    var suggested: Bool = false
    var girl: Bool = false
    @State private var glow = false
    let onTap: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    private var isCompact: Bool { hsc == .compact }

    private var newHere: Bool { suggested && !visited && isUnlocked && !subscriptionLocked && !world.isBonusWorld }
    private var showTier: Bool { visited && isUnlocked && !subscriptionLocked && !world.isBonusWorld }
    private var tierBadge: String? {
        if newHere { return girl ? tr("✨ עוֹד לֹא בִּקַּרְתְּ") : tr("✨ עוֹד לֹא בִּקַּרְתָּ") }
        return showTier ? WorldTiers.kidBadge(tier: tier, girl: girl) : nil
    }
    private var footLabel: String {
        if newHere { return tr("בִּקּוּר רִאשׁוֹן = +\(ProgressStore.firstVisitDiamonds) 💎") }
        if tier >= 3 { return tr("👑 הָעוֹלָם הֻשְׁלַם") }
        if currentRoom >= world.rooms - 1 { return tr("חֶדֶר \(world.rooms)/\(world.rooms) · הַבּוֹס מְחַכֶּה 🐉") }
        return tr("חֶדֶר \(max(1, min(currentRoom + 1, world.rooms)))/\(world.rooms)")
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HomeTileHeader(emoji: world.emoji,
                               badge: badgeOverride ?? (subscriptionLocked ? tr("👑 טוֹפִי+") : tierBadge),
                               badgeTint: badgeOverride == nil && !subscriptionLocked && tierBadge != nil
                                   ? (newHere ? Color(hex: "FFE28A") : WorldTiers.color(tier: tier)) : nil)
                HomeTileText(title: world.name,
                             subtitle: world.isBonusWorld ? tr("כָּל הַנּוֹשְׂאִים · דַּקּוֹת כְּפוּלוֹת")
                                : (showTier ? WorldTiers.crownsLine(tier: tier) : nil)
                                    ?? (world.topic.pack?.tagline ?? world.topic.displayName))
                Spacer(minLength: 6)
                HomeTileFoot(label: footOverride ?? footLabel,
                             frac: tier >= 3 ? 1 : Double(currentRoom) / Double(max(1, world.rooms)))
            }
            .homeTileChrome(tint: world.glowColor, compact: isCompact)
            .overlay {
                // 🏆 Silver, gold and champion wear their colour on the rim; a
                // world never visited gets a dashed invitation.
                if showTier {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(WorldTiers.color(tier: tier).opacity(tier == 0 ? 0.7 : 0.95), lineWidth: 2)
                } else if newHere {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(hex: "FFE28A").opacity(0.95), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                }
            }
            .shadow(color: showTier && tier >= 1 ? WorldTiers.color(tier: tier).opacity(0.45)
                        : (newHere ? Color(hex: "FFE28A").opacity(0.45) : .clear), radius: 10)
            .overlay {
                if pulse {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(hex: "FFD23F").opacity(glow ? 0.95 : 0.25), lineWidth: 2.5)
                }
            }
            .shadow(color: Color(hex: "FFD23F").opacity(pulse ? (glow ? 0.7 : 0.15) : 0), radius: glow ? 22 : 8)
            // The gold border and the shadow carry the pulse. Breathing the
            // whole tile between 1 and 1.03 also breathed its NAME and its
            // "חֶדֶר 3/10" line, which SwiftUI rasterises and then scales —
            // the world a child is being pointed at was the one with soft text.
        }
        .buttonStyle(.juicy)
        .onAppear {
            guard pulse else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { glow = true }
        }
        // Star-locked worlds are inert; subscription-locked ones stay tappable so
        // the tap can open the paywall.
        .disabled(!isUnlocked && !subscriptionLocked)
    }
}

// MARK: - Shared tile pieces (WorldCard + FeatureCard read as one family)

struct HomeTileHeader: View {
    let emoji: String
    var badge: String? = nil
    /// A coloured badge (the mint "חינם" on טופי טיים) instead of the glass one.
    var badgeTint: Color? = nil
    @Environment(\.horizontalSizeClass) private var hsc
    var body: some View {
        HStack(alignment: .top) {
            Text(emoji)
                .font(.system(size: hsc == .compact ? 34 : 40))
                .shadow(color: .black.opacity(0.25), radius: 5, y: 4)
            Spacer(minLength: 0)
            if let badge {
                if let badgeTint {
                    Text(badge)
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "0B3D2A"))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LinearGradient(colors: [badgeTint, badgeTint.opacity(0.8)],
                                                                  startPoint: .top, endPoint: .bottom)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.7), lineWidth: 1))
                        .shadow(color: badgeTint.opacity(0.6), radius: 6, y: 2)
                } else {
                    Text(badge)
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.24)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.32), lineWidth: 1))
                }
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
            // One line (Rani: the home felt too busy) — and never cut with "…"
            // (Rani: "חתוכה!"): a long one shrinks until it fits whole.
            Text(subtitle)
                .font(.system(size: hsc == .compact ? 11 : 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .lineLimit(1).minimumScaleFactor(0.55)
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
            .glassPane(radius: 16, tint: tint)
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
    .environment(\.layoutDirection, .app)
}
