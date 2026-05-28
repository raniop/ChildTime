import SwiftUI

struct StreakMeter: View {
    let streak: Int
    @State private var pulsing = false

    private var level: Int {
        switch streak {
        case 0...2: return 0
        case 3...4: return 1
        case 5...9: return 2
        default: return 3
        }
    }

    private var color: Color {
        switch level {
        case 0: return .white.opacity(0.4)
        case 1: return AppColor.starGold
        case 2: return AppColor.flameOrange
        default: return AppColor.gemPurple
        }
    }

    private var emoji: String {
        switch level {
        case 0: return ""
        case 1: return "🔥"
        case 2: return "🔥🔥"
        default: return "🔥🔥🔥"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 16))
                    .scaleEffect(pulsing ? 1.15 : 1.0)
            }
            Text("×\(streak)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
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
        }
    }
    .environment(\.layoutDirection, .rightToLeft)
}
