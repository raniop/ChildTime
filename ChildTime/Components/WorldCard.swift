import SwiftUI

struct WorldCard: View {
    let world: World
    let isUnlocked: Bool
    let currentRoom: Int
    let starsHeld: Int
    let onTap: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc

    @State private var float: CGFloat = 0
    @State private var shimmer: Bool = false

    private var isCompact: Bool { hsc == .compact }
    private var cardHeight: CGFloat { isCompact ? 120 : 150 }
    private var emojiSize: CGFloat { isCompact ? 68 : 92 }
    private var emojiFrame: CGFloat { isCompact ? 84 : 110 }
    private var titleSize: CGFloat { isCompact ? 22 : 28 }
    private var labelSize: CGFloat { isCompact ? 14 : 17 }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Layered background
                background

                // Themed decorations behind everything else
                WorldDecorations(world: world)
                    .opacity(isUnlocked ? 0.7 : 0.25)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.huge, style: .continuous))

                // Subtle shimmer sweep
                if isUnlocked {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.18), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 120)
                    .offset(x: shimmer ? 200 : -200)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.huge, style: .continuous))
                }

                // Foreground content
                HStack(spacing: AppSpacing.lg) {
                    // Big emoji with float + glow
                    Text(world.emoji)
                        .font(.system(size: emojiSize))
                        .offset(y: float)
                        .shadow(color: world.glowColor.opacity(0.7), radius: 20)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 4)
                        .opacity(isUnlocked ? 1 : 0.35)
                        .frame(width: emojiFrame)

                    // Right side: title + progress
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(world.name)
                            .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if isUnlocked {
                            HStack(spacing: 6) {
                                Image(systemName: "door.left.hand.open")
                                    .font(.system(size: labelSize - 3))
                                Text("חדר \(currentRoom + 1) / \(world.rooms)")
                                    .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.9))

                            progressBar
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: labelSize - 3))
                                Text("\(world.starsToUnlock) ⭐ לפתיחה")
                                    .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.85))
                            progressBar
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(AppSpacing.lg)
            }
            .frame(height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.huge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.huge, style: .continuous)
                    .stroke(.white.opacity(isUnlocked ? 0.35 : 0.12), lineWidth: 2)
            )
            .glow(world.glowColor, radius: isUnlocked ? 22 : 0)
            .scaleEffect(isUnlocked ? 1.0 : 0.97)
            .opacity(isUnlocked ? 1 : 0.88)
        }
        .buttonStyle(.juicy)
        .disabled(!isUnlocked)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                float = -4
            }
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false).delay(1)) {
                shimmer = true
            }
        }
    }

    private var background: some View {
        ZStack {
            world.gradient.gradient

            // Inner radial highlight (top-right)
            RadialGradient(
                colors: [Color.white.opacity(0.18), .clear],
                center: UnitPoint(x: 0.85, y: 0.1),
                startRadius: 0,
                endRadius: 200
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
                    .frame(width: geo.size.width * progressValue)
                    .glow(world.glowColor, radius: 8)
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        FloatingOrbs.home()
        VStack(spacing: 16) {
            WorldCard(world: Worlds.all[0], isUnlocked: true,  currentRoom: 4, starsHeld: 47, onTap: {})
            WorldCard(world: Worlds.all[1], isUnlocked: true,  currentRoom: 0, starsHeld: 47, onTap: {})
            WorldCard(world: Worlds.all[2], isUnlocked: false, currentRoom: 0, starsHeld: 47, onTap: {})
        }
        .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
