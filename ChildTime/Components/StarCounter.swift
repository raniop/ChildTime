import SwiftUI

extension Int {
    /// Compact, readable balance label for HUD chips and stat cells.
    /// Exact under 1,000 ("850"), then abbreviated from the thousands up so a
    /// growing balance never overflows a chip: 1.2K · 2.5K · 104K · 1.3M · 3B.
    /// One decimal while the leading value is < 10 ("1.2K"), whole otherwise
    /// ("104K"). Always rounded DOWN (truncated) so the label never overstates
    /// what the child holds — 1,284,500 is "1.2M", not yet "1.3M". Stars never
    /// decrease, so this keeps the leaderboard rank legible years in.
    var currencyShort: String {
        let a = abs(self)
        if a < 1_000 { return "\(self)" }
        let sign = self < 0 ? "-" : ""
        func fmt(_ value: Double, _ suffix: String) -> String {
            if value < 10 {
                // Truncate to 1 decimal (e.g. 1.28 → "1.2"), dropping a trailing ".0".
                let t = (value * 10).rounded(.towardZero) / 10
                let s = String(format: "%.1f", t)
                return sign + (s.hasSuffix(".0") ? String(s.dropLast(2)) : s) + suffix
            }
            return sign + "\(Int(value.rounded(.towardZero)))" + suffix
        }
        if a < 1_000_000     { return fmt(Double(a) / 1_000, "K") }
        if a < 1_000_000_000 { return fmt(Double(a) / 1_000_000, "M") }
        return fmt(Double(a) / 1_000_000_000, "B")
    }

    /// The EXACT value with locale thousands separators ("1,284,500"). Used in
    /// the tap-to-explain popovers, where the chip itself shows `currencyShort`.
    var grouped: String { self.formatted(.number.grouping(.automatic)) }
}

struct StarCounter: View {
    let value: Int
    var icon: String = "star.fill"
    var color: Color = AppColor.starGold

    @State private var displayed: Int = 0
    @State private var pop: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .scaleEffect(pop ? 1.4 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: pop)
            Text("\(displayed)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.textPrimary)
                .numericTextTransition(Double(displayed))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .glow(color, radius: 10)
        .onAppear { displayed = value }
        .onChangeCompat(of: value) { _, new in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                displayed = new
            }
            pop = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { pop = false }
        }
    }
}

struct MinuteCounter: View {
    let minutes: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .foregroundStyle(AppColor.successMint)
            Text("\(minutes) דק׳")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.textPrimary)
                .numericTextTransition(Double(minutes))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .glow(AppColor.successMint, radius: minutes > 0 ? 12 : 0)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 20) {
            StarCounter(value: 47)
            StarCounter(value: 12, icon: "diamond.fill", color: AppColor.gemPurple)
            MinuteCounter(minutes: 8)
        }
    }
}
