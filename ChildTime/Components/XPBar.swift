import SwiftUI

struct XPBar: View {
    let level: Int
    let xp: Int
    let xpForCurrentLevel: Int
    let xpForNextLevel: Int

    var progress: Double {
        let range = max(1, xpForNextLevel - xpForCurrentLevel)
        let done = max(0, xp - xpForCurrentLevel)
        return min(1, Double(done) / Double(range))
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Text("רמה \(level)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
                Image(systemName: "sparkles")
                    .foregroundStyle(AppColor.starGold)
                    .font(.system(size: 12))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(AppGradient.gold)
                        .frame(width: geo.size.width * progress)
                        .glow(AppColor.starGold, radius: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
        }
        .frame(width: 120)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 20) {
            XPBar(level: 1, xp: 5, xpForCurrentLevel: 0, xpForNextLevel: 10)
            XPBar(level: 3, xp: 35, xpForCurrentLevel: 25, xpForNextLevel: 50)
            XPBar(level: 5, xp: 150, xpForCurrentLevel: 100, xpForNextLevel: 200)
        }
    }
    .environment(\.layoutDirection, .rightToLeft)
}
