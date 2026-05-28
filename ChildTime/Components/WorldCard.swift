import SwiftUI

struct WorldCard: View {
    let world: World
    let isUnlocked: Bool
    let currentRoom: Int
    let starsHeld: Int
    let onTap: () -> Void

    @State private var float: CGFloat = 0
    @State private var shimmer: Bool = false

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
                        .font(.system(size: 92))
                        .offset(y: float)
                        .shadow(color: world.glowColor.opacity(0.7), radius: 20)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 4)
                        .opacity(isUnlocked ? 1 : 0.35)
                        .frame(width: 110)

                    // Right side: title + progress
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(world.name)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                        if isUnlocked {
                            HStack(spacing: 6) {
                                Image(systemName: "door.left.hand.open")
                                    .font(.system(size: 14))
                                Text("חדר \(currentRoom + 1) / \(world.rooms)")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.9))

                            // Progress bar (custom — more juicy than ProgressView)
                            progressBar
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14))
                                Text("\(world.starsToUnlock) ⭐ לפתיחה")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.85))
                            progressBar
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(AppSpacing.lg)
            }
            .frame(height: 150)
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
