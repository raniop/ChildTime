import SwiftUI

/// Shared sizing constants so every home tile (WorldCard + FeatureCard) lays
/// out its emoji, title, subtitle, and footer in exactly the same vertical
/// positions, regardless of how much content each card carries.
enum HomeTileLayout {
    static let rowSpacing: CGFloat = 6
    static func emojiZone(_ size: CGFloat) -> CGFloat { size }
    static func titleZone(_ size: CGFloat) -> CGFloat { size * 2.1 }    // up to 2 lines
    static func subtitleZone(_ size: CGFloat) -> CGFloat { size * 1.4 }
    static func badgeZone(_ size: CGFloat) -> CGFloat { size + 4 }
}

struct WorldCard: View {
    let world: World
    let isUnlocked: Bool
    let currentRoom: Int
    let starsHeld: Int
    /// When true the world is gated behind the monthly subscription. The card
    /// stays tappable (tapping opens the paywall) but shows a "טופי+" badge.
    var subscriptionLocked: Bool = false
    let onTap: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc

    @State private var float: CGFloat = 0
    @State private var shimmer: Bool = false

    private var isCompact: Bool { hsc == .compact }
    /// Whether the card should render with the dimmed "locked" treatment —
    /// either it hasn't been unlocked by stars yet, or it's behind the paywall.
    private var showsLocked: Bool { !isUnlocked || subscriptionLocked }
    private var emojiSize: CGFloat { isCompact ? 64 : 84 }
    private var titleSize: CGFloat { isCompact ? 22 : 26 }
    private var labelSize: CGFloat { isCompact ? 15 : 17 }
    /// Fixed tile height (shared verbatim with FeatureCard) so every home tile
    /// has an identical footprint regardless of how much content it holds.
    /// Tall enough that the emoji/title/subtitle/footer never overflow & clip.
    private var tileHeight: CGFloat { isCompact ? 224 : 284 }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Layered background
                background

                // Themed decorations behind everything else
                WorldDecorations(world: world)
                    .opacity(showsLocked ? 0.2 : 0.55)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))

                // Subtle shimmer sweep (only when unlocked)
                if !showsLocked {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.16), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 70)
                    .offset(y: shimmer ? 200 : -200)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                }

                // Foreground content — shared rhythm with FeatureCard so the
                // emoji / title / subtitle / footer line up across every tile.
                VStack(spacing: HomeTileLayout.rowSpacing) {
                    Spacer(minLength: 0)

                    // Big emoji centered (fixed zone)
                    Text(world.emoji)
                        .font(.system(size: emojiSize))
                        .offset(y: float)
                        .shadow(color: world.glowColor.opacity(0.8), radius: 22)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 4)
                        .opacity(showsLocked ? 0.35 : 1)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: HomeTileLayout.emojiZone(emojiSize))

                    // Title (fixed zone)
                    Text(world.name)
                        .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: HomeTileLayout.titleZone(titleSize))
                        .padding(.horizontal, 10)

                    // Topic subtitle (fixed zone)
                    Text(world.topic.displayName)
                        .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: HomeTileLayout.subtitleZone(labelSize))

                    Spacer(minLength: 0)

                    // Footer (fixed zone): badge slot on top, progress bar pinned
                    // to the bottom — identical to FeatureCard so bars align.
                    VStack(spacing: 4) {
                        Group {
                            if subscriptionLocked {
                                HStack(spacing: 4) {
                                    Image(systemName: "crown.fill")
                                    Text("טוֹפִּי+")
                                        .fontWeight(.heavy)
                                }
                                .foregroundStyle(AppColor.starGold)
                            } else if !isUnlocked {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.fill")
                                    Text("\(world.starsToUnlock) ⭐")
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white.opacity(0.85))
                            } else {
                                Color.clear
                            }
                        }
                        .font(.system(size: labelSize - 1, weight: .semibold, design: .rounded))
                        .frame(height: HomeTileLayout.badgeZone(labelSize))
                        .frame(maxWidth: .infinity, alignment: .center)

                        // Subscription-locked worlds show a decorative gold bar
                        // (a star-unlock bar would be meaningless there); every
                        // other state shows the real progress bar.
                        Group {
                            if subscriptionLocked {
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [AppColor.starGold, .white.opacity(0.7), AppColor.starGold],
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(height: 8)
                                    .glow(AppColor.starGold, radius: 6)
                            } else {
                                progressBar
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 14)
            }
            .frame(maxWidth: 270)
            .frame(height: tileHeight)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(subscriptionLocked ? AppColor.starGold.opacity(0.6)
                                                : .white.opacity(showsLocked ? 0.12 : 0.35),
                            lineWidth: 2)
            )
            // Subscription-locked cards keep a gold glow to read as "premium";
            // star-locked ones stay flat. Footprint is identical in every state.
            .glow(subscriptionLocked ? AppColor.starGold : world.glowColor,
                  radius: showsLocked && !subscriptionLocked ? 0 : 18)
            .opacity(showsLocked ? 0.9 : 1)
        }
        .buttonStyle(.juicy)
        // Star-locked worlds are inert; subscription-locked ones stay tappable so
        // the tap can open the paywall.
        .disabled(!isUnlocked && !subscriptionLocked)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                float = -4
            }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false).delay(1)) {
                shimmer = true
            }
        }
    }

    private var background: some View {
        ZStack {
            world.gradient.gradient

            // Inner radial highlight from top-right
            RadialGradient(
                colors: [Color.white.opacity(0.20), .clear],
                center: UnitPoint(x: 0.8, y: 0.15),
                startRadius: 0,
                endRadius: 160
            )

            if !isUnlocked {
                Color.black.opacity(0.42)
            }
        }
    }

    private var progressValue: Double {
        if isUnlocked {
            return Double(currentRoom) / Double(world.rooms)
        } else {
            return min(1, Double(starsHeld) / Double(max(1, world.starsToUnlock)))
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.black.opacity(0.25))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [world.glowColor, Color.white.opacity(0.7), world.glowColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, geo.size.width * progressValue))
                    .glow(world.glowColor, radius: 6)
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        FloatingOrbs.home()
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
            spacing: 14
        ) {
            WorldCard(world: Worlds.all[0], isUnlocked: true,  currentRoom: 4, starsHeld: 47, onTap: {})
            WorldCard(world: Worlds.all[1], isUnlocked: true,  currentRoom: 0, starsHeld: 47, onTap: {})
            WorldCard(world: Worlds.all[2], isUnlocked: false, currentRoom: 0, starsHeld: 47, onTap: {})
        }
        .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
