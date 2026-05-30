import SwiftUI

/// Shows the current run of correct answers — the streak count, escalating fire,
/// and the live star multiplier it unlocks. The bigger the streak, the hotter it
/// looks and the more every answer is worth, to make a long run feel worth it.
struct StreakMeter: View {
    let streak: Int
    @State private var pulsing = false

    private var level: Int {
        switch streak {
        case 0...2:   return 0
        case 3...4:   return 1
        case 5...9:   return 2
        case 10...14: return 3
        default:      return 4
        }
    }

    private var color: Color {
        switch level {
        case 0:  return .white.opacity(0.4)
        case 1:  return AppColor.starGold
        case 2:  return AppColor.flameOrange
        case 3:  return AppColor.gemPurple
        default: return Color(hex: "FF3B6B")   // on fire
        }
    }

    private var emoji: String {
        switch level {
        case 0:  return ""
        case 1:  return "🔥"
        case 2:  return "🔥🔥"
        case 3:  return "⚡"
        default: return "👑"
        }
    }

    private var multiplier: Int { RewardEngine.comboMultiplier(streak: streak) }

    var body: some View {
        HStack(spacing: 5) {
            if !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 15))
                    .scaleEffect(pulsing ? 1.2 : 1.0)
            }
            Text("\(streak)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            if multiplier > 1 {
                Text("×\(multiplier)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(color))
                    .scaleEffect(pulsing ? 1.12 : 1.0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
                .overlay(Capsule().stroke(color, lineWidth: 1.5))
        )
        .opacity(streak > 0 ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: streak)
        .onChange(of: streak) { _, _ in
            pulsing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { pulsing = false }
        }
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 20) {
            StreakMeter(streak: 0)
            StreakMeter(streak: 2)
            StreakMeter(streak: 4)
            StreakMeter(streak: 7)
            StreakMeter(streak: 12)
            StreakMeter(streak: 18)
        }
    }
    .environment(\.layoutDirection, .rightToLeft)
}
