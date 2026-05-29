import SwiftUI

/// The motivational time HUD shown at the top of a question session. Keeps the
/// earned screen-time front-and-center and always answers the four questions a
/// kid cares about: how much did I earn today, how far to the next prize, to the
/// lucky wheel, and to my next level.
struct SessionProgressHUD: View {
    let earnedToday: Int
    let questionsUntilReward: Int
    let questionsUntilWheel: Int
    let questionsUntilLevel: Int
    let wheelReady: Bool
    /// In Free Learning mode there's no screen-time, so the 🎮 earned-today and
    /// 🚀 prize-countdown chips are hidden; progression chips remain.
    var showsEarn: Bool = true
    var compact: Bool = false

    private var chipFont: Font {
        .system(size: compact ? 12 : 14, weight: .bold, design: .rounded)
    }
    private var emojiSize: CGFloat { compact ? 15 : 18 }

    var body: some View {
        HStack(spacing: compact ? 6 : 10) {
            if showsEarn {
                // 🎮 Time earned today — the headline (Earn mode only).
                chip(
                    emoji: "🎮",
                    text: "היום \(earnedToday) דק׳",
                    tint: AppColor.successMint,
                    prominent: true
                )
                // 🚀 Questions to the next chest.
                chip(
                    emoji: "🚀",
                    text: rewardText,
                    tint: AppColor.flameOrange,
                    prominent: false
                )
            }
            // 🎁 Questions to the lucky wheel.
            chip(
                emoji: "🎁",
                text: wheelReady ? "גלגל מוכן!" : "גלגל ב-\(questionsUntilWheel)",
                tint: AppColor.gemPurple,
                prominent: wheelReady
            )
            // ⭐ Questions to the next level.
            chip(
                emoji: "⭐",
                text: "רמה ב-\(questionsUntilLevel)",
                tint: AppColor.starGold,
                prominent: false
            )
        }
    }

    private var rewardText: String {
        questionsUntilReward <= 0 ? "פרס!" : "פרס ב-\(questionsUntilReward)"
    }

    private func chip(emoji: String, text: String, tint: Color, prominent: Bool) -> some View {
        HStack(spacing: 4) {
            Text(emoji).font(.system(size: emojiSize))
            Text(text)
                .font(chipFont)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 5 : 7)
        .background(
            Capsule()
                .fill(.white.opacity(prominent ? 0.22 : 0.12))
                .overlay(Capsule().stroke(tint.opacity(prominent ? 0.7 : 0.3), lineWidth: prominent ? 2 : 1))
        )
        .glow(prominent ? tint : .clear, radius: prominent ? 8 : 0)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 20) {
            SessionProgressHUD(earnedToday: 18, questionsUntilReward: 7,
                               questionsUntilWheel: 3, questionsUntilLevel: 5, wheelReady: false)
            SessionProgressHUD(earnedToday: 24, questionsUntilReward: 0,
                               questionsUntilWheel: 0, questionsUntilLevel: 2, wheelReady: true, compact: true)
        }
        .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
