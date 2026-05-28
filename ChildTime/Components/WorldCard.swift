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
    private var emojiSize: CGFloat { isCompact ? 80 : 110 }
    private var titleSize: CGFloat { isCompact ? 19 : 23 }
    private var labelSize: CGFloat { isCompact ? 13 : 15 }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Layered background
                background

                // Themed decorations behind everything else
                WorldDecorations(world: world)
                    .opacity(isUnlocked ? 0.55 : 0.2)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))

                // Subtle shimmer sweep (only when unlocked)
                if isUnlocked {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.16), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 70)
                    .offset(y: shimmer ? 200 : -200)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                }

                // Foreground content — vertical tile layout
                VStack(spacing: 8) {
                    Spacer(minLength: 8)

                    // Big emoji centered
                    Text(world.emoji)
                        .font(.system(size: emojiSize))
                        .offset(y: float)
                        .shadow(color: world.glowColor.opacity(0.8), radius: 22)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 4)
                        .opacity(isUnlocked ? 1 : 0.35)

                    // Title
                    Text(world.name)
                        .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)

                    Spacer(minLength: 4)

                    // Bottom row: progress text + bar
                    VStack(spacing: 4) {
                        if isUnlocked {
                            HStack(spacing: 4) {
                                Image(systemName: "door.left.hand.open")
                                    .font(.system(size: labelSize - 2))
                                Text("חדר \(currentRoom + 1) / \(world.rooms)")
                                    .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.9))
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: labelSize - 2))
                                Text("\(world.starsToUnlock) ⭐")
                                    .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.85))
                        }
                        progressBar
                            .padding(.horizontal, 14)
                    }
                    .padding(.bottom, 12)
                }
            }
            .aspectRatio(0.92, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(.white.opacity(isUnlocked ? 0.35 : 0.12), lineWidth: 2)
            )
            .glow(world.glowColor, radius: isUnlocked ? 18 : 0)
            .scaleEffect(isUnlocked ? 1.0 : 0.97)
            .opacity(isUnlocked ? 1 : 0.88)
        }
        .buttonStyle(.juicy)
        .disabled(!isUnlocked)
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
                    .frame(width: geo.size.width * progressValue)
                    .glow(world.glowColor, radius: 6)
            }
        }
        .frame(height: 6)
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
