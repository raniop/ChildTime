import SwiftUI

struct WorldCard: View {
    let world: World
    let isUnlocked: Bool
    let currentRoom: Int
    let starsHeld: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.lg) {
                Text(world.emoji)
                    .font(.system(size: 64))
                    .frame(width: 80)
                    .opacity(isUnlocked ? 1 : 0.35)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(world.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.textPrimary)
                        .opacity(isUnlocked ? 1 : 0.5)

                    if isUnlocked {
                        HStack(spacing: 4) {
                            Text("חדר \(currentRoom + 1) / \(world.rooms)")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        ProgressView(value: Double(currentRoom) / Double(world.rooms))
                            .tint(world.glowColor)
                            .frame(height: 4)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                            Text("\(world.starsToUnlock) ⭐ לפתיחה")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(AppColor.textSecondary)
                        ProgressView(value: min(1, Double(starsHeld) / Double(world.starsToUnlock)))
                            .tint(world.glowColor)
                            .frame(height: 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(AppSpacing.lg)
            .background(
                ZStack {
                    world.gradient.gradient
                    if !isUnlocked {
                        Color.black.opacity(0.45)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(.white.opacity(isUnlocked ? 0.3 : 0.1), lineWidth: 1)
            )
            .glow(world.glowColor, radius: isUnlocked ? 16 : 0)
            .opacity(isUnlocked ? 1 : 0.85)
        }
        .buttonStyle(.juicy)
        .disabled(!isUnlocked)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 16) {
            WorldCard(world: Worlds.all[0], isUnlocked: true, currentRoom: 4, starsHeld: 47, onTap: {})
            WorldCard(world: Worlds.all[1], isUnlocked: false, currentRoom: 0, starsHeld: 47, onTap: {})
            WorldCard(world: Worlds.all[2], isUnlocked: false, currentRoom: 0, starsHeld: 47, onTap: {})
        }
        .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
