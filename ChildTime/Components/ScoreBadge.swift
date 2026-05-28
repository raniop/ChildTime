import SwiftUI

/// The headline "ניקוד" pill — used everywhere we want to surface a score.
/// Two visual variants:
///   • `.lifetime` — gold-on-dark, with trophy. For WorldMap / progress.
///   • `.session`  — purple-on-dark, with sparkle. For the in-runner top bar.
struct ScoreBadge: View {
    enum Style { case lifetime, session }

    let value: Int
    var style: Style = .lifetime
    var compact: Bool = false

    private var emoji: String {
        switch style {
        case .lifetime: return "🏆"
        case .session:  return "✨"
        }
    }

    private var tint: Color {
        switch style {
        case .lifetime: return AppColor.starGold
        case .session:  return AppColor.companionGlow
        }
    }

    private var label: String {
        switch style {
        case .lifetime: return "ניקוד"
        case .session:  return "סבב"
        }
    }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            Text(emoji)
                .font(.system(size: compact ? 14 : 16))
            Text("\(value)")
                .font(.system(size: compact ? 14 : 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(value)))
            if !compact {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 5 : 7)
        .background(
            Capsule()
                .fill(.white.opacity(0.18))
                .overlay(Capsule().stroke(tint.opacity(0.55), lineWidth: 1.2))
        )
        .glow(tint.opacity(0.5), radius: compact ? 4 : 8)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 20) {
            ScoreBadge(value: 1247, style: .lifetime)
            ScoreBadge(value: 80, style: .session)
            ScoreBadge(value: 80, style: .session, compact: true)
        }
    }
    .environment(\.layoutDirection, .rightToLeft)
}
